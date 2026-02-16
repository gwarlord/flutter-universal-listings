import 'package:cloud_firestore/cloud_firestore.dart';

enum HomeSortOption {
  recommended,
  mostVouched,
  nearest,
  newest,
  aToZ,
  vouchCount,
}

/// Model to hold all home screen filter criteria
class HomeFilterState {
  // Country filter (existing)
  final List<String> selectedCountries;
  
  // Boolean filters
  final bool openNowOnly;
  final bool hasMiniStore;
  final bool hasRentals;
  final bool hasBooking;
  final bool hasDeals;
  
  // Fulfillment filters
  final bool supportsDelivery;
  final bool supportsPickup;
  final bool supportsDineIn;
  
  // Category filters
  final List<String> categoryIds;

  // Sort option
  final HomeSortOption sortOption;
  
  // Distance filter (in kilometers)
  final double? maxDistance;
  final GeoPoint? userLocation;
  
  // Price range filter (optional)
  final double? minPrice;
  final double? maxPrice;

  const HomeFilterState({
    this.selectedCountries = const [],
    this.openNowOnly = false,
    this.hasMiniStore = false,
    this.hasRentals = false,
    this.hasBooking = false,
    this.hasDeals = false,
    this.supportsDelivery = false,
    this.supportsPickup = false,
    this.supportsDineIn = false,
    this.categoryIds = const [],
    this.sortOption = HomeSortOption.recommended,
    this.maxDistance,
    this.userLocation,
    this.minPrice,
    this.maxPrice,
  });

  /// Check if any filters are active (excluding country)
  bool get hasActiveFilters {
    return openNowOnly ||
        hasMiniStore ||
        hasRentals ||
        hasBooking ||
        hasDeals ||
        supportsDelivery ||
        supportsPickup ||
        supportsDineIn ||
        categoryIds.isNotEmpty ||
        maxDistance != null ||
        minPrice != null ||
        maxPrice != null;
  }

  /// Count number of active filters
  int get activeFilterCount {
    int count = 0;
    if (openNowOnly) count++;
    if (hasMiniStore) count++;
    if (hasRentals) count++;
    if (hasBooking) count++;
    if (hasDeals) count++;
    if (supportsDelivery) count++;
    if (supportsPickup) count++;
    if (supportsDineIn) count++;
    if (categoryIds.isNotEmpty) count++;
    if (maxDistance != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    return count;
  }

  HomeFilterState copyWith({
    List<String>? selectedCountries,
    bool? openNowOnly,
    bool? hasMiniStore,
    bool? hasRentals,
    bool? hasBooking,
    bool? hasDeals,
    bool? supportsDelivery,
    bool? supportsPickup,
    bool? supportsDineIn,
    List<String>? categoryIds,
    bool clearCategories = false,
    HomeSortOption? sortOption,
    double? maxDistance,
    bool clearMaxDistance = false,
    GeoPoint? userLocation,
    bool clearUserLocation = false,
    double? minPrice,
    double? maxPrice,
    bool clearPriceRange = false,
  }) {
    return HomeFilterState(
      selectedCountries: selectedCountries ?? this.selectedCountries,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      hasMiniStore: hasMiniStore ?? this.hasMiniStore,
      hasRentals: hasRentals ?? this.hasRentals,
      hasBooking: hasBooking ?? this.hasBooking,
      hasDeals: hasDeals ?? this.hasDeals,
      supportsDelivery: supportsDelivery ?? this.supportsDelivery,
      supportsPickup: supportsPickup ?? this.supportsPickup,
      supportsDineIn: supportsDineIn ?? this.supportsDineIn,
      categoryIds: clearCategories ? const [] : (categoryIds ?? this.categoryIds),
      sortOption: sortOption ?? this.sortOption,
      maxDistance: clearMaxDistance ? null : (maxDistance ?? this.maxDistance),
      userLocation: clearUserLocation ? null : (userLocation ?? this.userLocation),
      minPrice: clearPriceRange ? null : (minPrice ?? this.minPrice),
      maxPrice: clearPriceRange ? null : (maxPrice ?? this.maxPrice),
    );
  }

  /// Clear all filters
  HomeFilterState clearAll() {
    return const HomeFilterState();
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'selectedCountries': selectedCountries,
      'openNowOnly': openNowOnly,
      'hasMiniStore': hasMiniStore,
      'hasRentals': hasRentals,
      'hasBooking': hasBooking,
      'hasDeals': hasDeals,
      'supportsDelivery': supportsDelivery,
      'supportsPickup': supportsPickup,
      'supportsDineIn': supportsDineIn,
      'categoryIds': categoryIds,
        'sortOption': sortOption.name,
      'maxDistance': maxDistance,
      'userLocation': userLocation != null
          ? {'latitude': userLocation!.latitude, 'longitude': userLocation!.longitude}
          : null,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
    };
  }

  /// Create from JSON for restoration
  factory HomeFilterState.fromJson(Map<String, dynamic> json) {
    GeoPoint? location;
    if (json['userLocation'] != null) {
      final loc = json['userLocation'] as Map<String, dynamic>;
      location = GeoPoint(loc['latitude'], loc['longitude']);
    }

    final sortRaw = json['sortOption']?.toString();
    final parsedSort = HomeSortOption.values.firstWhere(
      (option) => option.name == sortRaw,
      orElse: () => HomeSortOption.recommended,
    );

    return HomeFilterState(
      selectedCountries: List<String>.from(json['selectedCountries'] ?? []),
      openNowOnly: json['openNowOnly'] ?? false,
      hasMiniStore: json['hasMiniStore'] ?? false,
      hasRentals: json['hasRentals'] ?? false,
      hasBooking: json['hasBooking'] ?? false,
      hasDeals: json['hasDeals'] ?? false,
      supportsDelivery: json['supportsDelivery'] ?? false,
      supportsPickup: json['supportsPickup'] ?? false,
      supportsDineIn: json['supportsDineIn'] ?? false,
      categoryIds: List<String>.from(json['categoryIds'] ?? []),
      sortOption: parsedSort,
      maxDistance: json['maxDistance']?.toDouble(),
      userLocation: location,
      minPrice: json['minPrice']?.toDouble(),
      maxPrice: json['maxPrice']?.toDouble(),
    );
  }
}
