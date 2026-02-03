import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/revenue_cat_service.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Custom Paywall Screen with native Flutter UI
/// Professional and confidence-inspiring design
class PaywallScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final String? offeringIdentifier;
  
  const PaywallScreen({
    super.key,
    required this.currentUser,
    this.offeringIdentifier,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Offering? _currentOffering;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Ensure RevenueCat is initialized
      try {
        await Purchases.getCustomerInfo();
      } catch (e) {
        await RevenueCatService().initialize(userId: widget.currentUser.userID);
      }

      final offerings = await RevenueCatService().getOfferings();
      
      if (offerings == null) {
        throw Exception('Failed to load offerings. Please check your internet connection.');
      }

      if (offerings.current == null) {
        throw Exception('No subscription plans configured.');
      }

      if (!mounted) return;
      setState(() {
        _currentOffering = offerings.current;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('CaribTap Pro'.tr()),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('CaribTap Pro'.tr()),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(height: 16),
              Text(
                'Something went wrong'.tr(),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadOfferings,
                child: Text('Retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('CaribTap Pro'.tr()),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _handleRestore,
            child: Text(
              'Restore'.tr(),
              style: TextStyle(color: Color(colorPrimary), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(colorPrimary).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user_rounded, size: 48, color: Color(colorPrimary)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Upgrade to CaribTap Pro'.tr(),
                    style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Experience the full potential of CaribTap with exclusive features designed for professionals.'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyMedium?.color),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Features Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildBenefit(theme, Icons.calendar_today_rounded, 'Booking Services', 'Enable clients to book your services directly.'),
                  _buildBenefit(theme, Icons.analytics_outlined, 'Advanced Analytics', 'Gain insights into your listing performance.'),
                  _buildBenefit(theme, Icons.verified_rounded, 'Pro Badge', 'Stand out with a professional badge on your profile.'),
                  _buildBenefit(theme, Icons.support_agent_rounded, 'Priority Support', 'Get help from our dedicated support team faster.'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Subscription Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      'Choose Your Plan'.tr(),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_currentOffering != null)
                    ..._buildPackageCards(context, _currentOffering!),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Confidence/Security Indicators
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 8),
                      Text(
                        'Secure Payment via App Store'.tr(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subscriptions will automatically renew. Cancel anytime in your account settings.'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Legal Links
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    TextSpan(
                      text: 'Privacy Policy'.tr(),
                      style: TextStyle(color: Color(colorPrimary), fontWeight: FontWeight.w600),
                      recognizer: TapGestureRecognizer()..onTap = () => _launchURL(privacyPolicyURL),
                    ),
                    const TextSpan(text: '  •  '),
                    TextSpan(
                      text: 'Terms of Use'.tr(),
                      style: TextStyle(color: Color(colorPrimary), fontWeight: FontWeight.w600),
                      recognizer: TapGestureRecognizer()..onTap = () => _launchURL(eula),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(ThemeData theme, IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(colorPrimary).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Color(colorPrimary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPackageCards(BuildContext context, Offering offering) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final packages = offering.availablePackages;
    
    return packages.asMap().entries.map((entry) {
      final package = entry.value;
      final isBestValue = package.packageType == PackageType.annual;
      final duration = _getPackageDuration(package);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isBestValue ? Color(colorPrimary) : theme.dividerColor,
            width: isBestValue ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isBestValue ? Color(colorPrimary).withOpacity(0.05) : theme.cardColor,
          boxShadow: [
            if (isBestValue)
              BoxShadow(
                color: Color(colorPrimary).withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: InkWell(
          onTap: () => _handlePurchasePackage(package),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isBestValue)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color(colorPrimary),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BEST VALUE'.tr().toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          Text(
                            package.storeProduct.title,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            duration.tr(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      package.storeProduct.priceString,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isBestValue ? Color(colorPrimary) : theme.textTheme.headlineSmall?.color
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBestValue ? Color(colorPrimary) : colorScheme.onBackground,
                      foregroundColor: isBestValue ? Colors.white : colorScheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _handlePurchasePackage(package),
                    child: Text(
                      'Select Plan'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  String _getPackageDuration(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return 'Monthly Subscription';
      case PackageType.annual:
        return 'Yearly Subscription';
      case PackageType.lifetime:
        return 'One-time Payment';
      case PackageType.weekly:
        return 'Weekly Subscription';
      case PackageType.sixMonth:
        return '6 Months Subscription';
      case PackageType.threeMonth:
        return '3 Months Subscription';
      case PackageType.twoMonth:
        return '2 Months Subscription';
      default:
        return 'Subscription';
    }
  }

  Future<void> _handlePurchasePackage(Package package) async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      print('💳 Purchasing package: ${package.identifier}');
      final customerInfo = await RevenueCatService().purchasePackage(package);
      
      if (customerInfo != null && mounted) {
        await _refreshUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome to CaribTap Pro! 🎉'.tr())));
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Purchase failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handleRestore() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final customerInfo = await Purchases.restorePurchases();
      final hasActiveSubscription = customerInfo.entitlements.all[RevenueCatService.caribTapProEntitlement]?.isActive ?? false;
      
      if (hasActiveSubscription) {
        await _refreshUserData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subscription restored!'.tr())));
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No active subscription found.'.tr())));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(widget.currentUser.userID)
          .get(const GetOptions(source: Source.server));
      
      if (doc.exists && mounted) {
        final freshUser = ListingsUser.fromJson(doc.data()!);
        context.read<AuthenticationBloc>().add(UpdateAuthUserEvent(freshUser));
      }
    } catch (e) {
      print('Error refreshing user: $e');
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
