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

      // Calculate total favorites across all users for this user's listings
      int totalFavorites = 0;
      if (listingIds.isNotEmpty) {
        final usersSnap = await _firestore.collection('users').get();
        for (var userDoc in usersSnap.docs) {
          try {
            final likedListings = List<String>.from(userDoc.data()['likedListingsIDs'] ?? []);
            for (var listingId in listingIds) {
              if (likedListings.contains(listingId)) {
                totalFavorites++;
              }
            }
          } catch (e) {
            // Skip users with invalid data
          }
        }
      }

      // Calculate advanced metrics
      _calculateAdvancedMetrics(listings, allReviews, totalFavorites);

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Error loading advanced analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateAdvancedMetrics(List<ListingModel> listings, List<ListingReviewModel> reviews, int totalFavorites) {
    // Total Views
    int totalViews = listings.fold(0, (sum, l) => sum + l.viewCount);
    
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

    // Rank all listings by performance score
    List<ListingModel> rankedListings = List.from(listings);
    rankedListings.sort((a, b) {
      int aScore = a.viewCount * 2 + (a.reviewsCount as int) * 5;
      int bScore = b.viewCount * 2 + (b.reviewsCount as int) * 5;
      return bScore.compareTo(aScore); // Sort descending
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
        'rankedListings': rankedListings,
        'avgRating': avgRating,
        'totalListings': listings.length,
      };
    });
  }

  void _showInfoDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(cfg.colorPrimary)),
            const SizedBox(width: 12),
            Expanded(child: Text(title.tr())),
          ],
        ),
        content: Text(description.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it').tr(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoIcon(String title, String description) {
    return GestureDetector(
      onTap: () => _showInfoDialog(title, description),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(cfg.colorPrimary).withOpacity(0.1),
        ),
        child: Icon(
          Icons.info_outline,
          size: 16,
          color: Color(cfg.colorPrimary),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? infoTitle, String? infoDescription, bool dark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (infoTitle != null && infoDescription != null)
          _buildInfoIcon(infoTitle, infoDescription),
      ],
    );
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
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 100, // Extra bottom padding for floating buttons
                ),
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
                    _buildSectionHeader(
                      'Performance Overview'.tr(),
                      'Performance Overview',
                      'Track your listing performance with these key metrics: Engagement Rate measures how users interact with your listings (favorites + reviews divided by views), Quality Score reflects your listing completeness and quality, Total Reviews shows all feedback received, and Avg Rating is your overall rating.',
                      dark,
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
                    _buildSectionHeader(
                      'Rating Distribution'.tr(),
                      'Rating Distribution',
                      'Shows how your reviews are distributed across star ratings (5-star down to 1-star). This helps you see if your listings are generally well-received or if there are areas to improve.',
                      dark,
                    ),
                    const SizedBox(height: 16),
                    _buildRatingDistribution(dark),

                    const SizedBox(height: 32),

                    // All Listings Ranked (Expandable)
                    _buildSectionHeader(
                      'All Listings Ranked'.tr(),
                      'Listings Ranked',
                      'All your listings ranked by performance score, which is calculated from views and reviews. The top-ranked listing is performing best. Expand to see detailed metrics for each listing.',
                      dark,
                    ),
                    const SizedBox(height: 16),
                    _buildRankedListingsExpansion(dark),
                    const SizedBox(height: 32),

                    // Listing Quality Breakdown (Premium users and Admins)
                    if (widget.currentUser.isAdmin || widget.currentUser.isPremium) ...[
                      _buildSectionHeader(
                        'Listing Quality Breakdown'.tr(),
                        'Quality Breakdown',
                        'Shows what percentage of your listings meet quality standards: Complete Profiles (has photos, description, and contact info), With Photos (at least one image), With Reviews (has received feedback), and With Contact Info (phone or email provided).',
                        dark,
                      ),
                      const SizedBox(height: 16),
                      _buildQualityBreakdown(dark),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, bool dark) {
    String? infoTitle;
    String? infoDescription;
    
    // Add info tooltips for each metric
    if (title == 'Engagement Rate') {
      infoTitle = 'Engagement Rate';
      infoDescription = 'Calculated as (Favorites + Reviews) / Views × 100%. This percentage shows how engaged users are with your listings. Higher is better!';
    } else if (title == 'Quality Score') {
      infoTitle = 'Quality Score';
      infoDescription = 'A 0-100 score based on listing completeness: photos (30 pts), description length (20 pts), reviews (25 pts), contact info (15 pts), and services (10 pts).';
    } else if (title == 'Total Reviews') {
      infoTitle = 'Total Reviews';
      infoDescription = 'Combined count of all reviews received across all your listings.';
    } else if (title == 'Avg Rating') {
      infoTitle = 'Average Rating';
      infoDescription = 'Average star rating across all reviews from all your listings.';
    }
    
    return GestureDetector(
      onTap: infoTitle != null && infoDescription != null 
          ? () => _showInfoDialog(infoTitle!, infoDescription!)
          : null,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                if (infoTitle != null)
                  _buildInfoIcon(infoTitle, infoDescription!),
              ],
            ),
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

  Widget _buildRankedListingsExpansion(bool dark) {
    final rankedListings = (_advancedMetrics['rankedListings'] as List<ListingModel>?) ?? [];
    
    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.trending_up, size: 20),
            const SizedBox(width: 12),
            Text(
              'All Listings Ranked'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(cfg.colorPrimary).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${rankedListings.length} listings',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(cfg.colorPrimary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        children: [
          if (rankedListings.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No listings yet'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: List.generate(rankedListings.length, (index) {
                final listing = rankedListings[index];
                final score = listing.viewCount * 2 + (listing.reviewsCount as int) * 5;
                return _buildRankedListingTile(listing, index + 1, score, dark);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildRankedListingTile(ListingModel listing, int rank, int score, bool dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank == 1 
                  ? Colors.amber 
                  : rank == 2 
                  ? Colors.grey[400]
                  : rank == 3
                  ? Colors.orange[300]
                  : Color(cfg.colorPrimary).withOpacity(0.3),
              borderRadius: BorderRadius.circular(50),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? Colors.white : Color(cfg.colorPrimary),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Listing Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.visibility, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 3),
                    Text(
                      '${listing.viewCount}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(
                      '${listing.reviewsCount ?? 0}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(cfg.colorPrimary).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Score: $score',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(cfg.colorPrimary),
              ),
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
