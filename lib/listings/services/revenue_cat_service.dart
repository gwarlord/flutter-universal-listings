import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // RevenueCat API Keys - replace with your actual keys from RevenueCat dashboard
  static const String _androidApiKey = 'test_HlFlRPeoSwcyoKewtdDNaMiGCLy';
  static const String _iosApiKey = 'test_HlFlRPeoSwcyoKewtdDNaMiGCLy';
  
  // Entitlement identifier - matches what you set up in RevenueCat dashboard
  static const String caribTapProEntitlement = 'CaribTap Pro';
  
  // Product identifiers
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  static const String lifetimeProductId = 'lifetime';

  bool _isConfigured = false;

  /// Initialize RevenueCat SDK
  /// Call this after user authentication with the user's ID
  Future<void> initialize({required String userId}) async {
    if (_isConfigured) {
      print('⚠️ RevenueCat already configured');
      return;
    }

    try {
      // Enable debug logging in debug mode
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      // Get the appropriate API key for the platform
      final apiKey = Platform.isAndroid ? _androidApiKey : _iosApiKey;
      print('🔑 Using API key for ${Platform.isAndroid ? 'Android' : 'iOS'}');

      // Configure RevenueCat with user ID
      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey)
        ..appUserID = userId;
      
      await Purchases.configure(configuration);
      print('✅ Purchases.configure() completed');
      
      // Log in the user
      await Purchases.logIn(userId);
      print('✅ Purchases.logIn() completed for user: $userId');
      
      _isConfigured = true;
      print('✅ RevenueCat fully initialized for user: $userId');
      
      // Set up listener for customer info updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
      
    } catch (e) {
      print('❌ RevenueCat initialization error: $e');
      _isConfigured = false; // Reset on error so we can retry
      rethrow;
    }
  }

  /// Listener for customer info updates
  void _onCustomerInfoUpdated(CustomerInfo customerInfo) async {
    print('📊 Customer info updated');
    // Update Firestore with latest subscription status
    try {
      final userId = customerInfo.originalAppUserId;
      await _updateUserSubscription(userId, customerInfo);
    } catch (e) {
      print('❌ Error updating customer info: $e');
    }
  }

  /// Get available offerings (subscription packages)
  Future<Offerings?> getOfferings() async {
    try {
      if (!_isConfigured) {
        print('⚠️ RevenueCat not configured before getOfferings()');
      }
      
      print('📦 Calling Purchases.getOfferings()...');
      final offerings = await Purchases.getOfferings();
      
      print('✅ Purchases.getOfferings() returned successfully');
      print('📋 Total offerings: ${offerings.all.length}');
      
      if (offerings.current == null) {
        print('⚠️ No current offering found in the dashboard');
        print('📋 Available offerings: ${offerings.all.keys.toList()}');
        return offerings; // Return anyway so we can see what's available
      }

      print('✅ Found ${offerings.current!.availablePackages.length} packages in current offering');
      for (var pkg in offerings.current!.availablePackages) {
        print('  📦 Package: ${pkg.identifier} - ${pkg.storeProduct.title}');
      }
      return offerings;
    } on PlatformException catch (e) {
      print('❌ Platform error fetching offerings: ${e.code} - ${e.message}');
      print('   Details: ${e.details}');
      return null;
    } catch (e) {
      print('❌ Error fetching offerings: $e');
      print('   Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Purchase a specific package
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      print('💳 Attempting to purchase: ${package.identifier}');
      // purchases_flutter 9 returns PurchaseResult
      final purchaseResult = await Purchases.purchasePackage(package);
      final customerInfo = purchaseResult.customerInfo;

      print('✅ Purchase successful!');
      
      // Update Firestore with new subscription info and wait for completion
      await _updateUserSubscription(
        customerInfo.originalAppUserId,
        customerInfo,
      );
      
      // Add small delay to ensure Firestore write is fully propagated
      await Future.delayed(const Duration(milliseconds: 300));
      
      print('✅ Firestore update complete, returning customer info');
      return customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        print('ℹ️ User cancelled the purchase');
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        print('❌ User is not allowed to make purchases');
      } else {
        print('❌ Purchase error: ${e.message}');
      }
      return null;
    } catch (e) {
      print('❌ Unexpected purchase error: $e');
      return null;
    }
  }

  /// Restore purchases (for users who already subscribed on another device)
  Future<CustomerInfo?> restorePurchases() async {
    try {
      print('🔄 Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      
      print('✅ Purchases restored');
      
      // Update Firestore with restored subscription info
      await _updateUserSubscription(
        customerInfo.originalAppUserId,
        customerInfo,
      );
      
      return customerInfo;
    } catch (e) {
      print('❌ Restore purchases error: $e');
      return null;
    }
  }

  /// Get current customer info (subscription status, entitlements, etc.)
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      print('📊 Retrieved customer info');
      return customerInfo;
    } catch (e) {
      print('❌ Error getting customer info: $e');
      return null;
    }
  }

  /// Check if user has CaribTap Pro entitlement
  Future<bool> hasCaribTapPro() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasEntitlement = customerInfo.entitlements.all[caribTapProEntitlement]?.isActive ?? false;
      
      print('🔍 CaribTap Pro status: ${hasEntitlement ? "Active ✅" : "Inactive ❌"}');
      return hasEntitlement;
    } catch (e) {
      print('❌ Error checking entitlement: $e');
      return false;
    }
  }

  /// Check if user has specific entitlement
  Future<bool> hasEntitlement(String entitlementId) async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementId]?.isActive ?? false;
    } catch (e) {
      print('❌ Error checking entitlement: $e');
      return false;
    }
  }

  /// Get subscription tier based on entitlements
  Future<String> getSubscriptionTier() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      if (customerInfo.entitlements.all.isEmpty || 
          !customerInfo.entitlements.all.values.any((e) => e.isActive)) {
        return 'free';
      }

      // Check for active entitlements and map to tier
      final hasCaribTapPro = customerInfo.entitlements.all[caribTapProEntitlement]?.isActive ?? false;
      
      if (hasCaribTapPro) {
        // Determine tier based on product identifier
        final activeEntitlement = customerInfo.entitlements.all[caribTapProEntitlement];
        final productId = activeEntitlement?.productIdentifier ?? '';
        
        if (productId.contains('lifetime')) {
          return 'premium'; // Lifetime gets premium features
        } else if (productId.contains('yearly')) {
          return 'premium'; // Yearly gets premium features
        } else {
          return 'professional'; // Monthly gets professional features
        }
      }
      
      return 'free';
    } catch (e) {
      print('❌ Error getting subscription tier: $e');
      return 'free';
    }
  }

  /// Update user subscription in Firestore based on CustomerInfo
  Future<void> _updateUserSubscription(String userId, CustomerInfo customerInfo) async {
    try {
      print('💾 Starting subscription update for user: $userId');
      
      // Check if user is admin - don't override admin subscriptions
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final isAdmin = userDoc.data()?['isAdmin'] ?? false;
        if (isAdmin) {
          print('ℹ️ Skipping subscription update for admin user: $userId');
          return;
        }
      }
      
      final tier = await getSubscriptionTier();
      print('📊 Determined subscription tier: $tier');
      
      DateTime? expiresAt;
      if (customerInfo.entitlements.all.isNotEmpty) {
        final activeEntitlement = customerInfo.entitlements.all.values
            .firstWhere((e) => e.isActive, orElse: () => customerInfo.entitlements.all.values.first);
        
        if (activeEntitlement.expirationDate != null) {
          expiresAt = DateTime.parse(activeEntitlement.expirationDate!);
          print('📅 Subscription expires: $expiresAt');
        }
      }
      
      // Update Firestore
      await _firestore.collection('users').doc(userId).update({
        'subscriptionTier': tier,
        'subscriptionExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'revenueCatCustomerId': customerInfo.originalAppUserId,
      });

      print('✅ Successfully updated Firestore subscription for user $userId to $tier');
    } catch (e) {
      print('❌ Error updating user subscription in Firestore: $e');
      print('❌ Stack: ${StackTrace.current}');
      rethrow; // Re-throw so caller knows it failed
    }
  }

  /// Log out the current user
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      _isConfigured = false;
      print('✅ User logged out from RevenueCat');
    } catch (e) {
      print('❌ Error logging out: $e');
    }
  }

  /// Set user attributes for better analytics
  Future<void> setUserAttributes(Map<String, String> attributes) async {
    try {
      await Purchases.setAttributes(attributes);
      print('✅ User attributes set');
    } catch (e) {
      print('❌ Error setting user attributes: $e');
    }
  }

  /// Get product by identifier
  Future<Package?> getPackageByProductId(String productId) async {
    try {
      final offerings = await getOfferings();
      if (offerings?.current == null) return null;
      
      for (final package in offerings!.current!.availablePackages) {
        if (package.storeProduct.identifier == productId) {
          return package;
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting package: $e');
      return null;
    }
  }
}
