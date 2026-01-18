import 'package:instaflutter/listings/model/booking_model.dart';

abstract class BookingRepository {
  Future<String> createBooking({required BookingModel booking});
  Future<List<BookingModel>> getMyBookings({required String userId});
  Future<List<BookingModel>> getListingBookings({required String listingId});
  Future<List<BookingModel>> getReceivedBookings({required String listersUserId});
  Future<void> updateBookingStatus({
    required String listingId,
    required String bookingId,
    required String status,
  });
  Future<void> cancelBooking({
    required String listingId,
    required String bookingId,
  });
  Future<List<DateTime>> getBookedDates({required String listingId});
  Future<List<DateTime>> getBlockedDates({required String listingId});
}
