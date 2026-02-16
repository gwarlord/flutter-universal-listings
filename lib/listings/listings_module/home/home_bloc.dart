import 'package:bloc/bloc.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/home_filter_state.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_repository.dart';
import 'package:instaflutter/listings/utils/listing_filter_helpers.dart';

part 'home_event.dart';

part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ListingsUser currentUser;
  final ListingsRepository listingsRepository;
  final ProfileRepository profileRepository;
  List<ListingModel> listings = [];
  List<ListingModel?> listingsWithAds = [];
  HomeFilterState currentFilters = const HomeFilterState();

  HomeBloc({
    required this.currentUser,
    required this.listingsRepository,
    required this.profileRepository,
  }) : super(HomeInitial()) {
    on<GetCategoriesEvent>((event, emit) async {
      emit(LoadingCategoriesState());
      List<CategoriesModel> categories =
          await listingsRepository.getCategories();
      emit(CategoriesListState(categories: categories));
    });

    on<GetListingsEvent>((event, emit) async {
      emit(LoadingListingsState());
      listings = await listingsRepository.getListings(
          favListingsIDs: currentUser.likedListingsIDs);
      calculateAdLocation();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<ApplyFiltersEvent>((event, emit) async {
      currentFilters = event.filters;
      emit(LoadingListingsState());
      
      // Get all listings first
      final allListings = await listingsRepository.getListings(
          favListingsIDs: currentUser.likedListingsIDs);
      
      // Apply filters
      listings = _applyFiltersToListings(allListings, event.filters);
      calculateAdLocation();
      emit(FiltersAppliedState(
        listingsWithAds: listingsWithAds,
        filters: currentFilters,
      ));
    });

    on<ClearFiltersEvent>((event, emit) async {
      currentFilters = const HomeFilterState();
      emit(LoadingListingsState());
      listings = await listingsRepository.getListings(
          favListingsIDs: currentUser.likedListingsIDs);
      calculateAdLocation();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });

    on<GetListingsWithFiltersEvent>((event, emit) async {
      emit(LoadingListingsState());
      final allListings = await listingsRepository.getListings(
          favListingsIDs: currentUser.likedListingsIDs);
      listings = _applyFiltersToListings(allListings, event.filters);
      calculateAdLocation();
      emit(FiltersAppliedState(
        listingsWithAds: listingsWithAds,
        filters: event.filters,
      ));
    });

    on<ToggleShowAllEvent>((event, emit) => emit(ToggleShowAllState()));
    on<ListingDeletedByUserEvent>((event, emit) {
      listings.remove(event.listing);
      calculateAdLocation();
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
      calculateAdLocation();
      emit(ListingsListState(listingsWithAds: listingsWithAds));
    });
    on<LoadingEvent>((event, emit) => emit(LoadingState()));
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

  calculateAdLocation() {
    listingsWithAds.clear();
    for (int i = 0; i < listings.length; i++) {
      if ((listingsWithAds.length + 1) % 5 == 0) {
        listingsWithAds.add(null);
        listingsWithAds.add(listings[i]);
      } else {
        listingsWithAds.add(listings[i]);
      }
    }
  }
}
