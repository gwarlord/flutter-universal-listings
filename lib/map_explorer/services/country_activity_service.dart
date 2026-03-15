import 'dart:math';

import 'package:caribtap/listings/listings_module/api/firebase/events_firebase.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/map_explorer/models/country_activity_summary.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';
import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';

class CountryActivityService {
  final EventsFirebaseUtils _eventsRepository;

  CountryActivityService({EventsFirebaseUtils? eventsRepository})
      : _eventsRepository = eventsRepository ?? EventsFirebaseUtils();

  Future<Map<String, CountryActivitySummary>> getActivityByCountry(
    List<CountryMapConfig> countries,
  ) async {
    final Map<String, CountryActivitySummary> results = {
      for (final country in countries)
        country.id: CountryActivitySummary(countryId: country.id),
    };

    try {
      final futures = await Future.wait<dynamic>([
        listingApiManager.getListings(favListingsIDs: const []),
        _eventsRepository.getEvents(),
      ]);

      final listings = futures[0] as List<ListingModel>;
      final events = futures[1] as List<EventModel>;

      for (final country in countries) {
        final countryListings = listings
            .where((listing) => listing.countryCode.toUpperCase() == country.isoCode)
            .toList();
        final countryEvents = events
            .where((event) => event.countryCode.toUpperCase() == country.isoCode)
            .toList();

        results[country.id] = _buildSummary(country.id, countryListings, countryEvents);
      }
    } catch (_) {
      // Keep zero-state fallback summaries so navigation remains functional.
      return results;
    }

    return results;
  }

  CountryActivitySummary _buildSummary(
    String countryId,
    List<ListingModel> listings,
    List<EventModel> events,
  ) {
    int dealsCount = 0;
    int rentalsCount = 0;
    int servicesCount = 0;
    int foodCount = 0;
    int miniStoresCount = 0;
    int featuredCount = 0;
    int experiencesCount = events.where((event) => _isActiveEvent(event)).length;

    final hotspotCounts = <String, int>{};

    for (final listing in listings) {
      if (_looksLikeDeals(listing)) dealsCount++;
      if (listing.rentalConfig != null) rentalsCount++;
      if (_looksLikeService(listing)) servicesCount++;
      if (_looksLikeFood(listing)) foodCount++;
      if (listing.storeEnabled) miniStoresCount++;
      if (listing.isFeatured) featuredCount++;
      if (_looksLikeExperience(listing)) experiencesCount++;

      final place = listing.place.trim();
      if (place.isNotEmpty) {
        hotspotCounts[place] = (hotspotCounts[place] ?? 0) + 1;
      }
    }

    final topHotspots = hotspotCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final scoreByIntent = <MapExplorerIntent, int>{
      MapExplorerIntent.deals: dealsCount,
      MapExplorerIntent.rentals: rentalsCount,
      MapExplorerIntent.services: servicesCount,
      MapExplorerIntent.food: foodCount,
      MapExplorerIntent.miniStores: miniStoresCount,
      MapExplorerIntent.experiences: experiencesCount,
    };

    MapExplorerIntent topCategory = MapExplorerIntent.all;
    int topScore = 0;
    scoreByIntent.forEach((intent, score) {
      if (score > topScore) {
        topScore = score;
        topCategory = intent;
      }
    });

    final listingsCount = listings.length;
    final hasTrending = max(topScore, featuredCount) >= 3 || listingsCount >= 10;

    return CountryActivitySummary(
      countryId: countryId,
      listingsCount: listingsCount,
      dealsCount: dealsCount,
      rentalsCount: rentalsCount,
      servicesCount: servicesCount,
      featuredCount: featuredCount,
      foodCount: foodCount,
      miniStoresCount: miniStoresCount,
      experiencesCount: experiencesCount,
      topCategory: topCategory,
      topHotspots: topHotspots.take(3).map((e) => e.key).toList(),
      hasTrending: hasTrending,
    );
  }

  bool _isActiveEvent(EventModel event) {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return event.status.toLowerCase() == 'active' && event.endAtSeconds >= nowSeconds;
  }

  bool _looksLikeDeals(ListingModel listing) {
    return listing.menuEnabled || listing.storeEnabled;
  }

  bool _looksLikeService(ListingModel listing) {
    return listing.services.isNotEmpty || listing.bookingEnabled;
  }

  bool _looksLikeFood(ListingModel listing) {
    final category = listing.categoryTitle.toLowerCase();
    return listing.menuEnabled ||
        category.contains('food') ||
        category.contains('restaurant') ||
        category.contains('cafe');
  }

  bool _looksLikeExperience(ListingModel listing) {
    final category = listing.categoryTitle.toLowerCase();
    return category.contains('experience') ||
        category.contains('tour') ||
        category.contains('activity');
  }
}
