import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/feed_item.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MapViewScreen extends StatefulWidget {
  final List<FeedItem> items;
  final bool fromHome;
  final ListingsUser currentUser;

  const MapViewScreen(
      {super.key,
      required this.items,
      required this.fromHome,
      required this.currentUser});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  Position? locationData;
  final Future _mapFuture =
      Future.delayed(const Duration(milliseconds: 500), () => true);
  GoogleMapController? _mapController;
  late ListingsUser currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _getLocation();
  }

  // For search and favorites
  final TextEditingController _searchController = TextEditingController();
  List<FeedItem> _filteredItems = [];
  int? _selectedItemIndex;
  bool _showFavoritesOnly = false;
  bool _showSearchBlock = true;

  String _getItemTitle(FeedItem item) =>
      item.type == FeedItemType.listing ? item.listing!.title : item.event!.title;
  String _getItemPhoto(FeedItem item) =>
      item.type == FeedItemType.listing ? item.listing!.photo : item.event!.posterImageUrl;
  double _getItemLat(FeedItem item) =>
      item.type == FeedItemType.listing ? item.listing!.latitude : item.event!.latitude;
  double _getItemLng(FeedItem item) =>
      item.type == FeedItemType.listing ? item.listing!.longitude : item.event!.longitude;
  bool _getItemIsFav(FeedItem item) =>
      item.type == FeedItemType.listing ? item.listing!.isFav : item.event!.isFav;

  @override
  Widget build(BuildContext context) {
    // Items to show: all or only favorites
    final itemsToShow = _showFavoritesOnly
        ? widget.items.where((item) => _getItemIsFav(item)).toList()
        : widget.items;

    _filteredItems = _searchController.text.isEmpty
      ? itemsToShow
      : itemsToShow
        .where((item) => _getItemTitle(item).toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.5),
        title: Text(widget.fromHome
            ? 'Map View'.tr()
            : widget.items.isNotEmpty && widget.items.first.type == FeedItemType.listing
                ? widget.items.first.listing!.categoryTitle
                : 'Map View'.tr()),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FutureBuilder(
              future: _mapFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator.adaptive());
                }
                if (kIsWeb) {
                  return _buildWebMapFallback(context);
                }
                return GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: List.generate(
                      _filteredItems.length,
                      (index) => Marker(
                          markerId: MarkerId('marker_$index'),
                          position: LatLng(_getItemLat(_filteredItems[index]), _getItemLng(_filteredItems[index])),
                          infoWindow: InfoWindow(
                              onTap: () {
                                final item = _filteredItems[index];
                                if (item.type == FeedItemType.listing) {
                                  push(
                                      context,
                                      ListingDetailsWrappingWidget(
                                        listing: item.listing!,
                                        currentUser: currentUser,
                                      ));
                                } else {
                                  push(
                                      context,
                                      EventDetailsScreen(
                                        event: item.event!,
                                      ));
                                }
                              },
                              title: _getItemTitle(_filteredItems[index])),
                          icon: _selectedItemIndex == index
                              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                              : BitmapDescriptor.defaultMarker)).toSet(),
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: locationData == null
                        ? widget.items.isNotEmpty
                            ? LatLng(_getItemLat(widget.items.first), _getItemLng(widget.items.first))
                            : const LatLng(0, 0)
                        : LatLng(locationData!.latitude, locationData!.longitude),
                    zoom: 14.4746,
                  ),
                  onMapCreated: _onMapCreated,
                );
              }),
          // Custom zoom buttons
          Positioned(
            right: 16,
            top: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: const Icon(Icons.add),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: const Icon(Icons.remove),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
          // Snap to location button
          Positioned(
            left: 16,
            bottom: 120,
            child: FloatingActionButton(
              heroTag: 'my_location',
              mini: true,
              onPressed: () {
                if (locationData != null && _mapController != null) {
                  _mapController!.animateCamera(CameraUpdate.newLatLng(
                      LatLng(locationData!.latitude, locationData!.longitude)));
                }
              },
              child: const Icon(Icons.my_location, color: Colors.blue),
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          // Toggle button to show/hide search block
          Positioned(
            left: 24,
            bottom: 48,
            child: FloatingActionButton(
              heroTag: 'toggle_search_block',
              mini: true,
              onPressed: () {
                setState(() {
                  _showSearchBlock = !_showSearchBlock;
                });
              },
              child: Icon(_showSearchBlock ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          // Search block
          if (_showSearchBlock)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).cardColor.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: _showFavoritesOnly
                                    ? 'Search favorite locations...'.tr()
                                    : 'Search all locations...'.tr(),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                ),
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade600,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: _showFavoritesOnly ? 'Show all locations' : 'Show only favorites',
                            child: IconButton(
                              icon: Icon(_showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
                                  color: _showFavoritesOnly ? Colors.red : Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _showFavoritesOnly = !_showFavoritesOnly;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_filteredItems.isNotEmpty)
                        SizedBox(
                          height: 54,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredItems.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final item = _filteredItems[i];
                              final title = _getItemTitle(item);
                              final photo = _getItemPhoto(item);
                              final lat = _getItemLat(item);
                              final lng = _getItemLng(item);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedItemIndex = i;
                                  });
                                  if (_mapController != null) {
                                    _mapController!.animateCamera(CameraUpdate.newLatLng(
                                        LatLng(lat, lng)));
                                  }
                                },
                                child: Container(
                                  width: 106,
                                  decoration: BoxDecoration(
                                    color: _selectedItemIndex == i
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedItemIndex == i
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey.shade300,
                                      width: 1.2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: photo.isNotEmpty
                                            ? NetworkImage(photo)
                                            : null,
                                        child: photo.isEmpty
                                            ? const Icon(Icons.place, size: 16)
                                            : null,
                                        radius: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebMapFallback(BuildContext context) {
    final isDark = isDarkMode(context);
    final first = widget.items.isNotEmpty ? widget.items.first : null;

    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 42),
            const SizedBox(height: 10),
            Text(
              'Interactive map unavailable on web'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Open the location in Google Maps instead.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: first == null
                  ? null
                  : () => _openItemInGoogleMaps(_getItemLat(first), _getItemLng(first)),
              icon: const Icon(Icons.open_in_new),
              label: Text('Open in Google Maps'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openItemInGoogleMaps(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (isDarkMode(context)) {
      _mapController!.setMapStyle(
        '[{"featureType": "all","'
        'elementType": "'
        'geo'
        'met'
        'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]',
      );
    }

    if (locationData != null) {
      _mapController!.moveCamera(CameraUpdate.newLatLng(
          LatLng(locationData!.latitude, locationData!.longitude)));
    }
  }

  void _getLocation() async {
    locationData = await getCurrentLocation();
    if (_mapController != null) {
      _mapController!.moveCamera(CameraUpdate.newLatLng(LatLng(
          locationData?.latitude ?? 0.01, locationData?.longitude ?? 0.01)));
    }
  }
}
