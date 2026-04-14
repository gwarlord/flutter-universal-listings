import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:caribtap/listings/services/subscription_products.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();

  factory SubscriptionService() => _instance;

  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  String? _currentUserId;

  Future<bool> isAvailable() async {
    final available = await _iap.isAvailable();
    debugPrint('🛒 In-App Purchase Available: $available');
    return available;
  }

  Future<List<ProductDetails>> loadProducts() async {
    debugPrint('🛒 Loading products: $subscriptionProductIds');
    final response = await _iap.queryProductDetails(subscriptionProductIds);
    debugPrint('🛒 Product query response - Found: ${response.productDetails.length} products');
    debugPrint('🛒 Products: ${response.productDetails.map((p) => p.id).toList()}');
    if (response.error != null) {
      debugPrint('🛒 Product query error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('🛒 Not found product IDs: ${response.notFoundIDs}');
    }
    _logStoreDiagnostics(response);
    return response.productDetails;
  }

  void _logStoreDiagnostics(ProductDetailsResponse response) {
    if (!Platform.isIOS) {
      return;
    }

    final error = response.error;
    final code = error?.code ?? '';
    final foundNone = response.productDetails.isEmpty;

    if (!foundNone && code.isEmpty) {
      return;
    }

    debugPrint('🍎 iOS IAP diagnostics:');
    if (error != null) {
      debugPrint('🍎 Error code: ${error.code}');
      debugPrint('🍎 Error message: ${error.message}');
    }
    debugPrint('🍎 Bundle ID expected in App Store Connect: com.caribtap.ios');

    if (code == 'storekit_no_response' || foundNone) {
      debugPrint('🍎 Check 1: Test on a physical iPhone (not simulator).');
      debugPrint('🍎 Check 2: App Store Connect app uses bundle ID com.caribtap.ios.');
      debugPrint('🍎 Check 3: Subscription products exist with exact IDs from app code.');
      debugPrint('🍎 Check 4: Products are in Ready to Submit/Approved state.');
      debugPrint('🍎 Check 5: Paid Apps agreement, tax, and banking are active.');
      debugPrint('🍎 Check 6: Device is signed in with a Sandbox tester account.');
      debugPrint('🍎 Check 7: In-App Purchase capability is enabled for the iOS target.');
    }
  }

  void startListening({required String userId}) {
    _currentUserId = userId;
    _purchaseSubscription?.cancel();
    _purchaseSubscription = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          await _handlePurchaseUpdate(purchase);
        }
      },
      onError: (error) {
        debugPrint('Purchase stream error: $error');
      },
    );
  }

  Future<void> stopListening() async {
    await _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
  }

  Future<void> purchase(ProductDetails product) async {
    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: _currentUserId,
    );
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> purchaseById(String productId) async {
    final products = await loadProducts();
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );
    await purchase(product);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<Map<String, dynamic>> claimProfessionalTrial() async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'claimProfessionalTrial',
    );
    final response = await callable.call(<String, dynamic>{});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getProfessionalTrialConfig() async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getProfessionalTrialConfig',
    );
    final response = await callable.call(<String, dynamic>{});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      return;
    }

    if (purchase.status == PurchaseStatus.error) {
      debugPrint('Purchase error: ${purchase.error}');
      return;
    }

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      await _verifyPurchase(purchase);
    }

    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('No user for purchase verification');
      return;
    }

    final verificationData = purchase.verificationData;
    final payload = <String, dynamic>{
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'productId': purchase.productID,
    };

    if (Platform.isAndroid) {
      payload['purchaseToken'] = verificationData.serverVerificationData;
      payload['packageName'] = 'com.caribtap.instaflutter.android';
    } else {
      payload['receiptData'] = verificationData.serverVerificationData;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      await callable.call(payload);
    } catch (e) {
      debugPrint('Purchase verification failed: $e');
    }
  }
}
