import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  // Entitlement identifier - MUST match exactly what you set up in RevenueCat dashboard
  static const String caribTapProEntitlement = 'CaribTap Pro';
  
  // Product identifiers
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';

  // API Keys - Replace these with your PUBLIC SDK KEYS from RevenueCat Dashboard
  // These will NOT charge real money in Sandbox/Test environments (TestFlight, Android Alpha/Beta)
  static const String _androidApiKey = 'test_HlFlRPeoSwcyoKewtdDNaMiGCLy';
  static const String _iosApiKey = 'test_HlFlRPeoSwcyoKewtdDNaMiGCLy';

  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isConfigured = false;

  /// Initialize RevenueCat SDK
  Future<void> initialize({required String userId}) async {
    if (_isConfigured) return;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;
      
      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey)
        ..appUserID = userId;
      
      await Purchases.configure(configuration);
      await Purchases.logIn(userId);
      
      _isConfigured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } catch (e) {
      print('❌ RevenueCat initialization error: $e');
      rethrow;
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo customerInfo) async {
    try {
      await _updateUserSubscription(customerInfo.originalAppUserId, customerInfo);
    } catch (e) {
      print('❌ Error updating customer info: $e');
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('❌ Error fetching offerings: $e');
      return null;
    }
  }

  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;
      await _updateUserSubscription(customerInfo.originalAppUserId, customerInfo);
      return customerInfo;
    } catch (e) {
      print('❌ Purchase error: $e');
      return null;
    }
  }

  Future<CustomerInfo?> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      await _updateUserSubscription(customerInfo.originalAppUserId, customerInfo);
      return customerInfo;
    } catch (e) {
      print('❌ Restore purchases error: $e');
      return null;
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      return null;
    }
  }

  Future<String> getSubscriptionTier() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      if (!customerInfo.entitlements.all.values.any((e) => e.isActive)) return 'free';

      final hasPro = customerInfo.entitlements.all[caribTapProEntitlement]?.isActive ?? false;
      if (hasPro) {
        final productId = customerInfo.entitlements.all[caribTapProEntitlement]?.productIdentifier ?? '';
        if (productId.contains('lifetime') || productId.contains('yearly')) return 'premium';
        return 'professional';
      }
      return 'free';
    } catch (e) {
      return 'free';
    }
  }

  Future<void> _updateUserSubscription(String userId, CustomerInfo customerInfo) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && (userDoc.data()?['isAdmin'] ?? false)) return;

      final tier = await getSubscriptionTier();
      DateTime? expiresAt;
      
      if (customerInfo.entitlements.all.isNotEmpty) {
        final active = customerInfo.entitlements.all.values.firstWhere((e) => e.isActive, orElse: () => customerInfo.entitlements.all.values.first);
        if (active.expirationDate != null) {
          expiresAt = DateTime.parse(active.expirationDate!);
        }
      }

      await _firestore.collection('users').doc(userId).update({
        'subscriptionTier': tier,
        'subscriptionExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'revenueCatCustomerId': customerInfo.originalAppUserId,
      });
    } catch (e) {
      print('❌ Firestore update error: $e');
    }
  }

  Future<void> logOut() async {
    await Purchases.logOut();
    _isConfigured = false;
  }
}
