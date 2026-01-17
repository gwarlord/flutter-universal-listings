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
      if (!emit.isDone) {
        emit(BookingCreatedState(bookingId: bookingId));
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(BookingErrorState(errorMessage: e.toString()));
      }
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
      print('🔄 BLoC: Updating booking status to ${event.status}');
      await bookingRepository.updateBookingStatus(
        listingId: event.listingId,
        bookingId: event.bookingId,
        status: event.status,
      );
      print('✅ BLoC: Booking status updated successfully');
      
      // Fetch updated booking (to obtain lister id), then refresh received bookings list
      final bookings = await bookingRepository.getListingBookings(
        listingId: event.listingId,
      );
      print('📋 BLoC: Found ${bookings.length} total bookings for listing');
      
      final booking = bookings.firstWhere((b) => b.id == event.bookingId);
      print('📌 BLoC: Found target booking, listersUserId: ${booking.listersUserId}');

      final receivedBookings = await bookingRepository.getReceivedBookings(
        listersUserId: booking.listersUserId,
      );
      print('📊 BLoC: Fetched ${receivedBookings.length} received bookings');

      emit(ReceivedBookingsLoadedState(bookings: receivedBookings));
    } catch (e) {
      print('❌ BLoC Error: $e');
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
      // Fetch updated booking (to obtain lister id), then refresh received bookings list
      final bookings = await bookingRepository.getListingBookings(
        listingId: event.listingId,
      );
      final booking = bookings.firstWhere((b) => b.id == event.bookingId);

      final receivedBookings = await bookingRepository.getReceivedBookings(
        listersUserId: booking.listersUserId,
      );

      emit(ReceivedBookingsLoadedState(bookings: receivedBookings));
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
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          // Return empty list on timeout instead of crashing
          return <DateTime>[];
        },
      );
      if (!emit.isDone) {
        emit(BookedDatesLoadedState(bookedDates: bookedDates));
      }
    } catch (e) {
      if (!emit.isDone) {
        // On error, still allow booking with empty dates
        emit(BookedDatesLoadedState(bookedDates: const []));
      }
    }
  }
}
