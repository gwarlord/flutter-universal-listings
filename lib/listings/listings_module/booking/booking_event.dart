import 'package:caribtap/listings/model/booking_model.dart';

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
  final String? listersUserId;

  UpdateBookingStatusEvent({
    required this.listingId,
    required this.bookingId,
    required this.status,
    this.listersUserId,
  });
}

class CancelBookingEvent extends BookingEvent {
  final String listingId;
  final String bookingId;
  final String? cancellationReason;
  final String? cancelledBy;
  final String? cancelledByUserId;
  final String? listersUserId;
  
  CancelBookingEvent({
    required this.listingId,
    required this.bookingId,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledByUserId,
    this.listersUserId,
  });
}

class UpdateBookingCompletionTagEvent extends BookingEvent {
  final String listingId;
  final String bookingId;
  final String completionTag;
  final String? listersUserId;
  final String? completionTaggedByUserId;

  UpdateBookingCompletionTagEvent({
    required this.listingId,
    required this.bookingId,
    required this.completionTag,
    this.listersUserId,
    this.completionTaggedByUserId,
  });
}

class GetBookedDatesEvent extends BookingEvent {
  final String listingId;
  GetBookedDatesEvent({required this.listingId});
}
