import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:instaflutter/core/ui/chat/chat/chat_screen.dart';
import 'package:instaflutter/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/add_review/add_review_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_bloc.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_bloc.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_event.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_request_dialog.dart';
import 'package:instaflutter/listings/listings_module/api/booking_api_manager.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:instaflutter/listings/ui/subscription/paywall_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:instaflutter/core/ui/video/adaptive_video_player.dart';
import 'package:instaflutter/core/ui/full_screen_video_viewer/full_screen_video_viewer.dart';
import 'package:instaflutter/core/model/channel_data_model.dart';
import 'package:instaflutter/core/model/user.dart' as core_user;

import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

// Extracts the username/handle from a social URL or returns a prettified version
String extractSocialHandle(String url, String domain) {
  try {
    final uri = Uri.parse(url);
    if (uri.host.contains(domain)) {
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last;
      }
    }
    return url;
  } catch (e) {
    return url;
  }
}

class ListingDetailsScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const ListingDetailsScreen({Key? key, required this.listing, required this.currentUser}) : super(key: key);

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  Map<String, dynamic>? _storePreview;

  Future<void> _fetchStorePreview(String url) async {
    try {
      final data = await MetadataFetch.extract(url);
      if (data != null) {
        setState(() {
          _storePreview = {
            'title': data.title,
            'description': data.description,
            'image': data.image,
          };
        });
      }
    } catch (e) {
      // Optionally handle error silently or log minimally
    }
  }
  late ListingModel listing;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _listingStream;
  int _pageIndex = 0;
  final PageController _pagerController = PageController(initialPage: 0);
  Timer? _autoScroll;
  Timer? _resumeAutoScrollTimer;
  bool _isCarouselInteracting = false;

  GoogleMapController? _mapController;
  late LatLng _placeLocation;
  final Future _mapFuture = Future.delayed(Duration.zero, () => true);

  late ListingsUser currentUser;
  bool isLoadingReviews = true;
  bool? _authorIsPremium;

  List<MediaItem> _mediaList = [];
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoMuted = true;
  bool _servicesExpanded = false;
  List<ListingReviewModel> reviews = []; // Explicitly declared here

  bool get _canEditOrDelete =>
      currentUser.userID == listing.authorID || currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    listing = widget.listing;
    _listingStream = FirebaseFirestore.instance
        .collection(cfg.listingsCollection)
        .doc(listing.id)
        .snapshots();
    if (listing.storeEnabled && listing.storeUrl.isNotEmpty) {
      _fetchStorePreview(listing.storeUrl);
    }
    if (listing.latitude != 0.0 && listing.longitude != 0.0) {
      _placeLocation = LatLng(listing.latitude, listing.longitude);
    }

    _buildMediaList();

    if (_mediaList.isNotEmpty && _mediaList.first.isVideo) {
      _loadVideoController(_mediaList.first.url);
    }

    context.read<ListingDetailsBloc>().add(GetListingReviewsEvent());

    if (currentUser.userID != listing.authorID) {
      _incrementViewCount();
    }

    if (_mediaList.length > 1) {
      _startAutoScroll();
    }

    _checkAuthorPremiumStatus();
  }

  void _buildMediaList() {
    _mediaList = [];
    for (final photo in listing.photos) {
      _mediaList.add(MediaItem.photo(photo));
    }
    final videos = listing.videos ?? [];
    for (final videoUrl in videos) {
      _mediaList.add(MediaItem.video(videoUrl));
    }
  }

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD':
      case 'XCD':
      case 'JMD':
      case 'TTD':
      case 'BSD':
      case 'BBD':
      case 'GYD':
      case 'DOP':
      case 'KYD':
      case 'SRD':
        return '\$';
      case 'ANG':
        return 'ƒ';
      case 'XOF':
        return 'CFA';
      case 'HTG':
        return 'G';
      default:
        return '\$';
    }
  }

  Future<void> _checkAuthorPremiumStatus() async {
    try {
      final authorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(listing.authorID)
          .get();
      
      if (authorDoc.exists) {
        final subscriptionTier = authorDoc.data()?['subscriptionTier'] as String? ?? 'free';
        setState(() {
          _authorIsPremium = subscriptionTier.toLowerCase() == 'premium' ||
                            subscriptionTier.toLowerCase() == 'professional' ||
                            (authorDoc.data()?['isAdmin'] as bool? ?? false);
        });
      } else {
        setState(() => _authorIsPremium = false);
      }
    } catch (e) {
      print('❌ Error checking author premium status: $e');
      setState(() => _authorIsPremium = false);
    }
  }
  
    void _loadVideoController(String videoUrl) {
      _videoController?.dispose();
      _videoReady = false;
      _videoMuted = true;
    
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      )
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _videoReady = true;
            });
            _videoController!.setVolume(0);
            _videoController!.play();
          }
        }).catchError((e) {
          debugPrint('Video loading error: $e');
        });
    }

  void _pauseAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
    _isCarouselInteracting = true;
    _resumeAutoScrollTimer?.cancel();
  }

  void _resumeAutoScrollAfterDelay() {
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _mediaList.length > 1) {
        _isCarouselInteracting = false;
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    if (_autoScroll != null || _isCarouselInteracting) return;
    _autoScroll = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_pageIndex < _mediaList.length - 1) {
        _pageIndex++;
      } else {
        _pageIndex = 0;
      }
      if (_pagerController.hasClients) {
        _pagerController.animateToPage(
          _pageIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final adaptiveTextColor = dark ? Colors.white : Colors.black;
    final primaryColor = Color(cfg.colorPrimary);
    final dividerColor = dark ? Colors.white12 : Colors.grey.shade300;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _listingStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data()!;
          listing = ListingModel.fromJson(data);
          // Refetch preview if storeUrl changed
          if (listing.storeEnabled && listing.storeUrl.isNotEmpty) {
            _fetchStorePreview(listing.storeUrl);
          } else {
            _storePreview = null;
          }
        }
        return MultiBlocListener(
          listeners: [
            BlocListener<ListingDetailsBloc, ListingDetailsState>(
              listener: (context, state) async {
                if (state is DeletedListingState) {
                  context.read<LoadingCubit>().hideLoading();
                  if (!mounted) return;
                  Navigator.pop(context, true);
                } else if (state is ReviewsFetchedState) { // Add listener for ReviewsFetchedState
                  setState(() {
                    reviews = state.reviews;
                  });
                }
              },
            ),
          ],
          child: Scaffold(
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Immersive Header (Airbnb/Spotify Style)
                SliverAppBar(
                  expandedHeight: 350,
                  pinned: true,
                  elevation: 0,
                  stretch: true,
                  backgroundColor: dark ? Colors.black : Colors.white,
                  leading: _buildHeaderCircleButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                    isDark: dark,
                  ),
                  actions: [
                    BlocConsumer<ListingDetailsBloc, ListingDetailsState>(
                      listener: (context, state) {
                        if (state is ListingFavToggleState) {
                          setState(() {
                            listing = state.listing;
                            context.read<AuthenticationBloc>().user = state.updatedUser;
                            currentUser = state.updatedUser;
                          });
                        }
                      },
                      buildWhen: (old, current) =>
                          old != current && current is ListingFavToggleState,
                      builder: (context, state) {
                        return _buildHeaderCircleButton(
                          icon: listing.isFav ? Icons.favorite : Icons.favorite_border,
                          iconColor: listing.isFav ? Colors.red : null,
                          onTap: () {
                            context.read<ListingDetailsBloc>().add(ListingFavUpdatedEvent());
                          },
                          isDark: dark,
                          margin: const EdgeInsets.only(right: 8),
                        );
                      },
                    ),
                    _buildHeaderCircleMenu(dark, adaptiveTextColor),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildMediaGallery(),
                        // Bottom gradient for title visibility when collapsed
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Main Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Verified Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                listing.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (listing.verified) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: primaryColor, width: 1.2),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified, color: primaryColor, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Rating Summary
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              reviews.isEmpty ? 'New'.tr() : _calculateAverageRating(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (reviews.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text('(${reviews.length})', style: TextStyle(color: dark ? Colors.grey : Colors.grey.shade600)),
                            ],
                          ],
                        ),
                        Divider(height: 48, thickness: 1, color: dividerColor),
                        // Author Info (only show if there's content to display)
                        if (listing.logo.isNotEmpty || _authorIsPremium == true) ...[
                          _buildAuthorSection(dark),
                          Divider(height: 48, thickness: 1, color: dividerColor),
                        ],
                        // Description
                        Text(
                          'About'.tr(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          listing.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: dark ? Colors.grey.shade300 : Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Store Section
                        if (listing.storeEnabled && listing.storeUrl.isNotEmpty) ...[
                          Text(
                            'Visit My Store'.tr(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_storePreview != null) ...[
                            InkWell(
                              onTap: () => _launchWebsite(listing.storeUrl),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryColor.withOpacity(0.25)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_storePreview!['image'] != null && _storePreview!['image'].toString().isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _storePreview!['image'],
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56),
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (_storePreview!['title'] != null)
                                            Text(
                                              _storePreview!['title'],
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          if (_storePreview!['description'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                _storePreview!['description'],
                                                style: TextStyle(
                                                  color: dark ? Colors.grey.shade300 : Colors.grey.shade800,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.shopping_cart_outlined, color: primaryColor, size: 18),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    listing.storeUrl,
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.w600,
                                                      decoration: TextDecoration.underline,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Icon(Icons.open_in_new, size: 16, color: primaryColor),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            InkWell(
                              onTap: () => _launchWebsite(listing.storeUrl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryColor.withOpacity(0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined, color: primaryColor),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        listing.storeUrl,
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.open_in_new, size: 18, color: primaryColor),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                        // Price Section (if not in bottom bar)
                        if (listing.price.trim().isNotEmpty)
                          _buildPriceCard(dark, primaryColor),
                        // Services Section
                        if (listing.services.isNotEmpty) _buildServicesSection(dark, primaryColor),
                        // Contact & Hours
                        if (_hasContactOrHours(listing)) ...[
                          const SizedBox(height: 32),
                          Text(
                            'Contact, Hours & Social'.tr(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _ContactHoursCard(
                            listing: listing,
                            colorPrimary: primaryColor,
                            isDark: dark,
                            onCall: () => _launchPhone(listing.phone),
                            onEmail: () => _launchEmail(listing.email),
                            onWebsite: () => _launchWebsite(listing.website),
                            onInstagram: () => _launchUrl(listing.instagram),
                            onFacebook: () => _launchUrl(listing.facebook),
                            onTiktok: () => _launchUrl(listing.tiktok),
                            onWhatsapp: () => _launchWhatsApp(listing.whatsapp),
                            onYoutube: () => _launchUrl(listing.youtube),
                            onX: () => _launchUrl(listing.x),
                            showOnlyFirst: 5,
                          ),
                        ],
                        // Location Map
                        if (listing.latitude != 0.0 && listing.longitude != 0.0) ...[
                          const SizedBox(height: 32),
                          Text(
                            "Where we're located".tr(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildMapSection(dark),
                        ],
                        // Filters/Details
                        if (listing.filters.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Text(
                            'Details'.tr(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailsList(dark, primaryColor),
                        ],
                        // Reviews
                        const SizedBox(height: 32),
                        _buildReviewsSection(dark, primaryColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomSheet: _buildStickyBottomBar(dark, primaryColor),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? (isDark ? Colors.white : Colors.black), size: 20),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildHeaderCircleMenu(bool isDark, Color adaptiveTextColor) {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton(
        icon: Icon(Icons.more_horiz, color: isDark ? Colors.white : Colors.black, size: 20),
        itemBuilder: (BuildContext context) {
          return [
            if (_canEditOrDelete)
              PopupMenuItem(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit, color: Color(cfg.colorPrimary)),
                  title: Text(
                    'Edit Listing'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final updated = await push(
                      context,
                      EditListingWrappingWidget(
                        currentUser: currentUser,
                        listingToEdit: listing,
                      ),
                    );
                    if (updated is ListingModel) setState(() => listing = updated);
                  },
                ),
              ),
            if (currentUser.userID != listing.authorID)
              PopupMenuItem(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_outline),
                  title: Text(
                    'Add Review'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.black : Colors.black,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    bool? reviewPublished = await push(
                      context,
                      AddReviewWrappingWidget(
                        listing: listing,
                        currentUser: currentUser,
                      ),
                    );
                    if (reviewPublished == true) {
                      context.read<ListingDetailsBloc>().add(LoadingEvent());
                      context.read<ListingDetailsBloc>().add(GetListingReviewsEvent());
                    }
                  },
                ),
              ),
            if (_canEditOrDelete)
              PopupMenuItem(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Delete Listing'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => deleteListing(context),
                ),
              ),
          ];
        },
      ),
    );
  }

  Widget _buildMediaGallery() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pagerController,
          physics: const AlwaysScrollableScrollPhysics(parent: PageScrollPhysics()),
          itemCount: _mediaList.length,
          allowImplicitScrolling: true,
          onPageChanged: (index) {
            _pauseAutoScroll();
            setState(() => _pageIndex = index);
            final media = _mediaList[index];
            if (media.isVideo) _loadVideoController(media.url);
            else _videoController?.pause();
            _resumeAutoScrollAfterDelay();
          },
          itemBuilder: (context, index) {
            final media = _mediaList[index];
            if (media.isVideo) {
              return _videoReady && _videoController != null
                  ? AdaptiveVideoPlayer(
                      controller: _videoController!,
                      fit: BoxFit.cover,
                      isMuted: _videoMuted,
                      onToggleMute: () => setState(() {
                        _videoMuted = !_videoMuted;
                        _videoController!.setVolume(_videoMuted ? 0 : 1);
                      }),
                      onTogglePlay: () => setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      }),
                      onToggleFullScreen: () {
                        _videoController?.pause();
                        push(context, FullScreenVideoViewer(
                          videoUrl: media.url,
                          heroTag: media.url,
                        ));
                      },
                    )
                  : const Center(child: CircularProgressIndicator.adaptive());
            }
            return GestureDetector(
              onTap: () => push(context, FullScreenImageViewer(
                galleryImagesList: _mediaList.where((m) => !m.isVideo).map((m) => m.url).toList(),
                index: _mediaList.asMap().entries.where((e) => !e.value.isVideo).toList().indexWhere((e) => e.value.url == media.url),
                imageUrl: '',
              )),
              child: displayImage(media.url),
            );
          },
        ),
        if (_mediaList.length > 1)
          Positioned(
            bottom: 24,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pageIndex + 1} / ${_mediaList.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAuthorSection(bool isDark) {
    return Row(
      children: [
        if (listing.logo.isNotEmpty) ...[
          GestureDetector(
            onTap: () => push(context, FullScreenImageViewer(
              galleryImagesList: [listing.logo],
              index: 0,
              imageUrl: '',
            )),
            child: Hero(
              tag: listing.logo,
              child: CircleAvatar(
                radius: 43,
                backgroundImage: NetworkImage(listing.logo),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_authorIsPremium == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.35), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade400, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Premium Listing'.tr(),
                        style: TextStyle(
                          color: Colors.amber.shade700.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(bool isDark, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price'.tr(),
            style: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_getCurrencySymbol(listing.currencyCode)} ${listing.price} ${listing.currencyCode}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSection(bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14), // Reduced again
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Services'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => setState(() => _servicesExpanded = !_servicesExpanded),
              child: Text(_servicesExpanded ? 'Show less'.tr() : 'Show all'.tr()),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _servicesExpanded ? listing.services.length : (listing.services.length > 3 ? 3 : listing.services.length),
          itemBuilder: (context, index) {
            final service = listing.services[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_outline, color: primaryColor),
              title: Text(service.name),
              trailing: Text(
                '\$${service.price} ${listing.currencyCode}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapSection(bool isDark) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: FutureBuilder(
              future: _mapFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());
                return GoogleMap(
                  myLocationEnabled: true,
                  gestureRecognizers: {}..add(Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())),
                  markers: {Marker(markerId: const MarkerId('m1'), position: _placeLocation)},
                  initialCameraPosition: CameraPosition(target: _placeLocation, zoom: 14),
                  onMapCreated: _onMapCreated,
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black87 : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 18, color: Color(cfg.colorPrimary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    listing.place,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsList(bool isDark, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: listing.filters.entries.map((e) => FilterDetailsWidget(
          filter: e,
          isDark: isDark,
          colorPrimary: primaryColor,
          isLast: listing.filters.entries.last.key == e.key,
        )).toList(),
      ),
    );
  }

  Widget _buildReviewsSection(bool isDark, Color primaryColor) {
    return BlocBuilder<ListingDetailsBloc, ListingDetailsState>(
      builder: (context, state) {
        if (state is ReviewsFetchedState) {
          final currentReviews = state.reviews; // Use a local variable to avoid setState
          if (currentReviews.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reviews'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: currentReviews.length > 5 ? 5 : currentReviews.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) => ReviewWidget(review: currentReviews[index]),
              ),
              if (currentReviews.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton(
                    onPressed: () {}, // Show all reviews
                    child: Text('Show all reviews'.tr()),
                  ),
                ),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator.adaptive());
      },
    );
  }

  Widget _buildStickyBottomBar(bool isDark, Color primaryColor) {
    bool showBooking = listing.bookingEnabled;
    bool showChat = currentUser.userID != listing.authorID && listing.chatEnabled;

    if (!showBooking && !showChat) return const SizedBox.shrink();

    final extraPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 28 + extraPadding),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (listing.price.isNotEmpty)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${_getCurrencySymbol(listing.currencyCode)}${listing.price}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(listing.currencyCode, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            const SizedBox(width: 16),
            if (showBooking && showChat) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _handleMessage,
                child: Icon(Icons.chat_bubble_outline, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _handleBooking,
                  child: Text(
                    'Book Now'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: showBooking ? _handleBooking : (showChat ? _handleMessage : null),
                  child: Text(
                    showBooking ? 'Book Now'.tr() : 'Message Seller'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBooking() async {
    // Fetch the latest listing from Firestore to ensure custom questions are up to date
    final latest = await listingApiManager.getListing(listingID: listing.id);
    final latestListing = latest ?? listing;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider(
        create: (context) => BookingBloc(bookingRepository: bookingApiManager)..add(GetBookedDatesEvent(listingId: latestListing.id)),
        child: BookingRequestDialog(listing: latestListing, currentUser: currentUser),
      ),
    );
  }

  void _handleMessage() {
    if (!currentUser.hasDirectMessaging) {
      push(context, PaywallScreen(currentUser: currentUser));
      return;
    }
    
    // Create the channel ID correctly
    List<String> ids = [currentUser.userID, listing.authorID];
    ids.sort();
    String channelId = '${ids.join()}_${listing.id}';

    push(
      context,
      ChatWrapperWidget(
        channelDataModel: ChannelDataModel(
          id: channelId,
          channelID: channelId,
          name: listing.title,
          listingId: listing.id,
          listingTitle: listing.title,
          listingImage: listing.photos.isNotEmpty ? listing.photos.first : '',
          participants: [
            core_user.User(
              userID: listing.authorID,
              firstName: listing.authorName, // Best effort fallback
              profilePictureURL: listing.logo,
            ),
          ],
        ),
        currentUser: currentUser,
        colorPrimary: Color(cfg.colorPrimary),
        colorAccent: Color(cfg.colorAccent),
      ),
    );
  }

  String _calculateAverageRating() {
    if (reviews.isEmpty) return '0.0';
    double total = 0;
    for (var r in reviews) total += r.starCount;
    return (total / reviews.length).toStringAsFixed(1);
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _resumeAutoScrollTimer?.cancel();
    _pagerController.dispose();
    _mapController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance.collection(cfg.listingsCollection).doc(listing.id).update({'viewCount': FieldValue.increment(1)});
    } catch (e) { print(e); }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (isDarkMode(context)) {
      _mapController?.setMapStyle('[{"featureType":"all","elementType":"geometry","stylers":[{"color":"#242f3e"}]}]'); // Simplified for brevity
    }
  }

  deleteListing(BuildContext blocContext) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Listing?'.tr()),
        content: Text('Are you sure you want to remove this listing?'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('No'.tr())),
          TextButton(onPressed: () {
            Navigator.pop(context);
            context.read<LoadingCubit>().showLoading(context, 'Deleting...'.tr(), false, Color(cfg.colorPrimary));
            blocContext.read<ListingDetailsBloc>().add(DeleteListingEvent());
          }, child: Text('Yes'.tr(), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  static bool _hasContactOrHours(ListingModel l) {
    return l.phone.trim().isNotEmpty ||
      l.email.trim().isNotEmpty ||
      l.website.trim().isNotEmpty ||
      l.openingHours.trim().isNotEmpty ||
      l.instagram.trim().isNotEmpty ||
      l.facebook.trim().isNotEmpty ||
      l.tiktok.trim().isNotEmpty ||
      l.whatsapp.trim().isNotEmpty ||
      l.youtube.trim().isNotEmpty ||
      l.x.trim().isNotEmpty;
  }

  Future<void> _launchPhone(String phone) async {
    if (phone.isEmpty) return;
    await _safeLaunch(Uri(scheme: 'tel', path: phone.trim()));
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty) return;
    await _safeLaunch(Uri(scheme: 'mailto', path: email.trim()));
  }

  Future<void> _launchWebsite(String website) async {
    if (website.isEmpty) return;
    await _safeLaunch(Uri.parse(website.startsWith('http') ? website : 'https://$website'));
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    await _safeLaunch(Uri.parse(url.startsWith('http') ? url : 'https://$url'));
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    await _safeLaunch(Uri.parse('whatsapp://send?phone=${phone.replaceAll(RegExp(r'[^\\d+]'), '')}'));
  }

  Future<void> _safeLaunch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) { debugPrint(e.toString()); }
  }
}

enum MediaType { photo, video }

class MediaItem {
  final String url;
  final MediaType type;
  bool get isVideo => type == MediaType.video;

  const MediaItem({required this.url, required this.type});

  factory MediaItem.photo(String url) => MediaItem(url: url, type: MediaType.photo);
  factory MediaItem.video(String url) => MediaItem(url: url, type: MediaType.video);
}

class _ContactHoursCard extends StatelessWidget {
  final ListingModel listing;
  final Color colorPrimary;
  final bool isDark;
  final VoidCallback onCall, onEmail, onWebsite, onInstagram, onFacebook, onTiktok, onWhatsapp, onYoutube, onX;

  final int showOnlyFirst;

  const _ContactHoursCard({
    super.key,
    required this.listing, required this.colorPrimary, required this.isDark,
    required this.onCall, required this.onEmail, required this.onWebsite,
    required this.onInstagram, required this.onFacebook, required this.onTiktok,
    required this.onWhatsapp, required this.onYoutube, required this.onX,
    this.showOnlyFirst = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final contactRows = <Widget>[];
    void addContactRow(Widget row) {
      if (contactRows.isNotEmpty) {
        contactRows.add(Divider(height: 1, indent: 56, color: isDark ? Colors.white10 : Colors.black12));
      }
      contactRows.add(row);
    }

    if (listing.phone.isNotEmpty) addContactRow(_ActionRow(icon: Icons.call, title: 'Phone'.tr(), value: listing.phone, onTap: onCall, accent: colorPrimary, isDark: isDark));
    if (listing.email.isNotEmpty) addContactRow(_ActionRow(icon: Icons.email, title: 'Email'.tr(), value: listing.email, onTap: onEmail, accent: colorPrimary, isDark: isDark));
    if (listing.website.isNotEmpty) addContactRow(_ActionRow(icon: FontAwesomeIcons.globe, title: 'Website'.tr(), value: listing.website, onTap: onWebsite, accent: colorPrimary, isDark: isDark));
    if (listing.instagram.isNotEmpty) {
      final igHandle = extractSocialHandle(listing.instagram, 'instagram.com');
      addContactRow(_ActionRow(icon: FontAwesomeIcons.instagram, title: 'Instagram'.tr(), value: igHandle, onTap: onInstagram, accent: colorPrimary, isDark: isDark));
    }
    if (listing.facebook.isNotEmpty) {
      final fbHandle = extractSocialHandle(listing.facebook, 'facebook.com');
      addContactRow(_ActionRow(icon: FontAwesomeIcons.facebook, title: 'Facebook'.tr(), value: fbHandle, onTap: onFacebook, accent: colorPrimary, isDark: isDark));
    }
    if (listing.tiktok.isNotEmpty) {
      final ttHandle = extractSocialHandle(listing.tiktok, 'tiktok.com');
      addContactRow(_ActionRow(icon: FontAwesomeIcons.tiktok, title: 'TikTok'.tr(), value: ttHandle, onTap: onTiktok, accent: colorPrimary, isDark: isDark));
    }
    if (listing.whatsapp.isNotEmpty) addContactRow(_ActionRow(icon: FontAwesomeIcons.whatsapp, title: 'WhatsApp'.tr(), value: listing.whatsapp, onTap: onWhatsapp, accent: colorPrimary, isDark: isDark));
    if (listing.youtube.isNotEmpty) {
      final ytHandle = extractSocialHandle(listing.youtube, 'youtube.com');
      addContactRow(_ActionRow(icon: Icons.ondemand_video, title: 'YouTube'.tr(), value: ytHandle, onTap: onYoutube, accent: colorPrimary, isDark: isDark));
    }
    if (listing.x.isNotEmpty) {
      final xHandle = extractSocialHandle(listing.x, 'x.com');
      addContactRow(_ActionRow(icon: FontAwesomeIcons.xTwitter, title: 'X'.tr(), value: xHandle, onTap: onX, accent: colorPrimary, isDark: isDark));
    }

    int maxToShow = showOnlyFirst > 0 ? showOnlyFirst : contactRows.length;

    return _ContactRowsExpander(
      contactRows: contactRows,
      maxToShow: maxToShow,
      openingHours: listing.openingHours,
      colorPrimary: colorPrimary,
      isDark: isDark,
    );
  }
}


// Helper widget to manage expansion state
class _ContactRowsExpander extends StatefulWidget {
  final List<Widget> contactRows;
  final int maxToShow;
  final String openingHours;
  final Color colorPrimary;
  final bool isDark;
  const _ContactRowsExpander({
    required this.contactRows,
    required this.maxToShow,
    required this.openingHours,
    required this.colorPrimary,
    required this.isDark,
  });
  @override
  State<_ContactRowsExpander> createState() => _ContactRowsExpanderState();
}

class _ContactRowsExpanderState extends State<_ContactRowsExpander> {
  bool showAll = false;
  @override
  Widget build(BuildContext context) {
    final visibleRows = showAll ? widget.contactRows : widget.contactRows.take(widget.maxToShow).toList();
    return Container(
      decoration: BoxDecoration(color: widget.isDark ? Colors.grey.shade900 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isDark ? Colors.white10 : Colors.black12)),
      child: Column(
        children: [
          ...visibleRows,
          if (!showAll && widget.contactRows.length > widget.maxToShow)
            TextButton(
              onPressed: () => setState(() => showAll = true),
              child: Text('Show All'.tr()),
            ),
          if (widget.openingHours.isNotEmpty)
            ...[
              if (visibleRows.isNotEmpty) Divider(height: 1, indent: 56, color: widget.isDark ? Colors.white10 : Colors.black12),
              _OpeningHoursRow(value: widget.openingHours, accent: widget.colorPrimary, isDark: widget.isDark),
            ],
        ],
      ),
    );
  }
}

class _OpeningHoursRow extends StatefulWidget {
  final String value;
  final Color accent;
  final bool isDark;

  const _OpeningHoursRow({super.key, required this.value, required this.accent, required this.isDark});

  @override
  State<_OpeningHoursRow> createState() => _OpeningHoursRowState();
}

class _OpeningHoursRowState extends State<_OpeningHoursRow> {
  bool _isExpanded = false;

  final List<String> daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  DateTime? _parseTimeOfDayStringToDateTime(String timeStr, DateTime now) {
    timeStr = timeStr.trim();
    if (timeStr.isEmpty) return null;

    // Preprocess "H:am" to "H:00 AM" and "H:pm" to "H:00 PM"
    timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+):am'), (match) => '${match.group(1)}:00 AM');
    timeStr = timeStr.replaceAllMapped(RegExp(r'(\d+):pm'), (match) => '${match.group(1)}:00 PM');

    final format12hr = DateFormat.jm(); // e.g., 10:00 AM
    final format24hr = DateFormat('HH:mm'); // e.g., 10:00

    try {
      // Try parsing as HH:mm AM/PM (12-hour)
      return format12hr.parse(timeStr);
    } catch (_) {
      try {
        // Try parsing as HH:mm (24-hour)
        return format24hr.parse(timeStr);
      } catch (_) {
        // Try parsing as just an hour number (e.g., "7" -> 7:00)
        final int? hour = int.tryParse(timeStr);
        if (hour != null && hour >= 0 && hour <= 23) {
          return DateTime(now.year, now.month, now.day, hour, 0);
        }
      }
    }
    return null;
  }

  // Formats the raw hours string (e.g., "07", "09:00→17:00", "Closed") for display
  String _formatDisplayHours(String rawHours, DateFormat formatter, DateTime now) {
    rawHours = rawHours.trim();
    if (rawHours.isEmpty) return rawHours;

    if (rawHours.toLowerCase() == 'closed') {
      return 'Closed'.tr();
    }

    final timeParts = rawHours.split('→');
    if (timeParts.length == 2) {
      // It's an explicit time range
      final open = _parseTimeOfDayStringToDateTime(timeParts[0], now);
      final close = _parseTimeOfDayStringToDateTime(timeParts[1], now);
      if (open != null && close != null) {
        return '${formatter.format(open)} - ${formatter.format(close)}';
      }
    } else if (timeParts.length == 1 && rawHours.isNotEmpty) {
      // It's a single time (e.g., "07", "10:00 AM")
      final open = _parseTimeOfDayStringToDateTime(rawHours, now);
      if (open != null) {
        return '${'Opens at'.tr()} ${formatter.format(open)}';
      }
    }
    return rawHours; // Fallback if no specific pattern is matched
  }

  bool _isTimeBetween(DateTime now, DateTime open, DateTime close) {
    final nowTime = TimeOfDay.fromDateTime(now);
    final openTime = TimeOfDay.fromDateTime(open);
    final closeTime = TimeOfDay.fromDateTime(close);

    // Convert to minutes since midnight for easier comparison
    final nowInMinutes = nowTime.hour * 60 + nowTime.minute;
    final openInMinutes = openTime.hour * 60 + openTime.minute;
    final closeInMinutes = closeTime.hour * 60 + closeTime.minute;

    if (openInMinutes < closeInMinutes) {
      // Case 1: Open and close times are in the same day (e.g., 9 AM to 5 PM)
      return nowInMinutes >= openInMinutes && nowInMinutes < closeInMinutes;
    } else {
      // Case 2: Overnight hours (e.g., 10 PM to 6 AM)
      // This means closing time is on the next day.
      // So if now is after opening or before closing (next day)
      return nowInMinutes >= openInMinutes || nowInMinutes < closeInMinutes;
    }
  }

  // Helper to parse the single-line openingHours string into a map
  Map<String, String> _parseOpeningHoursString(String openingHoursString) {
    final Map<String, String> parsedHours = {};

    String remainingString = openingHoursString;

    for (int i = 0; i < daysOfWeek.length; i++) {
      final currentDay = daysOfWeek[i];
      final dayPrefix = '$currentDay:';

      int startIndex = remainingString.indexOf(dayPrefix);
      if (startIndex == -1 && i == 0) {
        // If the very first day isn't found, then the format is unexpected.
        // For now, if currentDay not found, assume closed.
        parsedHours[currentDay] = 'Closed';
        continue;
      } else if (startIndex == -1) {
        // If a subsequent day is not found, it means the previous day's hours extend to the end
        // or this day is implicitly closed. We'll default to closed.
        parsedHours[currentDay] = 'Closed';
        continue;
      }
      
      // Advance past the day prefix
      int hoursStartIndex = startIndex + dayPrefix.length;

      // Find the start of the next day's entry in the *original* string
      int nextDayEntryIndex = -1;
      for (int j = i + 1; j < daysOfWeek.length; j++) {
        final nextDayPrefix = '${daysOfWeek[j]}:';
        nextDayEntryIndex = openingHoursString.indexOf(nextDayPrefix, hoursStartIndex);
        if (nextDayEntryIndex != -1) {
          break; // Found the next day's marker
        }
      }
      
      String rawHours;
      if (nextDayEntryIndex != -1) {
        // Extract hours up to the next day's prefix from the original string
        rawHours = openingHoursString.substring(hoursStartIndex, nextDayEntryIndex).trim();
      } else {
        // This is the last day, extract hours until the end of the string
        rawHours = openingHoursString.substring(hoursStartIndex).trim();
      }
      parsedHours[currentDay] = rawHours;
    }
    
    // Fallback for any days not explicitly found (e.g., if the string is malformed or incomplete)
    for (final day in daysOfWeek) {
      parsedHours.putIfAbsent(day, () => 'Closed');
    }

    return parsedHours;
  }


  @override
  Widget build(BuildContext context) {
    final parsedHours = _parseOpeningHoursString(widget.value);

    final now = DateTime.now();
    final todayDayName = DateFormat('EEEE').format(now);
    String rawTodayHours = parsedHours[todayDayName] ?? 'Closed'; // Get today's raw hours from the parsed map
    bool isOpen = false;

    if (rawTodayHours.toLowerCase() != 'closed') {
      final format = DateFormat('h:mm a'); // Changed from DateFormat.jm()
      if (rawTodayHours.contains('→')) {
        try {
          final timeParts = rawTodayHours.split('→');
          final openTime = _parseTimeOfDayStringToDateTime(timeParts[0], now);
          final closeTime = _parseTimeOfDayStringToDateTime(timeParts[1], now);

          if (openTime != null && closeTime != null) {
            isOpen = _isTimeBetween(now, openTime, closeTime);
          }
        } catch (_) {} 
      } else {
        // If only one time is provided (e.g., "10:am"), assume it's an opening time and it's open if after this time.
        // A more complex app might assume a default closing time (e.g., end of day or 8 hours later).
        try {
          final openTime = _parseTimeOfDayStringToDateTime(rawTodayHours, now);
          if (openTime != null) {
            final nowTimeOfDay = TimeOfDay.fromDateTime(now);
            final openTimeOfDay = TimeOfDay.fromDateTime(openTime);

            // Check if current time is after the opening time.
            // Since no closing time is specified, we assume it's "open from this time onwards"
            // for the purpose of the "Open Now" status.
            if (nowTimeOfDay.hour > openTimeOfDay.hour ||
                (nowTimeOfDay.hour == openTimeOfDay.hour && nowTimeOfDay.minute >= openTimeOfDay.minute)) {
              isOpen = true;
            }
          }
        } catch (_) {}
      }
    }

    final displayTodayHours = _formatDisplayHours(rawTodayHours, DateFormat('h:mm a'), now); // Changed from DateFormat.jm()

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.access_time, color: widget.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Opening Hours'.tr(), style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.grey : Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOpen ? 'Open Now'.tr() : 'Closed'.tr(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOpen ? Colors.green : Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(displayTodayHours, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
            child: Column(
              children: daysOfWeek.map((day) { // Use daysOfWeek to ensure order
                final rawHours = parsedHours[day] ?? 'Closed';
                final isToday = day == todayDayName;
                final displayHours = _formatDisplayHours(rawHours, DateFormat('h:mm a'), now); // Changed from DateFormat.jm()
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        day.tr(),
                        style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal),
                      ),
                      Text(
                        displayHours,
                        style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal), // Changed FontWeight.w600 to FontWeight.normal
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}


class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color accent;
  final bool isDark;

  const _ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}


// Placeholder for _InfoRow, assuming its existence
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final bool isDark;

  const _InfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey : Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FilterDetailsWidget extends StatelessWidget {
  final MapEntry<String, dynamic> filter;
  final bool isDark;
  final Color colorPrimary;
  final bool isLast;

  const FilterDetailsWidget({
    super.key,
    required this.filter,
    required this.isDark,
    required this.colorPrimary,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colorPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  filter.key.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Text(
                filter.value.toString().tr(),
                style: TextStyle(
                  color: isDark ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(indent: 56, height: 1, color: isDark ? Colors.white10 : Colors.black12),
      ],
    );
  }
}

class ReviewWidget extends StatelessWidget {
  final ListingReviewModel review;

  const ReviewWidget({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (review.profilePictureURL.isNotEmpty)
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(review.profilePictureURL),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                review.fullName(), // Corrected from review.reviewerName
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(review.createdAt * 1000)), // Corrected .toDate()
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RatingBarIndicator(
          rating: review.starCount.toDouble(),
          itemBuilder: (context, index) => Icon(
            Icons.star,
            color: Colors.amber,
          ),
          itemCount: 5,
          itemSize: 20.0,
          direction: Axis.horizontal,
        ),
        const SizedBox(height: 8),
        Text(
          review.content, // Corrected from review.review
          style: TextStyle(fontSize: 15, height: 1.4, color: isDarkMode(context) ? Colors.grey.shade300 : Colors.grey.shade800),
        ),
      ],
    );
  }
}

// Wrapper for ListingDetailsScreen, as it's used in other files.
class ListingDetailsWrappingWidget extends StatelessWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const ListingDetailsWrappingWidget({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ListingDetailsBloc>(
      create: (context) => ListingDetailsBloc(
        listingsRepository: listingApiManager,
        profileRepository: profileApiManager,
        listing: listing,
        currentUser: currentUser,
      )..add(GetListingReviewsEvent()),
      child: ListingDetailsScreen(
        listing: listing,
        currentUser: currentUser,
      ),
    );
  }
}
