import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/listings_app_config.dart';

class SubscriptionScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const SubscriptionScreen({super.key, required this.currentUser});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  String _selectedBillingPeriod = 'monthly'; // monthly or yearly

  final List<Map<String, dynamic>> _tiers = [
    {
      'name': 'Free',
      'tier': 'free',
      'monthlyPrice': 0,
      'yearlyPrice': 0,
      'color': Colors.grey,
      'features': [
        'Create up to 3 listings',
        'Basic listing management',
        'Standard search visibility',
        'Community support',
      ],
    },
    {
      'name': 'Professional',
      'tier': 'professional',
      'monthlyPrice': 19.99,
      'yearlyPrice': 199.99,
      'color': Colors.blue,
      'popular': true,
      'features': [
        'Unlimited listings',
        'Booking services integration',
        'Priority search visibility',
        'Advanced listing customization',
        'Email support',
        'Analytics dashboard',
      ],
    },
    {
      'name': 'Premium',
      'tier': 'premium',
      'monthlyPrice': 39.99,
      'yearlyPrice': 399.99,
      'color': Colors.purple,
      'features': [
        'Everything in Professional',
        'Featured listings placement',
        'Advanced analytics & insights',
        'Priority 24/7 support',
        'White-label customization',
        'API access',
        'Dedicated account manager',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Your Plan'.tr()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Unlock Premium Features'.tr(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Choose the perfect plan for your business'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Billing period toggle
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: dark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBillingToggle('Monthly', 'monthly', dark),
                        _buildBillingToggle('Yearly (Save 17%)', 'yearly', dark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Subscription tiers
                  ..._tiers.map((tier) => _buildTierCard(tier, dark)),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildBillingToggle(String label, String value, bool dark) {
    final isSelected = _selectedBillingPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedBillingPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(colorPrimary)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.tr(),
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (dark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier, bool dark) {
    final isCurrentPlan = widget.currentUser.subscriptionTier.toLowerCase() == tier['tier'];
    final isPopular = tier['popular'] == true;
    final price = _selectedBillingPeriod == 'monthly'
        ? tier['monthlyPrice']
        : tier['yearlyPrice'];
    final pricePerMonth = _selectedBillingPeriod == 'yearly'
        ? (tier['yearlyPrice'] / 12).toStringAsFixed(2)
        : price.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPopular
              ? tier['color']
              : (dark ? Colors.grey[700]! : Colors.grey[300]!),
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: dark ? Colors.grey[900] : Colors.white,
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: tier['color'],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Text(
                'MOST POPULAR'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier['name'].tr(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (tier['tier'] == 'free')
                          Text(
                            'Free Forever'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              color: dark ? Colors.white70 : Colors.black54,
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$$pricePerMonth',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: tier['color'],
                                ),
                              ),
                              Text(
                                '/mo',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: dark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (isCurrentPlan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Current Plan'.tr(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ...List.generate(
                  tier['features'].length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: tier['color'],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tier['features'][index].tr(),
                            style: TextStyle(
                              fontSize: 14,
                              color: dark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrentPlan
                          ? (dark ? Colors.grey[700] : Colors.grey[300])
                          : tier['color'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isCurrentPlan
                        ? null
                        : () => _handleSubscribe(tier['tier'], price),
                    child: Text(
                      isCurrentPlan
                          ? 'Current Plan'.tr()
                          : (tier['tier'] == 'free'
                              ? 'Downgrade'.tr()
                              : 'Subscribe Now'.tr()),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscribe(String tier, double price) async {
    if (tier == 'free') {
      // Handle downgrade
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Downgrade'.tr()),
          content: Text(
            'Are you sure you want to downgrade to the Free plan? You will lose access to premium features.'.tr(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Downgrade'.tr()),
            ),
          ],
        ),
      );

      if (confirm == true) {
        // TODO: Handle downgrade logic
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downgrade feature coming soon!'.tr())),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Integrate with RevenueCat payment flow
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing will be integrated with RevenueCat'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
