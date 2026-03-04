import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    context
        .read<BookingBloc>()
        .add(GetMyBookingsEvent(userId: widget.currentUser.userID));
  }

  @override
  void dispose() {
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
          labelColor: Colors.white,
          unselectedLabelColor: isDarkMode(context) ? Colors.white70 : Colors.black54,
          tabs: [
            Tab(text: 'Pending'.tr()),
            Tab(text: 'Confirmed'.tr()),
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

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBookingsList(pendingBookings, 'pending'),
                _buildBookingsList(confirmedBookings, 'confirmed'),
                _buildBookingsList(rejectedBookings, 'rejected'),
                _buildBookingsList(cancelledBookings, 'cancelled'),
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

  Widget _buildBookingsList(List<dynamic> bookings, String status) {
    if (bookings.isEmpty) {
      return Center(child: Text('No $status bookings'.tr()));
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
                      const SizedBox(height: 4),
                      Text(
                        'Host: ${booking.listersName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
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
            Divider(
              color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Start Date: ${DateFormat('MMM dd, yyyy').format(booking.checkInDate)}',
              style: TextStyle(
                fontSize: 12,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'End Date: ${DateFormat('MMM dd, yyyy').format(booking.checkOutDate)}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Duration: ${booking.numberOfNights} night${booking.numberOfNights > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Guests: ${booking.numberOfGuests}',
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
            if (booking.isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelBooking(booking),
                  child: Text('Cancel request'.tr()),
                ),
              ),
            ] else if (booking.isConfirmed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showContactHost(booking),
                  child: Text('Contact host'.tr()),
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

  void _cancelBooking(dynamic booking) {
    final bookingBloc = context.read<BookingBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF22242A) : null,
        title: Text(
          'Cancel booking request?'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel this booking request?'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
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
              Navigator.pop(dialogContext);
              bookingBloc.add(
                CancelBookingEvent(
                  listingId: booking.listingId,
                  bookingId: booking.id,
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
        content: Column(
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
