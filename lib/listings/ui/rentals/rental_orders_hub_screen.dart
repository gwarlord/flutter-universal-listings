import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/rental_booking.dart';
import 'package:caribtap/listings/services/rental_service.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/ui/rentals/rental_booking_detail_screen.dart';

class RentalOrdersHubScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final bool showAppBar;

  const RentalOrdersHubScreen({
    Key? key,
    required this.currentUser,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<RentalOrdersHubScreen> createState() => _RentalOrdersHubScreenState();
}

class _RentalOrdersHubScreenState extends State<RentalOrdersHubScreen>
    with SingleTickerProviderStateMixin {
  final RentalService _rentalService = RentalService();
  final EntitlementService _entitlementService = EntitlementService();
  final Map<String, String> _currencyCodeCache = {};
  final Map<String, _CustomerPreview> _customerPreviewCache = {};
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _listerSearchController = TextEditingController();
  late TabController _tabController;
  late VoidCallback _entitlementListener;
  String _selectedStatus = 'pending';
  String _customerSearchQuery = '';
  String _listerSearchQuery = '';
  bool _showHistory = false; // Toggle between active orders and all orders
  bool _showListerTab = false;

  @override
  void initState() {
    super.initState();
    _showListerTab = ProGate.tierAtLeast(
      _entitlementService.currentEntitlement,
      2,
      isAdmin: widget.currentUser.isAdmin,
    );
    _tabController = TabController(length: _showListerTab ? 2 : 1, vsync: this);

    _entitlementListener = () {
      final hasAccess = ProGate.tierAtLeast(
        _entitlementService.currentEntitlement,
        2,
        isAdmin: widget.currentUser.isAdmin,
      );
      if (hasAccess != _showListerTab && mounted) {
        setState(() {
          _showListerTab = hasAccess;
          _tabController.dispose();
          _tabController =
              TabController(length: _showListerTab ? 2 : 1, vsync: this);
        });
      }
    };
    _entitlementService.entitlementNotifier.addListener(_entitlementListener);
  }

  @override
  void dispose() {
    _entitlementService.entitlementNotifier.removeListener(_entitlementListener);
    _customerSearchController.dispose();
    _listerSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final tabBar = TabBar(
      controller: _tabController,
      labelColor: Color(cfg.colorPrimary),
      unselectedLabelColor: isDark ? Colors.white : onSurface.withOpacity(0.7),
      tabs: [
        Tab(text: 'My Rentals'.tr()),
        if (_showListerTab) Tab(text: 'Manage Rentals'.tr()),
      ],
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('Rental Orders'.tr()),
              bottom: tabBar,
            )
          : null,
      body: widget.showAppBar
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildCustomerTab(),
                if (_showListerTab) _buildListerTab(),
              ],
            )
          : Column(
              children: [
                Container(
                  color: surface,
                  child: tabBar,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCustomerTab(),
                      if (_showListerTab) _buildListerTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerTab() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    final onSurfaceFaint = onSurface.withOpacity(0.5);
    final outline = theme.colorScheme.outline;

    return Column(
      children: [
        // Filter toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: outline,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showHistory ? 'All Rentals'.tr() : 'Active Rentals'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showHistory = !_showHistory;
                  });
                },
                icon: Icon(
                  _showHistory ? Icons.filter_list_off : Icons.history,
                  size: 20,
                ),
                label: Text(_showHistory ? 'Active Only'.tr() : 'Show History'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Color(cfg.colorPrimary),
                ),
              ),
            ],
          ),
        ),
        _buildCustomerSearchBar(),
        // Rentals list
        Expanded(
          child: StreamBuilder<List<RentalBooking>>(
            stream: _rentalService.getCustomerBookings(widget.currentUser.userID),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var bookings = snapshot.data ?? [];

              // Filter bookings based on toggle
              final filteredBookings = _showHistory
                  ? bookings
                  : bookings
                      .where((b) =>
                          b.status == RentalBookingStatus.pending ||
                          b.status == RentalBookingStatus.confirmed ||
                          b.status == RentalBookingStatus.active)
                      .toList();

              if (filteredBookings.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: onSurfaceFaint,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showHistory ? 'No rental history'.tr() : 'No active rentals'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (_customerSearchQuery.trim().isEmpty) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    return _buildCustomerBookingCard(context, filteredBookings[index]);
                  },
                );
              }

              return FutureBuilder<List<RentalBooking>>(
                future: _filterBookingsForSearch(filteredBookings, _customerSearchQuery),
                builder: (context, searchSnapshot) {
                  if (searchSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final searched = searchSnapshot.data ?? const <RentalBooking>[];
                  if (searched.isEmpty) {
                    return _buildEmptyState(
                      Icons.search_off,
                      'No matching rentals'.tr(),
                      'Try order #, customer name/email, or product'.tr(),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: searched.length,
                    itemBuilder: (context, index) {
                      return _buildCustomerBookingCard(context, searched[index]);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _customerSearchController,
        onChanged: (value) {
          setState(() {
            _customerSearchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by order #, name, email, product'.tr(),
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(Icons.search, color: hintColor),
          suffixIcon: _customerSearchQuery.trim().isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  color: hintColor,
                  tooltip: 'Clear'.tr(),
                  onPressed: () {
                    setState(() {
                      _customerSearchController.clear();
                      _customerSearchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey.shade800 : theme.colorScheme.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildListerTab() {
    return Column(
      children: [
        _buildStatusFilter(),
        _buildListerSearchBar(),
        Expanded(
          child: StreamBuilder<List<RentalBooking>>(
            stream: _rentalService.getListerBookings(widget.currentUser.userID),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              var bookings = snapshot.data ?? [];
              final hasSearch = _listerSearchQuery.trim().isNotEmpty;

              if (_selectedStatus != 'all') {
                if (_selectedStatus == 'completed') {
                  bookings = bookings.where((b) {
                    final slug = b.status.toString().split('.').last;
                    return slug == 'completed' || slug == 'disputed';
                  }).toList();
                } else {
                  bookings = bookings
                      .where((b) => b.status.toString().split('.').last == _selectedStatus)
                      .toList();
                }
              }

              // Oldest request first so listers see requests in FIFO order.
              bookings.sort((a, b) {
                final byCreatedAt = a.createdAt.compareTo(b.createdAt);
                if (byCreatedAt != 0) return byCreatedAt;
                return a.id.compareTo(b.id);
              });

              if (bookings.isEmpty) {
                return _buildEmptyState(
                  Icons.event_busy,
                  'No bookings'.tr(),
                  'Rental requests will appear here.'.tr(),
                );
              }

              if (!hasSearch) {
                final customerIssueBookingIds =
                    _buildCustomerIssueBookingIds(snapshot.data ?? const <RentalBooking>[]);
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _buildListerBookingCard(
                      context,
                      booking,
                      hasPriorIssueHistory:
                          _hasPriorIssueHistory(booking, customerIssueBookingIds),
                    );
                  },
                );
              }

              return FutureBuilder<List<RentalBooking>>(
                future: _filterBookingsForSearch(bookings, _listerSearchQuery),
                builder: (context, searchSnapshot) {
                  if (searchSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final filtered = searchSnapshot.data ?? const <RentalBooking>[];
                  if (filtered.isEmpty) {
                    return _buildEmptyState(
                      Icons.search_off,
                      'No matching bookings'.tr(),
                      'Try order #, customer name/email, or product'.tr(),
                    );
                  }

                  filtered.sort((a, b) {
                    final byCreatedAt = a.createdAt.compareTo(b.createdAt);
                    if (byCreatedAt != 0) return byCreatedAt;
                    return a.id.compareTo(b.id);
                  });

                  final customerIssueBookingIds =
                      _buildCustomerIssueBookingIds(snapshot.data ?? const <RentalBooking>[]);

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final booking = filtered[index];
                      return _buildListerBookingCard(
                        context,
                        booking,
                        hasPriorIssueHistory:
                            _hasPriorIssueHistory(booking, customerIssueBookingIds),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListerSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _listerSearchController,
        onChanged: (value) {
          setState(() {
            _listerSearchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by order #, name, email, product'.tr(),
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(Icons.search, color: hintColor),
          suffixIcon: _listerSearchQuery.trim().isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  color: hintColor,
                  tooltip: 'Clear'.tr(),
                  onPressed: () {
                    setState(() {
                      _listerSearchController.clear();
                      _listerSearchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? Colors.grey.shade800 : theme.colorScheme.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Future<List<RentalBooking>> _filterBookingsForSearch(
    List<RentalBooking> bookings,
    String rawQuery,
  ) async {
    final normalizedQuery = _normalizeSearchText(rawQuery);

    if (normalizedQuery.isEmpty) return bookings;

    final matches = await Future.wait(
      bookings.map((booking) async {
        final customerPreview = await _fetchCustomerPreview(booking.customerId);
        final itemPreview = await _fetchRentalItemPreview(booking);

        final bookingIdLower = booking.id.toLowerCase();
        final shortIdLower = booking.id.length >= 8
            ? booking.id.substring(0, 8).toLowerCase()
            : bookingIdLower;
        final nameLower = customerPreview.name.toLowerCase();
        final contactLower = (customerPreview.contact ?? '').toLowerCase();
        final productLower = itemPreview.title.toLowerCase();

        final normalizedBookingId = _normalizeSearchText(bookingIdLower);
        final normalizedShortId = _normalizeSearchText(shortIdLower);
        final normalizedName = _normalizeSearchText(nameLower);
        final normalizedContact = _normalizeSearchText(contactLower);
        final normalizedProduct = _normalizeSearchText(productLower);

        final matched = normalizedBookingId.contains(normalizedQuery) ||
          normalizedShortId.contains(normalizedQuery) ||
          normalizedName.contains(normalizedQuery) ||
          normalizedContact.contains(normalizedQuery) ||
          normalizedProduct.contains(normalizedQuery);

        return matched ? booking : null;
      }),
    );

    return matches.whereType<RentalBooking>().toList();
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Widget _buildStatusFilter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceVariant = theme.colorScheme.surfaceVariant;
    final outline = theme.colorScheme.outline;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    final primary = theme.colorScheme.primary;
    final options = <String>[
      'all',
      'active',
      'pending',
      'confirmed',
      'completed',
      'cancelled',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: options.map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_localizedStatusSlug(status)),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedStatus = status),
              selectedColor: primary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? primary : onSurfaceMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor:
                  isDark ? Colors.grey[850] : surfaceVariant,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.grey[700]! : outline),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _localizedStatusSlug(String status) {
    switch (status) {
      case 'all':
        return 'All'.tr();
      case 'pending':
        return 'Pending'.tr();
      case 'confirmed':
        return 'Confirmed'.tr();
      case 'active':
        return 'Active'.tr();
      case 'completed':
        return 'Completed'.tr();
      case 'cancelled':
        return 'Cancelled'.tr();
      case 'disputed':
        return 'Disputed'.tr();
      default:
        return status.capitalize();
    }
  }

  String _localizedBookingStatus(RentalBookingStatus status) {
    switch (status) {
      case RentalBookingStatus.pending:
        return 'Pending'.tr();
      case RentalBookingStatus.confirmed:
        return 'Confirmed'.tr();
      case RentalBookingStatus.active:
        return 'Active'.tr();
      case RentalBookingStatus.completed:
        return 'Completed'.tr();
      case RentalBookingStatus.cancelled:
        return 'Cancelled'.tr();
      case RentalBookingStatus.disputed:
        return 'Disputed'.tr();
    }
  }

  Widget _buildCustomerBookingCard(BuildContext context, RentalBooking booking) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final surfaceVariant = theme.colorScheme.surfaceVariant;
    final onSurface = theme.colorScheme.onSurface;
    final statusStyle = _statusStyle(booking.status);
    final canCancel = booking.status == RentalBookingStatus.pending ||
      (booking.status == RentalBookingStatus.confirmed &&
        booking.collectedAt == null);

    return FutureBuilder<_RentalItemPreview>(
      future: _fetchRentalItemPreview(booking),
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final imageUrl = preview?.imageUrl;
        final title = preview?.title ?? 'Rental Item'.tr();
        final currencyCode = preview?.currencyCode ?? 'USD';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: surface,
          child: InkWell(
            onTap: () => _navigateToDetail(booking),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusStyle.icon, size: 20, color: statusStyle.color),
                      const SizedBox(width: 8),
                      Text(
                        _localizedBookingStatus(booking.status),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: statusStyle.color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrency(booking.totalAmount, currencyCode),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                      ),
                    ],
                  ),
                  if (booking.depositAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${'Security Deposit'.tr()}: ${_formatCurrency(booking.depositAmount, currencyCode)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onSurface.withOpacity(0.75),
                            ),
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: surfaceVariant,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.image, color: onSurface.withOpacity(0.4));
                                  },
                                )
                              : Icon(Icons.image, color: onSurface.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${'Start'.tr()}: ${_formatDateTime(context, booking.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${'End'.tr()}: ${_formatDateTime(context, booking.endTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${'Requested'.tr()}: ${_formatDateTime(context, booking.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: onSurface.withOpacity(0.7),
                        ),
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmCancelBooking(context, booking),
                        icon: const Icon(Icons.cancel),
                        label: Text('Cancel Booking'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelBooking(BuildContext context, RentalBooking booking) async {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[850] : Colors.grey[100];
    final reasonController = TextEditingController();
    bool showError = false;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Cancel this booking?'.tr(),
            style: TextStyle(color: onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please share a brief reason so the renter understands what happened.'.tr(),
                style: TextStyle(color: onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: TextStyle(color: onSurface),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Schedule change'.tr(),
                  hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                  filled: true,
                  fillColor: fillColor,
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Please add a reason before continuing.'.tr() : null,
                ),
                onChanged: (_) {
                  if (showError) {
                    setState(() => showError = false);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go Back'.tr(),
                style: TextStyle(color: onSurface.withOpacity(0.8)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  setState(() => showError = true);
                  return;
                }
                Navigator.pop(context, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Confirm Cancellation'.tr()),
            ),
          ],
        ),
      ),
    );

    if (reason != null && reason.trim().isNotEmpty) {
      await _updateStatus(
        booking,
        RentalBookingStatus.cancelled,
        reason: reason.trim(),
      );
    }
  }

  Future<void> _confirmDeclineBooking(BuildContext context, RentalBooking booking) async {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[850] : Colors.grey[100];
    final reasonController = TextEditingController();
    const alreadyRentedReason =
      'This item is no longer available because it has already been rented.';
    bool showError = false;
    bool itemAlreadyRented = false;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Decline this booking request?'.tr(),
            style: TextStyle(color: onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please share a brief reason so the renter has a clear update.'.tr(),
                style: TextStyle(color: onSurface.withOpacity(0.8)),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: itemAlreadyRented,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Item is no longer available (already rented)'.tr(),
                  style: TextStyle(color: onSurface),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  final selected = value ?? false;
                  setState(() {
                    itemAlreadyRented = selected;
                    if (selected) {
                      reasonController.text = alreadyRentedReason;
                    } else if (reasonController.text.trim() == alreadyRentedReason) {
                      reasonController.clear();
                    }
                    if (showError && reasonController.text.trim().isNotEmpty) {
                      showError = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: TextStyle(color: onSurface),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Not available'.tr(),
                  hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                  filled: true,
                  fillColor: fillColor,
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Please add a reason before continuing.'.tr() : null,
                ),
                onChanged: (_) {
                  if (showError) {
                    setState(() => showError = false);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go Back'.tr(),
                style: TextStyle(color: onSurface.withOpacity(0.8)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  setState(() => showError = true);
                  return;
                }
                Navigator.pop(context, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Send Decline'.tr()),
            ),
          ],
        ),
      ),
    );

    if (reason != null && reason.trim().isNotEmpty) {
      await _updateStatus(
        booking,
        RentalBookingStatus.cancelled,
        reason: reason.trim(),
      );
    }
  }

  Widget _buildListerBookingCard(
    BuildContext context,
    RentalBooking booking, {
    bool hasPriorIssueHistory = false,
  }) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final surfaceVariant = theme.colorScheme.surfaceVariant;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    final statusStyle = _statusStyle(booking.status);
    
    return FutureBuilder<_RentalItemPreview>(
      future: _fetchRentalItemPreview(booking),
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final imageUrl = preview?.imageUrl;
        final title = preview?.title ?? 'Rental Item'.tr();
        final currencyCode = preview?.currencyCode ?? 'USD';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: surface,
          child: InkWell(
            onTap: () => _navigateToDetail(booking),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusStyle.icon, size: 20, color: statusStyle.color),
                      const SizedBox(width: 8),
                      Text(
                        _localizedBookingStatus(booking.status),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: statusStyle.color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrency(booking.totalAmount, currencyCode),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                      ),
                    ],
                  ),
                  if (booking.depositAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${'Security Deposit'.tr()}: ${_formatCurrency(booking.depositAmount, currencyCode)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onSurface.withOpacity(0.75),
                            ),
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: surfaceVariant,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.image, color: onSurface.withOpacity(0.4));
                                  },
                                )
                              : Icon(Icons.image, color: onSurface.withOpacity(0.4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<_CustomerPreview>(
                    future: _fetchCustomerPreview(booking.customerId),
                    builder: (context, snapshot) {
                      final preview = snapshot.data ?? const _CustomerPreview(name: 'Customer');
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preview.name,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (preview.contact != null && preview.contact!.isNotEmpty)
                                      Text(
                                        preview.contact!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: onSurfaceMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${'Requested'.tr()}: ${_formatDateTime(context, booking.createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: onSurfaceMuted,
                                ),
                          ),
                          if (hasPriorIssueHistory)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Prior rental issues noted'.tr(),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    color: Colors.orange,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Info'.tr(),
                                    onPressed: _showIssueHistoryInfo,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${'Start'.tr()}: ${_formatDateTime(context, booking.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${'End'.tr()}: ${_formatDateTime(context, booking.endTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (booking.status == RentalBookingStatus.pending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _confirmDeclineBooking(context, booking),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: Text('Decline'.tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateStatus(booking, RentalBookingStatus.confirmed),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Text('Confirm'.tr()),
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
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    final onSurfaceFaint = onSurface.withOpacity(0.5);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: onSurfaceFaint),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: onSurfaceMuted),
          ),
        ],
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

  Future<void> _updateStatus(
    RentalBooking booking,
    RentalBookingStatus status, {
    String? reason,
  }) async {
    try {
      await _rentalService.updateBookingStatus(
        bookingId: booking.id,
        newStatus: status,
        reason: reason,
      );
      if (mounted) {
        _showSuccessDialog('Status updated'.tr());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _friendlyRentalErrorMessage(
                e,
                isCancellation: status == RentalBookingStatus.cancelled,
              ),
            ),
          ),
        );
      }
    }
  }

  String _friendlyRentalErrorMessage(Object error, {bool isCancellation = false}) {
    final raw = error.toString().toLowerCase();

    if (isCancellation &&
        (raw.contains('can no longer be cancelled') ||
            raw.contains('already been collected') ||
            raw.contains('cannot cancel'))) {
      return 'This booking can no longer be cancelled because the item was already collected.';
    }

    if (isCancellation && raw.contains('permission-denied')) {
      return 'This booking can no longer be cancelled because it was already collected.';
    }

    return 'Error: $error';
  }

  void _showSuccessDialog(String message) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Success!'.tr(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text('OK'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, Set<String>> _buildCustomerIssueBookingIds(List<RentalBooking> bookings) {
    final map = <String, Set<String>>{};

    for (final booking in bookings) {
      final note = booking.returnIssueNote?.trim() ?? '';
      if (note.isEmpty || booking.customerId.isEmpty) {
        continue;
      }

      map.putIfAbsent(booking.customerId, () => <String>{}).add(booking.id);
    }

    return map;
  }

  bool _hasPriorIssueHistory(
    RentalBooking booking,
    Map<String, Set<String>> customerIssueBookingIds,
  ) {
    final issueBookingIds = customerIssueBookingIds[booking.customerId];
    if (issueBookingIds == null || issueBookingIds.isEmpty) {
      return false;
    }

    if (issueBookingIds.length > 1) {
      return true;
    }

    return !issueBookingIds.contains(booking.id);
  }

  void _showIssueHistoryInfo() {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Issue History'.tr(),
          style: TextStyle(color: onSurface),
        ),
        content: Text(
          'This customer has previous rentals with issues noted. Search this user in Manage Rentals to review those past bookings.'.tr(),
          style: TextStyle(color: onSurface.withOpacity(0.85)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'.tr()),
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(RentalBookingStatus status) {
    switch (status) {
      case RentalBookingStatus.pending:
        return _StatusStyle(Colors.orange, Icons.schedule);
      case RentalBookingStatus.confirmed:
        return _StatusStyle(Colors.blue, Icons.check_circle);
      case RentalBookingStatus.active:
        return _StatusStyle(Colors.green, Icons.play_circle);
      case RentalBookingStatus.completed:
        return _StatusStyle(Colors.grey, Icons.done_all);
      case RentalBookingStatus.cancelled:
        return _StatusStyle(Colors.red, Icons.cancel);
      case RentalBookingStatus.disputed:
        return _StatusStyle(Colors.purple, Icons.warning);
    }
  }

  String _formatDateTime(BuildContext context, DateTime dateTime) {
    final date = MaterialLocalizations.of(context).formatMediumDate(dateTime);
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(dateTime),
      alwaysUse24HourFormat: false,
    );
    return '$date at $time';
  }

  Future<_RentalItemPreview> _fetchRentalItemPreview(RentalBooking booking) async {
    final listingDoc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(booking.listingId)
        .get();
    final listingData = listingDoc.data();
    final listingTitle = (listingData?['title'] as String?)?.trim();
    final listingPhoto = _firstPhotoUrl(listingData);
    final listingCurrencyCode =
      ((listingData?['storeCurrencyCode'] as String?)?.trim() ?? '').isNotEmpty
        ? (listingData?['storeCurrencyCode'] as String)
        : ((listingData?['currencyCode'] as String?)?.trim() ?? '').isNotEmpty
          ? (listingData?['currencyCode'] as String)
          : 'USD';

    if (booking.rentalUnitId.isNotEmpty && booking.rentalUnitId != 'multiple') {
      final rentalDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(booking.listingId)
          .collection('rental_catalog')
          .doc(booking.rentalUnitId)
          .get();
      final rentalData = rentalDoc.data();
      final rentalTitle = (rentalData?['name'] as String?)?.trim();
      final rentalPhoto = _firstPhotoUrl(rentalData);
      final rentalCurrencyCode = (rentalData?['currencyCode'] as String?)?.trim();
      return _RentalItemPreview(
        title: rentalTitle?.isNotEmpty == true
            ? rentalTitle!
            : (listingTitle?.isNotEmpty == true ? listingTitle! : 'Rental Item'.tr()),
        imageUrl: rentalPhoto ?? listingPhoto,
        currencyCode: rentalCurrencyCode?.isNotEmpty == true
            ? rentalCurrencyCode!
            : listingCurrencyCode,
      );
    }

    return _RentalItemPreview(
      title: listingTitle?.isNotEmpty == true ? listingTitle! : 'Rental Item'.tr(),
      imageUrl: listingPhoto,
      currencyCode: listingCurrencyCode,
    );
  }

  Future<_CustomerPreview> _fetchCustomerPreview(String customerId) async {
    if (customerId.isEmpty) {
      return const _CustomerPreview(name: 'Customer');
    }

    final cached = _customerPreviewCache[customerId];
    if (cached != null) return cached;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(customerId)
        .get();
    if (!userDoc.exists) {
      return const _CustomerPreview(name: 'Customer');
    }

    final data = userDoc.data();
    final firstName = (data?['firstName'] as String?)?.trim() ?? '';
    final lastName = (data?['lastName'] as String?)?.trim() ?? '';
    final displayName = (data?['displayName'] as String?)?.trim() ?? '';
    final fullName = (data?['name'] as String?)?.trim() ?? '';
    final email = (data?['email'] as String?)?.trim() ?? '';
    final phone = (data?['phoneNumber'] as String?)?.trim() ??
        (data?['phone'] as String?)?.trim() ?? '';
    final profilePictureURL = (data?['profilePictureURL'] as String?)?.trim() ?? '';

    final combinedName = '$firstName $lastName'.trim();
    final resolvedName = combinedName.isNotEmpty
        ? combinedName
        : (displayName.isNotEmpty
            ? displayName
            : (fullName.isNotEmpty
                ? fullName
                : (email.isNotEmpty ? email : 'Customer')));
    final contact = email.isNotEmpty ? email : (phone.isNotEmpty ? phone : null);

    final preview = _CustomerPreview(name: resolvedName, contact: contact, profilePictureURL: profilePictureURL);
    _customerPreviewCache[customerId] = preview;
    return preview;
  }

  Future<String> _getListingCurrencyCode(String listingId) async {
    final cached = _currencyCodeCache[listingId];
    if (cached != null) return cached;

    final listingDoc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .get();
    final listingData = listingDoc.data();
    final currencyCode =
      ((listingData?['storeCurrencyCode'] as String?)?.trim() ?? '').isNotEmpty
        ? (listingData?['storeCurrencyCode'] as String)
        : ((listingData?['currencyCode'] as String?)?.trim() ?? '').isNotEmpty
          ? (listingData?['currencyCode'] as String)
          : 'USD';
    _currencyCodeCache[listingId] = currencyCode;
    return currencyCode;
  }

  String _formatCurrency(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)} ${currencyCode.toUpperCase()}';
  }

  String _getCurrencySymbol(String currencyCode) {
    final symbols = {
      'USD': '\$',
      'XCD': '\$',
      'JMD': '\$',
      'TTD': '\$',
      'BSD': '\$',
      'BBD': '\$',
      'CAD': '\$',
      'GBP': '£',
      'EUR': '€',
    };
    return symbols[currencyCode] ?? currencyCode;
  }

  String? _firstPhotoUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    final directPhoto = data['photo'];
    if (directPhoto is String && directPhoto.trim().isNotEmpty) {
      return directPhoto;
    }
    final photos = data['photos'];
    if (photos is List && photos.isNotEmpty) {
      final first = photos.first;
      if (first is String && first.trim().isNotEmpty) {
        return first;
      }
    }
    return null;
  }
}

class _StatusStyle {
  final Color color;
  final IconData icon;

  _StatusStyle(this.color, this.icon);
}

class _RentalItemPreview {
  final String title;
  final String? imageUrl;
  final String currencyCode;

  const _RentalItemPreview({
    required this.title,
    required this.imageUrl,
    required this.currencyCode,
  });
}

class _CustomerPreview {
  final String name;
  final String? contact;
  final String profilePictureURL;

  const _CustomerPreview({
    required this.name,
    this.contact,
    this.profilePictureURL = '',
  });
}

extension _StatusCapitalization on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
