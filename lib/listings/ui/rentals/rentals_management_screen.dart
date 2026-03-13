import 'package:flutter/material.dart';
import '../../model/rental_booking.dart';
import '../../services/rental_service.dart';
import 'rental_booking_detail_screen.dart';

class RentalsManagementScreen extends StatefulWidget {
  final String listerId;

  const RentalsManagementScreen({
    Key? key,
    required this.listerId,
  }) : super(key: key);

  @override
  State<RentalsManagementScreen> createState() =>
      _RentalsManagementScreenState();
}

class _RentalsManagementScreenState extends State<RentalsManagementScreen>
    with SingleTickerProviderStateMixin {
  final RentalService _rentalService = RentalService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rental Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: StreamBuilder<List<RentalBooking>>(
        stream: _rentalService.getListerBookings(widget.listerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allBookings = snapshot.data ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsList(
                allBookings
                    .where((b) => b.status == RentalBookingStatus.active)
                    .toList(),
              ),
              _buildBookingsList(
                allBookings
                    .where((b) => b.status == RentalBookingStatus.pending)
                    .toList(),
              ),
              _buildBookingsList(
                allBookings
                    .where((b) => b.status == RentalBookingStatus.confirmed)
                    .toList(),
              ),
              _buildBookingsList(
                allBookings
                    .where((b) =>
                        b.status == RentalBookingStatus.completed ||
                        b.status == RentalBookingStatus.disputed)
                    .toList(),
              ),
              _buildBookingsList(
                allBookings
                    .where((b) => b.status == RentalBookingStatus.cancelled)
                    .toList(),
              ),
              _buildBookingsList(allBookings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsList(List<RentalBooking> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No bookings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        return _buildBookingCard(bookings[index]);
      },
    );
  }

  Widget _buildBookingCard(RentalBooking booking) {
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

    final dateFormat = MaterialLocalizations.of(context).formatMediumDate;
    final timeFormat = MaterialLocalizations.of(context).formatTimeOfDay;
    
    final startDate = dateFormat(booking.startTime);
    final startTime = timeFormat(
        TimeOfDay.fromDateTime(booking.startTime), alwaysUse24HourFormat: false);
    final endDate = dateFormat(booking.endTime);
    final endTime = timeFormat(
        TimeOfDay.fromDateTime(booking.endTime), alwaysUse24HourFormat: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status row
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
                  if (booking.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.red[900]),
                          const SizedBox(width: 4),
                          Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              
              // Date/time info
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start: $startDate at $startTime',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'End: $endDate at $endTime',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Pricing info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${booking.quantity} ${booking.pricingUnit.toString().split('.').last}(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    '\$${booking.totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              
              // Overage warning
              if (booking.mileageOverageCharge != null &&
                  booking.mileageOverageCharge! > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.orange[900]),
                      const SizedBox(width: 8),
                      Text(
                        'Mileage overage: \$${booking.mileageOverageCharge!.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Action buttons for pending bookings
              if (booking.status == RentalBookingStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _declineBooking(booking),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirmBooking(booking),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(RentalBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalBookingDetailScreen(booking: booking),
      ),
    );
  }

  Future<void> _confirmBooking(RentalBooking booking) async {
    try {
      await _rentalService.updateBookingStatus(
        bookingId: booking.id,
        newStatus: RentalBookingStatus.confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking confirmed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineBooking(RentalBooking booking) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _DeclineReasonDialog(),
    );

    if (reason != null) {
      try {
        await _rentalService.updateBookingStatus(
          bookingId: booking.id,
          newStatus: RentalBookingStatus.cancelled,
          reason: reason,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking declined')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _DeclineReasonDialog extends StatefulWidget {
  @override
  State<_DeclineReasonDialog> createState() => _DeclineReasonDialogState();
}

class _DeclineReasonDialogState extends State<_DeclineReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline Booking'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Reason for declining (optional)',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
