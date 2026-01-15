import 'dart:async';
import 'dart:io';

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
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/add_review/add_review_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_bloc.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

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

  GoogleMapController? _mapController;
  late LatLng _placeLocation;
  final Future _mapFuture = Future.delayed(Duration.zero, () => true);

  late ListingsUser currentUser;
  bool isLoadingReviews = true;

  List<ListingReviewModel> reviews = [];

  bool get _canEditOrDelete =>
      currentUser.userID == listing.authorID || currentUser.isAdmin;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    listing = widget.listing;
    _placeLocation = LatLng(listing.latitude, listing.longitude);

    context.read<ListingDetailsBloc>().add(GetListingReviewsEvent());

    if (listing.photos.length > 1) {
      _autoScroll = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
        if (_pageIndex < listing.photos.length - 1) {
          _pageIndex++;
        } else {
          _pageIndex = 0;
        }
        _pagerController.animateToPage(
          _pageIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

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
                  colorAccent: Color(colorAccent),
                  colorPrimary: Color(colorPrimary),
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(listing.title),
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
                                ? Color(colorPrimary)
                                : dark
                                ? Colors.white
                                : null,
                          ),
                          title: Text(
                            listing.isFav
                                ? 'Remove From Favorites'.tr()
                                : 'Add To Favorites'.tr(),
                            style: const TextStyle(fontSize: 18),
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
                              color: dark ? Colors.white : null,
                            ),
                            title: Text(
                              'Edit Listing'.tr(),
                              style: const TextStyle(fontSize: 18),
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
                              if (updated == true) {
                                if (!mounted) return;
                                setState(() {});
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
                              color: dark ? Colors.white : null,
                            ),
                            title: Text(
                              'Add Review'.tr(),
                              style: const TextStyle(fontSize: 18),
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
                              color: dark ? Colors.white : null,
                            ),
                            title: Text(
                              'Send Message'.tr(),
                              style: const TextStyle(fontSize: 18),
                            ),
                            onTap: () {
                              Navigator.pop(context);
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
                              style: const TextStyle(fontSize: 18),
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
                // الصور
                if (listing.photos.isNotEmpty)
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 3,
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (listing.photos.length > 1) {
                              push(
                                context,
                                FullScreenImageViewer(
                                  galleryImagesList: [...listing.photos],
                                  index: _pageIndex,
                                  imageUrl: '',
                                ),
                              );
                            } else {
                              push(
                                context,
                                FullScreenImageViewer(
                                  imageUrl: listing.photos.first,
                                ),
                              );
                            }
                          },
                          child: PageView.builder(
                            controller: _pagerController,
                            itemCount: listing.photos.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) =>
                                displayImage(listing.photos[index]),
                          ),
                        ),
                        if (listing.photos.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SmoothPageIndicator(
                                effect: ColorTransitionEffect(
                                  activeDotColor: Color(colorPrimary),
                                  dotHeight: 8,
                                  dotWidth: 8,
                                  dotColor: Colors.grey.shade300,
                                ),
                                controller: _pagerController,
                                count: listing.photos.length,
                              ),
                            ),
                          )
                      ],
                    ),
                  ),

                // ===== Title + Price (overflow safe) =====
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          listing.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.grey.shade200 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          listing.price,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.grey.shade200 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== Description (readable container) =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.black.withOpacity(0.25)
                          : Colors.white.withOpacity(0.90),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dark
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      listing.description,
                      style: TextStyle(
                        height: 1.45,
                        fontSize: 15,
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),

                // NEW: Contact & Hours
                if (_hasContactOrHours(listing)) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16, 16, 0),
                    child: Text(
                      'Contact & Hours'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ContactHoursCard(
                      listing: listing,
                      colorPrimary: Color(colorPrimary),
                      isDark: dark,
                      onCall: () => _launchPhone(listing.phone),
                      onEmail: () => _launchEmail(listing.email),
                      onWebsite: () => _launchWebsite(listing.website),
                    ),
                  ),
                ],

                // Location
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16, 0),
                  child: Text(
                    'Location'.tr(),
                    style: TextStyle(
                      fontSize: 19,
                      color: dark ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                ),

                Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                  child: Text(
                    listing.place,
                    style: TextStyle(
                      fontSize: 15,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),

                // ===== Map (smaller height) =====
                SizedBox(
                  height: 220,
                  child: FutureBuilder(
                    future: _mapFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator.adaptive(),
                        );
                      }
                      return GoogleMap(
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

                // Extra info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 20, 16, 16),
                  child: Text(
                    'Extra info'.tr(),
                    style: TextStyle(
                      fontSize: 19,
                      color: dark ? Colors.grey.shade200 : Colors.black87,
                    ),
                  ),
                ),

                ListView.builder(
                  itemCount: listing.filters.entries.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) => FilterDetailsWidget(
                    filter: listing.filters.entries.elementAt(index),
                  ),
                ),

                // Reviews
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16, 16, 0),
                  child: Text(
                    'Reviews'.tr(),
                    style: TextStyle(
                      fontSize: 19,
                      color: dark ? Colors.grey.shade200 : Colors.black87,
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
                          colorPrimary: Color(colorPrimary),
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
    _pagerController.dispose();
    _mapController?.dispose();
    super.dispose();
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
                  Color(colorPrimary),
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
                  Color(colorPrimary),
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
    return phone.isNotEmpty ||
        email.isNotEmpty ||
        website.isNotEmpty ||
        hours.isNotEmpty;
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

    Uri uri;
    if (w.startsWith('http://') || w.startsWith('https://')) {
      uri = Uri.parse(w);
    } else {
      uri = Uri.parse('https://$w');
    }
    await _safeLaunch(uri);
  }

  Future<void> _safeLaunch(Uri uri) async {
    try {
      final ok = await canLaunchUrl(uri);
      if (!ok) {
        debugPrint('Could not launch: $uri');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      debugPrint('_safeLaunch error: $e');
      debugPrint('$st');
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

  const _ContactHoursCard({
    required this.listing,
    required this.colorPrimary,
    required this.isDark,
    required this.onCall,
    required this.onEmail,
    required this.onWebsite,
  });

  @override
  Widget build(BuildContext context) {
    final phone = listing.phone.trim();
    final email = listing.email.trim();
    final website = listing.website.trim();
    final hours = listing.openingHours.trim();

    final bg = isDark ? Colors.grey.shade900 : Colors.white;
    final border = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final muted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
        ],
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
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color accent;
  final Color muted;
  final bool isDark;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
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
            Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
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
              color: isDarkMode(context)
                  ? Colors.grey.shade200
                  : Colors.grey.shade900,
            ),
          ),
          subtitle: Text(
            formatReviewTimestamp(review.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode(context)
                  ? Colors.grey.shade400
                  : Colors.grey.shade500,
            ),
          ),
          trailing: RatingBar.builder(
            onRatingUpdate: (_) {},
            ignoreGestures: true,
            glow: false,
            itemCount: 5,
            allowHalfRating: true,
            itemSize: 20,
            unratedColor: Color(colorPrimary).withOpacity(.5),
            initialRating: review.starCount,
            itemBuilder: (context, index) =>
                Icon(Icons.star, color: Color(colorPrimary)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16, 8),
          child: Text(review.content),
        )
      ],
    );
  }
}

class FilterDetailsWidget extends StatelessWidget {
  final MapEntry<String, dynamic> filter;

  const FilterDetailsWidget({super.key, required this.filter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              filter.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              '${filter.value}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
