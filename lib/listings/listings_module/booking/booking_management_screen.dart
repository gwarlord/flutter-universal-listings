import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/ui/chat/chat/chat_screen.dart';
import 'package:caribtap/core/model/user.dart' as core_user;
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/api/booking_api_manager.dart';
import 'package:caribtap/listings/listings_module/booking/booking_bloc.dart';
import 'package:caribtap/listings/listings_module/booking/booking_event.dart';
import 'package:caribtap/listings/listings_module/booking/booking_state.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/ui/collaboration/chat_scope_integration.dart';
import 'package:caribtap/listings/listings_module/proof_of_payment/proof_of_payment_upload_widget.dart';
import 'package:caribtap/listings/model/proof_of_payment_model.dart';
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
  bool _statusUpdated = false;
  DateTime? _selectedFilterDate;
  Set<String> _bookingDateKeys = {};

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

  void _updateBookingDateKeys(List<dynamic> bookings) {
    final nextKeys = _collectBookingDateKeys(bookings);
    if (_bookingDateKeys.length == nextKeys.length && _bookingDateKeys.containsAll(nextKeys)) {
      return;
    }
    setState(() {
      _bookingDateKeys = nextKeys;
    });
  }

  Future<void> _openOrderChat(dynamic booking) async {
    if (booking.id == null || booking.id.isEmpty) {
      showSnackBar(context, 'Missing order ID'.tr());
      return;
    }
    if (booking.listingId == null || booking.listingId.isEmpty) {
      showSnackBar(context, 'Missing listing ID'.tr());
      return;
    }
    if (booking.customerId == null || booking.customerId.isEmpty) {
      showSnackBar(context, 'Missing customer ID'.tr());
      return;
    }
    if (booking.listersUserId == null || booking.listersUserId.isEmpty) {
      showSnackBar(context, 'Missing owner ID'.tr());
      return;
    }

    final allowed = await ChatScopeIntegration.canAccessOrderThreadChat(
      orderId: booking.id,
      listingId: booking.listingId,
      userId: widget.currentUser.userID,
      listingOwnerId: booking.listersUserId,
      customerUid: booking.customerId,
    );

    if (!allowed) {
      showSnackBar(context, 'You do not have access to this chat'.tr());
      return;
    }

    final collaborators = await collaborationApiManager.getListingCollaborators(
      listingId: booking.listingId,
    );

    final collaboratorUsers = collaborators
        .where((c) => c.permissions.manageChats)
        .map((c) => core_user.User(
              userID: c.uid,
              firstName: c.displayName ?? 'Collaborator',
              profilePictureURL: c.profilePictureUrl ?? '',
            ))
        .toList();

    final ownerUser = core_user.User(
      userID: booking.listersUserId,
      firstName: booking.listersName,
    );

    final customerUser = core_user.User(
      userID: booking.customerId,
      firstName: booking.customerName,
    );

    final channel = await ChatScopeIntegration.createOrderThreadChat(
      orderId: booking.id,
      listingId: booking.listingId,
      ownerUid: booking.listersUserId,
      ownerUser: ownerUser,
      customerUid: booking.customerId,
      customerUser: customerUser,
      collaboratorUsers: collaboratorUsers,
    );

    if (!mounted) return;
    await push(
      context,
      ChatWrapperWidget(
        channelDataModel: channel,
        currentUser: widget.currentUser,
        colorPrimary: Color(cfg.colorPrimary),
        colorAccent: Color(cfg.colorAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Booking Requests'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _selectedFilterDate != null ? Color(cfg.colorPrimary) : null,
            ),
            onPressed: _bookingDateKeys.isEmpty ? null : _openBookingDateFilter,
            tooltip: _selectedFilterDate == null
                ? 'Filter by date'.tr()
                : DateFormat('MMM dd, yyyy').format(_selectedFilterDate!),
          ),
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
      body: BlocListener<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingErrorState) {
            _statusUpdated = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is ReceivedBookingsLoadedState && _statusUpdated) {
            // Show success only after a status update
            _statusUpdated = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Booking status updated successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          if (state is ReceivedBookingsLoadedState) {
            _updateBookingDateKeys(state.bookings);
          }
        },
        child: BlocBuilder<BookingBloc, BookingState>(
          builder: (context, state) {
            if (state is BookingLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            } else if (state is ReceivedBookingsLoadedState) {
              final allBookings = _applyDateFilter(state.bookings);
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
      ),
    );
  }

  Future<void> _openBookingDateFilter() async {
    if (_bookingDateKeys.isEmpty) {
      showSnackBar(context, 'No bookings available for filtering'.tr());
      return;
    }

    final dark = isDarkMode(context);
    DateTime displayMonth = _selectedFilterDate ?? DateTime.now();
    displayMonth = DateTime(displayMonth.year, displayMonth.month);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setDialogState(() {
                        displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(displayMonth),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setDialogState(() {
                        displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
              content: _buildCalendarGrid(displayMonth, dark, onSelect: (selected) {
                setState(() {
                  _selectedFilterDate = selected;
                });
                Navigator.pop(dialogContext);
              }),
              actions: [
                if (_selectedFilterDate != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedFilterDate = null;
                      });
                      Navigator.pop(dialogContext);
                    },
                    child: Text('Clear filter'.tr()),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Close'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    DateTime displayMonth,
    bool dark, {
    required ValueChanged<DateTime> onSelect,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final firstDayOfWeekIndex = localizations.firstDayOfWeekIndex;
    final weekdayLabels = List.generate(
      7,
      (index) => localizations.narrowWeekdays[(index + firstDayOfWeekIndex) % 7],
    );

    final daysInMonth = DateUtils.getDaysInMonth(displayMonth.year, displayMonth.month);
    final firstWeekday = DateTime(displayMonth.year, displayMonth.month, 1).weekday;
    final firstDayIndex = firstWeekday % 7;
    final leadingEmpty = (firstDayIndex - firstDayOfWeekIndex + 7) % 7;
    final totalCells = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;
    final primary = Color(cfg.colorPrimary);

    return SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                final dayIndex = index - leadingEmpty + 1;
                if (dayIndex < 1 || dayIndex > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(displayMonth.year, displayMonth.month, dayIndex);
                final key = _dateKey(date);
                final hasBooking = _bookingDateKeys.contains(key);
                final isSelected = _selectedFilterDate != null && DateUtils.isSameDay(_selectedFilterDate, date);

                final bgColor = isSelected
                    ? primary
                    : hasBooking
                        ? primary.withOpacity(0.2)
                        : Colors.transparent;
                final textColor = isSelected
                    ? Colors.white
                    : hasBooking
                        ? primary
                        : (dark ? Colors.white70 : Colors.black87);

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: hasBooking ? () => onSelect(date) : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      dayIndex.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasBooking ? FontWeight.w600 : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Dates with bookings'.tr(),
                style: TextStyle(fontSize: 11, color: dark ? Colors.white54 : Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyDateFilter(List<dynamic> bookings) {
    if (_selectedFilterDate == null) {
      return bookings;
    }

    final target = DateUtils.dateOnly(_selectedFilterDate!);
    return bookings.where((booking) => _isBookingOnDate(booking, target)).toList();
  }

  bool _isBookingOnDate(dynamic booking, DateTime target) {
    final start = DateUtils.dateOnly(booking.checkInDate);
    final end = DateUtils.dateOnly(booking.checkOutDate);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  Set<String> _collectBookingDateKeys(List<dynamic> bookings) {
    final keys = <String>{};
    for (final booking in bookings) {
      final start = DateUtils.dateOnly(booking.checkInDate);
      final end = DateUtils.dateOnly(booking.checkOutDate);
      DateTime cursor = start;
      while (!cursor.isAfter(end)) {
        keys.add(_dateKey(cursor));
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return keys;
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
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
                IconButton(
                  tooltip: 'Order Chat'.tr(),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => _openOrderChat(booking),
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
            if (booking.customAnswers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Custom questions'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: booking.customAnswers.entries
                    .map<Widget>((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: dark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.value.isEmpty ? '-'.tr() : e.value,
                            style: TextStyle(
                              fontSize: 11,
                              color: dark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
              ),
            ],
            // Proof of Payment section - Only show for confirmed bookings
            if (booking.isConfirmed) ...[
              const SizedBox(height: 16),
              ProofOfPaymentUploadWidget(
                listingId: booking.listingId,
                orderId: booking.id,
                currentUserId: widget.currentUser.userID,
                isLister: true,
                listingAcceptsProofOfPayment: booking.listingAcceptsProofOfPayment,
                proofOfPayment: booking.proofOfPayment != null
                    ? ProofOfPayment.fromJson(booking.proofOfPayment)
                    : null,
                onReviewComplete: () {
                  // Refresh bookings after review
                  _refreshBookings();
                },
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
    _statusUpdated = true;
    context.read<BookingBloc>().add(
          UpdateBookingStatusEvent(
            listingId: booking.listingId,
            bookingId: booking.id,
            status: 'confirmed',
          ),
        );
  }

  void _rejectBooking(dynamic booking) {
    // Validate booking data
    if (booking.listingId == null || booking.listingId.isEmpty) {
      print('❌ DEBUG: Invalid listingId: ${booking.listingId}');
      showAlertDialog(context, 'Error'.tr(), 'Invalid booking data: missing listing ID'.tr());
      return;
    }
    if (booking.id == null || booking.id.isEmpty) {
      print('❌ DEBUG: Invalid bookingId: ${booking.id}');
      showAlertDialog(context, 'Error'.tr(), 'Invalid booking data: missing booking ID'.tr());
      return;
    }
    
    print('✅ DEBUG: Booking data valid - listingId: ${booking.listingId}, bookingId: ${booking.id}');
    
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Reject booking?'.tr(),
          style: TextStyle(
            color: dark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to reject this booking?'.tr(),
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _statusUpdated = true;
              print('DEBUG: Rejecting booking - listingId: ${booking.listingId}, bookingId: ${booking.id}');
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _cancelBooking(dynamic booking) {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        title: Text('Cancel booking?'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black87)),
        content: Text('Are you sure you want to cancel this confirmed booking?'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('No'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _statusUpdated = true;
              context.read<BookingBloc>().add(
                    CancelBookingEvent(
                      listingId: booking.listingId,
                      bookingId: booking.id,
                    ),
                  );
            },
            child: Text(
              'Yes, cancel'.tr(),
              style: TextStyle(color: Colors.red),
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
