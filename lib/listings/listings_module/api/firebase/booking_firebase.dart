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

      // ✅ Trigger Email Notification
      await _triggerBookingEmail(booking, 'pending');

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
          final booking = BookingModel.fromJson(doc.data());
          booking.id = doc.id; // Ensure ID is set from document ID
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

        // ✅ Trigger Status Change Email
        await _triggerBookingEmail(booking, status);
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

  /// ✅ Internal helper to create email trigger documents in the 'mail' collection
  Future<void> _triggerBookingEmail(BookingModel booking, String status) async {
    try {
      String subject = '';
      String customerHtml = '';
      String listerHtml = '';

      final startDateStr = booking.checkInDate.toLocal().toString().split(' ')[0];
      final endDateStr = booking.checkOutDate.toLocal().toString().split(' ')[0];
        final String qnaHtml = booking.customAnswers.isNotEmpty
          ? '<h4>Custom Questions</h4>' +
            booking.customAnswers.entries
              .map((e) => '<p><b>${e.key}</b><br>${e.value.isEmpty ? '-' : e.value}</p>')
              .join('')
          : '';

      switch (status) {
        case 'pending':
          subject = 'Booking Request: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>We've received your booking request for <b>${booking.listingTitle}</b>.</p>
            <p><b>Start Date:</b> $startDateStr</p>
            <p><b>End Date:</b> $endDateStr</p>
            $qnaHtml
            <p>The lister will review your request and you will receive another email once it's confirmed or rejected.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          listerHtml = '''
            <h3>Hello ${booking.listersName},</h3>
            <p>You have a new booking request for your listing: <b>${booking.listingTitle}</b>.</p>
            <p><b>Customer:</b> ${booking.customerName}</p>
            <p><b>Start Date:</b> $startDateStr</p>
            <p><b>End Date:</b> $endDateStr</p>
            $qnaHtml
            <p>Please log in to the app to confirm or reject this request.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;

        case 'confirmed':
          subject = 'Booking CONFIRMED: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Congratulations ${booking.customerName}!</h3>
            <p>Your booking for <b>${booking.listingTitle}</b> has been <b>CONFIRMED</b>.</p>
            <p><b>Start Date:</b> $startDateStr</p>
            <p><b>End Date:</b> $endDateStr</p>
            $qnaHtml
            <p>Thank you for your business!</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;

        case 'rejected':
          subject = 'Booking Update: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>We're sorry, but your booking request for <b>${booking.listingTitle}</b> was not accepted at this time.</p>
            $qnaHtml
            <p>Please feel free to browse other listings on CaribTap.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;

        case 'cancelled':
          subject = 'Booking CANCELLED: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>Your booking for <b>${booking.listingTitle}</b> has been successfully cancelled.</p>
            $qnaHtml
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          listerHtml = '''
            <h3>Hello ${booking.listersName},</h3>
            <p>The booking request from ${booking.customerName} for <b>${booking.listingTitle}</b> has been cancelled by the customer.</p>
            $qnaHtml
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;
      }

      // Send to Customer
      if (customerHtml.isNotEmpty && booking.customerEmail.isNotEmpty) {
        await _firestore.collection('mail').add({
          'to': booking.customerEmail,
          'from': 'CaribTap <no-reply@caribtap.com>', // ✅ Added explicit FROM name
          'message': {
            'subject': subject,
            'html': customerHtml,
          },
        });
      }

      // Send to Lister
      if (listerHtml.isNotEmpty && booking.listersEmail.isNotEmpty) {
        await _firestore.collection('mail').add({
          'to': booking.listersEmail,
          'from': 'CaribTap <no-reply@caribtap.com>', // ✅ Added explicit FROM name
          'message': {
            'subject': subject,
            'html': listerHtml,
          },
        });
      }
    } catch (e) {
      print('Error triggering booking email: $e');
    }
  }
}
