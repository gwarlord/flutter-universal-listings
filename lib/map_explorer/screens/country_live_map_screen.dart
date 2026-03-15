import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:caribtap/listings/listings_module/api/firebase/events_firebase.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/map_view/map_view_screen.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/feed_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';
import 'package:caribtap/map_explorer/models/map_explorer_entry.dart';
import 'package:caribtap/map_explorer/models/map_explorer_intent.dart';

class CountryLiveMapScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final CountryMapConfig country;
  final MapExplorerEntry entry;

  const CountryLiveMapScreen({
    super.key,
    required this.currentUser,
    required this.country,
    required this.entry,
  });

  @override
  State<CountryLiveMapScreen> createState() => _CountryLiveMapScreenState();
}

class _CountryLiveMapScreenState extends State<CountryLiveMapScreen> {
  final EventsFirebaseUtils _eventsRepository = EventsFirebaseUtils();
  bool _loading = true;
  List<FeedItem> _items = const [];
  List<ListingModel> _allListings = const [];
  List<EventModel> _allEvents = const [];
  late MapExplorerIntent _activeIntent;

  @override
  void initState() {
    super.initState();
    _activeIntent = widget.entry.intent ?? MapExplorerIntent.all;
    _loadMapItems();
  }

  Future<void> _loadMapItems() async {
    try {
      final futures = await Future.wait<dynamic>([
        listingApiManager.getListings(favListingsIDs: widget.currentUser.likedListingsIDs),
        _eventsRepository.getEvents(),
      ]);

      _allListings = futures[0] as List<ListingModel>;
      _allEvents = futures[1] as List<EventModel>;
      final filteredItems = _buildFeed(_allListings, _allEvents);

      if (!mounted) return;
      setState(() {
        _items = filteredItems;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  List<FeedItem> _buildFeed(List<ListingModel> listings, List<EventModel> events) {
    final countryListings = listings
        .where((listing) => listing.countryCode.toUpperCase() == widget.country.isoCode)
        .toList();
    final countryEvents = events
        .where((event) => event.countryCode.toUpperCase() == widget.country.isoCode)
        .toList();

    final intent = _activeIntent;
    List<ListingModel> filteredListings = countryListings.where((listing) {
      return _matchesIntent(listing, intent);
    }).toList();

    final hotspotToken = _resolveHotspotToken(widget.entry.hotspotId);
    if (hotspotToken != null && hotspotToken.isNotEmpty) {
      filteredListings = filteredListings.where((listing) {
        return listing.place.toLowerCase().contains(hotspotToken);
      }).toList();
    }

    // If a strict intent yields empty data, fall back to country-level markers.
    if (filteredListings.isEmpty && countryListings.isNotEmpty && intent != MapExplorerIntent.all) {
      filteredListings = countryListings;
    }

    final feed = <FeedItem>[
      ...filteredListings.map(FeedItem.listing),
    ];

    if (intent == MapExplorerIntent.all || intent == MapExplorerIntent.experiences) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (final event in countryEvents) {
        if (event.status.toLowerCase() == 'active' && event.endAtSeconds >= now) {
          feed.add(FeedItem.event(event));
        }
      }
    }

    return feed;
  }

  String? _resolveHotspotToken(String? hotspotId) {
    if (hotspotId == null || hotspotId.trim().isEmpty) {
      return null;
    }
    final normalized = hotspotId.trim().toLowerCase();
    for (final hotspot in widget.country.hotspots) {
      if (hotspot.id.toLowerCase() == normalized) {
        return hotspot.name.toLowerCase();
      }
    }
    return normalized.replaceAll('_', ' ');
  }

  bool _matchesIntent(ListingModel listing, MapExplorerIntent intent) {
    switch (intent) {
      case MapExplorerIntent.all:
        return true;
      case MapExplorerIntent.deals:
        return listing.menuEnabled || listing.storeEnabled;
      case MapExplorerIntent.rentals:
        return listing.rentalConfig != null;
      case MapExplorerIntent.services:
        return listing.services.isNotEmpty || listing.bookingEnabled;
      case MapExplorerIntent.food:
        final title = listing.categoryTitle.toLowerCase();
        return listing.menuEnabled || title.contains('food') || title.contains('restaurant');
      case MapExplorerIntent.miniStores:
        return listing.storeEnabled;
      case MapExplorerIntent.experiences:
        final title = listing.categoryTitle.toLowerCase();
        return title.contains('experience') || title.contains('tour') || title.contains('activity');
      case MapExplorerIntent.trending:
        return listing.isFeatured || listing.storeEnabled || listing.menuEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Live Map')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return MapViewScreen(
      items: _items,
      fromHome: true,
      currentUser: widget.currentUser,
      titleOverride: _buildMapTitle(),
      initialFocus: LatLng(
        widget.country.centerLat,
        widget.country.centerLng,
      ),
      initialZoom: widget.country.defaultMapZoom,
      followUserLocation: false,
    );
  }

  String _buildMapTitle() {
    final intent = _activeIntent;
    if (intent == MapExplorerIntent.all) {
      return '${widget.country.displayName} Live Map';
    }
    return '${widget.country.displayName} ${intent.label}';
  }
}
