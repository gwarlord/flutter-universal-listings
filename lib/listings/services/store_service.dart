import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:instaflutter/listings/model/catalog_item.dart';
import 'package:instaflutter/listings/model/order_request.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
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
        .orderBy('sortOrder')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => CatalogItem.fromJson(doc.data()))
          .toList();
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
    // This ensures the snapshot stays in sync if user upgrades
    final currentTierSnapshot = currentUser.subscriptionTier.toLowerCase();
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'listerTierSnapshot': currentTierSnapshot,
        'updatedAt': Timestamp.now(),
      });
    } catch (_) {
      // Silently ignore - non-critical metadata update
    }

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

    // Update store updated timestamp (non-critical - may fail due to rules)
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'storeUpdatedAt': now,
      });
    } catch (_) {
      // Silently ignore - non-critical metadata update
    }
  }

  /// Delete catalog item
  /// REQUIRES: current user is Premium tier
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

    // Update store updated timestamp (non-critical - may fail due to rules)
    try {
      await _firestore.collection('listings').doc(listingId).update({
        'storeUpdatedAt': Timestamp.now(),
      });
    } catch (_) {
      // Silently ignore - non-critical metadata update
    }
  }

  /// Upload catalog media (photo or video)
  /// Returns the download URL
  Future<String> uploadCatalogMedia({
    required String listingId,
    required String itemId,
    required File file,
    required bool isVideo,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final fileName = '${_uuid.v4()}.$ext';
    final path = 'listings/$listingId/catalog_items/$itemId/${isVideo ? 'videos' : 'photos'}/$fileName';

    final ref = _storage.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Create order request
  /// REQUIRES: listing must be from Premium user
  Future<String> createOrderRequest({
    required OrderRequest orderRequest,
    required ListingsUser customer,
  }) async {
    // Verify listing exists and is Premium
    final listing = await _firestore
        .collection('listings')
        .doc(orderRequest.listingId)
        .get();

    if (!listing.exists) {
      throw Exception('Listing not found');
    }

    final listingData = ListingModel.fromJson(listing.data()!);
    
    // CRITICAL: Verify lister is Premium
    if (listingData.listerTierSnapshot != 'premium') {
      throw Exception('🔒 This store is not available');
    }

    if (!listingData.storeEnabled) {
      throw Exception('Store is not enabled for this listing');
    }

    // Create order request
    final now = Timestamp.now();
    final orderId = _uuid.v4();
    final orderData = orderRequest.copyWith(
      id: orderId,
      customerId: customer.userID,
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
  /// REQUIRES: current user is the lister (Premium)
  Future<void> updateOrderStatus({
    required String requestId,
    required OrderStatus status,
    required ListingsUser currentUser,
    String? listerNotes,
  }) async {
    // Get order request
    final orderDoc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final order = OrderRequest.fromJson(orderDoc.data()!);

    // Verify user is the lister
    if (order.listerId != currentUser.userID) {
      throw Exception('You do not have permission to update this order');
    }

    // CRITICAL: Verify Premium tier
    if (!isPremiumUser(currentUser)) {
      throw Exception('🔒 Premium subscription required to manage orders');
    }

    // Update status
    final updateData = <String, dynamic>{
      'status': status.value,
      'updatedAt': Timestamp.now(),
    };
    if (listerNotes != null && listerNotes.trim().isNotEmpty) {
      updateData['listerNotes'] = listerNotes.trim();
    }
    await _firestore.collection('order_requests').doc(requestId).update(updateData);

    // If confirmed, decrement inventory
    if (status == OrderStatus.confirmed) {
      await _decrementInventoryOnConfirm(order);
    }

    // Dine-in orders can be fulfilled directly from requested
    if (status == OrderStatus.fulfilled &&
        order.fulfillment.method == FulfillmentMethod.dineIn &&
        order.status == OrderStatus.requested) {
      await _decrementInventoryOnConfirm(order);
    }
  }

  /// Decrement inventory when order is confirmed
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
        // Handle variants
        if (item.variant != null && catalogItem.variants.isNotEmpty) {
          final sku = item.variant!['sku'] as String?;
          if (sku != null) {
            final updatedVariants = catalogItem.variants.map((v) {
              if (v.sku == sku) {
                return CatalogVariant(
                  sku: v.sku,
                  size: v.size,
                  color: v.color,
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
          // Regular item stock
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

  /// Get order requests for a lister (Premium only)
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

  /// Get order requests for a customer
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

  /// Get single order request
  Future<OrderRequest?> getOrderRequest(String requestId) async {
    final doc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!doc.exists) return null;
    return OrderRequest.fromJson(doc.data()!);
  }

  /// Cancel order (customer can cancel if status is 'requested')
  Future<void> cancelOrder({
    required String requestId,
    required ListingsUser currentUser,
  }) async {
    final orderDoc = await _firestore.collection('order_requests').doc(requestId).get();
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }

    final order = OrderRequest.fromJson(orderDoc.data()!);

    // Only customer can cancel, and only if status is requested
    if (order.customerId != currentUser.userID) {
      throw Exception('You do not have permission to cancel this order');
    }

    if (order.status != OrderStatus.requested) {
      throw Exception('Order cannot be cancelled at this stage');
    }

    await _firestore.collection('order_requests').doc(requestId).update({
      'status': OrderStatus.cancelled.value,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Migrate existing listings to set listerTierSnapshot from author's tier
  /// Call this once when Premium user first accesses their store features
  Future<Map<String, dynamic>> migrateListingTierSnapshots() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('migrateListingTierSnapshots');
      final result = await callable.call();
      return result.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      // Silently fail - migration is not critical for functionality
      // listerTierSnapshot defaults to 'free' which won't break queries
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Update store fulfillment settings
  Future<void> updateListingStoreSettings({
    required String listingId,
    required bool pickupEnabled,
    required bool deliveryEnabled,
    required bool dineInEnabled,
    required bool shippingEnabled,
    required double shippingFee,
    required int leadTimeHours,
  }) async {
    await _firestore.collection('listings').doc(listingId).update({
      'storePickupEnabled': pickupEnabled,
      'storeDeliveryEnabled': deliveryEnabled,
      'storeDineInEnabled': dineInEnabled,
      'storeShippingEnabled': shippingEnabled,
      'storeShippingFee': shippingFee,
      'storeLeadTimeHours': leadTimeHours,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Set or update order tracking information
  /// Verifies user has CaribTap Pro entitlement server-side
  /// Sends email notification to customer
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

  /// Resend tracking email to customer
  Future<void> sendTrackingEmail(String orderId) async {
    try {
      final callable = _functions.httpsCallable('sendTrackingEmail');
      await callable.call({'orderId': orderId});
    } catch (e) {
      throw Exception('Failed to send tracking email: $e');
    }
  }
}
