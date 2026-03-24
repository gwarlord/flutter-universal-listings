import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/model/booking_model.dart';
import 'package:caribtap/listings/listings_module/api/booking_repository.dart';

class BookingFirebase extends BookingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createBooking({required BookingModel booking}) async {
    try {
      final bookingId = _firestore.collection('listings').doc().id;
      booking.id = bookingId;
      
      final bookingData = booking.toJson();

      // Save to listing's bookings subcollection
      await _firestore
          .collection('listings')
          .doc(booking.listingId)
          .collection('bookings')
          .doc(bookingId)
          .set(bookingData);

      // Also save to user's bookings for easy retrieval
      await _firestore
          .collection('users')
          .doc(booking.customerId)
          .collection('myBookings')
          .doc(bookingId)
          .set(bookingData);

      // Save to lister's received bookings
      await _firestore
          .collection('users')
          .doc(booking.listersUserId)
          .collection('receivedBookings')
          .doc(bookingId)
          .set(bookingData);

      // Email notifications are handled server-side by Cloud Functions.

      return bookingId;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<BookingModel>> getMyBookings({required String userId}) async {
    try {
      debugPrint('🟢 DEBUG [getMyBookings]: Fetching bookings for userId=$userId');
      
      // Try with orderBy first (recommended for performance)
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('myBookings')
            .orderBy('createdAt', descending: true)
            .get();
        debugPrint('🟢 DEBUG [getMyBookings]: Query with orderBy succeeded');
      } catch (orderByError) {
        debugPrint('⚠️  DEBUG [getMyBookings]: orderBy failed, fetching without ordering: $orderByError');
        // Fallback: Get without ordering
        snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('myBookings')
            .get();
      }

      debugPrint('🟢 DEBUG [getMyBookings]: Found ${snapshot.docs.length} bookings');
      
      final List<BookingModel> bookings = [];
      for (final doc in snapshot.docs) {
        try {
          var booking = BookingModel.fromJson(doc.data());
          booking.id = doc.id; // Ensure ID is set from document ID
          booking = await _resolveLatestMyBookingStatus(
            userId: userId,
            booking: booking,
          );
          bookings.add(booking);
          debugPrint('🟢 DEBUG [getMyBookings]: Parsed booking ${booking.id} - status=${booking.status}');
        } catch (parseError) {
          debugPrint('❌ DEBUG [getMyBookings]: Failed to parse booking ${doc.id}: $parseError');
        }
      }
      
      // Manual sort if orderBy wasn't used
      if (bookings.isNotEmpty && bookings.first.createdAt != null) {
        bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      debugPrint('🟢 DEBUG [getMyBookings]: Successfully parsed ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      debugPrint('❌ DEBUG [getMyBookings]: Query error: $e');
      throw Exception('Failed to fetch my bookings: $e');
    }
  }

  Future<BookingModel> _resolveLatestMyBookingStatus({
    required String userId,
    required BookingModel booking,
  }) async {
    final bookingId = booking.id.trim();
    final listingId = booking.listingId.trim();
    final localStatus = booking.status.toLowerCase().trim();

    if (bookingId.isEmpty || listingId.isEmpty) {
      return booking;
    }

    if (localStatus != 'pending' && localStatus != 'confirmed') {
      return booking;
    }

    try {
      final canonicalDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (!canonicalDoc.exists || canonicalDoc.data() == null) {
        return booking;
      }

      final canonicalBooking = BookingModel.fromJson(canonicalDoc.data()!);
      if (canonicalBooking.id.trim().isEmpty) {
        canonicalBooking.id = bookingId;
      }

      final canonicalStatus = canonicalBooking.status.toLowerCase().trim();
      if (canonicalStatus == localStatus) {
        return booking;
      }

      debugPrint(
        '⚠️ DEBUG [getMyBookings]: Detected stale myBookings status for $bookingId '
        '($localStatus -> $canonicalStatus).',
      );

      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('myBookings')
            .doc(bookingId)
            .update({
          'status': canonicalBooking.status,
          'updatedAt': canonicalBooking.updatedAt.toIso8601String(),
          'cancellationReason': canonicalBooking.cancellationReason,
          'cancelledBy': canonicalBooking.cancelledBy,
          'cancelledByUserId': canonicalBooking.cancelledByUserId,
            'completionTag': canonicalBooking.completionTag,
            'completionTaggedAt': canonicalBooking.completionTaggedAt?.toIso8601String(),
            'completionTaggedByUserId': canonicalBooking.completionTaggedByUserId,
        });
      } catch (syncError) {
        debugPrint('⚠️ DEBUG [getMyBookings]: Unable to self-heal myBookings $bookingId: $syncError');
      }

      return canonicalBooking;
    } catch (e) {
      debugPrint('⚠️ DEBUG [getMyBookings]: Canonical status check failed for ${booking.id}: $e');
      return booking;
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
      debugPrint('🟢 DEBUG [getReceivedBookings]: Fetching bookings for listerId=$listersUserId');

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _firestore
            .collection('users')
            .doc(listersUserId)
            .collection('receivedBookings')
            .orderBy('createdAt', descending: true)
            .get();
        debugPrint('🟢 DEBUG [getReceivedBookings]: Query with orderBy succeeded');
      } catch (orderByError) {
        debugPrint('⚠️  DEBUG [getReceivedBookings]: orderBy failed, fetching without ordering: $orderByError');
        snapshot = await _firestore
            .collection('users')
            .doc(listersUserId)
            .collection('receivedBookings')
            .get();
      }

      debugPrint('🟢 DEBUG [getReceivedBookings]: Found ${snapshot.docs.length} bookings');
      final bookings = <BookingModel>[];
      for (final doc in snapshot.docs) {
        try {
          final booking = BookingModel.fromJson(doc.data());
          booking.id = doc.id;
          bookings.add(booking);
          debugPrint('🟢 DEBUG [getReceivedBookings]: Parsed booking ${booking.id} - status=${booking.status}');
        } catch (parseError) {
          debugPrint('❌ DEBUG [getReceivedBookings]: Failed to parse booking ${doc.id}: $parseError');
        }
      }

      if (bookings.isNotEmpty && bookings.first.createdAt != null) {
        bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      debugPrint('🟢 DEBUG [getReceivedBookings]: Successfully parsed ${bookings.length} bookings');
      return bookings;
    } catch (e) {
      debugPrint('❌ DEBUG [getReceivedBookings]: Query error: $e');
      throw Exception('Failed to fetch received bookings: $e');
    }
  }

  @override
  Future<void> updateBookingStatus({
    required String listingId,
    required String bookingId,
    required String status,
    String? cancellationReason,
    String? cancelledBy,
    String? cancelledByUserId,
  }) async {
    final now = DateTime.now();
    final String normalizedStatus = status.toLowerCase();
    final String? trimmedCancellationReason = cancellationReason?.trim();
    final Map<String, dynamic> updateData = {
      'status': status,
      'updatedAt': now.toIso8601String(),
    };

    if (normalizedStatus == 'cancelled') {
      if (trimmedCancellationReason != null && trimmedCancellationReason.isNotEmpty) {
        updateData['cancellationReason'] = trimmedCancellationReason;
      }
      if (cancelledBy != null && cancelledBy.trim().isNotEmpty) {
        updateData['cancelledBy'] = cancelledBy.trim().toLowerCase();
      }
      if (cancelledByUserId != null && cancelledByUserId.trim().isNotEmpty) {
        updateData['cancelledByUserId'] = cancelledByUserId.trim();
      }
    }

    try {
      // Update in listing's bookings
      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }

    try {
      // Get the booking to update user's collections
      final bookingDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final booking = BookingModel.fromJson(bookingDoc.data()!);

        // Best-effort mirror updates. A permission error here should not mask
        // a successful primary status update on listings/{listingId}/bookings.
        try {
          await _firestore
              .collection('users')
              .doc(booking.customerId)
              .collection('myBookings')
              .doc(bookingId)
              .update(updateData);
        } catch (e) {
          debugPrint('⚠️ Mirror update skipped for myBookings ($bookingId): $e');
        }

        try {
          await _firestore
              .collection('users')
              .doc(booking.listersUserId)
              .collection('receivedBookings')
              .doc(bookingId)
              .update(updateData);
        } catch (e) {
          debugPrint('⚠️ Mirror update skipped for receivedBookings ($bookingId): $e');
        }

        // Email notifications are handled server-side by Cloud Functions.
      }
    } catch (e) {
      debugPrint('⚠️ Post-update sync error for booking ($bookingId): $e');
    }
  }

  @override
  Future<void> cancelBooking({
    required String listingId,
    required String bookingId,
    String? cancellationReason,
    String? cancelledBy,
    String? cancelledByUserId,
  }) async {
    await updateBookingStatus(
      listingId: listingId,
      bookingId: bookingId,
      status: 'cancelled',
      cancellationReason: cancellationReason,
      cancelledBy: cancelledBy,
      cancelledByUserId: cancelledByUserId,
    );
  }

  @override
  Future<void> updateBookingCompletionTag({
    required String listingId,
    required String bookingId,
    required String completionTag,
    String? completionTaggedByUserId,
  }) async {
    final now = DateTime.now();
    final normalizedTag = completionTag.trim().toLowerCase();
    final updateData = <String, dynamic>{
      'completionTag': normalizedTag,
      'completionTaggedAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    final taggedBy = completionTaggedByUserId?.trim() ?? '';
    if (taggedBy.isNotEmpty) {
      updateData['completionTaggedByUserId'] = taggedBy;
    }

    try {
      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update booking completion tag: $e');
    }

    try {
      final bookingDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final booking = BookingModel.fromJson(bookingDoc.data()!);

        try {
          await _firestore
              .collection('users')
              .doc(booking.customerId)
              .collection('myBookings')
              .doc(bookingId)
              .update(updateData);
        } catch (e) {
          debugPrint('⚠️ Mirror completion tag update skipped for myBookings ($bookingId): $e');
        }

        try {
          await _firestore
              .collection('users')
              .doc(booking.listersUserId)
              .collection('receivedBookings')
              .doc(bookingId)
              .update(updateData);
        } catch (e) {
          debugPrint('⚠️ Mirror completion tag update skipped for receivedBookings ($bookingId): $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Completion tag sync error for booking ($bookingId): $e');
    }
  }

  @override
  Future<List<DateTime>> getBookedDates({required String listingId}) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .where('status', whereIn: ['confirmed', 'pending'])
          .get()
          .timeout(const Duration(seconds: 10));

      final bookedDates = <DateTime>[];
      
      for (final doc in snapshot.docs) {
        final booking = BookingModel.fromJson(doc.data());
        var currentDate = booking.checkInDate;
        
        // Safety check to prevent infinite loops
        int daysCount = 0;
        const maxDays = 365; // Maximum 1 year booking
        
        while (currentDate.isBefore(booking.checkOutDate) && daysCount < maxDays) {
          bookedDates.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
          currentDate = currentDate.add(const Duration(days: 1));
          daysCount++;
        }
      }

      return bookedDates;
    } catch (e) {
      throw Exception('Failed to fetch booked dates: $e');
    }
  }

  @override
  Future<List<DateTime>> getBlockedDates({required String listingId}) async {
    try {
      final listingDoc = await _firestore
          .collection('listings')
          .doc(listingId)
          .get();

      if (!listingDoc.exists) {
        return [];
      }

      final blockedDatesMs = List<int>.from(listingDoc.data()?['blockedDates'] ?? []);
      return blockedDatesMs
          .map((ms) => DateTime.fromMillisecondsSinceEpoch(ms))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch blocked dates: $e');
    }
  }

}
