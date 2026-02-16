import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:instaflutter/listings/model/tap_model.dart';

enum DateRangeOption { last7Days, last30Days, last90Days, allTime }

extension DateRangeOptionExtension on DateRangeOption {
  String get label {
    switch (this) {
      case DateRangeOption.last7Days:
        return 'Last 7 days'.tr();
      case DateRangeOption.last30Days:
        return 'Last 30 days'.tr();
      case DateRangeOption.last90Days:
        return 'Last 90 days'.tr();
      case DateRangeOption.allTime:
        return 'All Time'.tr();
    }
  }
}

class AdvancedAnalyticsScreen extends StatefulWidget {
  final ListingsUser currentUser;
  const AdvancedAnalyticsScreen({super.key, required this.currentUser});

  @override
  State<AdvancedAnalyticsScreen> createState() =>
      _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  late FirebaseFirestore _firestore;
  bool _isLoading = true;
  
  List<ListingModel> _userListings = [];
  ListingModel? _selectedListing;
  DateRangeOption _selectedDateRange = DateRangeOption.last30Days;
  
  Map<String, dynamic> _advancedMetrics = {};

  final List<FlSpot> _viewSparklineData = const [
    FlSpot(0, 30), FlSpot(1, 52), FlSpot(2, 41), FlSpot(3, 68),
    FlSpot(4, 55), FlSpot(5, 70), FlSpot(6, 62),
  ];

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _loadUserListings();
  }

  Future<void> _loadUserListings() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final listingsSnap = await _firestore
          .collection(cfg.listingsCollection)
          .where('authorID', isEqualTo: widget.currentUser.userID)
          .get();
      final listings = listingsSnap.docs.map((doc) {
        final model = ListingModel.fromJson(doc.data());
        model.id = doc.id;
        return model;
      }).toList();
      
      if (mounted) {
        setState(() => _userListings = listings);
        await _fetchAnalyticsData();
      }
    } catch (e, s) {
      print('❌ Error loading user listings: $e\n$s');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnalyticsData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startTime;
      switch (_selectedDateRange) {
        case DateRangeOption.last7Days:
          startTime = now.subtract(const Duration(days: 7));
          break;
        case DateRangeOption.last30Days:
          startTime = now.subtract(const Duration(days: 30));
          break;
        case DateRangeOption.last90Days:
          startTime = now.subtract(const Duration(days: 90));
          break;
        case DateRangeOption.allTime:
          startTime = DateTime(2000);
          break;
      }
      final previousStartTime = startTime.subtract(now.difference(startTime));
      
      final listingIds = _selectedListing != null ? [_selectedListing!.id] : _userListings.map((l) => l.id).toList();

      if (listingIds.isEmpty) {
        _calculateAdvancedMetrics(listings: [], reviews: [], totalFavorites: 0, 
                                  chatsLast: 0, chatsPrevious: 0,
                                  bookingsLast: 0, bookingsPrevious: 0,
                                  favoritesLast: 0, favoritesPrevious: 0,
                                  tapsLast: 0, tapsPrevious: 0);
        return;
      }
      
      final bookingsLast = await _fetchCountInDateRange('bookings', 'listingId', listingIds, 'createdAt', startTime, now);
      final bookingsPrevious = await _fetchCountInDateRange('bookings', 'listingId', listingIds, 'createdAt', previousStartTime, startTime);

      final chatsLast = await _fetchCountInDateRange('${socialFeedsCollection}/${widget.currentUser.userID}/chat_feed_live', 'listingId', listingIds, 'createdAt', startTime, now);
      final chatsPrevious = await _fetchCountInDateRange('${socialFeedsCollection}/${widget.currentUser.userID}/chat_feed_live', 'listingId', listingIds, 'createdAt', previousStartTime, startTime);
      
      final favoritesLast = await _fetchFavoritesCountInDateRange(listingIds, startTime, now);
      final favoritesPrevious = await _fetchFavoritesCountInDateRange(listingIds, previousStartTime, startTime);
      final totalFavorites = await _fetchTotalFavorites(listingIds);

      final tapsLast = await _fetchTapsCountInDateRange(listingIds, startTime, now);
      final tapsPrevious = await _fetchTapsCountInDateRange(listingIds, previousStartTime, startTime);

      final reviewsSnap = await _firestore.collection(cfg.reviewCollection).where('listingID', whereIn: listingIds).get();
      final allReviews = reviewsSnap.docs.map((doc) => ListingReviewModel.fromJson(doc.data())).toList();
      
      _calculateAdvancedMetrics(
        listings: _selectedListing != null ? [_selectedListing!] : _userListings,
        reviews: allReviews,
        totalFavorites: totalFavorites,
        chatsLast: chatsLast,
        chatsPrevious: chatsPrevious,
        bookingsLast: bookingsLast,
        bookingsPrevious: bookingsPrevious,
        favoritesLast: favoritesLast,
        favoritesPrevious: favoritesPrevious,
        tapsLast: tapsLast,
        tapsPrevious: tapsPrevious,
      );
      
    } catch (e, s) {
      print('❌ Error loading advanced analytics: $e\n$s');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _fetchCountInDateRange(String collection, String field, List<String> values, String dateField, DateTime start, DateTime end) async {
    if (values.isEmpty) return 0;
    try {
      Query query = _firestore.collection(collection)
        .where(field, whereIn: values)
        .where(dateField, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where(dateField, isLessThan: Timestamp.fromDate(end));
      
      final snapshot = await query.get();
      return snapshot.docs.length;
    } catch (e) {
      print('⚠️ Query failed for $collection: $e');
      return 0;
    }
  }

  Future<int> _fetchTapsCountInDateRange(List<String> listingIds, DateTime start, DateTime end) async {
    if (listingIds.isEmpty) return 0;
    int totalTaps = 0;
    for (String id in listingIds) {
      final snapshot = await _firestore
          .collection(cfg.listingsCollection)
          .doc(id)
          .collection('taps')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .get();
      totalTaps += snapshot.docs.length;
    }
    return totalTaps;
  }
  
  Future<int> _fetchFavoritesCountInDateRange(List<String> listingIds, DateTime start, DateTime end) async {
    // This logic remains client-side as filtering nested arrays in Firestore is not directly supported.
    if (listingIds.isEmpty) return 0;
    int count = 0;
    final usersSnap = await _firestore.collection('users').where('likedListings', isNotEqualTo: []).get();
    for (var userDoc in usersSnap.docs) {
      final likedListings = userDoc.data()['likedListings'] as List<dynamic>? ?? [];
      for (var item in likedListings) {
        if (item is Map<String, dynamic> && listingIds.contains(item['listingId'])) {
          final favoritedAt = _parseTimestamp(item['favoritedAt']);
          if (favoritedAt != null && favoritedAt.isAfter(start) && favoritedAt.isBefore(end)) {
            count++;
          }
        }
      }
    }
    return count;
  }

  Future<int> _fetchTotalFavorites(List<String> listingIds) async {
    if (listingIds.isEmpty) return 0;
    int count = 0;
    // Note: This query is inefficient and may become slow.
    // A better approach would be to denormalize a `favoritedBy` list on the listing itself.
    final usersSnap = await _firestore.collection('users').where('likedListingsIDs', arrayContainsAny: listingIds).get();
     for (var userDoc in usersSnap.docs) {
        final likedListings = List<String>.from(userDoc.data()['likedListingsIDs'] ?? []);
        count += likedListings.where((id) => listingIds.contains(id)).length;
      }
    return count;
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  void _calculateAdvancedMetrics({
    required List<ListingModel> listings,
    required List<ListingReviewModel> reviews,
    required int totalFavorites,
    required int chatsLast,
    required int chatsPrevious,
    required int bookingsLast,
    required int bookingsPrevious,
    required int favoritesLast,
    required int favoritesPrevious,
    required int tapsLast,
    required int tapsPrevious,
  }) {
    int totalViews = listings.fold(0, (sum, l) => sum + l.viewCount);
    double avgRating = reviews.isEmpty ? 0 : reviews.map((r) => r.starCount).reduce((a, b) => a + b) / reviews.length;
    
    double _calculateTrend(int current, int previous) {
      if (previous > 0) return (current - previous) / previous;
      return current > 0 ? 1.0 : 0.0;
    }

    // Logic for Growth Opportunities
    final lowQualityListings = listings.where((l) => l.photos.length < 3 || l.description.length < 100).toList();
    final bookingsNeeded = (TapBadge.communityVouched.threshold - (bookingsLast + bookingsPrevious)).clamp(0, 10);

    setState(() {
      _advancedMetrics = {
        'totalViews': totalViews,
        'totalFavorites': totalFavorites,
        'totalReviews': reviews.length,
        'totalChats': chatsLast,
        'totalTaps': tapsLast,
        'avgRating': avgRating,
        'totalListings': listings.length,
        'totalBookings': bookingsLast,
        'bookingsTrend': _calculateTrend(bookingsLast, bookingsPrevious),
        'chatsTrend': _calculateTrend(chatsLast, chatsPrevious),
        'favoritesTrend': _calculateTrend(favoritesLast, favoritesPrevious),
        'tapsTrend': _calculateTrend(tapsLast, tapsPrevious),
        'viewsTrend': 0.15, // Mock data
        'lowQualityListings': lowQualityListings,
        'bookingsForBadge': bookingsNeeded,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode(context);
    final Color scaffoldBackgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Advanced Analytics'.tr(), style: TextStyle(color: primaryTextColor)),
        elevation: 0,
        backgroundColor: scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: primaryTextColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : RefreshIndicator(
              onRefresh: _fetchAnalyticsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 16),
                    _buildSectionHeader('Performance Snapshot'.tr()),
                    _buildPerformanceSnapshot(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Engagement Deep Dive'.tr()),
                    _buildEngagementGrid(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Growth Opportunities'.tr()),
                    _buildInsights(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilters() {
    final bool isDark = isDarkMode(context);
    final Color dropdownColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final Color chipColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: dropdownColor,
              borderRadius: BorderRadius.circular(8),
              border: isDark ? null : Border.all(color: Colors.grey.shade300)
            ),
            child: DropdownButton<ListingModel?>(
              value: _selectedListing,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: Text("All Listings".tr()),
              items: [
                DropdownMenuItem<ListingModel?>(
                  value: null,
                  child: Text("All Listings".tr()),
                ),
                ..._userListings.map((listing) => DropdownMenuItem<ListingModel?>(
                  value: listing,
                  child: Text(listing.title, overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedListing = value);
                _fetchAnalyticsData();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PopupMenuButton<DateRangeOption>(
            onSelected: (DateRangeOption result) {
              setState(() => _selectedDateRange = result);
              _fetchAnalyticsData();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<DateRangeOption>>[
              ...DateRangeOption.values.map((option) => PopupMenuItem<DateRangeOption>(
                value: option,
                child: Text(option.label),
              ))
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(8),
                border: isDark ? null : Border.all(color: Colors.grey.shade300)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: isDark ? Colors.white70 : Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_selectedDateRange.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20, 
          fontWeight: FontWeight.bold,
          color: isDarkMode(context) ? Colors.white : Colors.black,
        ),
      ),
    );
  }
  
  Widget _buildPerformanceSnapshot() {
    final int totalViews = _advancedMetrics['totalViews'] ?? 0;
    final double viewsTrend = _advancedMetrics['viewsTrend'] ?? 0.0;
    final int totalBookings = _advancedMetrics['totalBookings'] ?? 0;
    final double bookingsTrend = _advancedMetrics['bookingsTrend'] ?? 0.0;
    final bool isDark = isDarkMode(context);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color subtleTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Views'.tr(),
                      style: TextStyle(color: subtleTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.compact().format(totalViews),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTrendIndicator(viewsTrend, 'vs previous period'.tr()),
                  ],
                ),
                SizedBox(
                  width: 120,
                  height: 50,
                  child: LineChart(
                    _sparklineChartData(_viewSparklineData, viewsTrend >= 0),
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Bookings'.tr(), totalBookings.toString(), bookingsTrend),
                _buildStatItem(
                    'Avg. Rating'.tr(),
                    '${_advancedMetrics['avgRating']?.toStringAsFixed(1) ?? 'N/A'} ★',
                    null),
                _buildStatItem(
                    'Listings'.tr(),
                    _advancedMetrics['totalListings']?.toString() ?? '0',
                    null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          'Favorites'.tr(),
          _advancedMetrics['totalFavorites']?.toString() ?? '0',
          Icons.favorite_border,
          Colors.pink,
          _advancedMetrics['favoritesTrend'],
        ),
        _buildMetricCard(
          'Reviews'.tr(),
          _advancedMetrics['totalReviews']?.toString() ?? '0',
          Icons.rate_review_outlined,
          Colors.orange,
          null,
        ),
        _buildMetricCard(
          'Chat Initiations'.tr(),
          _advancedMetrics['totalChats']?.toString() ?? '0',
          Icons.chat_bubble_outline,
          Colors.blue,
          _advancedMetrics['chatsTrend'],
        ),
        _buildMetricCard(
          'Taps / Vouch'.tr(),
          _advancedMetrics['totalTaps']?.toString() ?? '0',
          Icons.touch_app_outlined,
          Colors.teal,
          _advancedMetrics['tapsTrend'],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color color, double? trend) {
    final bool isDark = isDarkMode(context);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color subtleTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: subtleTextColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (trend != null) ...[
                  const SizedBox(height: 4),
                  _buildTrendIndicator(trend, ''),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsights() {
    final lowQualityListings = _advancedMetrics['lowQualityListings'] as List<ListingModel>? ?? [];
    final bookingsNeeded = _advancedMetrics['bookingsForBadge'] as int? ?? 0;

    return Column(
      children: [
        if (lowQualityListings.isNotEmpty)
          _buildInsightCard(
            Icons.lightbulb_outline,
            Colors.amber,
            'Improve Listing Quality'.tr(),
            'You have ${lowQualityListings.length} listings that could be improved with more photos or a longer description.'.tr(),
          ),
        if (bookingsNeeded > 0)
          _buildInsightCard(
            Icons.military_tech_outlined,
            Colors.green,
            'Become a Top Lister'.tr(),
            'You are $bookingsNeeded bookings away from earning the "Community Vouched" badge!'.tr(),
          ),
      ],
    );
  }

  Widget _buildInsightCard(IconData icon, Color color, String title, String subtitle) {
    final bool isDark = isDarkMode(context);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color subtleTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Card(
      color: cardColor,
      elevation: isDark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: isDark ? Colors.white : Colors.black
        )),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: subtleTextColor)),
        trailing: const Icon(Icons.arrow_forward, size: 18),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, double? trend) {
    final bool isDark = isDarkMode(context);
    final Color subtleTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: subtleTextColor, fontSize: 12)),
        if (trend != null) ...[
          const SizedBox(height: 4),
          _buildTrendIndicator(trend, ''),
        ]
      ],
    );
  }

  Widget _buildTrendIndicator(double trend, String text) {
    final bool isPositive = trend > 0;
    final bool isNeutral = trend.abs() < 0.001;
    final color =
        isNeutral ? Colors.grey : (isPositive ? Colors.green : Colors.red);
    final icon = isNeutral
        ? Icons.arrow_right_alt
        : (isPositive ? Icons.arrow_upward : Icons.arrow_downward);

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${(trend * 100).toStringAsFixed(0)}% $text',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  LineChartData _sparklineChartData(List<FlSpot> spots, bool isPositive) {
    final color = isPositive ? Colors.green : Colors.red;
    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }
}
