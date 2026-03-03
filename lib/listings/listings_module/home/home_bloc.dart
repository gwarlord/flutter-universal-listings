import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/feed_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/home_filter_state.dart';
import 'package:caribtap/listings/listings_module/api/firebase/events_firebase.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/ui/profile/api/profile_repository.dart';
import 'package:caribtap/listings/utils/listing_filter_helpers.dart';

part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ListingsUser currentUser;
  final ListingsRepository listingsRepository;
  final ProfileRepository profileRepository;
  final EventsFirebaseUtils eventsRepository;
  List<ListingModel> listings = [];
  List<FeedItem> feedItems = [];
  List<FeedItem?> listingsWithAds = [];
  HomeFilterState currentFilters = const HomeFilterState();

  HomeBloc({
    required this.currentUser,
    required this.listingsRepository,
    required this.profileRepository,
    EventsFirebaseUtils? eventsRepository,
  })  : eventsRepository = eventsRepository ?? EventsFirebaseUtils(),
        super(HomeInitial()) {
    on<GetCategoriesEvent>((event, emit) async {
      emit(LoadingCategoriesState());
      List<CategoriesModel> categories =
          await listingsRepository.getCategories();
      emit(CategoriesListState(categories: categories));
    });

    on<GetListingsEvent>((event, emit) async {
      emit(LoadingListingsState());
      await _loadUnifiedFeed(filters: currentFilters, includeFiltering: false);
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<ApplyFiltersEvent>((event, emit) async {
      currentFilters = event.filters;
      emit(LoadingListingsState());

      await _loadUnifiedFeed(filters: event.filters, includeFiltering: true);
      emit(FiltersAppliedState(
        listingsWithAds: listingsWithAds,
        filters: currentFilters,
      ));
    });

    on<ClearFiltersEvent>((event, emit) async {
      currentFilters = const HomeFilterState();
      emit(LoadingListingsState());
      await _loadUnifiedFeed(filters: currentFilters, includeFiltering: false);
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<GetListingsWithFiltersEvent>((event, emit) async {
      emit(LoadingListingsState());
      await _loadUnifiedFeed(filters: event.filters, includeFiltering: true);
      emit(FiltersAppliedState(
        listingsWithAds: listingsWithAds,
        filters: event.filters,
      ));
    });

    on<ToggleShowAllEvent>((event, emit) => emit(ToggleShowAllState()));
    on<ListingDeletedByUserEvent>((event, emit) {
      listings.remove(event.listing);
      feedItems.removeWhere(
        (item) => item.type == FeedItemType.listing && item.listing?.id == event.listing.id,
      );
      _calculateAdLocationFromFeed();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });
    on<ListingFavUpdated>((event, emit) async {
      event.listing.isFav = !event.listing.isFav;
      listings.firstWhere((element) => element.id == event.listing.id).isFav =
          event.listing.isFav;
      if (event.listing.isFav) {
        currentUser.likedListingsIDs.add(event.listing.id);
      } else {
        currentUser.likedListingsIDs.remove(event.listing.id);
      }
      await profileRepository.updateCurrentUser(currentUser);
      emit(ListingFavToggleState(
        listing: event.listing,
        updatedUser: currentUser,
      ));
    });
    on<ListingDeleteByAdminEvent>((event, emit) async {
      await listingsRepository.deleteListing(listingModel: event.listing);
      listings.remove(event.listing);
      feedItems.removeWhere(
        (item) => item.type == FeedItemType.listing && item.listing?.id == event.listing.id,
      );
      _calculateAdLocationFromFeed();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<EventDeleteEvent>((event, emit) async {
      // Use this.eventsRepository because the constructor parameter shadows the field
      await this.eventsRepository.deleteEvent(event.event.id);
      feedItems.removeWhere(
        (item) => item.type == FeedItemType.event && item.event?.id == event.event.id,
      );
      _calculateAdLocationFromFeed();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }

  Future<void> _loadUnifiedFeed({
    required HomeFilterState filters,
    required bool includeFiltering,
  }) async {
    final futures = await Future.wait<dynamic>([
      listingsRepository.getListings(
        favListingsIDs: currentUser.likedListingsIDs,
      ),
      _getFilteredEvents(filters),
    ]);

    final allListings = futures[0] as List<ListingModel>;
    final events = futures[1] as List<EventModel>;

    final sortedListings = includeFiltering
        ? _applyFiltersToListings(allListings, filters)
        : _sortListings(allListings, filters);
    listings = sortedListings;

    feedItems = _mergeAndSortFeed(
      listings: sortedListings,
      events: events,
      filters: filters,
    );

    _calculateAdLocationFromFeed();
  }

  Future<List<EventModel>> _getFilteredEvents(HomeFilterState filters) async {
    if (!filters.includeEvents) {
      return <EventModel>[];
    }

    try {
      final allEvents = await eventsRepository.getEvents();
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final filtered = allEvents.where((event) {
        if (event.status.toLowerCase() != 'active') {
          return false;
        }
        if (event.endAtSeconds < nowSeconds) {
          return false;
        }
        if (filters.selectedCountries.isNotEmpty &&
            !filters.selectedCountries.contains(event.countryCode)) {
          return false;
        }
        if (filters.maxDistance != null && filters.userLocation != null) {
          final distance = ListingFilterHelpers.calculateDistance(
            filters.userLocation!.latitude,
            filters.userLocation!.longitude,
            event.latitude,
            event.longitude,
          );
          if (distance > filters.maxDistance!) {
            return false;
          }
        }
        return true;
      }).toList();

      filtered.sort((a, b) => b.startAtSeconds.compareTo(a.startAtSeconds));
      return filtered;
    } catch (_) {
      return <EventModel>[];
    }
  }

  List<FeedItem> _mergeAndSortFeed({
    required List<ListingModel> listings,
    required List<EventModel> events,
    required HomeFilterState filters,
  }) {
    final sortedListings = _sortListings([...listings], filters);
    final sortedEvents = _sortEvents([...events], filters);

    final listingRank = <String, int>{};
    for (int i = 0; i < sortedListings.length; i++) {
      listingRank[sortedListings[i].id] = i;
    }

    final merged = <FeedItem>[
      ...sortedListings.map(FeedItem.listing),
      ...sortedEvents.map(FeedItem.event),
    ];

    merged.sort((a, b) => _compareFeedItems(a, b, filters, listingRank));
    return merged;
  }

  List<EventModel> _sortEvents(List<EventModel> events, HomeFilterState filters) {
    switch (filters.sortOption) {
      case HomeSortOption.aToZ:
        events.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return events;
      case HomeSortOption.nearest:
        if (filters.userLocation == null) {
          return events;
        }
        events.sort((a, b) {
          final distanceA = ListingFilterHelpers.calculateDistance(
            filters.userLocation!.latitude,
            filters.userLocation!.longitude,
            a.latitude,
            a.longitude,
          );
          final distanceB = ListingFilterHelpers.calculateDistance(
            filters.userLocation!.latitude,
            filters.userLocation!.longitude,
            b.latitude,
            b.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
        return events;
      case HomeSortOption.newest:
      case HomeSortOption.mostVouched:
      case HomeSortOption.vouchCount:
      case HomeSortOption.recommended:
        events.sort((a, b) => b.startAtSeconds.compareTo(a.startAtSeconds));
        return events;
    }
  }

  int _compareFeedItems(
    FeedItem a,
    FeedItem b,
    HomeFilterState filters,
    Map<String, int> listingRank,
  ) {
    if (a.type == FeedItemType.listing && b.type == FeedItemType.listing) {
      final rankA = listingRank[a.listing!.id] ?? 0;
      final rankB = listingRank[b.listing!.id] ?? 0;
      return rankA.compareTo(rankB);
    }

    if (a.type == FeedItemType.event && b.type == FeedItemType.event) {
      return _compareEvents(a.event!, b.event!, filters);
    }

    switch (filters.sortOption) {
      case HomeSortOption.aToZ:
        final titleA = a.type == FeedItemType.listing
            ? a.listing!.title.toLowerCase()
            : a.event!.title.toLowerCase();
        final titleB = b.type == FeedItemType.listing
            ? b.listing!.title.toLowerCase()
            : b.event!.title.toLowerCase();
        return titleA.compareTo(titleB);
      case HomeSortOption.nearest:
        final distanceA = _feedDistance(a, filters);
        final distanceB = _feedDistance(b, filters);
        return distanceA.compareTo(distanceB);
      case HomeSortOption.newest:
      case HomeSortOption.mostVouched:
      case HomeSortOption.vouchCount:
      case HomeSortOption.recommended:
        return _feedRecencySeconds(b).compareTo(_feedRecencySeconds(a));
    }
  }

  int _compareEvents(EventModel a, EventModel b, HomeFilterState filters) {
    switch (filters.sortOption) {
      case HomeSortOption.aToZ:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case HomeSortOption.nearest:
        if (filters.userLocation == null) {
          return 0;
        }
        final distanceA = ListingFilterHelpers.calculateDistance(
          filters.userLocation!.latitude,
          filters.userLocation!.longitude,
          a.latitude,
          a.longitude,
        );
        final distanceB = ListingFilterHelpers.calculateDistance(
          filters.userLocation!.latitude,
          filters.userLocation!.longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      case HomeSortOption.newest:
      case HomeSortOption.mostVouched:
      case HomeSortOption.vouchCount:
      case HomeSortOption.recommended:
        return b.startAtSeconds.compareTo(a.startAtSeconds);
    }
  }

  double _feedDistance(FeedItem item, HomeFilterState filters) {
    if (filters.userLocation == null) {
      return double.infinity;
    }

    if (item.type == FeedItemType.listing) {
      return ListingFilterHelpers.calculateDistance(
        filters.userLocation!.latitude,
        filters.userLocation!.longitude,
        item.listing!.latitude,
        item.listing!.longitude,
      );
    }

    return ListingFilterHelpers.calculateDistance(
      filters.userLocation!.latitude,
      filters.userLocation!.longitude,
      item.event!.latitude,
      item.event!.longitude,
    );
  }

  int _feedRecencySeconds(FeedItem item) {
    if (item.type == FeedItemType.listing) {
      return _recencySeconds(item.listing!);
    }
    return item.event!.startAtSeconds;
  }

  /// Apply filter criteria to a list of listings
  List<ListingModel> _applyFiltersToListings(
    List<ListingModel> allListings,
    HomeFilterState filters,
  ) {
    final filtered = allListings.where((listing) {
      // Country filter
      if (filters.selectedCountries.isNotEmpty &&
          !filters.selectedCountries.contains(listing.countryCode)) {
        return false;
      }

      // Open now filter (client-side)
      if (filters.openNowOnly && !ListingFilterHelpers.isOpenNow(listing)) {
        return false;
      }

      // Mini Store filter
      if (filters.hasMiniStore && !listing.storeEnabled) {
        return false;
      }

      // Rentals filter
      if (filters.hasRentals && listing.rentalConfig == null) {
        return false;
      }

      // Booking filter
      if (filters.hasBooking && !listing.bookingEnabled) {
        return false;
      }

      // Deals filter - check if listing has menu or services (common deal scenarios)
      if (filters.hasDeals && !listing.menuEnabled && !listing.storeEnabled) {
        return false;
      }

      // Delivery filter
      if (filters.supportsDelivery && !listing.storeDeliveryEnabled) {
        return false;
      }

      // Pickup filter
      if (filters.supportsPickup && !listing.storePickupEnabled) {
        return false;
      }

      // Dine-in filter
      if (filters.supportsDineIn && !listing.storeDineInEnabled) {
        return false;
      }

      // Category filter
      if (filters.categoryIds.isNotEmpty &&
          !filters.categoryIds.contains(listing.categoryID)) {
        return false;
      }

      // Distance filter
      if (filters.maxDistance != null && filters.userLocation != null) {
        final distance = ListingFilterHelpers.calculateDistance(
          filters.userLocation!.latitude,
          filters.userLocation!.longitude,
          listing.latitude,
          listing.longitude,
        );
        if (distance > filters.maxDistance!) {
          return false;
        }
      }

      // Price range filter (parse string price)
      if (filters.minPrice != null || filters.maxPrice != null) {
        final priceStr = listing.price.trim();
        if (priceStr.isNotEmpty && priceStr != '0') {
          try {
            // Try to parse the price, removing currency symbols
            final cleanPrice = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
            final price = double.tryParse(cleanPrice);
            if (price != null) {
              if (filters.minPrice != null && price < filters.minPrice!) {
                return false;
              }
              if (filters.maxPrice != null && price > filters.maxPrice!) {
                return false;
              }
            }
          } catch (e) {
            // If price parsing fails, don't filter out
          }
        }
      }

      return true;
    }).toList();

    return _sortListings(filtered, filters);
  }

  List<ListingModel> _sortListings(
    List<ListingModel> listings,
    HomeFilterState filters,
  ) {
    if (listings.length < 2) {
      return listings;
    }

    switch (filters.sortOption) {
      case HomeSortOption.mostVouched:
      case HomeSortOption.vouchCount:
        listings.sort((a, b) => b.tapCount.compareTo(a.tapCount));
        return listings;
      case HomeSortOption.nearest:
        if (filters.userLocation == null) {
          return listings;
        }
        listings.sort((a, b) {
          final distanceA = ListingFilterHelpers.calculateDistance(
            filters.userLocation!.latitude,
            filters.userLocation!.longitude,
            a.latitude,
            a.longitude,
          );
          final distanceB = ListingFilterHelpers.calculateDistance(
            filters.userLocation!.latitude,
            filters.userLocation!.longitude,
            b.latitude,
            b.longitude,
          );
          return distanceA.compareTo(distanceB);
        });
        return listings;
      case HomeSortOption.newest:
        listings.sort((a, b) => _recencySeconds(b).compareTo(_recencySeconds(a)));
        return listings;
      case HomeSortOption.aToZ:
        listings.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        return listings;
      case HomeSortOption.recommended:
        return _sortRecommended(listings, filters);
    }
  }

  int _recencySeconds(ListingModel listing) {
    return listing.freshness.lastRefreshedAt.seconds;
  }

  List<ListingModel> _sortRecommended(
    List<ListingModel> listings,
    HomeFilterState filters,
  ) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    double maxTapCount = 0;
    double maxAgeDays = 0;
    double maxDistance = 0;

    for (final listing in listings) {
      if (listing.tapCount > maxTapCount) {
        maxTapCount = listing.tapCount.toDouble();
      }

      final ageDays = (nowSeconds - _recencySeconds(listing)) / 86400;
      if (ageDays > maxAgeDays) {
        maxAgeDays = ageDays;
      }

      if (filters.userLocation != null) {
        final distance = ListingFilterHelpers.calculateDistance(
          filters.userLocation!.latitude,
          filters.userLocation!.longitude,
          listing.latitude,
          listing.longitude,
        );
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }

    final hasProximity = filters.userLocation != null && maxDistance > 0;
    double vouchWeight = 0.45;
    double recencyWeight = 0.35;
    double proximityWeight = 0.15;
    const double openWeight = 0.05;

    if (!hasProximity) {
      recencyWeight += proximityWeight;
      proximityWeight = 0;
    }

    listings.sort((a, b) {
      final scoreA = _recommendedScore(
        listing: a,
        nowSeconds: nowSeconds,
        maxTapCount: maxTapCount,
        maxAgeDays: maxAgeDays,
        maxDistance: maxDistance,
        filters: filters,
        vouchWeight: vouchWeight,
        recencyWeight: recencyWeight,
        proximityWeight: proximityWeight,
        openWeight: openWeight,
      );
      final scoreB = _recommendedScore(
        listing: b,
        nowSeconds: nowSeconds,
        maxTapCount: maxTapCount,
        maxAgeDays: maxAgeDays,
        maxDistance: maxDistance,
        filters: filters,
        vouchWeight: vouchWeight,
        recencyWeight: recencyWeight,
        proximityWeight: proximityWeight,
        openWeight: openWeight,
      );
      return scoreB.compareTo(scoreA);
    });

    return listings;
  }

  double _recommendedScore({
    required ListingModel listing,
    required int nowSeconds,
    required double maxTapCount,
    required double maxAgeDays,
    required double maxDistance,
    required HomeFilterState filters,
    required double vouchWeight,
    required double recencyWeight,
    required double proximityWeight,
    required double openWeight,
  }) {
    final vouchScore = maxTapCount > 0
        ? (listing.tapCount / maxTapCount).clamp(0, 1).toDouble()
        : 0.0;

    final ageDays = (nowSeconds - _recencySeconds(listing)) / 86400;
    final recencyScore = maxAgeDays > 0
        ? (1 - (ageDays / maxAgeDays)).clamp(0, 1).toDouble()
        : 1.0;

    double proximityScore = 0.0;
    if (filters.userLocation != null && maxDistance > 0) {
      final distance = ListingFilterHelpers.calculateDistance(
        filters.userLocation!.latitude,
        filters.userLocation!.longitude,
        listing.latitude,
        listing.longitude,
      );
      proximityScore = (1 - (distance / maxDistance)).clamp(0, 1).toDouble();
    }

    final openBoost = ListingFilterHelpers.isOpenNow(listing) ? openWeight : 0.0;

    return (vouchScore * vouchWeight) +
        (recencyScore * recencyWeight) +
        (proximityScore * proximityWeight) +
        openBoost;
  }

  void _calculateAdLocationFromFeed() {
    listingsWithAds.clear();
    for (int i = 0; i < feedItems.length; i++) {
      if ((listingsWithAds.length + 1) % 5 == 0) {
        listingsWithAds.add(null);
        listingsWithAds.add(feedItems[i]);
      } else {
        listingsWithAds.add(feedItems[i]);
      }
    }
  }
}
