import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_module/api/booking_repository.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_event.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository bookingRepository;

  BookingBloc({required this.bookingRepository}) : super(const BookingInitial()) {
    on<CreateBookingEvent>(_onCreateBooking);
    on<GetMyBookingsEvent>(_onGetMyBookings);
    on<GetListingBookingsEvent>(_onGetListingBookings);
    on<GetReceivedBookingsEvent>(_onGetReceivedBookings);
    on<UpdateBookingStatusEvent>(_onUpdateBookingStatus);
    on<CancelBookingEvent>(_onCancelBooking);
    on<GetBookedDatesEvent>(_onGetBookedDates);
  }

  Future<void> _onCreateBooking(
    CreateBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookingId = await bookingRepository.createBooking(booking: event.booking);
      emit(BookingCreatedState(bookingId: bookingId));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onGetMyBookings(
    GetMyBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookings = await bookingRepository.getMyBookings(userId: event.userId);
      emit(MyBookingsLoadedState(bookings: bookings));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onGetListingBookings(
    GetListingBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookings = await bookingRepository.getListingBookings(listingId: event.listingId);
      emit(ListingBookingsLoadedState(bookings: bookings));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onGetReceivedBookings(
    GetReceivedBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookings = await bookingRepository.getReceivedBookings(
        listersUserId: event.listersUserId,
      );
      emit(ReceivedBookingsLoadedState(bookings: bookings));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateBookingStatus(
    UpdateBookingStatusEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      await bookingRepository.updateBookingStatus(
        listingId: event.listingId,
        bookingId: event.bookingId,
        status: event.status,
      );
      // Fetch updated booking
      final bookings = await bookingRepository.getListingBookings(
        listingId: event.listingId,
      );
      final booking = bookings.firstWhere((b) => b.id == event.bookingId);
      emit(BookingStatusUpdatedState(booking: booking));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      await bookingRepository.cancelBooking(
        listingId: event.listingId,
        bookingId: event.bookingId,
      );
      // Fetch updated booking
      final bookings = await bookingRepository.getListingBookings(
        listingId: event.listingId,
      );
      final booking = bookings.firstWhere((b) => b.id == event.bookingId);
      emit(BookingStatusUpdatedState(booking: booking));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }

  Future<void> _onGetBookedDates(
    GetBookedDatesEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(const BookingLoading());
    try {
      final bookedDates = await bookingRepository.getBookedDates(
        listingId: event.listingId,
      );
      emit(BookedDatesLoadedState(bookedDates: bookedDates));
    } catch (e) {
      emit(BookingErrorState(errorMessage: e.toString()));
    }
  }
}
