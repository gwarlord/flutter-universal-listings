import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/booking_model.dart';
import 'package:instaflutter/listings/listings_module/api/booking_repository.dart';

class BookingFirebase extends BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createBooking({required BookingModel booking}) async {
    try {
      final bookingId = _firestore.collection('listings').doc().id;
      booking.id = bookingId;
      
      // Save to listing's bookings subcollection
      await _firestore
          .collection('listings')
          .doc(booking.listingId)
          .collection('bookings')
          .doc(bookingId)
          .set(booking.toJson());

      // Also save to user's bookings for easy retrieval
      await _firestore
          .collection('users')
          .doc(booking.customerId)
          .collection('myBookings')
          .doc(bookingId)
          .set(booking.toJson());

      // Save to lister's received bookings
      await _firestore
          .collection('users')
          .doc(booking.listersUserId)
          .collection('receivedBookings')
          .doc(bookingId)
          .set(booking.toJson());

      return bookingId;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<BookingModel>> getMyBookings({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('myBookings')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch my bookings: $e');
    }
  }

  @override
  Future<List<BookingModel>> getListingBookings({required String listingId}) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .orderBy('checkInDate')
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch listing bookings: $e');
    }
  }

  @override
  Future<List<BookingModel>> getReceivedBookings({required String listersUserId}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(listersUserId)
          .collection('receivedBookings')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch received bookings: $e');
    }
  }

  @override
  Future<void> updateBookingStatus({
    required String listingId,
    required String bookingId,
    required String status,
  }) async {
    try {
      final now = DateTime.now();
      
      // Update in listing's bookings
      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': status,
        'updatedAt': now.toIso8601String(),
      });

      // Get the booking to update user's collections
      final bookingDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final booking = BookingModel.fromJson(bookingDoc.data()!);

        // Update in customer's myBookings
        await _firestore
            .collection('users')
            .doc(booking.customerId)
            .collection('myBookings')
            .doc(bookingId)
            .update({
          'status': status,
          'updatedAt': now.toIso8601String(),
        });

        // Update in lister's receivedBookings
        await _firestore
            .collection('users')
            .doc(booking.listersUserId)
            .collection('receivedBookings')
            .doc(bookingId)
            .update({
          'status': status,
          'updatedAt': now.toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  @override
  Future<void> cancelBooking({
    required String listingId,
    required String bookingId,
  }) async {
    await updateBookingStatus(
      listingId: listingId,
      bookingId: bookingId,
      status: 'cancelled',
    );
  }

  @override
  Future<List<DateTime>> getBookedDates({required String listingId}) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .where('status', whereIn: ['confirmed', 'pending'])
          .get();

      final bookedDates = <DateTime>[];
      
      for (final doc in snapshot.docs) {
        final booking = BookingModel.fromJson(doc.data());
        final currentDate = booking.checkInDate;
        
        while (currentDate.isBefore(booking.checkOutDate)) {
          bookedDates.add(currentDate);
          currentDate.add(const Duration(days: 1));
        }
      }

      return bookedDates;
    } catch (e) {
      throw Exception('Failed to fetch booked dates: $e');
    }
  }
}
