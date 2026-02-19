import 'package:equatable/equatable.dart';

/// Location filter for search queries
class LocationFilter extends Equatable {
  final String? place;
  final bool useUserLocation;
  final double? radius;
  final double? latitude;
  final double? longitude;

  const LocationFilter({
    this.place,
    this.useUserLocation = false,
    this.radius,
    this.latitude,
    this.longitude,
  });

  factory LocationFilter.fromJson(Map<String, dynamic> json) {
    return LocationFilter(
      place: json['place'] as String?,
      useUserLocation: json['useUserLocation'] as bool? ?? false,
      radius: (json['radius'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (place != null) 'place': place,
      'useUserLocation': useUserLocation,
      if (radius != null) 'radius': radius,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  LocationFilter copyWith({
    String? place,
    bool? useUserLocation,
    double? radius,
    double? latitude,
    double? longitude,
  }) {
    return LocationFilter(
      place: place ?? this.place,
      useUserLocation: useUserLocation ?? this.useUserLocation,
      radius: radius ?? this.radius,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  List<Object?> get props => [place, useUserLocation, radius, latitude, longitude];
}

/// Price range filter
class PriceRange extends Equatable {
  final double? min;
  final double? max;

  const PriceRange({this.min, this.max});

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (min != null) 'min': min,
      if (max != null) 'max': max,
    };
  }

  @override
  List<Object?> get props => [min, max];
}

/// Search filters container
class SearchFilters extends Equatable {
  final String? category;
  final LocationFilter location;
  final PriceRange? priceRange;
  final bool? openNow;
  final bool? delivery;
  final bool? booking;
  final bool? verified;
  final double? minRating;
  final List<String>? keywords;

  const SearchFilters({
    this.category,
    this.location = const LocationFilter(),
    this.priceRange,
    this.openNow,
    this.delivery,
    this.booking,
    this.verified,
    this.minRating,
    this.keywords,
  });

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      category: json['category'] as String?,
      location: json['location'] != null
          ? LocationFilter.fromJson(json['location'] as Map<String, dynamic>)
          : const LocationFilter(),
      priceRange: json['priceRange'] != null
          ? PriceRange.fromJson(json['priceRange'] as Map<String, dynamic>)
          : null,
      openNow: json['openNow'] as bool?,
      delivery: json['delivery'] as bool?,
      booking: json['booking'] as bool?,
      verified: json['verified'] as bool?,
      minRating: (json['minRating'] as num?)?.toDouble(),
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (category != null) 'category': category,
      'location': location.toJson(),
      if (priceRange != null) 'priceRange': priceRange!.toJson(),
      if (openNow != null) 'openNow': openNow,
      if (delivery != null) 'delivery': delivery,
      if (booking != null) 'booking': booking,
      if (verified != null) 'verified': verified,
      if (minRating != null) 'minRating': minRating,
      if (keywords != null) 'keywords': keywords,
    };
  }

  SearchFilters copyWith({
    String? category,
    LocationFilter? location,
    PriceRange? priceRange,
    bool? openNow,
    bool? delivery,
    bool? booking,
    bool? verified,
    double? minRating,
    List<String>? keywords,
  }) {
    return SearchFilters(
      category: category ?? this.category,
      location: location ?? this.location,
      priceRange: priceRange ?? this.priceRange,
      openNow: openNow ?? this.openNow,
      delivery: delivery ?? this.delivery,
      booking: booking ?? this.booking,
      verified: verified ?? this.verified,
      minRating: minRating ?? this.minRating,
      keywords: keywords ?? this.keywords,
    );
  }

  @override
  List<Object?> get props => [
        category,
        location,
        priceRange,
        openNow,
        delivery,
        booking,
        verified,
        minRating,
        keywords,
      ];
}
