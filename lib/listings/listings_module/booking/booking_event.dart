import 'package:instaflutter/listings/model/booking_model.dart';

abstract class BookingEvent {}

class CreateBookingEvent extends BookingEvent {
  final BookingModel booking;
  CreateBookingEvent({required this.booking});
}

class GetMyBookingsEvent extends BookingEvent {
  final String userId;
  GetMyBookingsEvent({required this.userId});
}

class GetListingBookingsEvent extends BookingEvent {
  final String listingId;
  GetListingBookingsEvent({required this.listingId});
}

class GetReceivedBookingsEvent extends BookingEvent {
  final String listersUserId;
  GetReceivedBookingsEvent({required this.listersUserId});
}

class UpdateBookingStatusEvent extends BookingEvent {
  final String listingId;
  final String bookingId;
  final String status;
  
  UpdateBookingStatusEvent({
    required this.listingId,
    required this.bookingId,
    required this.status,
  });
}

class CancelBookingEvent extends BookingEvent {
  final String listingId;
  final String bookingId;
  
  CancelBookingEvent({
    required this.listingId,
    required this.bookingId,
  });
}

class GetBookedDatesEvent extends BookingEvent {
  final String listingId;
  GetBookedDatesEvent({required this.listingId});
}
