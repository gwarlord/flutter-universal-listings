import 'package:flutter/material.dart';
import '../../model/rental_booking.dart';
import '../../services/rental_service.dart';
import 'rental_booking_detail_screen.dart';

class CustomerRentalsScreen extends StatelessWidget {
  final String customerId;

  const CustomerRentalsScreen({
    Key? key,
    required this.customerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    final onSurfaceFaint = onSurface.withOpacity(0.5);
    final rentalService = RentalService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rentals'),
      ),
      body: StreamBuilder<List<RentalBooking>>(
        stream: rentalService.getCustomerBookings(customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 80, color: onSurfaceFaint),
                  const SizedBox(height: 16),
                  Text(
                    'No rentals yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: onSurfaceMuted),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return _buildBookingCard(context, bookings[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, RentalBooking booking) {
    Color statusColor;
    IconData statusIcon;

    switch (booking.status) {
      case RentalBookingStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case RentalBookingStatus.confirmed:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        break;
      case RentalBookingStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.play_circle;
        break;
      case RentalBookingStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.done_all;
        break;
      case RentalBookingStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case RentalBookingStatus.disputed:
        statusColor = Colors.purple;
        statusIcon = Icons.warning;
        break;
    }

    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurfaceMuted = theme.colorScheme.onSurface.withOpacity(0.7);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: surface,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RentalBookingDetailScreen(booking: booking),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    booking.status.toString().split('.').last.toUpperCase(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '\$${booking.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'Start: ${_formatDateTime(context, booking.startTime)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: onSurfaceMuted),
              ),
              Text(
                'End: ${_formatDateTime(context, booking.endTime)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date at $time';
  }
}
