import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/rental_booking.dart';
import 'package:instaflutter/listings/services/rental_service.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
import 'package:instaflutter/listings/ui/rentals/rental_booking_detail_screen.dart';

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
  final Map<String, String> _currencyCodeCache = {};
  late TabController _tabController;
  String _selectedStatus = 'all';
  bool _showHistory = false; // Toggle between active orders and all orders

  bool get _showListerTab =>
      isPremiumUser(widget.currentUser) || widget.currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _showListerTab ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final tabBar = TabBar(
      controller: _tabController,
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
                _buildCustomerTab(isDark),
                if (_showListerTab) _buildListerTab(isDark),
              ],
            )
          : Column(
              children: [
                Container(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  child: tabBar,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCustomerTab(isDark),
                      if (_showListerTab) _buildListerTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerTab(bool isDark) {
    return Column(
      children: [
        // Filter toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
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
                  color: isDark ? Colors.white : Colors.black,
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
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showHistory ? 'No rental history'.tr() : 'No active rentals'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) {
                  return _buildCustomerBookingCard(context, filteredBookings[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListerTab(bool isDark) {
    return Column(
      children: [
        _buildStatusFilter(isDark),
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

              if (_selectedStatus != 'all') {
                bookings = bookings
                    .where((b) => b.status.toString().split('.').last == _selectedStatus)
                    .toList();
              }

              if (bookings.isEmpty) {
                return _buildEmptyState(
                  isDark,
                  Icons.event_busy,
                  'No bookings'.tr(),
                  'Rental requests will appear here.'.tr(),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bookings.length,
                itemBuilder: (context, index) {
                  return _buildListerBookingCard(context, bookings[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilter(bool isDark) {
    final options = <String>[
      'all',
      'pending',
      'confirmed',
      'active',
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
              label: Text(status == 'all' ? 'All'.tr() : status.capitalize()),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedStatus = status),
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomerBookingCard(BuildContext context, RentalBooking booking) {
    final statusStyle = _statusStyle(booking.status);
    final canCancel = booking.status == RentalBookingStatus.pending ||
        booking.status == RentalBookingStatus.confirmed ||
        booking.status == RentalBookingStatus.active;

    return FutureBuilder<_RentalItemPreview>(
      future: _fetchRentalItemPreview(booking),
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final imageUrl = preview?.imageUrl;
        final title = preview?.title ?? 'Rental Item'.tr();
        final currencyCode = preview?.currencyCode ?? 'USD';

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
                  Row(
                    children: [
                      Icon(statusStyle.icon, size: 20, color: statusStyle.color),
                      const SizedBox(width: 8),
                      Text(
                        booking.status.toString().split('.').last.toUpperCase(),
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
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade200,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.image, color: Colors.grey.shade500);
                                  },
                                )
                              : Icon(Icons.image, color: Colors.grey.shade500),
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
                    'Start: ${_formatDateTime(context, booking.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'End: ${_formatDateTime(context, booking.endTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
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
    final isDark = isDarkMode(context);
    final reasonController = TextEditingController();
    bool showError = false;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Cancel booking?'.tr(),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please share a brief reason for cancellation.'.tr(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Schedule change'.tr(),
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Reason is required'.tr() : null,
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
                'Keep'.tr(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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
              child: Text('Cancel Booking'.tr()),
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
    final isDark = isDarkMode(context);
    final reasonController = TextEditingController();
    bool showError = false;

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Decline booking?'.tr(),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please share a brief reason for declining.'.tr(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g., Not available'.tr(),
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  border: const OutlineInputBorder(),
                  errorText: showError ? 'Reason is required'.tr() : null,
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
                'Keep'.tr(),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
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
              child: Text('Decline Booking'.tr()),
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

  Widget _buildListerBookingCard(BuildContext context, RentalBooking booking) {
    final statusStyle = _statusStyle(booking.status);
    return FutureBuilder<String>(
      future: _getListingCurrencyCode(booking.listingId),
      builder: (context, snapshot) {
        final currencyCode = snapshot.data ?? 'USD';

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
                  Row(
                    children: [
                      Icon(statusStyle.icon, size: 20, color: statusStyle.color),
                      const SizedBox(width: 8),
                      Text(
                        booking.status.toString().split('.').last.toUpperCase(),
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
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    'Start: ${_formatDateTime(context, booking.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'End: ${_formatDateTime(context, booking.endTime)}',
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
                            ),
                            child: Text('Decline'.tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _updateStatus(booking, RentalBookingStatus.confirmed),
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

  Widget _buildEmptyState(bool isDark, IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated'.tr())),
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

extension _StatusCapitalization on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
