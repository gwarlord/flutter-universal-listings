import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/ui/video/adaptive_video_player.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/utils/ads/ads_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'share_ad_widget.dart';
import 'ad_upload_screen.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Helper function to convert country code to flag emoji
String _countryCodeToFlag(String countryCode) {
  final code = countryCode.toUpperCase();
  return String.fromCharCode(code.codeUnitAt(0) - 65 + 0x1F1E6) +
      String.fromCharCode(code.codeUnitAt(1) - 65 + 0x1F1E6);
}

class DealsFeedScreen extends StatefulWidget {
  final int initialIndex;
  final ListingsUser? currentUser;

  const DealsFeedScreen({Key? key, this.initialIndex = 0, this.currentUser}) : super(key: key);

  @override
  State<DealsFeedScreen> createState() => _DealsFeedScreenState();
}

class _DealsFeedScreenState extends State<DealsFeedScreen> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  bool _isUserScrolling = false;
  bool _isMutedPreference = true;
  int _currentIndex = 0;
  List<dynamic> _feedItems = []; // Changed to store both DealAdModel and Ads
  StreamSubscription<List<DealAdModel>>? _adsSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _adsSubscription = DealAdService().getApprovedAds().listen((ads) {
      if (mounted) {
        setState(() {
          _feedItems = _injectAds(ads);
          if (_feedItems.isNotEmpty && _currentIndex >= _feedItems.length) {
            _currentIndex = 0;
          }
        });
        _startAutoScroll();
      }
    });
  }

  /// Returns true when the user has enough profile data to enable targeted ordering.
  bool _hasUserProfile(ListingsUser? user) {
    if (user == null) return false;
    final hasCountry = user.countryCode.isNotEmpty;
    final hasInterests =
        user.likedListingsIDs.isNotEmpty || user.likedEventsIDs.isNotEmpty;
    final hasDemo = user.gender != 'Prefer not to say' ||
        user.ageRange != 'Prefer not to say';
    return hasCountry || hasInterests || hasDemo;
  }

  /// Computes a relevance score for [ad] against [user] profile.
  /// Higher score = more relevant = shown earlier.
  double _scoreAdForUser(DealAdModel ad, ListingsUser user) {
    double score = 0;
    final t = ad.targeting;

    // --- Location ---
    if (t.locations.isEmpty) {
      score += 2; // Broad/all-countries: fine for everyone
    } else if (t.locations
        .any((l) => l.toLowerCase() == user.countryCode.toLowerCase())) {
      score += 8; // Explicitly targets this user's country
    } else {
      score -= 5; // Targets a different country
    }

    // --- Gender ---
    if (t.genders.isEmpty ||
        t.genders.any((g) => g.toLowerCase() == 'all')) {
      score += 1;
    } else if (t.genders
        .any((g) => g.toLowerCase() == user.gender.toLowerCase())) {
      score += 4;
    } else {
      score -= 3;
    }

    // --- Audience type ---
    final hasInterests = user.likedListingsIDs.isNotEmpty ||
        user.likedEventsIDs.isNotEmpty;
    if (t.audienceTypes.contains('ALL')) {
      score += 1;
    } else if (t.audienceTypes.contains('INTEREST_BASED') && hasInterests) {
      score += 5;
    } else if (t.audienceTypes.contains('FAVORITES') && hasInterests) {
      score += 3;
    }

    return score;
  }

  List<dynamic> _injectAds(List<DealAdModel> ads) {
    final rng = Random();
    final sorted = List<DealAdModel>.from(ads);

    if (!_hasUserProfile(widget.currentUser)) {
      // No profile data — randomise so the feed doesn't always start the same
      sorted.shuffle(rng);
    } else {
      final user = widget.currentUser!;
      // Pre-compute scores once, adding a small random tiebreaker so ads
      // with equal relevance rotate rather than freezing in approval order.
      final scores = {
        for (final ad in sorted)
          ad.id: _scoreAdForUser(ad, user) + rng.nextDouble()
      };
      sorted.sort(
          (a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
    }

    List<dynamic> items = [];
    for (int i = 0; i < sorted.length; i++) {
      items.add(sorted[i]);
      // Inject a Google/native ad slot every 3 deal-ads
      if ((i + 1) % 3 == 0) {
        items.add('ad_placeholder');
      }
    }
    return items;
  }

  void _startAutoScroll() {
    _scheduleCurrentAdAdvance();
  }

  void _scheduleCurrentAdAdvance() {
    _autoScrollTimer?.cancel();

    if (_isUserScrolling || _feedItems.isEmpty || !_pageController.hasClients) {
      return;
    }

    final currentItem = _feedItems[_currentIndex.clamp(0, _feedItems.length - 1)];
    if (currentItem is DealAdModel && currentItem.mediaType == 'video') {
      return;
    }

    _autoScrollTimer = Timer(const Duration(seconds: 4), () {
      _goToNextPage();
    });
  }

  void _goToNextPage() {
    if (_isUserScrolling || _feedItems.isEmpty || !_pageController.hasClients || !mounted) {
      return;
    }

    final nextPage = (_currentIndex + 1) % _feedItems.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _adsSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: null,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.depth != 0) {
            return false;
          }

          if (notification is ScrollStartNotification && notification.dragDetails != null) {
            _isUserScrolling = true;
            _stopAutoScroll();
          }

          if (notification is ScrollEndNotification) {
            _isUserScrolling = false;
            _startAutoScroll();
          }
          return false;
        },
        child: _feedItems.isEmpty
            ? Center(
                child: Text('No deals or promotions available.'.tr(), style: const TextStyle(color: Colors.white)),
              )
            : PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: _feedItems.length,
                controller: _pageController,
                onPageChanged: (index) {
                  if (mounted) {
                    setState(() {
                      _currentIndex = index;
                    });
                  } else {
                    _currentIndex = index;
                  }
                  _startAutoScroll();
                },
                itemBuilder: (context, index) {
                  final item = _feedItems[index];
                  if (item is String && item == 'ad_placeholder') {
                    return Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sponsored'.tr(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 10),
                            AdsUtils.dealsFeedAd(),
                          ],
                        ),
                      ),
                    );
                  }
                  return DealFeedItem(
                    ad: item as DealAdModel,
                    currentUser: widget.currentUser,
                    isActive: index == _currentIndex,
                    isMuted: _isMutedPreference,
                    onMuteChanged: (isMuted) {
                      if (_isMutedPreference == isMuted) return;
                      setState(() {
                        _isMutedPreference = isMuted;
                      });
                    },
                    onVideoCompleted: () {
                      if (index == _currentIndex && !_isUserScrolling) {
                        _goToNextPage();
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}

class DealFeedItem extends StatefulWidget {
  final DealAdModel ad;
  final ListingsUser? currentUser;
  final bool isActive;
  final bool isMuted;
  final ValueChanged<bool>? onMuteChanged;
  final VoidCallback? onVideoCompleted;

  const DealFeedItem({
    Key? key,
    required this.ad,
    this.currentUser,
    this.isActive = false,
    this.isMuted = true,
    this.onMuteChanged,
    this.onVideoCompleted,
  }) : super(key: key);

  @override
  State<DealFeedItem> createState() => _DealFeedItemState();
}

class _DealFeedItemState extends State<DealFeedItem> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  late bool _isMuted;
  bool _isExpanded = false;
  bool _hasReportedVideoCompletion = false;
  bool _isNavigatingToListing = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    // Only initialise the controller when this item is the active (visible) one.
    // This avoids buffering all videos in the PageView simultaneously.
    if (widget.ad.mediaType == 'video' && widget.isActive) {
      _initVideoController();
    }
  }

  void _initVideoController() {
    if (_videoController != null) return; // already created
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.ad.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _videoController!.addListener(_onVideoStateChanged);
          _videoController!.setLooping(false);
          _videoController!.setVolume(_isMuted ? 0 : 1);
          if (widget.isActive) {
            _hasReportedVideoCompletion = false;
            _videoController!.seekTo(Duration.zero);
            _videoController!.play();
          }
        }
      });
  }

  @override
  void didUpdateWidget(covariant DealFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isMuted != widget.isMuted) {
      _isMuted = widget.isMuted;
      if (_videoController != null && _isInitialized) {
        _videoController!.setVolume(_isMuted ? 0 : 1);
      }
    }

    if (widget.ad.mediaType == 'video') {
      // Lazily initialise when this item becomes active for the first time.
      if (widget.isActive && _videoController == null) {
        _initVideoController();
        return;
      }

      if (_videoController != null && _isInitialized) {
        if (!oldWidget.isActive && widget.isActive) {
          _hasReportedVideoCompletion = false;
          _videoController!.seekTo(Duration.zero);
          _videoController!.play();
        } else if (oldWidget.isActive && !widget.isActive) {
          _videoController!.pause();
        }
      }
    }
  }

  void _onVideoStateChanged() {
    if (!mounted || !widget.isActive || _videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    final value = _videoController!.value;
    if (value.duration == Duration.zero) return;

    final hasReachedEnd = value.position >= (value.duration - const Duration(milliseconds: 150));
    if (hasReachedEnd && !_hasReportedVideoCompletion) {
      _hasReportedVideoCompletion = true;
      widget.onVideoCompleted?.call();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoStateChanged);
    _videoController?.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation() {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Delete Ad?'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to permanently remove this advertisement?'.tr(),
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(color: dark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await DealAdService().deleteAd(widget.ad.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ad deleted successfully'.tr())),
                );
              }
            },
            child: Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToListingDetails() async {
    if (_isNavigatingToListing) return;

    setState(() => _isNavigatingToListing = true);

    try {
      final listing = await listingApiManager.getListing(listingID: widget.ad.listingId);

      if (!mounted) return;

      if (listing != null) {
        if (widget.currentUser != null) {
          push(context, ListingDetailsWrappingWidget(
            listing: listing,
            currentUser: widget.currentUser!,
          ));
        } else {
          // If no user is logged in, show a snackbar or handle appropriately
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please log in to view listing details'.tr())),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing not found or was removed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading listing: {}'.tr(args: ['$e']))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigatingToListing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final size = MediaQuery.of(context).size;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = (size.width * devicePixelRatio).round();
    final cacheHeight = (size.height * devicePixelRatio).round();
    final blurredCacheWidth = (cacheWidth / 2).round();
    final blurredCacheHeight = (cacheHeight / 2).round();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          // 1. Background Blur
          Positioned.fill(
            child: widget.ad.mediaType == 'video'
                ? (_isInitialized
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      )
                    : (widget.ad.thumbnailUrl?.isNotEmpty == true
                        ? ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: CachedNetworkImage(
                              imageUrl: widget.ad.thumbnailUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Container(color: Colors.black)))
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: CachedNetworkImage(
                      imageUrl: ad.mediaUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: blurredCacheWidth,
                      memCacheHeight: blurredCacheHeight,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
          ),

          // 2. Main Content
          Positioned.fill(
            child: Center(
              child: widget.ad.mediaType == 'video'
                  ? (_isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            if (widget.ad.thumbnailUrl?.isNotEmpty == true)
                              CachedNetworkImage(
                                imageUrl: widget.ad.thumbnailUrl!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            else
                              Container(color: Colors.black),
                            const CircularProgressIndicator(color: Colors.white),
                          ],
                        ))
                  : CachedNetworkImage(
                      imageUrl: ad.mediaUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      memCacheWidth: cacheWidth,
                      memCacheHeight: cacheHeight,
                      placeholder: (context, url) => Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                    ),
            ),
          ),

          // 3. Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // 4. Top Right Actions
          Positioned(
            right: 8,
            top: topPadding + 10,
            child: Column(
              children: [
                ShareAdWidget(adTitle: ad.caption, adUrl: ad.mediaUrl, adId: ad.id, listingId: ad.listingId),
                const SizedBox(height: 12),
                if (widget.ad.mediaType == 'video') ...[
                  IconButton(
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _videoController?.setVolume(_isMuted ? 0 : 1);
                      });
                      widget.onMuteChanged?.call(_isMuted);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // Admin-only Actions (edit/delete for admins only)
                if (widget.currentUser != null && widget.currentUser!.isAdmin) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 28),
                    onPressed: () {
                      push(context, AdUploadScreen(adToEdit: widget.ad));
                    },
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
                    onPressed: _showDeleteConfirmation,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),

          // 5. Bottom Info
          Positioned(
            bottom: 30 + bottomPadding,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.caption,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      ),
                      if (ad.caption.length > 60)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            _isExpanded ? '...see less' : '...see more',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ad.adType.toUpperCase(), 
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    if (ad.visibilityCountries.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: ad.visibilityCountries.take(3).map((countryCode) {
                            final country = CaribbeanCountries.byCode(countryCode);
                            if (country == null) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _countryCodeToFlag(countryCode),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    country.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    if (ad.visibilityCountries.length > 3) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${ad.visibilityCountries.length - 3}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Period: ${DateFormat('MMM d').format(ad.startDate)} - ${DateFormat('MMM d, yyyy').format(ad.endDate)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // NEW: View Listing Button
                SizedBox(
                  height: 36,
                  child: TextButton.icon(
                    onPressed: _isNavigatingToListing ? null : _navigateToListingDetails,
                    icon: _isNavigatingToListing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          )
                        : const Icon(Icons.store_outlined, color: Colors.white, size: 18),
                    label: Text(
                      _isNavigatingToListing ? 'Loading...'.tr() : 'View Listing'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
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
}
