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
      print('🔵 Firebase: Updating booking status - listingId=$listingId, bookingId=$bookingId, status=$status');
      
      // Update in listing's bookings
      try {
        await _firestore
            .collection('listings')
            .doc(listingId)
            .collection('bookings')
            .doc(bookingId)
            .update({
          'status': status,
          'updatedAt': now.toIso8601String(),
        });
        print('✅ Firebase: Updated listing bookings collection');
      } catch (e) {
        print('❌ Firebase Error updating listing bookings: $e');
        rethrow;
      }

      // Get the booking to update user's collections
      DocumentSnapshot? bookingDoc;
      try {
        bookingDoc = await _firestore
            .collection('listings')
            .doc(listingId)
            .collection('bookings')
            .doc(bookingId)
            .get();
      } catch (e) {
        print('❌ Firebase Error fetching booking document: $e');
        rethrow;
      }

      if (bookingDoc != null && bookingDoc.exists) {
        final booking = BookingModel.fromJson(bookingDoc.data() as Map<String, dynamic>);
        print('📖 Firebase: Found booking - customerId=${booking.customerId}, listersUserId=${booking.listersUserId}');

        // Update in customer's myBookings
        try {
          await _firestore
              .collection('users')
              .doc(booking.customerId)
              .collection('myBookings')
              .doc(bookingId)
              .update({
            'status': status,
            'updatedAt': now.toIso8601String(),
          });
          print('✅ Firebase: Updated customer myBookings collection');
        } catch (e) {
          print('❌ Firebase Error updating customer myBookings: $e');
          // Don't rethrow - try to continue
        }

        // Update in lister's receivedBookings
        try {
          await _firestore
              .collection('users')
              .doc(booking.listersUserId)
              .collection('receivedBookings')
              .doc(bookingId)
              .update({
            'status': status,
            'updatedAt': now.toIso8601String(),
          });
          print('✅ Firebase: Updated lister receivedBookings collection');
        } catch (e) {
          print('❌ Firebase Error updating lister receivedBookings: $e');
          // Don't rethrow - try to continue
        }

        // ✅ Trigger Status Change Email
        try {
          await _triggerBookingEmail(booking, status);
          print('✅ Firebase: Email notification triggered');
        } catch (e) {
          print('⚠️ Firebase Warning - Email trigger error: $e');
          // Don't rethrow - email is not critical
        }
      } else {
        throw Exception('Booking not found in listing collection');
      }
    } catch (e) {
      print('❌ Firebase Error: $e');
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
      print('DEBUG: Triggering email for booking: ${booking.id} with status: $status');
      
      String subject = '';
      String customerHtml = '';
      String listerHtml = '';

      final checkInStr = booking.checkInDate.toLocal().toString().split(' ')[0];
      final checkOutStr = booking.checkOutDate.toLocal().toString().split(' ')[0];

      // Extract services from guestNotes if present
      String servicesHtml = '';
      if (booking.guestNotes.contains('Selected Services:')) {
        final servicesPart = booking.guestNotes.split('Selected Services:')[1];
        final services = servicesPart.split('\n').where((s) => s.trim().startsWith('-')).toList();
        if (services.isNotEmpty) {
          servicesHtml = '<p><b>Selected Services:</b></p><ul>';
          for (var service in services) {
            servicesHtml += '<li>${service.trim().substring(2)}</li>';
          }
          servicesHtml += '</ul>';
        }
      }

      switch (status) {
        case 'pending':
          subject = 'Booking Request: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>We've received your booking request for <b>${booking.listingTitle}</b>.</p>
            <p><b>Start Date:</b> $checkInStr</p>
            <p><b>End Date:</b> $checkOutStr</p>
            $servicesHtml
            <p>The lister will review your request and you will receive another email once it's confirmed or rejected.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          listerHtml = '''
            <h3>Hello ${booking.listersName},</h3>
            <p>You have a new booking request for your listing: <b>${booking.listingTitle}</b>.</p>
            <p><b>Customer:</b> ${booking.customerName}</p>
            <p><b>Start Date:</b> $checkInStr</p>
            <p><b>End Date:</b> $checkOutStr</p>
            $servicesHtml
            <p>Please log in to the app to confirm or reject this request.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;

        case 'confirmed':
          subject = 'Booking CONFIRMED: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Congratulations ${booking.customerName}!</h3>
            <p>Your booking for <b>${booking.listingTitle}</b> has been <b>CONFIRMED</b>.</p>
            <p><b>Start Date:</b> $checkInStr</p>
            <p><b>End Date:</b> $checkOutStr</p>
            $servicesHtml
            <p>We appreciate your business.</p>
            <br><p>Best regards,<br>${booking.listingTitle} Team</p>
          ''';
          break;

        case 'rejected':
          subject = 'Booking Update: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>Thank you for your interest in <b>${booking.listingTitle}</b>.</p>
            <p>Unfortunately, your booking request cannot be accommodated for the requested dates:</p>
            <p><b>Start Date:</b> $checkInStr</p>
            <p><b>End Date:</b> $checkOutStr</p>
            $servicesHtml
            <p>We understand this may be disappointing. We encourage you to explore our other wonderful listings that may suit your needs, or consider alternative dates.</p>
            <p>Thank you for choosing <b>${booking.listingTitle}</b> powered by CaribTap, and we hope to serve you soon.</p>
            <br><p>Best regards,<br>${booking.listingTitle} Team</p>
          ''';
          break;

        case 'cancelled':
          subject = 'Booking CANCELLED: ${booking.listingTitle}';
          customerHtml = '''
            <h3>Hello ${booking.customerName},</h3>
            <p>Your booking for <b>${booking.listingTitle}</b> has been successfully cancelled.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          listerHtml = '''
            <h3>Hello ${booking.listersName},</h3>
            <p>The booking request from ${booking.customerName} for <b>${booking.listingTitle}</b> has been cancelled by the customer.</p>
            <br><p>Best regards,<br>CaribTap Team</p>
          ''';
          break;
      }

      // Send to Customer
      if (customerHtml.isNotEmpty && booking.customerEmail.isNotEmpty) {
        print('DEBUG: Writing customer email to Firestore for: ${booking.customerEmail}');
        await _firestore.collection('mail').add({
          'to': booking.customerEmail,
          'message': {
            'subject': subject,
            'html': customerHtml,
          },
        });
      }

      // Send to Lister
      if (listerHtml.isNotEmpty && booking.listersEmail.isNotEmpty) {
        print('DEBUG: Writing lister email to Firestore for: ${booking.listersEmail}');
        await _firestore.collection('mail').add({
          'to': booking.listersEmail,
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
