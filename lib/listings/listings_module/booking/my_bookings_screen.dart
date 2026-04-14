import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/model/attention_state_model.dart';
import 'package:caribtap/listings/ui/attention/attention_cubit.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/ui/chat/chat/chat_screen.dart';
import 'package:caribtap/core/model/user.dart' as core_user;
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/booking/booking_bloc.dart';
import 'package:caribtap/listings/listings_module/booking/booking_event.dart';
import 'package:caribtap/listings/listings_module/booking/booking_state.dart';
import 'package:caribtap/listings/listings_module/api/booking_api_manager.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/ui/collaboration/chat_scope_integration.dart';
import 'package:caribtap/listings/listings_module/proof_of_payment/proof_of_payment_upload_widget.dart';
import 'package:caribtap/listings/model/proof_of_payment_model.dart';
import 'package:intl/intl.dart';

class MyBookingsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const MyBookingsScreen({super.key, required this.currentUser});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}
class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    context
        .read<BookingBloc>()
        .add(GetMyBookingsEvent(userId: widget.currentUser.userID));
    // Clear the my-bookings badge whenever this screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<AttentionCubit>()
            .markModuleAsSeen(AttentionModule.myBookings);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
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
    if (booking.listersUserId == null || booking.listersUserId.isEmpty) {
      showSnackBar(context, 'Missing host ID'.tr());
      return;
    }

    final customerId = booking.customerId ?? widget.currentUser.userID;
    final allowed = await ChatScopeIntegration.canAccessOrderThreadChat(
      orderId: booking.id,
      listingId: booking.listingId,
      userId: widget.currentUser.userID,
      listingOwnerId: booking.listersUserId,
      customerUid: customerId,
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
      userID: customerId,
      firstName: booking.customerName ?? widget.currentUser.firstName,
      profilePictureURL: widget.currentUser.profilePictureURL,
    );

    final channel = await ChatScopeIntegration.createOrderThreadChat(
      orderId: booking.id,
      listingId: booking.listingId,
      ownerUid: booking.listersUserId,
      ownerUser: ownerUser,
      customerUid: customerId,
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
        title: Text('My Bookings'.tr()),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 18),
          labelColor: Colors.white,
          unselectedLabelColor: isDarkMode(context) ? Colors.white70 : Colors.black,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Pending'.tr()),
            Tab(text: 'Confirmed'.tr()),
            Tab(text: 'Past'.tr()),
            Tab(text: 'Rejected'.tr()),
            Tab(text: 'Cancelled'.tr()),
          ],
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          } else if (state is MyBookingsLoadedState) {
            final allBookings = state.bookings;
            final pendingBookings = allBookings.where((b) => b.isPending).toList();
            final confirmedBookings =
                allBookings.where((b) => b.isConfirmed).toList();
            final rejectedBookings =
                allBookings.where((b) => b.isRejected).toList();
            final cancelledBookings =
                allBookings.where((b) => b.isCancelled).toList();

            final filteredPendingBookings =
                pendingBookings.where(_matchesBookingSearch).toList();
            final filteredRejectedBookings =
                rejectedBookings.where(_matchesBookingSearch).toList();
            final filteredCancelledBookings =
                cancelledBookings.where(_matchesBookingSearch).toList();
           
       // Split confirmed bookings into upcoming and past
       final upcomingConfirmedBookings = confirmedBookings
         .where((b) => !_isBookingInPast(b))
         .toList();
       final pastConfirmedBookings = confirmedBookings
         .where((b) => _isBookingInPast(b))
         .toList();
           
       final filteredUpcomingConfirmedBookings =
         upcomingConfirmedBookings.where(_matchesBookingSearch).toList();
       final filteredPastConfirmedBookings =
         pastConfirmedBookings.where(_matchesBookingSearch).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search bookings...'.tr(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingsList(filteredPendingBookings, 'pending'),
                          _buildBookingsList(filteredUpcomingConfirmedBookings, 'confirmed'),
                          _buildBookingsList(filteredPastConfirmedBookings, 'past'),
                                         _buildBookingsList(filteredRejectedBookings, 'rejected'),
                                         _buildBookingsList(filteredCancelledBookings, 'cancelled'),
                    ],
                  ),
                ),
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
                            GetMyBookingsEvent(
                              userId: widget.currentUser.userID,
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

  bool _matchesBookingSearch(dynamic booking) {
    if (_searchQuery.isEmpty) return true;

    final checkIn = booking.checkInDate is DateTime
        ? DateFormat('MMM dd, yyyy').format(booking.checkInDate as DateTime)
        : '';
    final checkOut = booking.checkOutDate is DateTime
        ? DateFormat('MMM dd, yyyy').format(booking.checkOutDate as DateTime)
        : '';

    final haystack = [
      (booking.listingTitle ?? '').toString(),
      (booking.listersName ?? '').toString(),
      (booking.status ?? '').toString(),
      (booking.guestNotes ?? '').toString(),
      checkIn,
      checkOut,
      (booking.numberOfGuests ?? '').toString(),
    ].join(' ').toLowerCase();

    return haystack.contains(_searchQuery);
  }

  bool _isBookingInPast(dynamic booking) {
    if (booking.checkOutDate is! DateTime) return false;
    final checkOutDate = booking.checkOutDate as DateTime;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return DateTime(checkOutDate.year, checkOutDate.month, checkOutDate.day)
        .isBefore(todayOnly);
  }

  Widget _buildBookingsList(List<dynamic> bookings, String status) {
    if (bookings.isEmpty) {
      return _buildEmptyState(status);
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
    final String hostName = (booking.listersName ?? '').toString().trim();

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
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100,
                      height: 100,
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
                      if (hostName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${'Host'.tr()}: $hostName',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _localizedBookingStatus(booking.status),
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
            Divider(
              color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              '${'Booked On'.tr()}: ${DateFormat('MMM dd, yyyy').format(booking.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${'Start Date'.tr()}: ${DateFormat('MMM dd, yyyy').format(booking.checkInDate)}',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${'End Date'.tr()}: ${DateFormat('MMM dd, yyyy').format(booking.checkOutDate)}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${'Duration'.tr()}: ${booking.numberOfNights} ${booking.numberOfNights > 1 ? 'nights'.tr() : 'night'.tr()}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${'Guests'.tr()}: ${booking.numberOfGuests}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (booking.guestNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Your notes:'.tr(),
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
                  fontStyle: FontStyle.italic,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
            // Proof of Payment section - Only show for confirmed bookings
            if (booking.isConfirmed) ...[
              const SizedBox(height: 16),
              ProofOfPaymentUploadWidget(
                listingId: booking.listingId,
                orderId: booking.id,
                currentUserId: widget.currentUser.userID,
                isLister: false,
                listingAcceptsProofOfPayment: booking.listingAcceptsProofOfPayment,
                proofOfPayment: booking.proofOfPayment != null
                    ? ProofOfPayment.fromJson(booking.proofOfPayment)
                    : null,
                onUploadComplete: () {
                  // Refresh booking data
                  context
                      .read<BookingBloc>()
                      .add(GetMyBookingsEvent(userId: widget.currentUser.userID));
                },
              ),
            ],
            if (booking.isPending && !_isCustomerCancellationLocked(booking)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelBooking(booking),
                  child: Text('Cancel request'.tr()),
                ),
              ),
            ] else if (booking.isPending && _isCustomerCancellationLocked(booking)) ...[
              const SizedBox(height: 12),
              Text(
                'Cancellation is no longer available for this booking.'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ] else if (booking.isConfirmed) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showContactHost(booking),
                      child: Text('Contact host'.tr()),
                    ),
                  ),
                  if (!_isCustomerCancellationLocked(booking)) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _cancelBooking(booking),
                        child: Text('Cancel booking'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
              if (_isCustomerCancellationLocked(booking)) ...[
                const SizedBox(height: 8),
                Text(
                  'Cancellation is no longer available for this booking.'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: dark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ] else if (booking.isCancelled && (booking.cancellationReason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Cancellation reason'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                booking.cancellationReason!.trim(),
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _localizedBookingStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending'.tr();
      case 'confirmed':
        return 'Confirmed'.tr();
      case 'rejected':
        return 'Rejected'.tr();
      case 'cancelled':
        return 'Cancelled'.tr();
      default:
        return status;
    }
  }

  Widget _buildEmptyState(String status) {
    final dark = isDarkMode(context);
    final label = _emptyBookingsLabel(status);

    if (status == 'pending' && _searchQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 52,
                color: dark ? Colors.white24 : Colors.black26,
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your booking may have been confirmed or rejected by the host — check the other tabs.'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.white54 : Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text('Check Confirmed'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(cfg.colorPrimary),
                  side: BorderSide(color: Color(cfg.colorPrimary).withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: dark ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }

  String _emptyBookingsLabel(String status) {
    switch (status) {
      case 'pending':
        return 'No pending bookings'.tr();
      case 'confirmed':
        return 'No confirmed bookings'.tr();
      case 'past':
        return 'No past bookings'.tr();
      case 'rejected':
        return 'No rejected bookings'.tr();
      case 'cancelled':
        return 'No cancelled bookings'.tr();
      default:
        return 'No bookings'.tr();
    }
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

  DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  bool _hasTerminalCompletionTag(dynamic booking) {
    final completionTag = (booking.completionTag ?? '').toString().trim().toLowerCase();
    return completionTag == 'completed' || completionTag == 'no_show';
  }

  bool _hasBookingPeriodEnded(dynamic booking) {
    final checkOut = _asDateTime(booking.checkOutDate);
    if (checkOut == null) return false;
    final endOfDay = DateTime(
      checkOut.year,
      checkOut.month,
      checkOut.day,
      23,
      59,
      59,
      999,
    );
    return DateTime.now().isAfter(endOfDay);
  }

  bool _isCustomerCancellationLocked(dynamic booking) {
    return _hasTerminalCompletionTag(booking) || _hasBookingPeriodEnded(booking);
  }

  void _cancelBooking(dynamic booking) {
    if (_isCustomerCancellationLocked(booking)) {
      showAlertDialog(
        context,
        'Cancellation unavailable'.tr(),
        'This booking can no longer be cancelled.'.tr(),
      );
      return;
    }

    final bookingBloc = context.read<BookingBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConfirmed = (booking.status ?? '').toString().toLowerCase() == 'confirmed';
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF22242A) : null,
        title: Text(
          isConfirmed ? 'Cancel confirmed booking?'.tr() : 'Cancel booking request?'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConfirmed
                    ? 'Please let the host know why you are cancelling this confirmed booking.'.tr()
                    : 'Are you sure you want to cancel this booking request?'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              if (isConfirmed) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  maxLines: 3,
                  maxLength: 250,
                  decoration: InputDecoration(
                    labelText: 'Cancellation reason'.tr(),
                    hintText: 'Enter your reason'.tr(),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'No'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final cancellationReason = reasonController.text.trim();
              if (isConfirmed && cancellationReason.isEmpty) {
                showAlertDialog(
                  context,
                  'Cancellation reason required'.tr(),
                  'Please provide a reason so the host can review it.'.tr(),
                );
                return;
              }

              Navigator.pop(dialogContext);
              bookingBloc.add(
                CancelBookingEvent(
                  listingId: booking.listingId,
                  bookingId: booking.id,
                  cancellationReason: cancellationReason.isEmpty ? null : cancellationReason,
                  cancelledBy: 'customer',
                  cancelledByUserId: widget.currentUser.userID,
                ),
              );
              // Wait a short moment for cancellation to process, then refresh bookings
              await Future.delayed(const Duration(milliseconds: 500));
              bookingBloc.add(
                GetMyBookingsEvent(userId: widget.currentUser.userID),
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

  void _showContactHost(dynamic booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listersEmail = booking.listersEmail ?? '';
    final listersName = booking.listersName ?? '';
    // Use only fields that exist on BookingModel for host phone
    // Only use customerPhone if it exists on BookingModel
    final listersPhone = (booking.customerPhone ?? '').toString();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF22242A) : null,
        title: Text(
          'Contact host'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listersName,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              if (listersEmail.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Email: $listersEmail',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy Email',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: '')); // dummy to ensure import
                        Clipboard.setData(ClipboardData(text: listersEmail));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Email copied'.tr())),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.email, size: 20),
                      tooltip: 'Send Email',
                      color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      final uri = Uri(
                        scheme: 'mailto',
                        path: listersEmail,
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ],
              ),
            // Only show phone actions if a valid phone field exists on booking
            if (listersPhone.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phone: $listersPhone',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy Phone',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: listersPhone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone copied'.tr())),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, size: 20),
                    tooltip: 'Call',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: listersPhone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.sms, size: 20),
                    tooltip: 'Send SMS',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () async {
                      final uri = Uri(scheme: 'sms', path: listersPhone);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MyBookingsWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const MyBookingsWrapperWidget({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BookingBloc(
        bookingRepository: bookingApiManager,
      ),
      child: MyBookingsScreen(currentUser: currentUser),
    );
  }
}
