import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caribtap/listings/model/catalog_item.dart';
import 'package:caribtap/listings/model/order_request.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/utils/subscription_helper.dart';
import 'package:caribtap/listings/utils/image_compress_utils.dart';
import 'package:uuid/uuid.dart';

/// Service for managing Mini Store catalog and orders
/// 
/// CRITICAL BUSINESS RULE: ALL write operations require Premium subscription
class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final _uuid = const Uuid();

  /// Get catalog items for a listing
  /// Returns stream for real-time updates
  Stream<List<CatalogItem>> getCatalogItems(String listingId) {
    return _firestore
        .collection('listings')
        .doc(listingId)
        .collection('catalog_items')
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CatalogItem.fromJson(doc.data()))
          .toList()
        ..sort((a, b) {
          final sortCompare = a.sortOrder.compareTo(b.sortOrder);
          if (sortCompare != 0) return sortCompare;

          final aCreatedAt = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bCreatedAt = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bCreatedAt.compareTo(aCreatedAt);
        });

      return items;
    });
  }

  /// Get single catalog item
  Future<CatalogItem?> getCatalogItem(String listingId, String itemId) async {
    final doc = await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('catalog_items')
        .doc(itemId)
        .get();

    if (!doc.exists) return null;
    return CatalogItem.fromJson(doc.data()!);
  }

  /// Create or update catalog item
  /// REQUIRES: current user is Premium tier
  Future<void> upsertCatalogItem({
    required String listingId,
    required CatalogItem item,
    required ListingsUser currentUser,
  }) async {
    // CRITICAL: Verify Premium tier (user must be premium to manage catalog)
    if (!isPremiumUser(currentUser)) {
      throw Exception('🔒 Mini Store is a Premium feature. Upgrade to manage catalog items.');
    }

    // Verify listing ownership
    final listing = await _firestore.collection('listings').doc(listingId).get();
    if (!listing.exists) {
      throw Exception('Listing not found');
    }

    final listingData = listing.data()!;
    if (listingData['authorID'] != currentUser.userID) {
      throw Exception('You do not have permission to manage this listing\'s catalog');
    }

    // Update listing's tier snapshot to reflect current user tier
    final currentTierSnapshot = currentUser.subscriptionTier.toLowerCase();
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'listerTierSnapshot': currentTierSnapshot,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {}

    // Set timestamps
    final now = Timestamp.now();
    final itemData = item.copyWith(
      updatedAt: now,
      createdAt: item.createdAt ?? now,
    );

    // Save item
    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('catalog_items')
        .doc(item.id)
        .set(itemData.toJson());

    // ✅ Update search keywords on parent listing
    await _updateListingSearchKeywords(listingId);

    // Update store updated timestamp
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'storeUpdatedAt': now,
      });
    } catch (_) {}
  }

  /// Delete catalog item
  Future<void> deleteCatalogItem({
    required String listingId,
    required String itemId,
    required ListingsUser currentUser,
  }) async {
    // CRITICAL: Verify Premium tier
    if (!isPremiumUser(currentUser)) {
      throw Exception('🔒 Mini Store is a Premium feature.');
    }

    // Verify listing ownership
    final listing = await _firestore.collection('listings').doc(listingId).get();
    if (!listing.exists) {
      throw Exception('Listing not found');
    }

    if (listing.data()!['authorID'] != currentUser.userID) {
      throw Exception('You do not have permission to manage this listing\'s catalog');
    }

    // Delete item
    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('catalog_items')
        .doc(itemId)
        .delete();

    // ✅ Update search keywords on parent listing
    await _updateListingSearchKeywords(listingId);

    try {
      await _firestore.collection('listings').doc(listingId).update({
        'storeUpdatedAt': Timestamp.now(),
      });
    } catch (_) {}
  }

  /// Re-aggregates all catalog item names and categories into the parent listing's searchKeywords
  Future<void> _updateListingSearchKeywords(String listingId) async {
    try {
      // Fetch catalog items
      final catalogSnap = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('catalog_items')
          .get();

      // Fetch rental items
      final rentalSnap = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('rental_catalog')
          .get();

      final Set<String> keywords = {};

      // Process Catalog Items
      for (var doc in catalogSnap.docs) {
        final data = doc.data();
        if (data['name'] != null) keywords.addAll(data['name'].toString().toLowerCase().split(RegExp(r'\s+')));
        if (data['category'] != null) keywords.addAll(data['category'].toString().toLowerCase().split(RegExp(r'\s+')));
      }

      // Process Rental Items
      for (var doc in rentalSnap.docs) {
        final data = doc.data();
        if (data['name'] != null) keywords.addAll(data['name'].toString().toLowerCase().split(RegExp(r'\s+')));
        if (data['category'] != null) keywords.addAll(data['category'].toString().toLowerCase().split(RegExp(r'\s+')));
      }

      // Filter out short/irrelevant keywords
      final finalKeywords = keywords.where((k) => k.length > 2).toList();

      await _firestore.collection('listings').doc(listingId).update({
        'searchKeywords': finalKeywords,
      });
    } catch (e) {
      print('Error updating store search keywords: $e');
    }
  }

  /// Upload catalog media (photo or video)
  Future<String> uploadCatalogMedia({
    required String listingId,
    required String itemId,
    required File file,
    required bool isVideo,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final fileName = '${_uuid.v4()}.$ext';
    final path = 'listings/$listingId/catalog_items/$itemId/${isVideo ? 'videos' : 'photos'}/$fileName';

    final fileToUpload = isVideo ? file : await compressImageFile(file);
    final ref = _storage.ref().child(path);
    await ref.putFile(fileToUpload);
    return await ref.getDownloadURL();
  }

  /// Create order request
  Future<String> createOrderRequest({
    required OrderRequest orderRequest,
    required ListingsUser customer,
  }) async {
    final listing = await _firestore
        .collection('listings')
        .doc(orderRequest.listingId)
        .get();

    if (!listing.exists) {
      throw Exception('Listing not found');
    }

    final listingData = ListingModel.fromJson(listing.data()!);
    
    if (listingData.listerTierSnapshot != 'premium') {
      throw Exception('🔒 This store is not available');
    }

    if (!listingData.storeEnabled) {
      throw Exception('Store is not enabled for this listing');
    }

    final fulfillmentAddress = orderRequest.fulfillment.address?.trim() ?? '';
    if (orderRequest.fulfillment.method == FulfillmentMethod.delivery &&
        fulfillmentAddress.isEmpty) {
      throw Exception('Delivery address is required');
    }

    if (orderRequest.fulfillment.method == FulfillmentMethod.shipping) {
      final shippingAddress = orderRequest.shipping?.address?.trim() ?? '';
      if (fulfillmentAddress.isEmpty && shippingAddress.isEmpty) {
        throw Exception('Shipping address is required');
      }
    }

    final now = Timestamp.now();
    final orderId = _uuid.v4();
    final normalizedFulfillment = FulfillmentInfo(
      method: orderRequest.fulfillment.method,
      address: fulfillmentAddress.isNotEmpty
          ? fulfillmentAddress
          : orderRequest.shipping?.address?.trim(),
      latitude: orderRequest.fulfillment.latitude,
      longitude: orderRequest.fulfillment.longitude,
      preferredAt: orderRequest.fulfillment.preferredAt,
    );

    ShippingInfo? normalizedShipping = orderRequest.shipping;
    if (orderRequest.fulfillment.method == FulfillmentMethod.shipping) {
      final normalizedShippingAddress =
          (orderRequest.shipping?.address?.trim().isNotEmpty == true)
              ? orderRequest.shipping!.address!.trim()
              : normalizedFulfillment.address;
      normalizedShipping = ShippingInfo(
        address: normalizedShippingAddress,
        latitude: orderRequest.shipping?.latitude,
        longitude: orderRequest.shipping?.longitude,
        instructions: orderRequest.shipping?.instructions,
        carrierName: orderRequest.shipping?.carrierName,
        trackingNumber: orderRequest.shipping?.trackingNumber,
        trackingUrl: orderRequest.shipping?.trackingUrl,
        status: orderRequest.shipping?.status ?? TrackingStatus.unknown,
        updatedAt: orderRequest.shipping?.updatedAt,
        updatedBy: orderRequest.shipping?.updatedBy,
      );
    }

    final orderData = orderRequest.copyWith(
      id: orderId,
      customerId: customer.userID,
      fulfillment: normalizedFulfillment,
      shipping: normalizedShipping,
      createdAt: now,
      updatedAt: now,
    );

    await _firestore
        .collection('order_requests')
        .doc(orderId)
        .set(orderData.toJson());

    return orderId;
  }

  /// Update order status
  Future<void> updateOrderStatus({
    required String requestId,
    required OrderStatus status,
    required ListingsUser currentUser,
    String? listerNotes,
  }) async {
    final orderDoc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final order = OrderRequest.fromJson(orderDoc.data()!);

    if (order.listerId != currentUser.userID) {
      throw Exception('You do not have permission to update this order');
    }

    if (!isPremiumUser(currentUser)) {
      throw Exception('🔒 Premium subscription required to manage orders');
    }

    final updateData = <String, dynamic>{
      'status': status.value,
      'updatedAt': Timestamp.now(),
    };
    if (status == OrderStatus.cancelled) {
      updateData['cancelledFromStatus'] = order.status.value;
    }
    if (listerNotes != null && listerNotes.trim().isNotEmpty) {
      updateData['listerNotes'] = listerNotes.trim();
    }
    await _firestore.collection('order_requests').doc(requestId).update(updateData);

    if (status == OrderStatus.confirmed) {
      await _decrementInventoryOnConfirm(order);
    }

    if (status == OrderStatus.fulfilled &&
        order.fulfillment.method == FulfillmentMethod.dineIn &&
        order.status == OrderStatus.requested) {
      await _decrementInventoryOnConfirm(order);
    }
  }

  Future<void> _decrementInventoryOnConfirm(OrderRequest order) async {
    final batch = _firestore.batch();

    for (final item in order.items) {
      final itemRef = _firestore
          .collection('listings')
          .doc(order.listingId)
          .collection('catalog_items')
          .doc(item.itemId);

      final itemDoc = await itemRef.get();
      if (!itemDoc.exists) continue;

      final catalogItem = CatalogItem.fromJson(itemDoc.data()!);
      
      if (catalogItem.trackStock) {
        if (item.variant != null && catalogItem.variants.isNotEmpty) {
          final sku = item.variant!['sku'] as String?;
          if (sku != null) {
            final updatedVariants = catalogItem.variants.map((v) {
              if (v.sku == sku) {
                return CatalogVariant(
                  sku: v.sku,
                  size: v.size,
                  color: v.color,
                  option1Value: v.effectiveOption1Value,
                  option2Value: v.effectiveOption2Value,
                  option3Value: v.effectiveOption3Value,
                  option4Value: v.effectiveOption4Value,
                  imageUrl: v.imageUrl,
                  price: v.price,
                  stockQty: (v.stockQty - item.qty).clamp(0, 999999),
                );
              }
              return v;
            }).toList();

            batch.update(itemRef, {
              'variants': updatedVariants.map((e) => e.toJson()).toList(),
              'updatedAt': Timestamp.now(),
            });
          }
        } else {
          final newStock = (catalogItem.stockQty - item.qty).clamp(0, 999999);
          batch.update(itemRef, {
            'stockQty': newStock,
            'isAvailable': newStock > 0,
            'updatedAt': Timestamp.now(),
          });
        }
      }
    }

    await batch.commit();
  }

  Stream<List<OrderRequest>> getOrderRequestsForLister({
    required String listerId,
    OrderStatus? statusFilter,
  }) {
    Query query = _firestore
        .collection('order_requests')
        .where('listerId', isEqualTo: listerId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderRequest.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Stream<List<OrderRequest>> getOrderRequestsForCustomer({
    required String customerId,
  }) {
    return _firestore
        .collection('order_requests')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderRequest.fromJson(doc.data()))
          .toList();
    });
  }

  Future<OrderRequest?> getOrderRequest(String requestId) async {
    final doc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!doc.exists) return null;
    return OrderRequest.fromJson(doc.data()!);
  }

  Future<void> cancelOrder({
    required String requestId,
    required ListingsUser currentUser,
  }) async {
    final orderDoc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final order = OrderRequest.fromJson(orderDoc.data()!);

    if (order.customerId != currentUser.userID) {
      throw Exception('You do not have permission to cancel this order');
    }

    if (order.status != OrderStatus.requested) {
      throw Exception('Order cannot be cancelled at this stage');
    }

    final proofUrl =
        (order.payment?['proofOfPaymentUrl'] as String?)?.trim() ?? '';
    if (proofUrl.isNotEmpty) {
      throw Exception('Order cannot be cancelled after proof of payment is uploaded');
    }

    await _firestore.collection('order_requests').doc(requestId).update({
      'status': OrderStatus.cancelled.value,
      'updatedAt': Timestamp.now(),
      'cancelledFromStatus': order.status.value,
    });
  }

  Future<void> reportFulfillmentIssue({
    required String orderId,
    required ListingsUser currentUser,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Please provide a reason for this report');
    }

    final orderDoc = await _firestore.collection('order_requests').doc(orderId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final order = OrderRequest.fromJson(orderDoc.data()!);
    if (order.customerId != currentUser.userID) {
      throw Exception('You can only report your own orders');
    }

    if (order.status != OrderStatus.fulfilled) {
      throw Exception('You can report this issue only after the order is marked fulfilled');
    }

    final existingPendingReport = await _firestore
        .collection('reports')
        .where('reportType', isEqualTo: 'order_fulfillment_issue')
        .where('orderId', isEqualTo: orderId)
        .where('reporterId', isEqualTo: currentUser.userID)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingPendingReport.docs.isNotEmpty) {
      throw Exception('You already submitted this report and it is under review');
    }

    final listingDoc =
        await _firestore.collection('listings').doc(order.listingId).get();
    final listingTitle = (listingDoc.data()?['title'] as String?)?.trim();

    await _firestore.collection('reports').add({
      'listingId': order.listingId,
      'listingTitle':
          (listingTitle != null && listingTitle.isNotEmpty) ? listingTitle : 'Order issue report',
      'listingAuthorId': order.listerId,
      'reporterId': currentUser.userID,
      'reporterName': currentUser.fullName(),
      'reason': trimmedReason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'reportType': 'order_fulfillment_issue',
      'orderId': orderId,
      'orderStatus': order.status.value,
    });

    if (listingDoc.exists) {
      try {
        await _firestore.collection('listings').doc(order.listingId).update({
          'isFlagged': true,
          'updatedAt': Timestamp.now(),
        });
      } catch (_) {
        // Report submission should still succeed if listing flag update fails.
      }
    }
  }

  Future<Map<String, dynamic>> migrateListingTierSnapshots() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('migrateListingTierSnapshots');
      final result = await callable.call();
      return result.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> updateListingStoreSettings({
    required String listingId,
    required bool pickupEnabled,
    required bool deliveryEnabled,
    required double deliveryFee,
    required bool dineInEnabled,
    required bool shippingEnabled,
    required double shippingFee,
    required int leadTimeHours,
  }) async {
    await _firestore.collection('listings').doc(listingId).update({
      'storePickupEnabled': pickupEnabled,
      'storeDeliveryEnabled': deliveryEnabled,
      'storeDeliveryFee': deliveryFee,
      'storeDineInEnabled': dineInEnabled,
      'storeShippingEnabled': shippingEnabled,
      'storeShippingFee': shippingFee,
      'storeLeadTimeHours': leadTimeHours,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<Map<String, dynamic>> setOrderTracking({
    required String orderId,
    required String trackingNumber,
    required String trackingUrl,
    String? carrierName,
    String? status,
  }) async {
    try {
      final callable = _functions.httpsCallable('setOrderTracking');
      final result = await callable.call({
        'orderId': orderId,
        'carrierName': carrierName,
        'trackingNumber': trackingNumber,
        'trackingUrl': trackingUrl,
        'status': status ?? 'UNKNOWN',
      });
      
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to set order tracking: $e');
    }
  }

  Future<void> sendTrackingEmail(String orderId) async {
    try {
      final callable = _functions.httpsCallable('sendTrackingEmail');
      await callable.call({'orderId': orderId});
    } catch (e) {
      throw Exception('Failed to send tracking email: $e');
    }
  }
}
