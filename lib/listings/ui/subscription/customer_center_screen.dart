import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/revenue_cat_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Customer Center Screen using RevenueCat's Customer Center
/// Allows users to manage their subscription, view billing info, and contact support
class CustomerCenterScreen extends StatefulWidget {
  final ListingsUser currentUser;
  
  const CustomerCenterScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<CustomerCenterScreen> createState() => _CustomerCenterScreenState();
}

class _CustomerCenterScreenState extends State<CustomerCenterScreen> {
  bool _isLoading = true;
  CustomerInfo? _customerInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final customerInfo = await RevenueCatService().getCustomerInfo();
      setState(() {
        _customerInfo = customerInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Subscription'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildCustomerCenterView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading subscription info'.tr(),
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
                _isLoading = true;
                _errorMessage = null;
              });
              _loadCustomerInfo();
            },
            child: Text('Retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCenterView() {
    final hasActiveSubscription = _customerInfo != null &&
        _customerInfo!.entitlements.all[RevenueCatService.caribTapProEntitlement]?.isActive == true;

    if (!hasActiveSubscription) {
      // User doesn't have an active subscription
      return _buildNoSubscriptionView();
    }

    // Display RevenueCat's Customer Center UI
    return CustomerCenterView(
      // Callback when user wants to restore purchases
      onRestoreCompleted: (CustomerInfo customerInfo) {
        print('✅ Purchases restored in Customer Center');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription restored!'.tr()),
              backgroundColor: Colors.green,
            ),
          );
          
          // Reload customer info
          _loadCustomerInfo();
        }
      },
    );
  }

  Widget _buildNoSubscriptionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Subscription'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You don\'t have an active CaribTap Pro subscription yet.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.star),
              label: Text('Upgrade to Pro'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                // Navigate to paywall (handled by caller)
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                // Restore purchases
                try {
                  final customerInfo = await RevenueCatService().restorePurchases();
                  
                  if (customerInfo != null &&
                      customerInfo.entitlements.all[RevenueCatService.caribTapProEntitlement]?.isActive == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Subscription restored!'.tr()),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadCustomerInfo();
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No subscription found to restore'.tr()),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Restore failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text('Restore Purchases'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
