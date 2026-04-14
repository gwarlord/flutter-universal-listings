import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';

class CountryActivitySummary {
  final String countryId;
  final int listingsCount;
  final int usersCount;
  final int dealsCount;
  final int rentalsCount;
  final int servicesCount;
  final int featuredCount;
  final int foodCount;
  final int miniStoresCount;
  final int experiencesCount;
  final MapExplorerIntent topCategory;
  final List<String> topHotspots;
  final bool hasTrending;

  const CountryActivitySummary({
    required this.countryId,
    this.listingsCount = 0,
    this.usersCount = 0,
    this.dealsCount = 0,
    this.rentalsCount = 0,
    this.servicesCount = 0,
    this.featuredCount = 0,
    this.foodCount = 0,
    this.miniStoresCount = 0,
    this.experiencesCount = 0,
    this.topCategory = MapExplorerIntent.all,
    this.topHotspots = const [],
    this.hasTrending = false,
  });

  CountryActivitySummary copyWith({
    int? listingsCount,
    int? usersCount,
    int? dealsCount,
    int? rentalsCount,
    int? servicesCount,
    int? featuredCount,
    int? foodCount,
    int? miniStoresCount,
    int? experiencesCount,
    MapExplorerIntent? topCategory,
    List<String>? topHotspots,
    bool? hasTrending,
  }) {
    return CountryActivitySummary(
      countryId: countryId,
      listingsCount: listingsCount ?? this.listingsCount,
      usersCount: usersCount ?? this.usersCount,
      dealsCount: dealsCount ?? this.dealsCount,
      rentalsCount: rentalsCount ?? this.rentalsCount,
      servicesCount: servicesCount ?? this.servicesCount,
      featuredCount: featuredCount ?? this.featuredCount,
      foodCount: foodCount ?? this.foodCount,
      miniStoresCount: miniStoresCount ?? this.miniStoresCount,
      experiencesCount: experiencesCount ?? this.experiencesCount,
      topCategory: topCategory ?? this.topCategory,
      topHotspots: topHotspots ?? this.topHotspots,
      hasTrending: hasTrending ?? this.hasTrending,
    );
  }

  static const CountryActivitySummary empty =
      CountryActivitySummary(countryId: '');
}
