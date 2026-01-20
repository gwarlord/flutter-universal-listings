import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/revenue_cat_service.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Custom Paywall Screen with native Flutter UI
/// Fallback to custom UI since PaywallView has platform issues on some devices
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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Upgrade to CaribTap Pro'.tr()),
        ),
        body: const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Upgrade to CaribTap Pro'.tr()),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading subscription options'.tr(),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = false;
                    _errorMessage = null;
                  });
                  Navigator.pop(context, false);
                },
                child: Text('Retry'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // Custom Paywall UI
    return Scaffold(
      appBar: AppBar(
        title: Text('Upgrade to CaribTap Pro'.tr()),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Icon(Icons.star, size: 64, color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      'Unlock Premium Features'.tr(),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get access to booking services and more!'.tr(),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Benefits
              _buildBenefit('📅', 'Booking Services', 'Professional'),
              _buildBenefit('📊', 'Advanced Analytics', 'Premium'),
              _buildBenefit('⚡', 'Priority Support', 'Premium'),
              
              const SizedBox(height: 32),
              
              // Subscription Options
              Text(
                'Choose Your Plan'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Monthly Plan
              _buildPlanCard(
                'Monthly',
                '\$9.99',
                'per month',
                '\$rc_monthly',
              ),
              
              // Yearly Plan (Best Value)
              _buildPlanCard(
                'Yearly',
                '\$99.99',
                'per year',
                '\$rc_annual',
                isBestValue: true,
              ),
              
              // Lifetime Plan
              _buildPlanCard(
                'Lifetime',
                '\$299.99',
                'one-time',
                '\$rc_lifetime',
              ),
              
              const SizedBox(height: 20),
              
              // Restore Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _handleRestore,
                  child: Text('Restore Purchases'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(String icon, String title, String tier) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  tier,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String title, String price, String duration, String identifier, {bool isBestValue = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: isBestValue ? Color(colorPrimary) : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        color: isBestValue ? Color(colorPrimary).withOpacity(0.05) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (isBestValue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Best Value'.tr(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        price,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(colorPrimary)),
                      ),
                      Text(
                        duration,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(colorPrimary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _handlePurchase(identifier),
                child: const Text(
                  'Subscribe Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase(String packageIdentifier) async {
    try {
      setState(() => _isLoading = true);
      
      print('🔍 Fetching offerings for package: $packageIdentifier');
      
      // Ensure RevenueCat is initialized
      try {
        await Purchases.getCustomerInfo();
      } catch (e) {
        print('⚠️ RevenueCat not initialized, attempting initialization');
        try {
          await RevenueCatService().initialize(userId: widget.currentUser.userID);
        } catch (initError) {
          print('❌ Failed to initialize RevenueCat: $initError');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to initialize payment system. Please try again.';
          });
          return;
        }
      }
      
      final offerings = await RevenueCatService().getOfferings();
      
      if (offerings == null) {
        print('❌ Offerings is null');
        setState(() {
          _isLoading = false;
          _errorMessage = 'RevenueCat offerings not loaded. Please try again.';
        });
        return;
      }
      
      if (offerings.current == null) {
        print('❌ Current offering is null. Available offerings: ${offerings.all.length}');
        setState(() {
          _isLoading = false;
          _errorMessage = 'No subscription plans available. Please check RevenueCat configuration.';
        });
        return;
      }

      print('✅ Found ${offerings.current!.availablePackages.length} packages');
      
      final package = offerings.current!.availablePackages
          .firstWhere((p) => p.identifier == packageIdentifier);
      
      print('💳 Purchasing package: ${package.identifier}');
      final customerInfo = await RevenueCatService().purchasePackage(package);
      
      if (customerInfo != null && mounted) {
        // 🔄 Refresh user data from Firestore to get updated subscription
        await _refreshUserData();
        
        if (mounted) {
          print('✅ Subscription updated, navigating back to refresh UI');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome to CaribTap Pro!'.tr()),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Pop twice: close paywall, then close any parent screen to force rebuild
          Navigator.pop(context, true);
          // Give a moment for the Firestore update to fully propagate
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Purchase error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Purchase error: ${e.toString()}';
      });
    }
  }

  Future<void> _handleRestore() async {
    try {
      setState(() => _isLoading = true);
      
      final customerInfo = await Purchases.restorePurchases();
      
      final hasActiveSubscription = customerInfo
          .entitlements.all[RevenueCatService.caribTapProEntitlement]?.isActive ?? false;
      
      if (hasActiveSubscription) {
        // 🔄 Refresh user data from Firestore
        await _refreshUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription restored successfully!'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          print('✅ Subscription restored, navigating back');
          Navigator.pop(context, true);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No active subscription found to restore'.tr()),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Restore error: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      print('🔄 Refreshing user data from Firestore...');
      // Add small delay to ensure Firestore write is complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(widget.currentUser.userID)
          .get(GetOptions(source: Source.server)); // Force server read
      
      if (doc.exists && mounted) {
        final freshUser = ListingsUser.fromJson(doc.data()!);
        print('✅ User refreshed successfully');
        print('   Subscription Tier: ${freshUser.subscriptionTier}');
        print('   Expires: ${freshUser.subscriptionExpiresAt}');
        print('   RevenueCat ID: ${freshUser.revenueCatCustomerId}');
        
        // Update the auth bloc with fresh user data
        context.read<AuthenticationBloc>().user = freshUser;
        
        // Also update the widget's current user for context
        widget.currentUser.subscriptionTier = freshUser.subscriptionTier;
        widget.currentUser.subscriptionExpiresAt = freshUser.subscriptionExpiresAt;
        widget.currentUser.revenueCatCustomerId = freshUser.revenueCatCustomerId;
      } else {
        print('❌ User document not found in Firestore');
      }
    } catch (e) {
      print('❌ Error refreshing user: $e');
      print('❌ Stack: ${StackTrace.current}');
    }
  }
}
