import 'package:flutter/material.dart';
import '../../model/rental_booking.dart';

class RentalBookingDetailScreen extends StatelessWidget {
  final RentalBooking booking;

  const RentalBookingDetailScreen({
    Key? key,
    required this.booking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          _buildStatusCard(context),
          const SizedBox(height: 16),
          
          // Booking info
          _buildSection(
            context,
            title: 'Booking Information',
            children: [
              _buildInfoRow(context, 'Booking ID', booking.id),
              _buildInfoRow(
                context,
                'Start',
                _formatDateTime(context, booking.startTime),
              ),
              _buildInfoRow(
                context,
                'End',
                _formatDateTime(context, booking.endTime),
              ),
              _buildInfoRow(
                context,
                'Duration',
                '${booking.quantity} ${booking.pricingUnit.toString().split('.').last}(s)',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Pricing
          _buildSection(
            context,
            title: 'Pricing',
            children: [
              _buildInfoRow(context, 'Unit Price',
                  '\$${booking.unitPrice.toStringAsFixed(2)}'),
              _buildInfoRow(context, 'Subtotal',
                  '\$${booking.subtotal.toStringAsFixed(2)}'),
              if (booking.depositAmount > 0)
                _buildInfoRow(context, 'Deposit',
                    '\$${booking.depositAmount.toStringAsFixed(2)}'),
              if (booking.mileageOverageCharge != null &&
                  booking.mileageOverageCharge! > 0)
                _buildInfoRow(
                  context,
                  'Mileage Overage',
                  '\$${booking.mileageOverageCharge!.toStringAsFixed(2)}',
                  valueColor: Colors.orange,
                ),
              const Divider(),
              _buildInfoRow(
                context,
                'Total',
                '\$${booking.totalAmount.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // Vehicle info
          if (booking.startOdometer != null || booking.endOdometer != null) ...[
            const SizedBox(height: 16),
            _buildSection(
              context,
              title: 'Vehicle Information',
              children: [
                if (booking.startOdometer != null)
                  _buildInfoRow(context, 'Start Odometer',
                      '${booking.startOdometer} km'),
                if (booking.endOdometer != null)
                  _buildInfoRow(
                      context, 'End Odometer', '${booking.endOdometer} km'),
                if (booking.totalKilometersDriven != null)
                  _buildInfoRow(context, 'Distance Driven',
                      '${booking.totalKilometersDriven} km'),
              ],
            ),
          ],
          
          // Checkout evidence
          if (booking.checkoutEvidence != null) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(
              context,
              'Checkout Evidence',
              booking.checkoutEvidence!,
            ),
          ],
          
          // Checkin evidence
          if (booking.checkinEvidence != null) ...[
            const SizedBox(height: 16),
            _buildEvidenceSection(
              context,
              'Checkin Evidence',
              booking.checkinEvidence!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
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

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(statusIcon, size: 40, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.status.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (booking.isOverdue)
                    Text(
                      'OVERDUE FOR RETURN',
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
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    TextStyle? valueStyle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: valueStyle ??
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: valueColor,
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection(
    BuildContext context,
    String title,
    dynamic evidence, // RentalEvidence
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            // TODO: Display evidence media, checklist, damage reports
            Text('Evidence details would be displayed here'),
          ],
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
