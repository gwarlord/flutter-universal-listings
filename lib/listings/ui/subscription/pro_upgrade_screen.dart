import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/entitlement_subscription.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/services/subscription_products.dart';
import 'package:caribtap/listings/services/subscription_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

class ProUpgradeScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const ProUpgradeScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final EntitlementService _entitlementService = EntitlementService();

  bool _isLoading = true;
  String? _errorMessage;
  List<ProductDetails> _products = const [];

  @override
  void initState() {
    super.initState();
    _subscriptionService.startListening(userId: widget.currentUser.userID);
    _loadProducts();
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
        print('⚠️ WARNING: No products loaded! Check Google Play Console configuration.');
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

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text('CaribTap Pro'.tr()),
        actions: [
          TextButton(
            onPressed: _restorePurchases,
            child: Text(
              'Restore'.tr(),
              style: TextStyle(color: Color(cfg.colorPrimary)),
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
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(theme, tier),
              const SizedBox(height: 20),
              _buildBenefits(theme, tier),
              const SizedBox(height: 24),
              ..._products.map((product) => _buildProductCard(theme, product)),
              const SizedBox(height: 20),
              _buildFooter(theme, entitlement),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, int tier) {
    final headline = tier > 0
        ? 'Current Tier: ${_tierLabel(tier)}'.tr()
        : 'Upgrade to CaribTap Pro'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Unlock premium tools for listings, rentals, and invoices.'.tr(),
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildBenefits(ThemeData theme, int tier) {
    final List<String> benefits = [
      'AI photo enhancement'.tr(),
      'Professional quotes'.tr(),
      'Invoices & receipts'.tr(),
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
              'You are currently on ${_tierLabel(tier)}.'.tr(),
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
                Text(
                  '${_tierLabel(tier)} ${label.isNotEmpty ? '- $label' : ''}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      return Text(
        'Your entitlement will appear here once verified.'.tr(),
        style: theme.textTheme.bodySmall,
      );
    }

    final expiresAt = entitlement.expiresAt;
    final expiresText = expiresAt != null
        ? DateFormat('yyyy-MM-dd').format(expiresAt)
        : 'No expiration'.tr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: ${entitlementStatusToString(entitlement.status)}'.tr(),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Expires: $expiresText'.tr(),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Auto-renew: ${entitlement.willRenew == true ? 'On' : 'Off'}'.tr(),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  String _tierLabel(int tier) {
    switch (tier) {
      case 1:
        return 'Tier 1';
      case 2:
        return 'Tier 2';
      case 3:
        return 'Tier 3';
      default:
        return 'Free';
    }
  }
}
