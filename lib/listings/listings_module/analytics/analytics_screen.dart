import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

class AnalyticsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const AnalyticsScreen({super.key, required this.currentUser});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late FirebaseFirestore _firestore;
  bool _isLoading = true;
  List<ListingModel> _userListings = [];
  Map<String, dynamic> _analytics = {
    'totalListings': 0,
    'totalViews': 0,
    'totalLikes': 0,
    'averageRating': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
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

      // Calculate analytics
      int totalViews = 0;
      int totalLikes = 0;
      double totalRating = 0;
      int ratedListings = 0;

      for (var listing in listings) {
        // Note: viewCount is not tracked in current model, using 0
        // totalViews += listing.viewCount ?? 0;
        totalLikes += widget.currentUser.likedListingsIDs.contains(listing.id) ? 1 : 0;
        if ((listing.reviewsCount ?? 0) > 0) {
          final avgRating = (listing.reviewsSum ?? 0) / (listing.reviewsCount ?? 1);
          totalRating += avgRating;
          ratedListings++;
        }
      }

      setState(() {
        _analytics = {
          'totalListings': listings.length,
          'totalViews': totalViews,
          'totalLikes': totalLikes,
          'averageRating': ratedListings > 0 ? totalRating / ratedListings : 0.0,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
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
              onRefresh: _loadAnalytics,
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
                            Icons.star,
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

                    // Overview Section
                    Text(
                      'Overview'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Analytics Cards
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAnalyticsCard(
                          icon: Icons.shopping_bag,
                          title: 'Listings'.tr(),
                          value: _analytics['totalListings'].toString(),
                          dark: dark,
                        ),
                        _buildAnalyticsCard(
                          icon: Icons.visibility,
                          title: 'Total Views'.tr(),
                          value: _analytics['totalViews'].toString(),
                          dark: dark,
                        ),
                        _buildAnalyticsCard(
                          icon: Icons.favorite,
                          title: 'Total Likes'.tr(),
                          value: _analytics['totalLikes'].toString(),
                          dark: dark,
                        ),
                        _buildAnalyticsCard(
                          icon: Icons.star,
                          title: 'Avg Rating'.tr(),
                          value: (_analytics['averageRating'] as double)
                              .toStringAsFixed(1),
                          dark: dark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Listings Performance
                    Text(
                      'Listing Performance'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_userListings.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No listings yet'.tr(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userListings.length,
                        itemBuilder: (context, index) {
                          final listing = _userListings[index];
                          return _buildListingPerformanceCard(
                            listing: listing,
                            dark: dark,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnalyticsCard({
    required IconData icon,
    required String title,
    required String value,
    required bool dark,
  }) {
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
          Icon(
            icon,
            color: Color(cfg.colorPrimary),
            size: 28,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: dark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: dark ? Colors.white : Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListingPerformanceCard({
    required ListingModel listing,
    required bool dark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Thumbnail
          if (listing.photos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                listing.photos.first,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image),
            ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Listing',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      listing.reviewsCount != null && listing.reviewsCount! > 0
                          ? '${((listing.reviewsSum ?? 0) / (listing.reviewsCount ?? 1)).toStringAsFixed(1)} stars (${listing.reviewsCount} reviews)'
                          : 'No ratings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
