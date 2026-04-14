import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/entitlement_subscription.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/services/subscription_products.dart';
import 'package:caribtap/listings/services/subscription_service.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ProUpgradeScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final int? initialTier;

  const ProUpgradeScreen({
    super.key,
    required this.currentUser,
    this.initialTier,
  });

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final EntitlementService _entitlementService = EntitlementService();

  bool _isLoading = true;
  bool _isClaimingTrial = false;
  bool _isLoadingTrialConfig = false;
  bool _trialEnabled = true;
  bool _trialRequiresPhoneVerified = false;
  String? _errorMessage;
  List<ProductDetails> _products = const [];
  int? _selectedTier;

  bool get _isApplePlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _subscriptionService.startListening(userId: widget.currentUser.userID);
    _selectedTier = widget.initialTier;
    _loadTrialConfig();
    _loadProducts();
  }

  @override
  void dispose() {
    _subscriptionService.stopListening();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📱 Checking store availability...');
      final available = await _subscriptionService.isAvailable();
      if (!available) {
        throw Exception('Store not available'.tr());
      }

      print('📱 Store available, loading products...');
      final products = await _subscriptionService.loadProducts();
      print('📱 Loaded ${products.length} products');
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      setState(() {
        _products = products;
        _isLoading = false;
      });

      if (products.isEmpty) {
        final store = _isApplePlatform ? 'App Store Connect' : 'Google Play Console';
        print('⚠️ WARNING: No products loaded! Check $store configuration.');
      }
    } catch (e) {
      print('❌ Error loading products: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    await _subscriptionService.restorePurchases();
  }

  Future<void> _openManageSubscriptions() async {
    final uri = Uri.parse(
      _isApplePlatform
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      showSnackBar(
        context,
        (_isApplePlatform
                ? 'Unable to open App Store subscriptions'
                : 'Unable to open Google Play subscriptions')
            .tr(),
      );
    }
  }

  Future<void> _loadTrialConfig() async {
    setState(() => _isLoadingTrialConfig = true);
    try {
      final config = await _subscriptionService.getProfessionalTrialConfig();
      if (!mounted) return;
      setState(() {
        _trialEnabled = config['enabled'] == true;
        _trialRequiresPhoneVerified = config['requiresPhoneVerified'] == true;
      });
    } catch (_) {
      // Fail open for growth mode; claim callable still enforces server policy.
      if (!mounted) return;
      setState(() {
        _trialEnabled = true;
        _trialRequiresPhoneVerified = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrialConfig = false);
      }
    }
  }

  Future<void> _claimProfessionalTrial() async {
    if (_isClaimingTrial) {
      return;
    }

    if (_trialRequiresPhoneVerified && widget.currentUser.phoneVerified != true) {
      showSnackBar(context, 'Phone verification is required to claim this trial.'.tr());
      return;
    }

    setState(() => _isClaimingTrial = true);
    try {
      final result = await _subscriptionService.claimProfessionalTrial();
      final userDoc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(widget.currentUser.userID)
          .get();
      if (userDoc.exists && mounted) {
        final freshUser = ListingsUser.fromJson(userDoc.data()!);
        context.read<AuthenticationBloc>().add(UpdateAuthUserEvent(freshUser));
      }
      if (!mounted) return;
      final expiresAt = result['expiresAt']?.toString();
      final message = expiresAt != null && expiresAt.isNotEmpty
          ? 'Your 30-day Professional trial is now active until {}.'.tr(
              args: [expiresAt.split('T').first],
            )
          : 'Your 30-day Professional trial is now active.'.tr();
      showSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      final message = error is FirebaseFunctionsException
          ? (error.message ?? 'Unable to start free trial.'.tr())
          : 'Unable to start free trial.'.tr();
      showSnackBar(context, message);
    } finally {
      if (mounted) {
        setState(() => _isClaimingTrial = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Color(cfg.colorPrimary),
        foregroundColor: Colors.white,
        title: Text('CaribTap Subscriptions'.tr()),
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Restore'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? _buildError(theme)
              : _buildBody(theme),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text('Unable to load plans'.tr(), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadProducts,
            child: Text('Retry'.tr()),
          ),
          if (widget.currentUser.subscriptionTier.toLowerCase() == 'free' && _trialEnabled) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: (_isClaimingTrial || _isLoadingTrialConfig)
                  ? null
                  : _claimProfessionalTrial,
              child: Text('Start Free 30 Days'.tr()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return StreamBuilder<EntitlementSubscription?>(
      stream: _entitlementService.watchEntitlement(widget.currentUser.userID),
      builder: (context, snapshot) {
        final entitlement = snapshot.data;
        final tier = ProGate.resolveTier(
          entitlement: entitlement,
          isAdmin: widget.currentUser.isAdmin,
        );

        return RefreshIndicator(
          onRefresh: _loadProducts,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              _buildHeader(theme, tier),
              if (tier == 0 && _trialEnabled) ...[
                const SizedBox(height: 16),
                _buildTrialCard(theme),
              ],
              const SizedBox(height: 20),
              _buildPlanSection(
                theme,
                tier: 2,
                currentTier: tier,
                products: _productsForTier(2),
              ),
              const SizedBox(height: 16),
              _buildPlanSection(
                theme,
                tier: 3,
                currentTier: tier,
                products: _productsForTier(3),
              ),
              const SizedBox(height: 20),
              _buildFooter(theme, entitlement),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, int tier) {
    final tierName = _tierLabel(tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tier > 0)
          RichText(
            text: TextSpan(
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: 'Current plan: '.tr()),
                TextSpan(
                  text: tierName.tr(),
                  style: TextStyle(color: _tierColor(tier)),
                ),
              ],
            ),
          )
        else
          Text(
            'Choose a plan'.tr(),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: 'Pick '.tr()),
              TextSpan(
                text: 'Professional'.tr(),
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' or '.tr()),
              TextSpan(
                text: 'Premium'.tr(),
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' to unlock business tools.'.tr()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrialCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(cfg.colorPrimary).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(cfg.colorPrimary).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start with 30 days free'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Claim one free 30-day Professional trial to explore business tools before subscribing.'.tr(),
            style: theme.textTheme.bodySmall,
          ),
          if (_trialRequiresPhoneVerified && widget.currentUser.phoneVerified != true) ...[
            const SizedBox(height: 8),
            Text(
              'Phone verification is required to claim this trial.'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isClaimingTrial || _isLoadingTrialConfig)
                  ? null
                  : _claimProfessionalTrial,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(cfg.colorPrimary),
                foregroundColor: Colors.white,
              ),
              child: _isClaimingTrial
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Start Free 30 Days'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  List<ProductDetails> _productsForTier(int tier) {
    final products = _products
        .where((product) {
          final definition = productDefinitionForId(product.id);
          final productTier = definition?.tier ?? tierForProductId(product.id);
          return productTier == tier;
        })
        .toList();

    products.sort((a, b) {
      final aDef = productDefinitionForId(a.id);
      final bDef = productDefinitionForId(b.id);
      final aLabel = aDef?.billingPeriodLabel ?? '';
      final bLabel = bDef?.billingPeriodLabel ?? '';
      final aOrder = aLabel.toLowerCase() == 'monthly' ? 0 : 1;
      final bOrder = bLabel.toLowerCase() == 'monthly' ? 0 : 1;
      return aOrder.compareTo(bOrder);
    });

    return products;
  }

  String _planDescription(int tier) {
    for (final product in subscriptionProducts) {
      if (product.tier == tier) {
        return product.description;
      }
    }
    return '';
  }

  List<String> _planBenefits(int tier) {
    final professionalBenefits = [
      'Create listings for sales, rentals, bookings, and events'.tr(),
      'Boost listing quality with AI-enhanced photos'.tr(),
      'Activate customer chat and manage blocked users'.tr(),
      'Manage bookings and rentals from one place'.tr(),
      'Access analytics to track performance'.tr(),
      'Post deals and promotions'.tr(),
      'Accept proof of payment on eligible listings'.tr(),
    ];

    if (tier == 3) {
      return [
        'Everything in Professional'.tr(),
        'Create your own Mini Store with internal catalog'.tr(),
        'Accept and manage customer orders'.tr(),
        'Generate quotes and invoices'.tr(),
        'Access advanced analytics'.tr(),
        'Unlock stronger commerce tools for structured selling'.tr(),
      ];
    }

    return professionalBenefits;
  }

  Widget _buildPlanSection(
    ThemeData theme, {
    required int tier,
    required int currentTier,
    required List<ProductDetails> products,
  }) {
    final label = _tierLabel(tier).tr();
    final isSelected = _selectedTier == tier;
    final isCurrent = currentTier == tier;
    final description = _planDescription(tier);
    final benefits = _planBenefits(tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Color(cfg.colorPrimary) : theme.dividerColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _tierColor(tier),
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Current plan'.tr(),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(cfg.colorPrimary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...products.map((product) => _buildProductCard(theme, product)),
        ],
      ),
    );
  }

  Widget _buildBenefits(ThemeData theme, int tier) {
    final List<String> benefits = [
      'AI photo enhancement'.tr(),
      'Quotes & invoices tools'.tr(),
      'Watermarking tools'.tr(),
      'Priority support'.tr(),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Benefits'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Color(cfg.colorPrimary)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          ),
          if (tier > 0) ...[
            const SizedBox(height: 8),
            Text(
              'You are currently on {}.'.tr(args: [_tierLabel(tier).tr()]),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, ProductDetails product) {
    final definition = productDefinitionForId(product.id);
    final tier = definition?.tier ?? tierForProductId(product.id);
    final label = definition?.billingPeriodLabel ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: _tierLabel(tier).tr(),
                        style: TextStyle(color: _tierColor(tier)),
                      ),
                      if (label.isNotEmpty)
                        TextSpan(text: ' - ${label.tr()}'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description.isNotEmpty
                      ? product.description
                      : (definition?.description ?? ''),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                product.price,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _subscriptionService.purchase(product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(cfg.colorPrimary),
                  foregroundColor: Colors.white,
                ),
                child: Text('Subscribe'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ThemeData theme, EntitlementSubscription? entitlement) {
    if (entitlement == null) {
      return const SizedBox.shrink();
    }

    final expiresAt = entitlement.expiresAt;
    final expiresText = expiresAt != null
        ? DateFormat('yyyy-MM-dd').format(expiresAt)
        : 'No expiration'.tr();
    final statusText = entitlementStatusToString(entitlement.status);
    final autoRenewText = entitlement.willRenew == true ? 'On'.tr() : 'Off'.tr();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status: {}'.tr(args: [statusText]),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Expires: {}'.tr(args: [expiresText]),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-renew: {}'.tr(args: [autoRenewText]),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openManageSubscriptions,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
              foregroundColor: Color(cfg.colorPrimary),
            ),
            child: Text(
                (_isApplePlatform
                      ? 'Manage subscription in App Store'
                      : 'Manage subscription in Google Play')
                  .tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Color(cfg.colorPrimary),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 1:
        return 'Professional';
      case 2:
        return 'Professional';
      case 3:
        return 'Premium';
      default:
        return 'Free';
    }
  }

  Color _tierColor(int tier) {
    switch (tier) {
      case 2:
      case 1:
        return Colors.blue;
      case 3:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
