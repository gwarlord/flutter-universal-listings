import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/model/rental_booking.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/rental_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/core/utils/helper.dart';

class RentalBookingsScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const RentalBookingsScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<RentalBookingsScreen> createState() => _RentalBookingsScreenState();
}

class _RentalBookingsScreenState extends State<RentalBookingsScreen> {
  final RentalService _rentalService = RentalService();
  String _selectedTab = 'pending'; // pending, confirmed, completed, cancelled

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rental Bookings'.tr()),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDark ? Colors.grey.shade900 : Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton('Pending', 'pending', primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildTabButton('Confirmed', 'confirmed', primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildTabButton('Active', 'active', primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildTabButton('Completed', 'completed', primaryColor, isDark),
                  const SizedBox(width: 8),
                  _buildTabButton('Cancelled', 'cancelled', primaryColor, isDark),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Bookings List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rental_bookings')
                  .where('listingId', isEqualTo: widget.listing.id)
                  .where('status', isEqualTo: _selectedTab)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: {}'.tr(args: ['${snapshot.error}'])),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final bookings = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return RentalBooking.fromJson(data, doc.id);
                }).toList();

                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _emptyStateMessage(_selectedTab).tr(),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _buildBookingCard(booking, primaryColor, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String value, Color primaryColor, bool isDark) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label.tr(),
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(RentalBooking booking, Color primaryColor, bool isDark) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(booking.customerId).get(),
      builder: (context, userSnapshot) {
        String customerName = 'Customer'.tr();
        String customerEmail = '';
        
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          customerName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          customerEmail = userData['email'] ?? '';
        }

        return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.2),
                  child: Icon(Icons.person, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        customerEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(booking.status, primaryColor),
              ],
            ),
            const Divider(height: 24),

            // Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(booking.startTime),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        DateFormat('h:mm a').format(booking.startTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End'.tr(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(booking.endTime),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        DateFormat('h:mm a').format(booking.endTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Price
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Price'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '\$${booking.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  if (booking.depositAmount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Security Deposit'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          '\$${booking.depositAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            if (booking.status == RentalBookingStatus.pending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateBookingStatus(
                        booking,
                        RentalBookingStatus.cancelled,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Decline'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(
                        booking,
                        RentalBookingStatus.confirmed,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Confirm'.tr()),
                    ),
                  ),
                ],
              ),
            ] else if (booking.status == RentalBookingStatus.confirmed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateBookingStatus(
                    booking,
                    RentalBookingStatus.active,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Mark as Collected'.tr()),
                ),
              ),
            ] else if (booking.status == RentalBookingStatus.active) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(
                        booking,
                        RentalBookingStatus.completed,
                        returnedInGoodCondition: true,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Returned OK'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _promptReturnedIssues(booking),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Returned Issues'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildStatusChip(RentalBookingStatus status, Color primaryColor) {
    Color color;
    String label;

    switch (status) {
      case RentalBookingStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case RentalBookingStatus.confirmed:
        color = Colors.green;
        label = 'Confirmed';
        break;
      case RentalBookingStatus.active:
        color = Colors.blue;
        label = 'Active';
        break;
      case RentalBookingStatus.completed:
        color = Colors.grey;
        label = 'Completed';
        break;
      case RentalBookingStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
      case RentalBookingStatus.disputed:
        color = Colors.purple;
        label = 'Disputed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label.tr(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  RentalBookingStatus? _getStatusFromTab(String tab) {
    switch (tab) {
      case 'pending':
        return RentalBookingStatus.pending;
      case 'confirmed':
        return RentalBookingStatus.confirmed;
      case 'active':
        return RentalBookingStatus.active;
      case 'completed':
        return RentalBookingStatus.completed;
      case 'cancelled':
        return RentalBookingStatus.cancelled;
      default:
        return null;
    }
  }

  String _emptyStateMessage(String tab) {
    switch (tab) {
      case 'pending':
        return 'No pending bookings';
      case 'confirmed':
        return 'No confirmed bookings';
      case 'active':
        return 'No active bookings';
      case 'completed':
        return 'No completed bookings';
      case 'cancelled':
        return 'No cancelled bookings';
      default:
        return 'No bookings found';
    }
  }

  Future<void> _updateBookingStatus(
    RentalBooking booking,
    RentalBookingStatus newStatus,
    {bool? returnedInGoodCondition, String? returnIssueNote}
  ) async {
    try {
      final effectiveStatus = newStatus == RentalBookingStatus.disputed
          ? RentalBookingStatus.completed
          : newStatus;

      await _rentalService.updateBookingStatus(
        bookingId: booking.id,
        newStatus: effectiveStatus,
        returnedInGoodCondition: returnedInGoodCondition,
        returnIssueNote: returnIssueNote,
      );
      
      if (mounted) {
        final statusLabel = _statusLabel(effectiveStatus).tr().toLowerCase();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking status updated to {}'.tr(args: [statusLabel])),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating booking: {}'.tr(args: ['$e'])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _promptReturnedIssues(RentalBooking booking) async {
    final controller = TextEditingController();
    bool showError = false;

    final note = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Returned with issues'.tr()),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the issue'.tr(),
              border: const OutlineInputBorder(),
              errorText: showError ? 'Issue note is required'.tr() : null,
            ),
            onChanged: (_) {
              if (showError) {
                setState(() => showError = false);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  setState(() => showError = true);
                  return;
                }
                Navigator.pop(context, value);
              },
              child: Text('Save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (note == null || note.trim().isEmpty) return;

    await _updateBookingStatus(
      booking,
      RentalBookingStatus.completed,
      returnedInGoodCondition: false,
      returnIssueNote: note.trim(),
    );
  }

  String _statusLabel(RentalBookingStatus status) {
    switch (status) {
      case RentalBookingStatus.pending:
        return 'Pending';
      case RentalBookingStatus.confirmed:
        return 'Confirmed';
      case RentalBookingStatus.active:
        return 'Active';
      case RentalBookingStatus.completed:
        return 'Completed';
      case RentalBookingStatus.cancelled:
        return 'Cancelled';
      case RentalBookingStatus.disputed:
        return 'Disputed';
    }
  }
}
