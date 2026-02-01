import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/ui/video/adaptive_video_player.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'share_ad_widget.dart';
import 'ad_upload_screen.dart';

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
  List<DealAdModel> _currentAds = []; // Added to store the ads
  StreamSubscription<List<DealAdModel>>? _adsSubscription; // Added subscription

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Subscribe to the stream to get ads and start auto-scroll
    _adsSubscription = DealAdService().getApprovedAds().listen((ads) {
      if (mounted) {
        setState(() {
          _currentAds = ads;
          _startAutoScroll(); // Start auto-scroll once ads are available
        });
      }
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel(); // Cancel any existing timer
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (_isUserScrolling || _currentAds.isEmpty) return; // Don't auto-scroll if user is interacting or no ads

      if (_pageController.hasClients) {
        final currentPage = _pageController.page ?? 0;
        final totalPages = _currentAds.length; // Use the stored ads

        if (totalPages == 0) return; // No ads to scroll

        int nextPage = (currentPage.toInt() + 1) % totalPages; // Explicit toInt for safety

        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
        );
      }
    });
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
          if (notification is UserScrollNotification) {
            if (notification.metrics.axisDirection == AxisDirection.down ||
                notification.metrics.axisDirection == AxisDirection.up) {
              // User started scrolling vertically
              if (notification.depth == 0) { // Only listen to the main scrollable
                _isUserScrolling = true;
                _stopAutoScroll();
              }
            }
            // Corrected: Only check extentAfter for reaching the end
            if (notification.metrics.extentAfter == 0 || notification.metrics.extentBefore == 0) { 
              // User stopped scrolling (or reached end/beginning), resume auto-scroll after a delay
              if (_isUserScrolling && notification.depth == 0) {
                _isUserScrolling = false;
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted && !_isUserScrolling) {
                    _startAutoScroll();
                  }
                });
              }
            }
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
              itemBuilder: (context, index) {
                return DealFeedItem(
                  ad: _currentAds[index], // Use _currentAds[index]
                  currentUser: widget.currentUser,
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
  const DealFeedItem({Key? key, required this.ad, this.currentUser}) : super(key: key);

  @override
  State<DealFeedItem> createState() => _DealFeedItemState();
}

class _DealFeedItemState extends State<DealFeedItem> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isMuted = true;
  bool _isExpanded = false;

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
            _videoController!.setLooping(true);
            _videoController!.setVolume(0);
            _videoController!.play();
          }
        });
    }
  }

  @override
  void dispose() {
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    
    // Check if current user is the owner or an admin
    final bool isOwner = widget.currentUser != null && 
        (widget.currentUser!.userID == ad.listerId || widget.currentUser!.isAdmin);

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
                    child: Image.network(ad.mediaUrl, fit: BoxFit.cover),
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
                  : Image.network(ad.mediaUrl, fit: BoxFit.contain),
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
                if (widget.ad.mediaType == 'video') ...[
                  const SizedBox(height: 12),
                  IconButton(
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        _videoController?.setVolume(_isMuted ? 0 : 1);
                      });
                    },
                  ),
                ],
                // Admin/Owner Actions
                if (isOwner) ...[
                  const SizedBox(height: 12),
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
