import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_module/api/booking_api_manager.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_bloc.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_event.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_state.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:intl/intl.dart';

class BookingManagementScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const BookingManagementScreen({super.key, required this.currentUser});

  @override
  State<BookingManagementScreen> createState() => _BookingManagementScreenState();
}

class _BookingManagementScreenState extends State<BookingManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    context.read<BookingBloc>().add(
          GetReceivedBookingsEvent(listersUserId: widget.currentUser.userID),
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshBookings() {
    context.read<BookingBloc>().add(
          GetReceivedBookingsEvent(listersUserId: widget.currentUser.userID),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Requests'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBookings,
            tooltip: 'Refresh'.tr(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: isDarkMode(context) ? Colors.white70 : Colors.black54,
          tabs: [
            Tab(text: 'Pending'.tr()),
            Tab(text: 'Confirmed'.tr()),
            Tab(text: 'All'.tr()),
          ],
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          } else if (state is ReceivedBookingsLoadedState) {
            final allBookings = state.bookings;
            final pendingBookings = allBookings.where((b) => b.isPending).toList();
            final confirmedBookings = allBookings.where((b) => b.isConfirmed).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(pendingBookings),
                _buildBookingsList(confirmedBookings),
                _buildBookingsList(allBookings),
              ],
            );
          } else if (state is BookingErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.errorMessage),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<BookingBloc>().add(
                            GetReceivedBookingsEvent(
                              listersUserId: widget.currentUser.userID,
                            ),
                          );
                    },
                    child: Text('Retry'.tr()),
                  ),
                ],
              ),
            );
          }

          return Center(child: Text('No bookings'.tr()));
        },
      ),
    );
  }

  Widget _buildBookingsList(List<dynamic> bookings) {
    if (bookings.isEmpty) {
      return Center(child: Text('No bookings'.tr()));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(dynamic booking) {
    final dark = isDarkMode(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: dark ? Colors.grey.shade900 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    booking.listingPhoto,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.listingTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.customerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          booking.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(booking.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Dates'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat('MMM dd, yyyy').format(booking.checkInDate)} - ${DateFormat('MMM dd, yyyy').format(booking.checkOutDate)} (${booking.numberOfNights} nights)',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guests: ${booking.numberOfGuests}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (booking.guestNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking.guestNotes,
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
            if (booking.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectBooking(booking),
                      child: Text('Reject'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveBooking(booking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: Text('Confirm'.tr()),
                    ),
                  ),
                ],
              ),
            ] else if (booking.isConfirmed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelBooking(booking),
                  child: Text('Cancel booking'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _approveBooking(dynamic booking) {
    context.read<BookingBloc>().add(
          UpdateBookingStatusEvent(
            listingId: booking.listingId,
            bookingId: booking.id,
            status: 'confirmed',
          ),
        );
  }

  void _rejectBooking(dynamic booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject booking?'.tr()),
        content: Text('Are you sure you want to reject this booking?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BookingBloc>().add(
                    UpdateBookingStatusEvent(
                      listingId: booking.listingId,
                      bookingId: booking.id,
                      status: 'rejected',
                    ),
                  );
            },
            child: Text(
              'Reject'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelBooking(dynamic booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel booking?'.tr()),
        content: Text('Are you sure you want to cancel this confirmed booking?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BookingBloc>().add(
                    CancelBookingEvent(
                      listingId: booking.listingId,
                      bookingId: booking.id,
                    ),
                  );
            },
            child: Text(
              'Yes, cancel'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingManagementWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const BookingManagementWrapperWidget({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BookingBloc(
        bookingRepository: bookingApiManager,
      ),
      child: BookingManagementScreen(currentUser: currentUser),
    );
  }
}
