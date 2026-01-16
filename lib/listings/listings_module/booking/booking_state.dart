import 'package:instaflutter/listings/model/booking_model.dart';

abstract class BookingState {
  const BookingState();
}

class BookingInitial extends BookingState {
  const BookingInitial();
}

class BookingLoading extends BookingState {
  const BookingLoading();
}

class BookingCreatedState extends BookingState {
  final String bookingId;
  const BookingCreatedState({required this.bookingId});
}

class MyBookingsLoadedState extends BookingState {
  final List<BookingModel> bookings;
  const MyBookingsLoadedState({required this.bookings});
}

class ListingBookingsLoadedState extends BookingState {
  final List<BookingModel> bookings;
  const ListingBookingsLoadedState({required this.bookings});
}

class ReceivedBookingsLoadedState extends BookingState {
  final List<BookingModel> bookings;
  const ReceivedBookingsLoadedState({required this.bookings});
}

class BookingStatusUpdatedState extends BookingState {
  final BookingModel booking;
  const BookingStatusUpdatedState({required this.booking});
}

class BookedDatesLoadedState extends BookingState {
  final List<DateTime> bookedDates;
  const BookedDatesLoadedState({required this.bookedDates});
}

class BookingErrorState extends BookingState {
  final String errorMessage;
  const BookingErrorState({required this.errorMessage});
}
