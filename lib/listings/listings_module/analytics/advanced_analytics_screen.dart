import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';

class AdvancedAnalyticsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const AdvancedAnalyticsScreen({super.key, required this.currentUser});

  @override
  State<AdvancedAnalyticsScreen> createState() => _AdvancedAnalyticsScreenState();
}

class _AdvancedAnalyticsScreenState extends State<AdvancedAnalyticsScreen> {
  late FirebaseFirestore _firestore;
  bool _isLoading = true;
  List<ListingModel> _userListings = [];
  Map<String, dynamic> _advancedMetrics = {};
  List<ListingReviewModel> _allReviews = [];

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _loadAdvancedAnalytics();
  }

  Future<void> _loadAdvancedAnalytics() async {
    try {
      setState(() => _isLoading = true);

      // Fetch user's listings
      final listingsSnap = await _firestore
          .collection(cfg.listingsCollection)
          .where('authorID', isEqualTo: widget.currentUser.userID)
          .get();

      final listings = listingsSnap.docs
          .map((doc) {
            final model = ListingModel.fromJson(doc.data());
            model.id = doc.id;
            return model;
          })
          .toList();

      _userListings = listings;

      // Fetch all reviews for user's listings
      final listingIds = listings.map((l) => l.id).toList();
      List<ListingReviewModel> allReviews = [];
      
      if (listingIds.isNotEmpty) {
        for (var listingId in listingIds) {
          final reviewsSnap = await _firestore
              .collection(cfg.reviewCollection)
              .where('listingID', isEqualTo: listingId)
              .get();
          
          final reviews = reviewsSnap.docs
              .map((doc) => ListingReviewModel.fromJson(doc.data()))
              .toList();
          allReviews.addAll(reviews);
        }
      }

      _allReviews = allReviews;

      // Calculate advanced metrics
      _calculateAdvancedMetrics(listings, allReviews);

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading advanced analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateAdvancedMetrics(List<ListingModel> listings, List<ListingReviewModel> reviews) {
    // Total Views and Favorites
    int totalViews = listings.fold(0, (sum, l) => sum + l.viewCount);
    int totalFavorites = 0;
    
    // Rating Breakdown
    Map<int, int> ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var review in reviews) {
      final rating = review.starCount.round();
      ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
    }

    // Engagement Rate: (favorites + reviews) / views
    double engagementRate = totalViews > 0 
        ? ((totalFavorites + reviews.length) / totalViews * 100)
        : 0;

    // Listing Quality Score (0-100)
    double avgQualityScore = listings.isEmpty ? 0 : listings.map((l) {
      int score = 0;
      // Has photos (30 points)
      if (l.photos.isNotEmpty) score += 30;
      // Has description (20 points)
      if (l.description.isNotEmpty && l.description.length > 50) score += 20;
      // Has reviews (25 points)
      if (l.reviewsCount > 0) score += 25;
      // Has contact info (15 points)
      if (l.phone.isNotEmpty || l.email.isNotEmpty) score += 15;
      // Has services (10 points)
      if (l.services.isNotEmpty) score += 10;
      return score;
    }).reduce((a, b) => a + b) / listings.length;

    // Top performing listing
    ListingModel? topListing = listings.isEmpty ? null : listings.reduce((a, b) {
      int aScore = a.viewCount * 2 + (a.reviewsCount as int) * 5;
      int bScore = b.viewCount * 2 + (b.reviewsCount as int) * 5;
      return aScore > bScore ? a : b;
    });

    // Average rating
    double avgRating = reviews.isEmpty ? 0 : 
        reviews.map((r) => r.starCount).reduce((a, b) => a + b) / reviews.length;

    setState(() {
      _advancedMetrics = {
        'totalViews': totalViews,
        'totalFavorites': totalFavorites,
        'totalReviews': reviews.length,
        'engagementRate': engagementRate,
        'avgQualityScore': avgQualityScore,
        'ratingDistribution': ratingDistribution,
        'topListing': topListing,
        'avgRating': avgRating,
        'totalListings': listings.length,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Advanced Analytics'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : RefreshIndicator(
              onRefresh: _loadAdvancedAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(cfg.colorPrimary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(cfg.colorPrimary).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.diamond,
                            size: 16,
                            color: Color(cfg.colorPrimary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Premium Feature'.tr(),
                            style: TextStyle(
                              color: Color(cfg.colorPrimary),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Overview Stats
                    Text(
                      'Performance Overview'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.3,
                      children: [
                        _buildMetricCard(
                          'Engagement Rate',
                          '${_advancedMetrics['engagementRate']?.toStringAsFixed(1) ?? '0.0'}%',
                          Icons.trending_up,
                          Colors.green,
                          dark,
                        ),
                        _buildMetricCard(
                          'Quality Score',
                          '${_advancedMetrics['avgQualityScore']?.toStringAsFixed(0) ?? '0'}/100',
                          Icons.star_outline,
                          Colors.amber,
                          dark,
                        ),
                        _buildMetricCard(
                          'Total Reviews',
                          '${_advancedMetrics['totalReviews'] ?? 0}',
                          Icons.rate_review,
                          Colors.blue,
                          dark,
                        ),
                        _buildMetricCard(
                          'Avg Rating',
                          '${_advancedMetrics['avgRating']?.toStringAsFixed(1) ?? '0.0'}★',
                          Icons.star,
                          Colors.orange,
                          dark,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Rating Distribution
                    Text(
                      'Rating Distribution'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRatingDistribution(dark),

                    const SizedBox(height: 32),

                    // Top Performing Listing
                    if (_advancedMetrics['topListing'] != null) ...[
                      Text(
                        'Top Performing Listing'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTopListingCard(_advancedMetrics['topListing'], dark),
                      const SizedBox(height: 32),
                    ],

                    // Listing Quality Breakdown
                    Text(
                      'Listing Quality Breakdown'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQualityBreakdown(dark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool dark) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr(),
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution(bool dark) {
    final distribution = _advancedMetrics['ratingDistribution'] as Map<int, int>? ?? {};
    final maxCount = distribution.values.fold<int>(0, (max, val) => val > max ? val : max);
    final totalReviews = _advancedMetrics['totalReviews'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [5, 4, 3, 2, 1].map((stars) {
          final count = distribution[stars] ?? 0;
          final percentage = totalReviews > 0 ? (count / totalReviews * 100) : 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Row(
                    children: [
                      Text(
                        '$stars',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: dark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(cfg.colorPrimary).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text(
                    '$count (${percentage.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopListingCard(ListingModel listing, bool dark) {
    final score = listing.viewCount * 2 + (listing.reviewsCount as int) * 5;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          if (listing.photos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                listing.photos.first,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, size: 40),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.viewCount} views',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${listing.reviewsCount} reviews',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Score: $score',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityBreakdown(bool dark) {
    final qualityMetrics = [
      {'label': 'Complete Profiles', 'value': _getCompleteListingsCount(), 'total': _userListings.length},
      {'label': 'With Photos', 'value': _userListings.where((l) => l.photos.isNotEmpty).length, 'total': _userListings.length},
      {'label': 'With Reviews', 'value': _userListings.where((l) => l.reviewsCount > 0).length, 'total': _userListings.length},
      {'label': 'With Contact Info', 'value': _userListings.where((l) => l.phone.isNotEmpty || l.email.isNotEmpty).length, 'total': _userListings.length},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: qualityMetrics.map((metric) {
          final percentage = metric['total'] as int > 0 
              ? ((metric['value'] as int) / (metric['total'] as int) * 100)
              : 0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (metric['label'] as String).tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${metric['value']}/${metric['total']} (${percentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: dark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(cfg.colorPrimary),
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  int _getCompleteListingsCount() {
    return _userListings.where((l) {
      return l.photos.isNotEmpty &&
          l.description.isNotEmpty &&
          l.description.length > 50 &&
          (l.phone.isNotEmpty || l.email.isNotEmpty);
    }).length;
  }
}
