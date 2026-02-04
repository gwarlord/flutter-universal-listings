import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/rental_config.dart';
import 'package:instaflutter/listings/model/rental_booking.dart';
import 'package:instaflutter/screens/rentals/rental_item_models.dart';

/// Service for managing rental browsing, inventory, and booking operations
class RentalBrowseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get available rental units for a listing
  Stream<List<RentalItemBrowse>> getAvailableRentalItems(String listingId) {
    return _firestore
        .collection('rental_units')
        .where('listingId', isEqualTo: listingId)
        .where('status', isEqualTo: 'available')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => RentalItemBrowse.fromJson({
                    ...doc.data(),
                    'id': doc.id,
                  }))
              .toList();
        });
  }

  /// Get single rental item details
  Future<RentalItemBrowse?> getRentalItem(String listingId, String itemId) async {
    try {
      final doc = await _firestore
          .collection('rental_units')
          .doc(itemId)
          .get();
      
      if (!doc.exists) return null;
      
      return RentalItemBrowse.fromJson({
        ...doc.data() ?? {},
        'id': doc.id,
      });
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
      // Query for overlapping bookings
      final bookings = await _firestore
          .collection('rental_bookings')
          .where('listingId', isEqualTo: listingId)
          .where('rentalUnitId', isEqualTo: rentalUnitId)
          .where('status', whereIn: ['pending', 'confirmed', 'active'])
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
  Future<String?> createRentalBooking({
    required String listingId,
    required String customerId,
    required String listerId,
    required List<RentalCartItem> cartItems,
    required double totalAmount,
    required double? depositAmount,
    required String? customerNotes,
  }) async {
    try {
      // For MVP, create one booking per rental item
      // In production, could group by date range for efficiency
      
      final bookingId = _firestore.collection('rental_bookings').doc().id;
      
      // Use first item's dates (in production, you might aggregate)
      if (cartItems.isEmpty) return null;
      
      final firstItem = cartItems.first;
      
      final booking = RentalBooking(
        id: bookingId,
        listingId: listingId,
        rentalUnitId: cartItems.length == 1 ? cartItems.first.rentalUnitId : 'multiple',
        customerId: customerId,
        listerId: listerId,
        startTime: firstItem.startDate,
        endTime: firstItem.endDate,
        totalAmount: totalAmount,
        status: RentalBookingStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('rental_bookings')
          .doc(bookingId)
          .set({
            ...booking.toJson(),
            'cartItems': cartItems.map((item) => {
              'rentalUnitId': item.rentalUnitId,
              'unitName': item.unitName,
              'startDate': item.startDate.millisecondsSinceEpoch,
              'endDate': item.endDate.millisecondsSinceEpoch,
              'pricePerDay': item.pricePerDay,
              'totalPrice': item.totalPrice,
            }).toList(),
            'depositAmount': depositAmount,
            'customerNotes': customerNotes,
          });

      return bookingId;
    } catch (e) {
      debugPrint('Error creating rental booking: $e');
      return null;
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
              .map((doc) => RentalBooking.fromJson({
                    ...doc.data(),
                    'id': doc.id,
                  }))
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
          .map((doc) => RentalBooking.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
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
