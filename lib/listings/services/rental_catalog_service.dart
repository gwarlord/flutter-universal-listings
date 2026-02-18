import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caribtap/listings/model/rental_catalog_item.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/utils/subscription_helper.dart';

/// Service for managing rental catalog items
class RentalCatalogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get all rental catalog items for a listing
  Stream<List<RentalCatalogItem>> getRentalCatalogItems(String listingId) {
    return _firestore
        .collection('listings')
        .doc(listingId)
        .collection('rental_catalog')
        .orderBy('sortOrder')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RentalCatalogItem.fromJson(doc.data()))
              .toList();
        });
  }

  /// Get single rental catalog item
  Future<RentalCatalogItem?> getRentalItem(String listingId, String itemId) async {
    final doc = await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('rental_catalog')
        .doc(itemId)
        .get();

    if (!doc.exists) return null;
    return RentalCatalogItem.fromJson(doc.data()!);
  }

  /// Create or update rental catalog item
  /// REQUIRES: current user is Premium tier
  Future<void> upsertRentalItem({
    required String listingId,
    required RentalCatalogItem item,
    required ListingsUser currentUser,
  }) async {
    // CRITICAL: Verify Premium tier
    if (!isPremiumUser(currentUser)) {
      throw Exception('🔒 Rentals is a Premium feature. Upgrade to manage rental items.');
    }

    final now = Timestamp.now();
    final itemData = item.copyWith(
      listingId: listingId,
      updatedAt: now,
      createdAt: item.createdAt ?? now,
    ).toJson();

    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('rental_catalog')
        .doc(item.id)
        .set(itemData, SetOptions(merge: true));
  }

  /// Delete rental catalog item
  Future<void> deleteRentalItem(String listingId, String itemId) async {
    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('rental_catalog')
        .doc(itemId)
        .delete();
  }

  /// Upload media for rental item
  Future<String> uploadRentalMedia({
    required String listingId,
    required String itemId,
    required File file,
    required bool isVideo,
  }) async {
    final ext = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final mediaType = isVideo ? 'videos' : 'photos';
    final path = 'rentals/$listingId/$itemId/$mediaType/$fileName';

    final ref = _storage.ref().child(path);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  /// Check availability for specific item and dates
  Future<bool> checkItemAvailability({
    required String listingId,
    required String itemId,
    required DateTime startDate,
    required DateTime endDate,
    int bufferMinutes = 30,
  }) async {
    try {
      // Get the item to check stock
      final item = await getRentalItem(listingId, itemId);
      if (item == null || !item.isAvailable || item.stockQty <= 0) {
        return false;
      }

      // Query for overlapping bookings
      final bookings = await _firestore
          .collection('rental_bookings')
          .where('listingId', isEqualTo: listingId)
          .where('rentalUnitId', isEqualTo: itemId)
          .where('status', whereIn: ['pending', 'confirmed', 'active'])
          .get();

      // Count overlapping bookings
      int overlappingCount = 0;
      for (var booking in bookings.docs) {
        final data = booking.data();
        final bookingStart = (data['startTime'] as Timestamp).toDate();
        final bookingEnd = (data['endTime'] as Timestamp).toDate();

        // Add buffer time
        final bufferedStart = bookingStart.subtract(Duration(minutes: bufferMinutes));
        final bufferedEnd = bookingEnd.add(Duration(minutes: bufferMinutes));

        // Check for overlap
        if (startDate.isBefore(bufferedEnd) && endDate.isAfter(bufferedStart)) {
          overlappingCount++;
        }
      }

      // Available if overlapping bookings less than stock quantity
      return overlappingCount < item.stockQty;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  /// Search rental items
  Future<List<RentalCatalogItem>> searchRentalItems(
    String listingId,
    String query,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('rental_catalog')
          .where('isAvailable', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => RentalCatalogItem.fromJson(doc.data()))
          .toList();

      // Filter by query
      return items
          .where((item) =>
              item.name.toLowerCase().contains(query.toLowerCase()) ||
              (item.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              item.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error searching rental items: $e');
      return [];
    }
  }

  /// Get unique categories from rental items
  Future<List<String>> getRentalCategories(String listingId) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('rental_catalog')
          .get();

      final categories = <String>{};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
}
