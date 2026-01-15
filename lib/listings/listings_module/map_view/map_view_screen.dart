import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_screen.dart';

class MapViewScreen extends StatefulWidget {
  final List<ListingModel> listings;
  final bool fromHome;
  final ListingsUser currentUser;

  const MapViewScreen(
      {super.key,
      required this.listings,
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
  List<ListingModel> _filteredFavorites = [];
  int? _selectedFavoriteIndex;
  Offset _searchBlockOffset = const Offset(0, 0);
  bool _isDragging = false;
  bool _showFavoritesOnly = true;
  bool _showSearchBlock = true;

  @override
  Widget build(BuildContext context) {
    // Listings to show: all or only favorites
    final favorites = widget.listings.where((l) => l.isFav).toList();
    final listingsToShow = _showFavoritesOnly ? favorites : widget.listings;
    _filteredFavorites = _searchController.text.isEmpty
      ? listingsToShow
      : listingsToShow
        .where((l) => l.title.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = mediaQuery.padding.bottom;
    final blockWidth = screenWidth - 32; // left+right margin
    final blockHeight = 120; // estimated block height

    void clampBlockPosition() {
      double dx = _searchBlockOffset.dx;
      double dy = _searchBlockOffset.dy;
      // Clamp horizontally
      dx = dx.clamp(-16.0, screenWidth - blockWidth - 16.0);
      // Clamp vertically (bottom: above nav bar, top: not off screen)
      dy = dy.clamp(-(screenHeight - blockHeight - bottomPadding - 24.0), 0.0);
      _searchBlockOffset = Offset(dx, dy);
    }
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.5),
        title: Text(widget.fromHome
            ? 'Map View'.tr()
            : widget.listings.isNotEmpty
                ? widget.listings.first.categoryTitle
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
                return GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  markers: List.generate(
                      _filteredFavorites.length,
                      (index) => Marker(
                          markerId: MarkerId('marker_$index'),
                          position: LatLng(_filteredFavorites[index].latitude, _filteredFavorites[index].longitude),
                          infoWindow: InfoWindow(
                              onTap: () {
                                push(
                                    context,
                                    ListingDetailsWrappingWidget(
                                      listing: _filteredFavorites[index],
                                      currentUser: currentUser,
                                    ));
                              },
                              title: _filteredFavorites[index].title),
                          icon: _selectedFavoriteIndex == index
                              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                              : BitmapDescriptor.defaultMarker)).toSet(),
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: locationData == null
                        ? widget.listings.isNotEmpty
                            ? LatLng(widget.listings.first.latitude, widget.listings.first.longitude)
                            : const LatLng(0, 0)
                        : LatLng(locationData!.latitude, locationData!.longitude),
                    zoom: 14.4746,
                  ),
                  onMapCreated: _onMapCreated,
                );
              }),
          // Custom zoom buttons (higher up)
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
          // Snap to location button (left)
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
            bottom: 64,
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
          // Search block (not draggable, always visible above bottom)
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
                                prefixIcon: const Icon(Icons.search),
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
                      if (_filteredFavorites.isNotEmpty)
                        SizedBox(
                          height: 54,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _filteredFavorites.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final fav = _filteredFavorites[i];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedFavoriteIndex = widget.listings.indexOf(fav);
                                  });
                                  if (_mapController != null) {
                                    _mapController!.animateCamera(CameraUpdate.newLatLng(
                                        LatLng(fav.latitude, fav.longitude)));
                                  }
                                },
                                child: Container(
                                  width: 106,
                                  decoration: BoxDecoration(
                                    color: _selectedFavoriteIndex == widget.listings.indexOf(fav)
                                        ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _selectedFavoriteIndex == widget.listings.indexOf(fav)
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey.shade300,
                                      width: 1.2,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundImage: fav.photo.isNotEmpty
                                            ? NetworkImage(fav.photo)
                                            : null,
                                        child: fav.photo.isEmpty
                                            ? const Icon(Icons.place, size: 16)
                                            : null,
                                        radius: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          fav.title,
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
