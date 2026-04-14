import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/model/rental_config.dart';
import 'package:caribtap/listings/model/rental_booking.dart';
import 'package:caribtap/listings/model/rental_catalog_item.dart';
import 'package:caribtap/screens/rentals/rental_item_models.dart';

/// Service for managing rental browsing, inventory, and booking operations
class RentalBrowseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get available rental items from the catalog for a listing
  Stream<List<RentalItemBrowse>> getAvailableRentalItems(String listingId) {
    return _firestore
        .collection('listings')
        .doc(listingId)
        .collection('rental_catalog')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final catalogItem = RentalCatalogItem.fromJson(doc.data() as Map<String, dynamic>, doc.id);
            // Convert RentalCatalogItem to RentalItemBrowse for backwards compatibility
            return RentalItemBrowse(
              id: catalogItem.id,
              listingId: catalogItem.listingId,
              unitName: catalogItem.name,
              description: catalogItem.description,
              category: catalogItem.category,
              rentalType: catalogItem.isVehicle ? 'vehicle' : 'general',
              basePrice: catalogItem.basePrice,
              pricingUnit: _pricingUnitToString(catalogItem.pricingUnit),
              currencyCode: 'USD', // Default, will be overridden by listing currency
              photos: catalogItem.photos,
              videos: catalogItem.videos,
              isAvailable: catalogItem.isAvailable && catalogItem.stockQty > 0,
              stockQty: catalogItem.stockQty,
              depositAmount: catalogItem.depositAmount,
              vehicleDetails: catalogItem.isVehicle ? {
                'make': catalogItem.make,
                'model': catalogItem.model,
                'year': catalogItem.year,
                'color': catalogItem.color,
                'licensePlate': catalogItem.licensePlate,
                'vin': catalogItem.vin,
              } : null,
              createdAt: catalogItem.createdAt,
              updatedAt: catalogItem.updatedAt,
            );
          }).toList();
        });
  }

  String _pricingUnitToString(RentalPricingUnit unit) {
    switch (unit) {
      case RentalPricingUnit.hourly:
        return 'hourly';
      case RentalPricingUnit.daily:
        return 'daily';
      case RentalPricingUnit.weekly:
        return 'weekly';
      case RentalPricingUnit.monthly:
        return 'monthly';
    }
  }

  /// Get single rental item details
  Future<RentalItemBrowse?> getRentalItem(String listingId, String itemId) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('rental_catalog')
          .doc(itemId)
          .get();
      
      if (!doc.exists) return null;
      
      final catalogItem = RentalCatalogItem.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      // Convert to RentalItemBrowse
      return RentalItemBrowse(
        id: catalogItem.id,
        listingId: catalogItem.listingId,
        unitName: catalogItem.name,
        description: catalogItem.description,
        category: catalogItem.category,
        rentalType: catalogItem.isVehicle ? 'vehicle' : 'general',
        basePrice: catalogItem.basePrice,
        pricingUnit: _pricingUnitToString(catalogItem.pricingUnit),
        currencyCode: 'USD',
        photos: catalogItem.photos,
        videos: catalogItem.videos,
        isAvailable: catalogItem.isAvailable && catalogItem.stockQty > 0,
        stockQty: catalogItem.stockQty,
        depositAmount: catalogItem.depositAmount,
        vehicleDetails: catalogItem.isVehicle ? {
          'make': catalogItem.make,
          'model': catalogItem.model,
          'year': catalogItem.year,
          'color': catalogItem.color,
          'licensePlate': catalogItem.licensePlate,
          'vin': catalogItem.vin,
        } : null,
        createdAt: catalogItem.createdAt,
        updatedAt: catalogItem.updatedAt,
      );
    } catch (e) {
      debugPrint('Error fetching rental item: $e');
      return null;
    }
  }

  /// Check availability for specific dates
  Future<bool> isAvailableForDates(
    String listingId,
    String rentalUnitId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final itemDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('rental_catalog')
          .doc(rentalUnitId)
          .get();

      if (!itemDoc.exists) {
        return false;
      }

      final itemData = itemDoc.data() as Map<String, dynamic>;
      final isAvailable = itemData['isAvailable'] != false;
      final stockQty = (itemData['stockQty'] as num?)?.toInt() ?? 0;
      if (!isAvailable || stockQty <= 0) {
        return false;
      }

      // Query for overlapping bookings
      final bookings = await _firestore
          .collection('rental_bookings')
          .where('listingId', isEqualTo: listingId)
          .where('rentalUnitId', isEqualTo: rentalUnitId)
          .where('status', whereIn: ['confirmed', 'active'])
          .get();

      for (var booking in bookings.docs) {
        final data = booking.data();
        final bookingStart = (data['startTime'] as Timestamp).toDate();
        final bookingEnd = (data['endTime'] as Timestamp).toDate();

        // Check for overlap
        if (startDate.isBefore(bookingEnd) && endDate.isAfter(bookingStart)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return false;
    }
  }

  /// Returns the soonest known availability date based on active/confirmed bookings.
  Future<DateTime?> getNextAvailableDate({
    required String listingId,
    required String rentalUnitId,
  }) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('rental_bookings')
          .where('listingId', isEqualTo: listingId)
          .where('rentalUnitId', isEqualTo: rentalUnitId)
          .where('status', whereIn: ['confirmed', 'active'])
          .where('endTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('endTime')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final endTime = snapshot.docs.first.data()['endTime'];
      if (endTime is Timestamp) {
        return endTime.toDate();
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching next available date: $e');
      return null;
    }
  }

  /// Calculate rental price based on duration and pricing unit
  double calculatePrice(
    double basePrice,
    RentalPricingUnit pricingUnit,
    DateTime startDate,
    DateTime endDate,
  ) {
    final duration = endDate.difference(startDate);
    
    switch (pricingUnit) {
      case RentalPricingUnit.hourly:
        return basePrice * duration.inHours;
      case RentalPricingUnit.daily:
        return basePrice * (duration.inDays + 1);
      case RentalPricingUnit.weekly:
        return basePrice * ((duration.inDays + 1) / 7).ceil();
      case RentalPricingUnit.monthly:
        return basePrice * ((duration.inDays + 1) / 30).ceil();
    }
  }

  /// Create a rental booking from cart items
  /// Each item in the cart will now result in an INDIVIDUAL booking record
  Future<List<String>> createRentalBooking({
    required String listingId,
    required String customerId,
    required String listerId,
    required List<RentalCartItem> cartItems,
    required double totalAmount,
    required double? depositAmount,
    required String? customerNotes,
  }) async {
    if (cartItems.isEmpty) return [];
    final listingDoc = await _firestore.collection('listings').doc(listingId).get();
    final listingAcceptsProofOfPayment =
        listingDoc.data()?['payments']?['acceptProofOfPayment'] == true;
      
    final List<String> bookingIds = [];
    final requestedByUnit = <String, int>{};
    final processedByUnit = <String, int>{};

    for (final item in cartItems) {
      requestedByUnit.update(item.rentalUnitId, (value) => value + 1,
          ifAbsent: () => 1);
    }
      
    // If item-level deposits exist in cart details, prefer those over listing-level split.
    final hasItemLevelDeposits = cartItems.any(
      (item) =>
        ((item.details?['securityDeposit'] as num?)?.toDouble() ?? 0.0) > 0,
    );
    final perItemDeposit =
      depositAmount != null ? (depositAmount / cartItems.length) : 0.0;

    try {
      for (final entry in requestedByUnit.entries) {
        final catalogDoc = await _firestore
            .collection('listings')
            .doc(listingId)
            .collection('rental_catalog')
            .doc(entry.key)
            .get();

        if (!catalogDoc.exists) {
          throw Exception('One or more rental items are no longer available.');
        }

        final catalogData = catalogDoc.data() as Map<String, dynamic>;
        final isCatalogAvailable = catalogData['isAvailable'] != false;
        final stockQty = (catalogData['stockQty'] as num?)?.toInt() ?? 0;

        if (!isCatalogAvailable || stockQty <= 0) {
          throw Exception(
            'One or more items were just rented and are no longer available.',
          );
        }

        if (entry.value > stockQty) {
          throw Exception(
            'Requested quantity exceeds availability for one or more items.',
          );
        }
      }

      for (final item in cartItems) {
        final bookingRef = _firestore.collection('rental_bookings').doc();
        final bookingId = bookingRef.id;
        final alreadyProcessedForUnit = processedByUnit[item.rentalUnitId] ?? 0;
        final durationDays = item.endDate.difference(item.startDate).inDays + 1;
        final itemDeposit =
          ((item.details?['securityDeposit'] as num?)?.toDouble() ??
            (hasItemLevelDeposits ? 0.0 : perItemDeposit));

        final booking = RentalBooking(
          id: bookingId,
          listingId: listingId,
          rentalUnitId: item.rentalUnitId,
          customerId: customerId,
          listerId: listerId,
          startTime: item.startDate,
          endTime: item.endDate,
          pricingUnit: RentalPricingUnit.daily,
          unitPrice: item.pricePerDay,
          quantity: durationDays,
          subtotal: item.totalPrice,
          depositAmount: itemDeposit,
          totalAmount: item.totalPrice + itemDeposit,
          status: RentalBookingStatus.pending,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          listingAcceptsProofOfPayment: listingAcceptsProofOfPayment,
        );

        final bookingPayload = {
          ...booking.toJson(),
          // Save snapshot of item details including photo
          'cartItems': [
            {
              'rentalUnitId': item.rentalUnitId,
              'unitName': item.unitName,
              'startDate': item.startDate.millisecondsSinceEpoch,
              'endDate': item.endDate.millisecondsSinceEpoch,
              'pricePerDay': item.pricePerDay,
              'totalPrice': item.totalPrice,
              'securityDeposit': itemDeposit,
              'photoUrl': item.photoUrl,
            }
          ],
          'depositAmount': itemDeposit,
          'customerNotes': customerNotes,
          'inventoryReserved': false,
        };

        final catalogRef = _firestore
            .collection('listings')
            .doc(listingId)
            .collection('rental_catalog')
            .doc(item.rentalUnitId);

        await _firestore.runTransaction((transaction) async {
          final catalogDoc = await transaction.get(catalogRef);
          if (!catalogDoc.exists) {
            throw Exception('This rental item is no longer available.');
          }

          final catalogData = catalogDoc.data() as Map<String, dynamic>;
          final isCatalogAvailable = catalogData['isAvailable'] != false;
          final stockQty = (catalogData['stockQty'] as num?)?.toInt() ?? 0;

          if (!isCatalogAvailable || stockQty <= 0) {
            throw Exception(
              'One or more items were just rented and are no longer available.',
            );
          }

          if (alreadyProcessedForUnit >= stockQty) {
            throw Exception(
              'Requested quantity exceeds availability for one or more items.',
            );
          }

          transaction.set(bookingRef, bookingPayload);
        });

        bookingIds.add(bookingId);
        processedByUnit[item.rentalUnitId] = alreadyProcessedForUnit + 1;
      }

      return bookingIds;
    } catch (e) {
      debugPrint('Error creating rental booking: $e');
      rethrow;
    }
  }

  /// Get booking history for customer
  Stream<List<RentalBooking>> getCustomerBookings(String customerId) {
    return _firestore
        .collection('rental_bookings')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RentalBooking.fromJson(doc.data(), doc.id))
              .toList();
        });
  }

  /// Get active rentals for customer
  Future<List<RentalBooking>> getActiveRentals(String customerId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('rental_bookings')
          .where('customerId', isEqualTo: customerId)
          .where('status', whereIn: ['confirmed', 'active'])
          .get();

      final bookings = snapshot.docs
          .map((doc) => RentalBooking.fromJson(doc.data(), doc.id))
          .toList();

      // Filter by date
      return bookings
          .where((b) => b.startTime.isBefore(now.add(Duration(days: 1))) &&
              b.endTime.isAfter(now))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active rentals: $e');
      return [];
    }
  }

  /// Search rental items by query
  Future<List<RentalItemBrowse>> searchRentalItems(
    String listingId,
    String query,
  ) async {
    try {
      final items = await _firestore
          .collection('rental_units')
          .where('listingId', isEqualTo: listingId)
          .where('status', isEqualTo: 'available')
          .get();

      final results = items.docs
          .map((doc) => RentalItemBrowse.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .toList();

      // Filter by query
      return results
          .where((item) =>
              item.unitName.toLowerCase().contains(query.toLowerCase()) ||
              (item.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    } catch (e) {
      debugPrint('Error searching rental items: $e');
      return [];
    }
  }
}

void debugPrint(String message) {
  print(message);
}
