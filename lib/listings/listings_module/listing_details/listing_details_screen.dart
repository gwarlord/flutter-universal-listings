import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:instaflutter/core/ui/chat/api/chat_api_manager.dart';
import 'package:instaflutter/core/ui/chat/chat/chat_screen.dart';
import 'package:instaflutter/core/ui/chat/conversation/conversation_bloc.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ListingDetailsBloc(
            listing: listing,
            listingsRepository: listingApiManager,
            profileRepository: profileApiManager,
            currentUser: currentUser,
          ),
        ),
        BlocProvider(
          create: (context) => ConversationsBloc(
            chatRepository: chatApiManager,
            currentUser: currentUser,
          ),
        ),
      ],
      child: ListingDetailsScreen(currentUser: currentUser, listing: listing),
    );
  }
}

class ListingDetailsScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const ListingDetailsScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  late ListingModel listing;
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

  List<ListingReviewModel> reviews = [];
  List<MediaItem> _mediaList = [];
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoMuted = true;
  bool _servicesExpanded = false;

  bool get _canEditOrDelete =>
      currentUser.userID == listing.authorID || currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    listing = widget.listing;
    _placeLocation = LatLng(listing.latitude, listing.longitude);

    _buildMediaList();

    context.read<ListingDetailsBloc>().add(GetListingReviewsEvent());

    // Increment view count (don't count owner's own views)
    if (currentUser.userID != listing.authorID) {
      _incrementViewCount();
    }

    if (_mediaList.length > 1) {
      _startAutoScroll();
    }
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

  void _loadVideoController(String videoUrl) {
    _videoController?.dispose();
    _videoReady = false;
    _videoMuted = true;
    
    _videoController = VideoPlayerController.network(
      videoUrl,
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
    _isCarouselInteracting = true;
    _resumeAutoScrollTimer?.cancel();
  }

  void _resumeAutoScrollAfterDelay() {
    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _mediaList.length > 1 && !_isCarouselInteracting) {
        _isCarouselInteracting = false;
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    if (_autoScroll != null) return;
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

    return MultiBlocListener(
      listeners: [
        BlocListener<ListingDetailsBloc, ListingDetailsState>(
          listener: (context, state) async {
            if (state is DeletedListingState) {
              context.read<LoadingCubit>().hideLoading();
              if (!mounted) return;
              Navigator.pop(context, true);
            }
          },
        ),
        BlocListener<ConversationsBloc, ConversationsState>(
          listener: (context, state) {
            if (state is FriendTapState) {
              push(
                context,
                ChatWrapperWidget(
                  channelDataModel: state.channelDataModel,
                  currentUser: currentUser,
                  colorAccent: Color(cfg.colorAccent),
                  colorPrimary: Color(cfg.colorPrimary),
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            listing.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                return PopupMenuButton(
                  itemBuilder: (BuildContext context) {
                    return [
                      PopupMenuItem(
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.all(0),
                          leading: Icon(
                            Icons.favorite,
                            color: listing.isFav
                                ? Color(cfg.colorPrimary)
                                : adaptiveTextColor,
                          ),
                          title: Text(
                            listing.isFav
                                ? 'Remove From Favorites'.tr()
                                : 'Add To Favorites'.tr(),
                            style: TextStyle(fontSize: 18, color: adaptiveTextColor),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context
                                .read<ListingDetailsBloc>()
                                .add(ListingFavUpdatedEvent());
                          },
                        ),
                      ),
                      if (_canEditOrDelete)
                        PopupMenuItem(
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.all(0),
                            leading: Icon(
                              Icons.edit,
                              color: dark ? Color(cfg.colorPrimary) : Colors.black,
                            ),
                            title: Text(
                              'Edit Listing'.tr(),
                              style: TextStyle(fontSize: 18, color: adaptiveTextColor),
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
                              if (updated is ListingModel) {
                                if (!mounted) return;
                                setState(() {
                                  listing = updated;
                                });
                              }
                            },
                          ),
                        ),
                      if (currentUser.userID != listing.authorID)
                        PopupMenuItem(
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.all(0),
                            leading: Icon(
                              Icons.stars,
                              color: adaptiveTextColor,
                            ),
                            title: Text(
                              'Add Review'.tr(),
                              style: TextStyle(fontSize: 18, color: adaptiveTextColor),
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
                              if (reviewPublished != null && reviewPublished) {
                                if (!mounted) return;
                                context
                                    .read<ListingDetailsBloc>()
                                    .add(LoadingEvent());
                                context
                                    .read<ListingDetailsBloc>()
                                    .add(GetListingReviewsEvent());
                              }
                            },
                          ),
                        ),
                      if (currentUser.userID != listing.authorID)
                        PopupMenuItem(
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.all(0),
                            leading: Icon(
                              Icons.chat,
                              color: adaptiveTextColor,
                            ),
                            trailing: !currentUser.hasDirectMessaging
                                ? Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Colors.orange,
                                  )
                                : null,
                            title: Text(
                              'Send Message'.tr(),
                              style: TextStyle(fontSize: 18, color: adaptiveTextColor),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              if (!currentUser.hasDirectMessaging) {
                                _showChatUnlockDialog(context);
                                return;
                              }
                              context.read<ConversationsBloc>().add(
                                FetchFriendByIDEvent(
                                  friendID: listing.authorID,
                                ),
                              );
                            },
                          ),
                        ),
                      if (_canEditOrDelete)
                        PopupMenuItem(
                          child: ListTile(
                            dense: true,
                            onTap: () => deleteListing(context),
                            contentPadding: const EdgeInsets.all(0),
                            leading: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Delete Listing'.tr(),
                              style: TextStyle(fontSize: 18, color: adaptiveTextColor),
                            ),
                          ),
                        ),
                    ];
                  },
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mediaList.isNotEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 3,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pagerController,
                          itemCount: _mediaList.length,
                          scrollDirection: Axis.horizontal,
                          onPageChanged: (index) {
                            _pauseAutoScroll();
                            setState(() => _pageIndex = index);
                            final media = _mediaList[index];
                            if (media.isVideo) {
                              _loadVideoController(media.url);
                            } else {
                              _videoController?.pause();
                            }
                            _resumeAutoScrollAfterDelay();
                          },
                          itemBuilder: (context, index) {
                            final media = _mediaList[index];
                            if (media.isVideo) {
                              return GestureDetector(
                                onTap: () {
                                  _pauseAutoScroll();
                                  if (_videoReady && _videoController != null) {
                                    setState(() {
                                      _videoController!.value.isPlaying
                                          ? _videoController!.pause()
                                          : _videoController!.play();
                                    });
                                  }
                                  _resumeAutoScrollAfterDelay();
                                },
                                child: _videoReady && _videoController != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          VideoPlayer(_videoController!),
                                          if (!_videoController!.value.isPlaying)
                                            Container(
                                              color: Colors.black.withOpacity(0.2),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.play_circle_fill,
                                                  size: 64,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: GestureDetector(
                                              onTap: () {
                                                if (_videoController != null) {
                                                  setState(() {
                                                    _videoMuted = !_videoMuted;
                                                    _videoController!.setVolume(_videoMuted ? 0 : 1);
                                                  });
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _videoMuted ? Icons.volume_off : Icons.volume_up,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        color: Colors.black.withOpacity(0.3),
                                        child: const Center(
                                          child: CircularProgressIndicator.adaptive(),
                                        ),
                                      ),
                              );
                            } else {
                              return GestureDetector(
                                onTap: () {
                                  _pauseAutoScroll();
                                  if (_mediaList.length > 1) {
                                    push(
                                      context,
                                      FullScreenImageViewer(
                                        galleryImagesList: _mediaList
                                            .where((m) => !m.isVideo)
                                            .map((m) => m.url)
                                            .toList(),
                                        index: _mediaList
                                            .asMap()
                                            .entries
                                            .where((e) => !e.value.isVideo)
                                            .toList()
                                            .indexWhere((e) => e.value.url == media.url),
                                        imageUrl: '',
                                      ),
                                    );
                                  } else {
                                    push(
                                      context,
                                      FullScreenImageViewer(
                                        imageUrl: media.url,
                                      ),
                                    );
                                  }
                                },
                                child: displayImage(media.url),
                              );
                            }
                          },
                        ),
                        if (_mediaList.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SmoothPageIndicator(
                                effect: ColorTransitionEffect(
                                  activeDotColor: Color(cfg.colorPrimary),
                                  dotHeight: 8,
                                  dotWidth: 8,
                                  dotColor: Colors.grey.shade300,
                                ),
                                controller: _pagerController,
                                count: _mediaList.length,
                              ),
                            ),
                          )
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (listing.verified) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Verified'.tr(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (listing.price.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${_getCurrencySymbol(listing.currencyCode)} ${listing.price} ${listing.currencyCode}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(cfg.colorPrimary),
                            ),
                          ),
                        ),
                      if (listing.bookingEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (loadingContext) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                                await Future.delayed(const Duration(milliseconds: 100));
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (dialogContext) => BlocProvider(
                                      create: (context) => BookingBloc(
                                        bookingRepository: bookingApiManager,
                                      )..add(GetBookedDatesEvent(listingId: listing.id)),
                                      child: BookingRequestDialog(
                                        listing: listing,
                                        currentUser: currentUser,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.event_available),
                              label: const Text('Book Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(cfg.colorPrimary),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (listing.countryCode.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: dark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(cfg.colorPrimary).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getCountryFlag(listing.countryCode),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getCountryName(listing.countryCode),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(cfg.colorPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(cfg.colorPrimary),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          listing.description,
                          style: TextStyle(
                            height: 1.6,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: dark ? Colors.grey.shade300 : Colors.grey.shade700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contact Seller Button (only show if not own listing)
                if (currentUser.userID != listing.authorID) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: listing.chatEnabled
                              ? Color(cfg.colorPrimary)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(
                          listing.chatEnabled ? Icons.chat_bubble : Icons.lock,
                          size: 22,
                        ),
                        label: Text(
                          listing.chatEnabled
                              ? 'Message Seller'.tr()
                              : 'Chat Disabled'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          if (!listing.chatEnabled) {
                            return;
                          }
                          if (!currentUser.hasDirectMessaging) {
                            _showChatUnlockDialog(context);
                            return;
                          }
                          context.read<ConversationsBloc>().add(
                            FetchFriendByIDEvent(
                              friendID: listing.authorID,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                if (_hasContactOrHours(listing)) ...[                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                    child: Text(
                      'Contact & Hours'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(cfg.colorPrimary),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ContactHoursCard(
                      listing: listing,
                      colorPrimary: Color(cfg.colorPrimary),
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
                    ),
                  ),
                  // ✅ Services Section
                  if (listing.services.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Services'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(cfg.colorPrimary),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${listing.services.length} total',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: _servicesExpanded ? 'Collapse' : 'Expand',
                            icon: Icon(
                              _servicesExpanded ? Icons.expand_less : Icons.expand_more,
                              color: Color(cfg.colorPrimary),
                            ),
                            onPressed: () => setState(() => _servicesExpanded = !_servicesExpanded),
                          ),
                        ],
                      ),
                    ),
                    if (_servicesExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: listing.services.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final service = listing.services[index];
                              return Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            service.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: dark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if (service.duration.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              service.duration,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${service.price} ${listing.currencyCode}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(cfg.colorPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                  child: Text(
                    'Location'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(cfg.colorPrimary),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: dark ? Colors.grey.shade500 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          listing.place,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: dark ? Colors.grey.shade500 : Colors.grey.shade600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16, 16, 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 160,
                      child: FutureBuilder(
                        future: _mapFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator.adaptive(),
                            );
                          }
                          return GoogleMap(
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            gestureRecognizers: {}..add(
                                Factory<OneSequenceGestureRecognizer>(
                                        () => EagerGestureRecognizer())),
                            markers: <Marker>{
                              Marker(
                                markerId: const MarkerId('marker_1'),
                                position: _placeLocation,
                                infoWindow: InfoWindow(title: listing.title),
                              ),
                            },
                            mapType: MapType.normal,
                            initialCameraPosition: CameraPosition(
                              target: _placeLocation,
                              zoom: 14.4746,
                            ),
                            onMapCreated: _onMapCreated,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                if (listing.filters.isNotEmpty) ...[                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                    child: Text(
                      'Details'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(cfg.colorPrimary),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: listing.filters.entries.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) => FilterDetailsWidget(
                          filter: listing.filters.entries.elementAt(index),
                          isDark: dark,
                          colorPrimary: Color(cfg.colorPrimary),
                          isLast: index == listing.filters.entries.length - 1,
                        ),
                      ),
                    ),
                  ),
                ],

                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 12),
                  child: Text(
                    'Reviews'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(cfg.colorPrimary),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                BlocConsumer<ListingDetailsBloc, ListingDetailsState>(
                  listener: (context, state) {
                    if (state is ReviewsFetchedState) {
                      isLoadingReviews = false;
                      reviews = state.reviews;
                    } else if (state is LoadingState) {
                      isLoadingReviews = true;
                    }
                  },
                  buildWhen: (old, current) =>
                  old != current &&
                      (current is ReviewsFetchedState ||
                          current is LoadingState),
                  builder: (context, state) {
                    if (isLoadingReviews) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }
                    if (reviews.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: showEmptyState(
                          'No Reviews found.'.tr(),
                          'You can add a review and it will show up here.'
                              .tr(),
                          buttonTitle: 'Add Review',
                          isDarkMode: dark,
                          action: () async {
                            bool? reviewPublished = await push(
                              context,
                              AddReviewWrappingWidget(
                                listing: listing,
                                currentUser: currentUser,
                              ),
                            );
                            if (reviewPublished != null && reviewPublished) {
                              if (!mounted) return;
                              context
                                  .read<ListingDetailsBloc>()
                                  .add(LoadingEvent());
                              context
                                  .read<ListingDetailsBloc>()
                                  .add(GetListingReviewsEvent());
                            }
                          },
                          colorPrimary: Color(cfg.colorPrimary),
                        ),
                      );
                    } else {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        shrinkWrap: true,
                        itemCount: reviews.length,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) =>
                            ReviewWidget(review: reviews[index]),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
      await FirebaseFirestore.instance
          .collection(cfg.listingsCollection)
          .doc(listing.id)
          .update({
        'viewCount': FieldValue.increment(1),
      });
      print('✅ View count incremented for listing: ${listing.id}');
    } catch (e) {
      print('❌ Error incrementing view count: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (isDarkMode(context)) {
      _mapController?.setMapStyle(
          '[{"featureType":"all","elementType":"geometry","stylers":[{"color":"#242f3e"}]},'
              '{"featureType":"all","elementType":"labels.text.stroke","stylers":[{"lightness":-80}]},'
              '{"featureType":"administrative","elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},'
              '{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},'
              '{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},'
              '{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},'
              '{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},'
              '{"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2b3544"}]},'
              '{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},'
              '{"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#38414e"}]},'
              '{"featureType":"road.arterial","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},'
              '{"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#746855"}]},'
              '{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},'
              '{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},'
              '{"featureType":"road.local","elementType":"geometry.fill","stylers":[{"color":"#38414e"}]},'
              '{"featureType":"road.local","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},'
              '{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},'
              '{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},'
              '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},'
              '{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},'
              '{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"lightness":-20}]}]');
    }
  }

  void _showChatUnlockDialog(BuildContext context) {
    final isDark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.lock, color: Color(cfg.colorPrimary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Premium Feature',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
        content: Text(
          'Direct messaging is a Premium feature. Upgrade to connect directly with sellers and buyers!',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaywallScreen(
                    currentUser: currentUser,
                  ),
                ),
              );
            },
            child: Text('Upgrade Now'.tr()),
          ),
        ],
      ),
    );
  }

  deleteListing(BuildContext blocContext) {
    Navigator.pop(context);
    String title = 'Delete Listing?'.tr();
    String content = 'Are you sure you want to remove this listing?'.tr();

    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: Text(
                'Yes'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                context.read<LoadingCubit>().showLoading(
                  context,
                  'Deleting...'.tr(),
                  false,
                  Color(cfg.colorPrimary),
                );
                blocContext.read<ListingDetailsBloc>().add(DeleteListingEvent());
              },
            ),
            TextButton(
              child: Text('No'.tr()),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: Text(
                'Yes'.tr(),
                style: const TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                context.read<LoadingCubit>().showLoading(
                  context,
                  'Deleting...'.tr(),
                  false,
                  Color(cfg.colorPrimary),
                );
                blocContext.read<ListingDetailsBloc>().add(DeleteListingEvent());
              },
            ),
            TextButton(
              child: Text('No'.tr()),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }
  }

  static bool _hasContactOrHours(ListingModel l) {
    final phone = (l.phone).trim();
    final email = (l.email).trim();
    final website = (l.website).trim();
    final hours = (l.openingHours).trim();
    final instagram = (l.instagram).trim();
    final facebook = (l.facebook).trim();
    final tiktok = (l.tiktok).trim();
    final whatsapp = (l.whatsapp).trim();
    final youtube = (l.youtube).trim();
    final x = (l.x).trim();
    return phone.isNotEmpty ||
        email.isNotEmpty ||
        website.isNotEmpty ||
        hours.isNotEmpty ||
        instagram.isNotEmpty ||
        facebook.isNotEmpty ||
        tiktok.isNotEmpty ||
        whatsapp.isNotEmpty ||
        youtube.isNotEmpty ||
        x.isNotEmpty;
  }

  String _getCountryFlag(String countryCode) {
    const flags = {
      'AG': '🇦🇬', 'BS': '🇧🇸', 'BB': '🇧🇧', 'BZ': '🇧🇿', 'CU': '🇨🇺',
      'DM': '🇩🇲', 'DO': '🇩🇴', 'GD': '🇬🇩', 'GY': '🇬🇾', 'HT': '🇭🇹',
      'JM': '🇯🇲', 'KN': '🇰🇳', 'LC': '🇱🇨', 'VC': '🇻🇨', 'SR': '🇸🇷',
      'TT': '🇹🇹', 'AI': '🇦🇮', 'AW': '🇦🇼', 'BM': '🇧🇲', 'BQ': '🇧🇶',
      'VG': '🇻🇬', 'KY': '🇰🇾', 'CW': '🇨🇼', 'GF': '🇬🇫', 'GP': '🇬🇵',
      'MQ': '🇲🇶', 'MS': '🇲🇸', 'PR': '🇵🇷', 'BL': '🇧🇱', 'MF': '🇲🇫',
      'SX': '🇸🇽', 'TC': '🇹🇨', 'VI': '🇻🇮',
    };
    return flags[countryCode] ?? '🌍';
  }

  String _getCountryName(String countryCode) {
    const names = {
      'AG': 'Antigua and Barbuda', 'BS': 'Bahamas', 'BB': 'Barbados', 'BZ': 'Belize', 'CU': 'Cuba',
      'DM': 'Dominica', 'DO': 'Dominican Republic', 'GD': 'Grenada', 'GY': 'Guyana', 'HT': 'Haiti',
      'JM': 'Jamaica', 'KN': 'Saint Kitts and Nevis', 'LC': 'Saint Lucia', 'VC': 'Saint Vincent and the Grenadines',
      'SR': 'Suriname', 'TT': 'Trinidad and Tobago', 'AI': 'Anguilla', 'AW': 'Aruba', 'BM': 'Bermuda',
      'BQ': 'Caribbean Netherlands', 'VG': 'British Virgin Islands', 'KY': 'Cayman Islands', 'CW': 'Curaçao',
      'GF': 'French Guiana', 'GP': 'Guadeloupe', 'MQ': 'Martinique', 'MS': 'Montserrat', 'PR': 'Puerto Rico',
      'BL': 'Saint Barthélemy', 'MF': 'Saint Martin', 'SX': 'Sint Maarten', 'TC': 'Turks and Caicos Islands',
      'VI': 'U.S. Virgin Islands',
    };
    return names[countryCode] ?? 'Caribbean';
  }

  Future<void> _launchPhone(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: p);
    await _safeLaunch(uri);
  }

  Future<void> _launchEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: e);
    await _safeLaunch(uri);
  }

  Future<void> _launchWebsite(String website) async {
    final w = website.trim();
    if (w.isEmpty) return;
    Uri uri = w.startsWith('http') ? Uri.parse(w) : Uri.parse('https://$w');
    await _safeLaunch(uri);
  }

  Future<void> _launchUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    Uri uri = u.startsWith('http') ? Uri.parse(u) : Uri.parse('https://$u');
    await _safeLaunch(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final p = phone.trim();
    if (p.isEmpty) return;
    final cleanPhone = p.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone');
    await _safeLaunch(uri);
  }

  Future<void> _safeLaunch(Uri uri) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('_safeLaunch error: $e');
    }
  }
}

class _ContactHoursCard extends StatelessWidget {
  final ListingModel listing;
  final Color colorPrimary;
  final bool isDark;

  final VoidCallback onCall;
  final VoidCallback onEmail;
  final VoidCallback onWebsite;

  final VoidCallback onInstagram;
  final VoidCallback onFacebook;
  final VoidCallback onTiktok;
  final VoidCallback onWhatsapp;
  final VoidCallback onYoutube;
  final VoidCallback onX;

  const _ContactHoursCard({
    required this.listing,
    required this.colorPrimary,
    required this.isDark,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
    required this.onInstagram,
    required this.onFacebook,
    required this.onTiktok,
    required this.onWhatsapp,
    required this.onYoutube,
    required this.onX,
  });

  @override
  Widget build(BuildContext context) {
    final phone = listing.phone.trim();
    final email = listing.email.trim();
    final website = listing.website.trim();
    final hours = listing.openingHours.trim();
    final instagram = listing.instagram.trim();
    final facebook = listing.facebook.trim();
    final tiktok = listing.tiktok.trim();
    final whatsapp = listing.whatsapp.trim();
    final youtube = listing.youtube.trim();
    final x = listing.x.trim();

    final bg = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final border = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final muted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        children: [
          if (phone.isNotEmpty)
            _ActionRow(
              icon: Icons.call,
              title: 'Phone'.tr(),
              value: phone,
              onTap: onCall,
              accent: colorPrimary,
              muted: muted,
              isDark: isDark,
              showDivider: email.isNotEmpty || website.isNotEmpty || instagram.isNotEmpty || facebook.isNotEmpty || tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty || hours.isNotEmpty,
            ),
          if (email.isNotEmpty)
            _ActionRow(
              icon: Icons.email,
              title: 'Email'.tr(),
              value: email,
              onTap: onEmail,
              accent: colorPrimary,
              muted: muted,
              isDark: isDark,
              showDivider: website.isNotEmpty || instagram.isNotEmpty || facebook.isNotEmpty || tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty || hours.isNotEmpty,
            ),
          if (website.isNotEmpty)
            _ActionRow(
              icon: Icons.language,
              title: 'Website'.tr(),
              value: website,
              onTap: onWebsite,
              accent: colorPrimary,
              muted: muted,
              isDark: isDark,
              showDivider: instagram.isNotEmpty || facebook.isNotEmpty || tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty || hours.isNotEmpty,
            ),
          if (instagram.isNotEmpty || facebook.isNotEmpty || tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  iconTheme: IconThemeData(
                    color: isDark ? Colors.white : colorPrimary,
                  ),
                  unselectedWidgetColor: isDark ? Colors.white : colorPrimary,
                  expansionTileTheme: ExpansionTileThemeData(
                    iconColor: isDark ? Colors.white : colorPrimary,
                    collapsedIconColor: isDark ? Colors.white : colorPrimary,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
                  leading: SvgPicture.asset(
                    'assets/images/social.svg',
                    width: 22,
                    height: 22,
                  ),
                  title: Text(
                    'Social Media'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : colorPrimary,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                  children: [
                    if (instagram.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/instagram.svg',
                        title: 'Instagram',
                        value: '',
                        onTap: onInstagram,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: facebook.isNotEmpty || tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty,
                      ),
                    if (facebook.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/facebook.svg',
                        title: 'Facebook',
                        value: '',
                        onTap: onFacebook,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: tiktok.isNotEmpty || whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty,
                      ),
                    if (tiktok.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/tiktok.svg',
                        title: 'TikTok',
                        value: '',
                        onTap: onTiktok,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: whatsapp.isNotEmpty || youtube.isNotEmpty || x.isNotEmpty,
                      ),
                    if (whatsapp.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/whatsapp.svg',
                        title: 'WhatsApp',
                        value: '',
                        onTap: onWhatsapp,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: youtube.isNotEmpty || x.isNotEmpty,
                      ),
                    if (youtube.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/youtube.svg',
                        title: 'YouTube',
                        value: '',
                        onTap: onYoutube,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: x.isNotEmpty,
                      ),
                    if (x.isNotEmpty)
                      _ActionRow(
                        icon: 'assets/images/x.svg',
                        title: 'X (Twitter)',
                        value: '',
                        onTap: onX,
                        accent: colorPrimary,
                        muted: muted,
                        isDark: isDark,
                        showDivider: false,
                      ),
                  ],
                ),
              ),
            ),
          if (hours.isNotEmpty)
            _InfoRow(
              icon: Icons.access_time,
              title: 'Opening Hours'.tr(),
              value: hours,
              accent: colorPrimary,
              muted: muted,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final dynamic icon; 
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color accent;
  final Color muted;
  final bool isDark;
  final bool showDivider;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.accent,
    required this.muted,
    required this.isDark,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey.shade200 : Colors.black87,
    );

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                icon is IconData
                    ? Icon(icon, color: accent, size: 22)
                    : SvgPicture.asset(
                        icon,
                        width: 22,
                        height: 22,
                        colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : muted,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (value.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(value, style: valueStyle),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: muted, size: 20),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 0.5,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final Color muted;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.muted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      fontSize: 16,
      color: isDark ? Colors.grey.shade200 : Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewWidget extends StatelessWidget {
  final ListingReviewModel review;

  const ReviewWidget({Key? key, required this.review}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          leading: displayCircleImage(review.profilePictureURL, 40, false),
          title: Text(
            review.fullName(),
            style: TextStyle(
              fontSize: 17,
              color: isDark
                  ? Colors.grey.shade200
                  : Colors.grey.shade900,
            ),
          ),
          subtitle: Text(
            formatReviewTimestamp(review.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.grey.shade400
                  : Colors.grey.shade500,
            ),
          ),
          trailing: RatingBarIndicator(
            rating: review.starCount,
            itemBuilder: (context, index) => Icon(
              Icons.star,
              color: Color(cfg.colorPrimary),
            ),
            itemCount: 5,
            itemSize: 20.0,
            unratedColor: Color(cfg.colorPrimary).withOpacity(.3),
            direction: Axis.horizontal,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16, 8),
          child: Text(
            review.content,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        )
      ],
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
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = filter.value;
    List<String> valuesList = [];
    if (value is List) {
      valuesList = value.map((e) => e.toString()).toList();
    } else if (value is String && value.contains(',')) {
      valuesList = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else if (value != null && value.toString().isNotEmpty) {
      valuesList = [value.toString()];
    }

    final displayValue = valuesList.join(', ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  filter.key.toLowerCase() == 'condition' ? 'Condition' : filter.key,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: colorPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 0.5,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
      ],
    );
  }
}

class MediaItem {
  final String url;
  final bool isVideo;

  MediaItem({required this.url, required this.isVideo});

  factory MediaItem.photo(String url) {
    return MediaItem(url: url, isVideo: false);
  }

  factory MediaItem.video(String url) {
    return MediaItem(url: url, isVideo: true);
  }
}
