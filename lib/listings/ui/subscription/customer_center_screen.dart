import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/revenue_cat_service.dart';
import 'package:instaflutter/listings/ui/subscription/paywall_screen.dart';
import 'package:intl/intl.dart';
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
  bool _isSavingReminder = false;
  CustomerInfo? _customerInfo;
  String? _errorMessage;
  int _reminderDays = 3;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  List<_SubscriptionHistoryItem> _history = const [];

  @override
  void initState() {
    super.initState();
    _reminderDays = widget.currentUser.settings.subscriptionReminderDays;
    _loadCustomerInfo();
    _loadReminderSetting();
  }

  Future<void> _syncSubscriptionFromRevenueCat() async {
    try {
      print('🔄 Manual sync: Fetching customer info from RevenueCat...');
      
      // Ensure RevenueCat is initialized
      await RevenueCatService().initialize(userId: widget.currentUser.userID);
      
      // Invalidate cache to get fresh data
      await Purchases.invalidateCustomerInfoCache();
      
      // Get fresh customer info
      final customerInfo = await Purchases.getCustomerInfo();
      
      print('📊 Customer Info received');
      print('   Entitlements: ${customerInfo.entitlements.all.keys.toList()}');
      
      // Manually call the update method to sync to Firestore
      final tier = await RevenueCatService().getSubscriptionTier();
      print('📊 Determined tier: $tier');
      
      DateTime? expiresAt;
      if (customerInfo.entitlements.all.isNotEmpty) {
        final activeEntitlement = customerInfo.entitlements.all.values
            .firstWhere((e) => e.isActive, orElse: () => customerInfo.entitlements.all.values.first);
        
        if (activeEntitlement.expirationDate != null) {
          expiresAt = DateTime.parse(activeEntitlement.expirationDate!);
          print('📅 Expires: $expiresAt');
        }
      }
      
      // Update Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.userID)
          .update({
        'subscriptionTier': tier,
        'subscriptionExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      });
      
      print('✅ Firestore updated successfully');
      
      // Reload the screen
      await _loadCustomerInfo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription synced successfully!'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      // Ensure RevenueCat is initialized
      await RevenueCatService().initialize(userId: widget.currentUser.userID);
      
      // Force invalidate cache to get fresh customer info from RevenueCat servers
      // This is important after purchases to get updated expiration dates
      await Purchases.invalidateCustomerInfoCache();
      
      // Also refresh the user data from Firestore to get the updated subscription info
      // RevenueCat might be slow to sync in test environment, but Firestore has it immediately
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.userID)
          .get();
      
      if (userDoc.exists && mounted) {
        final updatedUser = ListingsUser.fromJson(userDoc.data()!);
        widget.currentUser.subscriptionTier = updatedUser.subscriptionTier;
        widget.currentUser.subscriptionExpiresAt = updatedUser.subscriptionExpiresAt;
        
        // Trigger immediate rebuild with updated user data before fetching RevenueCat
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      
      final customerInfo = await RevenueCatService().getCustomerInfo();
      if (mounted) {
        setState(() {
          _customerInfo = customerInfo;
          _history = _buildHistory(customerInfo);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadReminderSetting() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.userID)
          .get();
      final data = snap.data();
      final settings = data?['settings'] as Map<String, dynamic>?;
      final storedDays = settings?['subscriptionReminderDays'];
      int parsedDays = _reminderDays;
      if (storedDays is num) {
        parsedDays = storedDays.toInt();
      } else if (storedDays is String) {
        parsedDays = int.tryParse(storedDays) ?? _reminderDays;
      }
      setState(() => _reminderDays = parsedDays);
    } catch (_) {
      // Ignore read errors; keep defaults
    }
  }

  Future<void> _updateReminderDays(int days) async {
    setState(() => _isSavingReminder = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.userID)
          .set({
        'settings': {
          'allowPushNotifications': widget.currentUser.settings.allowPushNotifications,
          'subscriptionReminderDays': days,
        }
      }, SetOptions(merge: true));
      setState(() => _reminderDays = days);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder preference updated'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update reminder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Subscription'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Subscription',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _syncSubscriptionFromRevenueCat();
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      backgroundColor: dark ? Colors.grey[900] : Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? _buildErrorView(dark)
              : _buildCustomerCenterView(),
    );
  }

  Widget _buildErrorView(bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading subscription info'.tr(),
            style: TextStyle(fontSize: 18, color: dark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600]),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entitlement = _customerInfo?.entitlements.all[RevenueCatService.caribTapProEntitlement];
    
    // Check if subscription is active based on Firestore data (more reliable after purchases)
    final hasActiveSubscription = widget.currentUser.isSubscriptionActive;

    if (!hasActiveSubscription) {
      // User doesn't have an active subscription
      return _buildNoSubscriptionView();
    }

    final currentPlan = entitlement?.productIdentifier ?? widget.currentUser.subscriptionTier;
    
    // Prefer Firestore expiration over RevenueCat's potentially stale entitlement
    // Firestore is updated immediately by webhooks, RevenueCat might be cached/delayed
    DateTime? expiresAt;
    if (widget.currentUser.subscriptionExpiresAt != null) {
      expiresAt = widget.currentUser.subscriptionExpiresAt;
    } else if (entitlement?.expirationDate != null) {
      expiresAt = DateTime.tryParse(entitlement!.expirationDate!);
    }

    return SingleChildScrollView(
      child: Container(
        color: dark ? Colors.grey[900] : Colors.white,
        child: Column(
          children: [
            _buildSummaryCard(currentPlan, expiresAt),
            const SizedBox(height: 12),
            _buildReminderCard(),
            const SizedBox(height: 12),
            _buildHistoryCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSubscriptionView() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_membership,
              size: 80,
              color: dark ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Subscription'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You don\'t have an active CaribTap Pro subscription yet.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: dark ? Colors.grey[400] : Colors.grey[600],
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
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PaywallScreen(currentUser: widget.currentUser),
                  ),
                );
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

  Widget _buildSummaryCard(String? currentPlan, DateTime? expiresAt) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final planLabel = (currentPlan ?? widget.currentUser.subscriptionTier).toUpperCase();
    final expiryLabel = expiresAt != null ? _dateFormat.format(expiresAt) : '—';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: dark ? Colors.grey[900] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Plan'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text(planLabel, style: TextStyle(fontSize: 14, color: dark ? Colors.white70 : Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text('Renew'.tr()),
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaywallScreen(currentUser: widget.currentUser),
                      ),
                    );
                    
                    // If purchase was successful, reload subscription data
                    if (result == true && mounted) {
                      await Future.delayed(const Duration(milliseconds: 500));
                      await _loadCustomerInfo();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: dark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 8),
                Text('${'Expires'.tr()}: $expiryLabel', style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final options = <int>[0, 1, 3, 7, 14];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: dark ? Colors.grey[900] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expiration Reminder'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dark ? Colors.white : Colors.black)),
                if (_isSavingReminder) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Email + push reminder before your plan expires.'.tr(), style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[700])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: options.map((d) {
                final selected = d == _reminderDays;
                return ChoiceChip(
                  label: Text(
                    d == 0 ? 'Off'.tr() : '${d}d',
                    style: TextStyle(
                      color: selected && dark ? Colors.white : (dark ? Colors.white70 : Colors.black87),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: selected,
                  selectedColor: Color(0xFF5B6EFF),
                  backgroundColor: dark ? Colors.grey[800] : Colors.grey[200],
                  labelStyle: const TextStyle(fontSize: 12),
                  onSelected: (val) {
                    if (!val) return;
                    _updateReminderDays(d);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: dark ? Colors.grey[900] : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Subscription History'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dark ? Colors.white : Colors.black)),
          ),
          Divider(height: 1, color: dark ? Colors.grey[800] : Colors.grey[300]),
          if (_history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _isLoading ? 'Loading history...'.tr() : 'No subscription history found yet.'.tr(),
                style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600]),
              ),
            )
          else
            ..._history.map((item) => ListTile(
                  leading: Icon(
                    item.status == 'active' ? Icons.check_circle : Icons.history,
                    color: item.status == 'active' ? Colors.green : (dark ? Colors.grey[600] : Colors.grey),
                  ),
                  title: Text(item.productId ?? 'Unknown', style: TextStyle(color: dark ? Colors.white : Colors.black)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.purchasedAt != null)
                        Text('${'Purchased'.tr()}: ${_dateFormat.format(item.purchasedAt!)}', style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600])),
                      if (item.expiresAt != null)
                        Text('${'Expires'.tr()}: ${_dateFormat.format(item.expiresAt!)}', style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600])),
                      if (item.price != null)
                        Text('${'Price'.tr()}: ${item.price}', style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600])),
                      Text('${'Store'.tr()}: ${item.store ?? '—'}', style: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600])),
                    ],
                  ),
                  trailing: Text(
                    item.status == 'active' 
                      ? 'ACTIVE'.tr() 
                      : 'LAST CHARGE'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: item.status == 'active' ? Colors.green : (dark ? Colors.grey[500] : Colors.grey[700]),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  List<_SubscriptionHistoryItem> _buildHistory(CustomerInfo? info) {
    if (info == null) return const [];
    final List<_SubscriptionHistoryItem> entries = [];

    // Active entitlement (current plan) - always show this first
    final ent = info.entitlements.all[RevenueCatService.caribTapProEntitlement];
    if (ent != null) {
      // Use Firestore expiration date if available (more up-to-date after purchases)
      // Otherwise fall back to RevenueCat entitlement expiration
      DateTime? expiresAt;
      if (widget.currentUser.subscriptionExpiresAt != null) {
        expiresAt = widget.currentUser.subscriptionExpiresAt;
      } else if (ent.expirationDate != null) {
        expiresAt = DateTime.tryParse(ent.expirationDate!);
      }
      
      entries.add(_SubscriptionHistoryItem(
        productId: ent.productIdentifier,
        purchasedAt: ent.latestPurchaseDate != null ? DateTime.tryParse(ent.latestPurchaseDate!) : null,
        expiresAt: expiresAt,
        store: ent.store.name,
        status: ent.isActive ? 'active' : 'expired',
        price: null, // Price not directly available in entitlement
      ));
    }

    // Add the most recent one-time purchase/transaction as "Last Charge" if available
    if (info.nonSubscriptionTransactions.isNotEmpty) {
      final t = info.nonSubscriptionTransactions.first;
      entries.add(_SubscriptionHistoryItem(
        productId: t.productIdentifier,
        purchasedAt: DateTime.tryParse(t.purchaseDate),
        expiresAt: null,
        store: 'In-App',
        status: 'last_charge',
        price: null, // Price not available in StoreTransaction
      ));
    }

    return entries;
  }
}

class _SubscriptionHistoryItem {
  final String? productId;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;
  final String? store;
  final String status;
  final String? price;

  const _SubscriptionHistoryItem({
    required this.productId,
    required this.purchasedAt,
    required this.expiresAt,
    required this.store,
    required this.status,
    this.price,
  });
}
