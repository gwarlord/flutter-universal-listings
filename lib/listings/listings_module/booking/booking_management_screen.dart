import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/model/attention_state_model.dart';
import 'package:caribtap/listings/ui/attention/attention_cubit.dart';
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
import 'package:caribtap/listings/services/blocked_user_repository.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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
    // Clear the booking-requests badge whenever this screen opens,
    // regardless of how the user navigated here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<AttentionCubit>()
            .markModuleAsSeen(AttentionModule.bookingRequests);
      }
    });
  }

  Future<_CustomerPreview> _fetchCustomerPreview(dynamic booking) async {
    final customerId = (booking.customerId ?? '').toString();
    final fallbackName = (booking.customerName ?? '').toString().trim().isNotEmpty
        ? booking.customerName.toString().trim()
        : 'Customer'.tr();
    final fallbackPhone = (booking.customerPhone ?? '').toString().trim();
    final fallbackEmail = (booking.customerEmail ?? '').toString().trim();

    if (customerId.isEmpty) {
      return _CustomerPreview(
        name: fallbackName,
        phone: fallbackPhone.isNotEmpty ? fallbackPhone : null,
        email: fallbackEmail.isNotEmpty ? fallbackEmail : null,
      );
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();

      if (!userDoc.exists) {
        return _CustomerPreview(
          name: fallbackName,
          phone: fallbackPhone.isNotEmpty ? fallbackPhone : null,
          email: fallbackEmail.isNotEmpty ? fallbackEmail : null,
        );
      }

      final data = userDoc.data();
      final firstName = (data?['firstName'] as String?)?.trim() ?? '';
      final lastName = (data?['lastName'] as String?)?.trim() ?? '';
      final displayName = (data?['displayName'] as String?)?.trim() ?? '';
      final fullName = (data?['name'] as String?)?.trim() ?? '';
      final email = (data?['email'] as String?)?.trim() ?? '';
      final phone = (data?['phoneNumber'] as String?)?.trim() ??
          (data?['phone'] as String?)?.trim() ?? '';
      final profilePictureURL =
          (data?['profilePictureURL'] as String?)?.trim() ?? '';

      final combinedName = '$firstName $lastName'.trim();
      final resolvedName = combinedName.isNotEmpty
          ? combinedName
          : (displayName.isNotEmpty
              ? displayName
              : (fullName.isNotEmpty ? fullName : fallbackName));

      return _CustomerPreview(
        name: resolvedName,
        phone: phone.isNotEmpty ? phone : (fallbackPhone.isNotEmpty ? fallbackPhone : null),
        email: email.isNotEmpty ? email : (fallbackEmail.isNotEmpty ? fallbackEmail : null),
        profilePictureURL: profilePictureURL,
      );
    } catch (_) {
      return _CustomerPreview(
        name: fallbackName,
        phone: fallbackPhone.isNotEmpty ? fallbackPhone : null,
        email: fallbackEmail.isNotEmpty ? fallbackEmail : null,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final selectedDateKey = _selectedFilterDate != null
        ? _dateKey(DateUtils.dateOnly(_selectedFilterDate!))
        : null;
    final shouldClearSelectedDate =
        selectedDateKey != null && !nextKeys.contains(selectedDateKey);

    if (_bookingDateKeys.length == nextKeys.length &&
        _bookingDateKeys.containsAll(nextKeys) &&
        !shouldClearSelectedDate) {
      return;
    }
    setState(() {
      _bookingDateKeys = nextKeys;
      if (shouldClearSelectedDate) {
        _selectedFilterDate = null;
      }
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
        title: Text('Manage Bookings'.tr()),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _selectedFilterDate != null ? Color(cfg.colorPrimary) : null,
            ),
            onPressed: _bookingDateKeys.isEmpty ? null : _openBookingDateFilter,
            tooltip: _selectedFilterDate == null
                ? 'Filter by date'.tr()
                : DateFormat('MMM dd, yyyy', context.locale.toString()).format(_selectedFilterDate!),
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
              final pendingBookings =
                  allBookings.where((b) => b.isPending).toList();
              final confirmedBookings =
                  allBookings.where((b) => b.isConfirmed).toList();

              final filteredAllBookings =
                  allBookings.where(_matchesBookingSearch).toList();
              final filteredPendingBookings =
                  pendingBookings.where(_matchesBookingSearch).toList();
              final filteredConfirmedBookings =
                  confirmedBookings.where(_matchesBookingSearch).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
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
                        const SizedBox(height: 6),
                        AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            final int tabIndex = _tabController.index;
                            int count;
                            String label;

                            if (tabIndex == 0) {
                              count = filteredPendingBookings.length;
                              label = 'Pending'.tr();
                            } else if (tabIndex == 1) {
                              count = filteredConfirmedBookings.length;
                              label = 'Confirmed'.tr();
                            } else {
                              count = filteredAllBookings.length;
                              label = 'All'.tr();
                            }

                            return Text(
                              _searchQuery.isEmpty
                                  ? '${count.toString()} ${label.toLowerCase()} ${'bookings'.tr().toLowerCase()}'
                                  : '${count.toString()} ${'matching'.tr()} ${label.toLowerCase()} ${'bookings'.tr().toLowerCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode(context)
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookingsList(filteredPendingBookings),
                        _buildBookingsList(filteredConfirmedBookings),
                        _buildBookingsList(filteredAllBookings),
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
      (booking.customerName ?? '').toString(),
      (booking.customerEmail ?? '').toString(),
      (booking.customerPhone ?? '').toString(),
      (booking.status ?? '').toString(),
      (booking.guestNotes ?? '').toString(),
      checkIn,
      checkOut,
      (booking.numberOfGuests ?? '').toString(),
    ].join(' ').toLowerCase();

    return haystack.contains(_searchQuery);
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
                    DateFormat('MMMM yyyy', context.locale.toString()).format(displayMonth),
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
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 320,
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.55,
                ),
                child: SingleChildScrollView(
                  child: _buildCalendarGrid(displayMonth, dark, onSelect: (selected) {
                    setState(() {
                      _selectedFilterDate = selected;
                    });
                    Navigator.pop(dialogContext);
                  }),
                ),
              ),
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
                'Dates with active bookings'.tr(),
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
      if (!_isCalendarRelevantBookingStatus(booking)) {
        continue;
      }

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

  bool _isCalendarRelevantBookingStatus(dynamic booking) {
    final status = (booking.status ?? '').toString().toLowerCase();
    return status == 'pending' || status == 'confirmed';
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
    final String bookingStatus = (booking.status ?? '').toString().toLowerCase();
    final String completionTag = (booking.completionTag ?? '').toString().trim().toLowerCase();
    final String cancelledBy = (booking.cancelledBy ?? '').toString().toLowerCase();
    final String cancelledByUserId = (booking.cancelledByUserId ?? '').toString().trim();
    final String customerId = (booking.customerId ?? '').toString().trim();
    final String cancellationReason = (booking.cancellationReason ?? '').toString().trim();
    final bool isCustomerCancelled =
        bookingStatus == 'cancelled' &&
        cancelledBy == 'customer' &&
        cancelledByUserId.isNotEmpty &&
        cancelledByUserId == customerId;

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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      if (completionTag.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCompletionTagColor(completionTag).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _localizedCompletionTag(completionTag),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getCompletionTagColor(completionTag),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FutureBuilder<_CustomerPreview>(
                future: _fetchCustomerPreview(booking),
                builder: (context, snapshot) {
                  final preview = snapshot.data ?? _CustomerPreview(
                    name: (booking.customerName ?? '').toString().trim().isNotEmpty
                        ? booking.customerName.toString().trim()
                        : 'Customer'.tr(),
                    phone: (booking.customerPhone ?? '').toString().trim().isNotEmpty
                        ? booking.customerPhone.toString().trim()
                        : null,
                    email: (booking.customerEmail ?? '').toString().trim().isNotEmpty
                        ? booking.customerEmail.toString().trim()
                        : null,
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: preview.profilePictureURL.isNotEmpty
                            ? NetworkImage(preview.profilePictureURL)
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: preview.profilePictureURL.isEmpty
                            ? Icon(Icons.person, size: 16, color: Colors.grey[700])
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer'.tr(),
                              style: TextStyle(
                                fontSize: 11,
                                color: dark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              preview.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: dark ? Colors.white70 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (preview.phone != null && preview.phone!.isNotEmpty)
                              Text(
                                preview.phone!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dark ? Colors.white54 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else if (preview.email != null && preview.email!.isNotEmpty)
                              Text(
                                preview.email!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: dark ? Colors.white54 : Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Message customer'.tr(),
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                        onPressed: () => _openOrderChat(booking),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ── Trust badge (verified phone) ────────────────────────────────
            if (booking.requesterPhoneVerified == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Verified Phone'.tr(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((booking.customerPhone ?? '').isNotEmpty) ...[
                      Text(
                        '  •  ${booking.customerPhone}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (isCustomerCancelled && cancellationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Customer cancellation reason'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cancellationReason,
                style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],

            // ── Block user action (lister only, customer-cancelled bookings) ─
            if (isCustomerCancelled &&
                customerId.isNotEmpty &&
                customerId != widget.currentUser.userID &&
                cancellationReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showBlockUserDialog(booking),
                  icon: const Icon(Icons.block, size: 14, color: Colors.red),
                  label: Text(
                    'Block this user from future bookings'.tr(),
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
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
              '${DateFormat('MMM dd, yyyy', context.locale.toString()).format(booking.checkInDate)} - ${DateFormat('MMM dd, yyyy', context.locale.toString()).format(booking.checkOutDate)} (${booking.numberOfNights} ${booking.numberOfNights == 1 ? 'night'.tr() : 'nights'.tr()})',
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: completionTag == 'completed'
                          ? null
                          : () => _tagBookingCompletion(booking, 'completed'),
                      child: Text('Mark completed'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: completionTag == 'no_show'
                          ? null
                          : () => _tagBookingCompletion(booking, 'no_show'),
                      child: Text('Mark no-show'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

  Color _getCompletionTagColor(String tag) {
    switch (tag.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'no_show':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  String _localizedCompletionTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'completed':
        return 'Completed'.tr();
      case 'no_show':
        return 'No-show'.tr();
      default:
        return tag;
    }
  }

  void _tagBookingCompletion(dynamic booking, String completionTag) {
    _statusUpdated = true;
    collaborationApiManager.logActivity(
      listingId: booking.listingId,
      actorUid: widget.currentUser.userID,
      actorName: widget.currentUser.fullName(),
      actorRole: 'OWNER',
      actionType: 'BOOKING_STATUS_CHANGED',
      targetType: 'BOOKING',
      targetId: booking.id,
      note: completionTag,
    );
    context.read<BookingBloc>().add(
          UpdateBookingCompletionTagEvent(
            listingId: booking.listingId,
            bookingId: booking.id,
            completionTag: completionTag,
            completionTaggedByUserId: widget.currentUser.userID,
            listersUserId: widget.currentUser.userID,
          ),
        );
  }

  void _approveBooking(dynamic booking) {
    _statusUpdated = true;
    collaborationApiManager.logActivity(
      listingId: booking.listingId,
      actorUid: widget.currentUser.userID,
      actorName: widget.currentUser.fullName(),
      actorRole: 'OWNER',
      actionType: 'BOOKING_STATUS_CHANGED',
      targetType: 'BOOKING',
      targetId: booking.id,
      note: 'confirmed',
    );
    context.read<BookingBloc>().add(
          UpdateBookingStatusEvent(
            listingId: booking.listingId,
            bookingId: booking.id,
            status: 'confirmed',
            listersUserId: widget.currentUser.userID,
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
              collaborationApiManager.logActivity(
                listingId: booking.listingId,
                actorUid: widget.currentUser.userID,
                actorName: widget.currentUser.fullName(),
                actorRole: 'OWNER',
                actionType: 'BOOKING_STATUS_CHANGED',
                targetType: 'BOOKING',
                targetId: booking.id,
                note: 'rejected',
              );
              context.read<BookingBloc>().add(
                    UpdateBookingStatusEvent(
                      listingId: booking.listingId,
                      bookingId: booking.id,
                      status: 'rejected',
                      listersUserId: widget.currentUser.userID,
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
              collaborationApiManager.logActivity(
                listingId: booking.listingId,
                actorUid: widget.currentUser.userID,
                actorName: widget.currentUser.fullName(),
                actorRole: 'OWNER',
                actionType: 'BOOKING_STATUS_CHANGED',
                targetType: 'BOOKING',
                targetId: booking.id,
                note: 'cancelled',
              );
              context.read<BookingBloc>().add(
                    CancelBookingEvent(
                      listingId: booking.listingId,
                      bookingId: booking.id,
                      cancelledBy: 'lister',
                      cancelledByUserId: widget.currentUser.userID,
                      listersUserId: widget.currentUser.userID,
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

  Future<void> _showBlockUserDialog(dynamic booking) async {
    final customerId = (booking.customerId ?? '').toString();
    if (customerId.isEmpty) return;

    final dark = isDarkMode(context);
    final onSurface = dark ? Colors.white : Colors.black87;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Block user?'.tr(),
          style: TextStyle(
            color: onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This user will no longer be able to send booking or rental requests to your business.'
                  .tr(),
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: onSurface),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason (optional)'.tr(),
                labelStyle:
                    TextStyle(color: dark ? Colors.white54 : Colors.black45),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey[800] : Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'.tr(),
                style:
                    TextStyle(color: dark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Block user'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await BlockedUserRepository().blockUser(
        listerId: widget.currentUser.userID,
        blockedUserId: customerId,
        reason: reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User has been blocked from future requests.'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to block user. Please try again.'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
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

class _CustomerPreview {
  final String name;
  final String? phone;
  final String? email;
  final String profilePictureURL;

  const _CustomerPreview({
    required this.name,
    this.phone,
    this.email,
    this.profilePictureURL = '',
  });
}
