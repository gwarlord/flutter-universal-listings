import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/favorite_listings/favorite_listings_bloc.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class FavoriteListingsWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const FavoriteListingsWrapperWidget({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final authUser = context.read<AuthenticationBloc>().user;
    final effectiveUser = authUser ?? currentUser;

    return BlocProvider(
      create: (context) => FavoriteListingsBloc(
        profileRepository: profileApiManager,
        currentUser: effectiveUser,
        listingsRepository: listingApiManager,
      ),
      child: FavoriteListingScreen(currentUser: effectiveUser),
    );
  }
}

class FavoriteListingScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const FavoriteListingScreen({super.key, required this.currentUser});

  @override
  State<FavoriteListingScreen> createState() => _FavoriteListingScreenState();
}

class _FavoriteListingScreenState extends State<FavoriteListingScreen> {
  List<ListingModel> favorites = [];
  List<EventModel> favoriteEvents = [];
  late ListingsUser currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    context.read<FavoriteListingsBloc>().add(GetMyFavoriteListings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Favorites'.tr(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<FavoriteListingsBloc>().add(LoadingEvent());
          context.read<FavoriteListingsBloc>().add(GetMyFavoriteListings());
        },
        child: BlocConsumer<FavoriteListingsBloc, FavoriteListingsState>(
          listener: (context, state) {
            if (state is FavoriteListingsReadyState) {
              isLoading = false;
              favorites = state.favorites;
              favoriteEvents = state.favoriteEvents;
            } else if (state is ListingFavToggleState) {
              currentUser = state.updatedUser;
              context.read<AuthenticationBloc>().user = state.updatedUser;
              if (!state.listing.isFav) {
                favorites.removeWhere((element) => element.id == state.listing.id);
              } else {
                favorites
                    .firstWhere((element) => element.id == state.listing.id)
                    .isFav = state.listing.isFav;
              }
            } else if (state is EventFavToggleState) {
              currentUser = state.updatedUser;
              context.read<AuthenticationBloc>().user = state.updatedUser;
              if (!state.event.isFav) {
                favoriteEvents
                    .removeWhere((element) => element.id == state.event.id);
              }
            } else if (state is LoadingState) {
              isLoading = true;
            }
          },
          builder: (context, state) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            // Filter out listings created by the current user
            final filteredFavorites = favorites.where((listing) => listing.authorID != currentUser.userID).toList();
            final filteredFavoriteEvents = favoriteEvents;
            if (filteredFavorites.isEmpty && filteredFavoriteEvents.isEmpty) {
              return Stack(
                children: [
                  ListView(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: showEmptyState(
                        'No Favorites'.tr(),
                        'All your favorite listings will show up here once you click the ❤ button.'
                            .tr(),
                        isDarkMode: isDarkMode(context)),
                  ),
                ],
              );
            } else {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (filteredFavorites.isNotEmpty) ...[
                    Text(
                      'Listings'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 16),
                      itemCount: filteredFavorites.length,
                      itemBuilder: (context, index) => FavoriteListingCard(
                        listing: filteredFavorites[index],
                        currentUser: currentUser,
                      ),
                    ),
                  ],
                  if (filteredFavoriteEvents.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Events'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...filteredFavoriteEvents.map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FavoriteEventCard(
                          event: event,
                          currentUser: currentUser,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }
          },
        ),
      ),
    );
  }
}

class FavoriteEventCard extends StatelessWidget {
  final EventModel event;
  final ListingsUser currentUser;

  const FavoriteEventCard({
    super.key,
    required this.event,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await push(context, EventDetailsScreen(event: event));
        if (!context.mounted) return;

        final updatedUser = context.read<AuthenticationBloc>().user;
        if (updatedUser != null &&
            !updatedUser.likedEventsIDs.contains(event.id) &&
            event.isFav) {
          context.read<FavoriteListingsBloc>().add(EventFavUpdated(event: event));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: event.posterImageUrl.trim().isEmpty
                  ? Container(
                      width: 72,
                      height: 72,
                      color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: Icon(
                        Icons.event,
                        color: Color(colorPrimary),
                      ),
                    )
                  : Image.network(
                      event.posterImageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.venueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove From Favorites'.tr(),
              icon: Icon(Icons.favorite, color: Color(colorPrimary)),
              onPressed: () => context
                  .read<FavoriteListingsBloc>()
                  .add(EventFavUpdated(event: event)),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoriteListingCard extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const FavoriteListingCard(
      {super.key, required this.listing, required this.currentUser});

  @override
  State<FavoriteListingCard> createState() => _FavoriteListingCardState();
}

class _FavoriteListingCardState extends State<FavoriteListingCard> {
  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    return GestureDetector(
      onTap: () async {
        bool? isListingDeleted = await push(
            context,
            ListingDetailsWrappingWidget(
                listing: widget.listing, currentUser: widget.currentUser));
        if (isListingDeleted != null && isListingDeleted) {
          if (!mounted) return;
          context
              .read<FavoriteListingsBloc>()
              .add(ListingDeletedByUserEvent(listing: widget.listing));
        }
        if (!widget.listing.isFav) {
          if (!mounted) return;
          context
              .read<FavoriteListingsBloc>()
            .add(ListingDeletedByUserEvent(listing: widget.listing));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: displayImage(widget.listing.photo),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Remove From Favorites'.tr(),
                    icon: Icon(
                      Icons.favorite,
                      color: Color(colorPrimary),
                    ),
                    onPressed: () => context
                        .read<FavoriteListingsBloc>()
                        .add(ListingFavUpdated(listing: widget.listing)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.listing.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 16,
                color: dark ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              widget.listing.place, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: dark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          RatingBar.builder(
            ignoreGestures: true,
            minRating: .5,
            initialRating: widget.listing.reviewsSum != 0
                ? widget.listing.reviewsSum / widget.listing.reviewsCount
                : 0,
            allowHalfRating: true,
            itemSize: 18,
            glow: false,
            unratedColor: Color(colorPrimary).withOpacity(0.3),
            itemBuilder: (context, index) =>
                Icon(Icons.star, color: Color(colorPrimary)),
            itemCount: 5,
            onRatingUpdate: (newValue) {},
          )
        ],
      ),
    );
  }
}
