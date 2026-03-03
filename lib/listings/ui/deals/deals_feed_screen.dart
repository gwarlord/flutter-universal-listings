import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/ui/video/adaptive_video_player.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'share_ad_widget.dart';
import 'ad_upload_screen.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';

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
  int _currentIndex = 0;
  List<DealAdModel> _currentAds = []; // Added to store the ads
  StreamSubscription<List<DealAdModel>>? _adsSubscription; // Added subscription

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Subscribe to the stream to get ads and start auto-scroll
    _adsSubscription = DealAdService().getApprovedAds().listen((ads) {
      if (mounted) {
        setState(() {
          _currentAds = ads;
          if (_currentAds.isNotEmpty && _currentIndex >= _currentAds.length) {
            _currentIndex = 0;
          }
        });
        _startAutoScroll(); // Start auto-scroll once ads are available
      }
    });
  }

  void _startAutoScroll() {
    _scheduleCurrentAdAdvance();
  }

  void _scheduleCurrentAdAdvance() {
    _autoScrollTimer?.cancel();

    if (_isUserScrolling || _currentAds.isEmpty || !_pageController.hasClients) {
      return;
    }

    final currentAd = _currentAds[_currentIndex.clamp(0, _currentAds.length - 1)];
    if (currentAd.mediaType == 'video') {
      return;
    }

    _autoScrollTimer = Timer(const Duration(seconds: 3), () {
      _goToNextPage();
    });
  }

  void _goToNextPage() {
    if (_isUserScrolling || _currentAds.isEmpty || !_pageController.hasClients || !mounted) {
      return;
    }

    final nextPage = (_currentIndex + 1) % _currentAds.length;
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
    _adsSubscription?.cancel(); // Cancel the stream subscription
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
        child: StreamBuilder<List<DealAdModel>>(
          stream: DealAdService().getApprovedAds(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            // Use _currentAds which is updated in initState for data
            // final ads = snapshot.data ?? []; // No longer needed here as _currentAds holds the data
            if (_currentAds.isEmpty) {
              return const Center(
                child: Text('No deals or promotions available.', style: TextStyle(color: Colors.white)),
              );
            }

            return PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _currentAds.length, // Use _currentAds.length
              controller: _pageController,
              onPageChanged: (index) {
                _currentIndex = index;
                _startAutoScroll();
              },
              itemBuilder: (context, index) {
                return DealFeedItem(
                  ad: _currentAds[index], // Use _currentAds[index]
                  currentUser: widget.currentUser,
                  isActive: index == _currentIndex,
                  onVideoCompleted: () {
                    if (index == _currentIndex && !_isUserScrolling) {
                      _goToNextPage();
                    }
                  },
                );
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
  final VoidCallback? onVideoCompleted;

  const DealFeedItem({
    Key? key,
    required this.ad,
    this.currentUser,
    this.isActive = false,
    this.onVideoCompleted,
  }) : super(key: key);

  @override
  State<DealFeedItem> createState() => _DealFeedItemState();
}

class _DealFeedItemState extends State<DealFeedItem> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isMuted = true;
  bool _isExpanded = false;
  bool _hasReportedVideoCompletion = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.ad.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _videoController!.addListener(_onVideoStateChanged);
            _videoController!.setLooping(false);
            _videoController!.setVolume(0);
            if (widget.isActive) {
              _hasReportedVideoCompletion = false;
              _videoController!.seekTo(Duration.zero);
              _videoController!.play();
            }
          }
        });
    }

  }

  @override
  void didUpdateWidget(covariant DealFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

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
          'Delete Ad?',
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to permanently remove this advertisement?',
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: dark ? Colors.white60 : Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () async {
              await DealAdService().deleteAd(widget.ad.id);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ad deleted successfully')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
                    : Container(color: Colors.black))
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Image.network(
                      ad.mediaUrl,
                      fit: BoxFit.cover,
                      cacheWidth: blurredCacheWidth,
                      cacheHeight: blurredCacheHeight,
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
                      : const CircularProgressIndicator(color: Colors.white))
                  : Image.network(
                      ad.mediaUrl,
                      fit: BoxFit.contain,
                      cacheWidth: cacheWidth,
                      cacheHeight: cacheHeight,
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
                ShareAdWidget(adTitle: ad.caption, adUrl: ad.mediaUrl, adId: ad.id),
                const SizedBox(height: 12),
                if (widget.ad.mediaType == 'video') ...[
                  IconButton(
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _videoController?.setVolume(_isMuted ? 0 : 1);
                      });
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
