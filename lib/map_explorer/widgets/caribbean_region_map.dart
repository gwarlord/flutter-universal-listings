import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:caribtap/map_explorer/data/caribbean_country_overlays_geojson.dart';
import 'package:caribtap/map_explorer/models/country_activity_summary.dart';
import 'package:caribtap/map_explorer/models/country_map_config.dart';
import 'package:caribtap/map_explorer/widgets/caribtap_explorer_marker_factory.dart';

/// Layer 1 map transformed to real geospatial rendering.
///
/// Coastlines and island outlines now come from Google map tiles instead of
/// hand-drawn SVG blobs. Country anchors remain tappable and drive the same
/// Layer 1 -> Layer 2 flow.
class CaribbeanRegionMap extends StatefulWidget {
  final List<CountryMapConfig> countries;
  final Map<String, CountryActivitySummary> activity;
  final String? selectedCountryId;
  final String? selectedMarkerId;
  final ValueChanged<CountryMapConfig> onIslandTap;
  final ValueChanged<CountryMapConfig> onMarkerTap;

  const CaribbeanRegionMap({
    super.key,
    required this.countries,
    required this.activity,
    required this.onIslandTap,
    required this.onMarkerTap,
    this.selectedCountryId,
    this.selectedMarkerId,
  });

  @override
  State<CaribbeanRegionMap> createState() => _CaribbeanRegionMapState();
}

class _CaribbeanRegionMapState extends State<CaribbeanRegionMap> {
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(17.6, -68.8),
    zoom: 4.7,
  );

  GoogleMapController? _controller;
  Map<String, List<List<LatLng>>> _countryOverlayRings =
      const <String, List<List<LatLng>>>{};
    Map<ExplorerMarkerState, BitmapDescriptor> _markerIcons =
      const <ExplorerMarkerState, BitmapDescriptor>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadGeoJsonOverlays());
    unawaited(_loadMarkerIcons());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadGeoJsonOverlays() async {
    try {
      final overlays = await CaribbeanCountryOverlaysGeoJson.load();
      if (!mounted) return;
      setState(() {
        _countryOverlayRings = overlays;
      });
    } catch (_) {
      // Fallback polygons are generated below when GeoJSON loading fails.
    }
  }

  Future<void> _loadMarkerIcons() async {
    final icons = await CaribTapExplorerMarkerFactory.loadMarkers();
    if (!mounted) return;
    setState(() {
      _markerIcons = icons;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: _onMapCreated,
            mapType: MapType.normal,
            compassEnabled: false,
            tiltGesturesEnabled: false,
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            trafficEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(3.5, 9.5),
            padding: const EdgeInsets.only(bottom: 80),
            markers: _buildCountryMarkers(),
            circles: _buildSelectedIslandAura(),
            polygons: _buildCountryPolygons(),
          ),
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF04111F).withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    controller.setMapStyle(_caribbeanMapStyle);
  }

  Set<Polygon> _buildCountryPolygons() {
    final polygons = <Polygon>{};
    for (final country in widget.countries) {
      final isSelected = widget.selectedCountryId == country.id;
      final hasGeoRings = _countryOverlayRings.containsKey(country.id);

      final baseFill = hasGeoRings && isSelected
          ? const Color(0xFF6DD5FA).withValues(alpha: 0.08)
          : Colors.transparent;

      final baseStroke = hasGeoRings && isSelected
          ? const Color(0xFF6DD5FA).withValues(alpha: 0.18)
          : Colors.transparent;
      final strokeWidth = isSelected ? 1 : 0;

      final rings = _countryOverlayRings[country.id] ?? <List<LatLng>>[_buildFallbackTapPolygon(country)];
      for (int i = 0; i < rings.length; i++) {
        polygons.add(
          Polygon(
            polygonId: PolygonId('country_overlay_${country.id}_$i'),
            points: rings[i],
            consumeTapEvents: true,
            geodesic: false,
            fillColor: baseFill,
            strokeColor: baseStroke,
            strokeWidth: strokeWidth,
            zIndex: isSelected ? 30 : 20,
            onTap: () => widget.onIslandTap(country),
          ),
        );
      }
    }
    return polygons;
  }

  Set<Marker> _buildCountryMarkers() {
    if (_markerIcons.isEmpty) {
      return const <Marker>{};
    }

    final selectedIslandId = widget.selectedCountryId;
    final selectedMarkerId = widget.selectedMarkerId;

    return widget.countries.map((country) {
      final countryActivity = widget.activity[country.id] ??
          CountryActivitySummary(countryId: country.id);
      final state = _markerStateFor(
        markerIslandId: country.id,
        selectedIslandId: selectedIslandId,
        selectedMarkerId: selectedMarkerId,
      );
      final icon = _markerIcons[state] ?? _markerIcons[ExplorerMarkerState.defaultState]!;

      final isSelectedMarker = state == ExplorerMarkerState.selected;
      final isDimmed = state == ExplorerMarkerState.dimmed;

      return Marker(
        markerId: MarkerId('country_pin_${country.id}'),
        position: LatLng(country.centerLat, country.centerLng),
        icon: icon,
        zIndex: isSelectedMarker ? 100 : 40,
        alpha: isDimmed ? 0.35 : 1.0,
        infoWindow: InfoWindow(
          title: country.displayName,
          snippet:
              '${countryActivity.listingsCount} listings • ${countryActivity.usersCount} users',
        ),
        onTap: () => widget.onMarkerTap(country),
      );
    }).toSet();
  }

  ExplorerMarkerState _markerStateFor({
    required String markerIslandId,
    required String? selectedIslandId,
    required String? selectedMarkerId,
  }) {
    if (selectedMarkerId != null && selectedMarkerId == markerIslandId) {
      return ExplorerMarkerState.selected;
    }
    if (selectedIslandId != null && markerIslandId != selectedIslandId) {
      return ExplorerMarkerState.dimmed;
    }
    return ExplorerMarkerState.defaultState;
  }

  Set<Circle> _buildSelectedIslandAura() {
    final selectedId = widget.selectedCountryId;
    if (selectedId == null) return const <Circle>{};

    CountryMapConfig? selected;
    for (final country in widget.countries) {
      if (country.id == selectedId) {
        selected = country;
        break;
      }
    }
    if (selected == null) return const <Circle>{};

    final center = LatLng(selected.centerLat, selected.centerLng);
    return {
      Circle(
        circleId: CircleId('island_aura_outer_${selected.id}'),
        center: center,
        radius: 95000,
        strokeWidth: 0,
        fillColor: const Color(0xFF56C6F8).withValues(alpha: 0.045),
        zIndex: 5,
      ),
      Circle(
        circleId: CircleId('island_aura_mid_${selected.id}'),
        center: center,
        radius: 62000,
        strokeWidth: 0,
        fillColor: const Color(0xFF56C6F8).withValues(alpha: 0.06),
        zIndex: 6,
      ),
      Circle(
        circleId: CircleId('island_aura_inner_${selected.id}'),
        center: center,
        radius: 32000,
        strokeWidth: 0,
        fillColor: const Color(0xFF56C6F8).withValues(alpha: 0.08),
        zIndex: 7,
      ),
    };
  }

  List<LatLng> _buildFallbackTapPolygon(CountryMapConfig country) {
    final radiusKm = _overlayTapRadiusKm(country);
    final segments = 28;
    final points = <LatLng>[];
    final lat = country.centerLat;
    final lng = country.centerLng;

    for (int i = 0; i < segments; i++) {
      final t = (i / segments) * 2 * math.pi;
      final stretchEastWest = _eastWestStretch(country);

      final dLat = (radiusKm / 111.0) * math.sin(t);
      final dLng =
          ((radiusKm * stretchEastWest) / (111.0 * math.cos(lat * math.pi / 180.0))) *
              math.cos(t);
      points.add(LatLng(lat + dLat, lng + dLng));
    }

    return points;
  }

  double _overlayTapRadiusKm(CountryMapConfig country) {
    switch (country.id) {
      case 'gy':
        return 170;
      case 'bs':
        return 140;
      case 'jm':
      case 'do':
      case 'ht':
        return 110;
      case 'pr':
        return 82;
      case 'tt':
        return 72;
      case 'dm':
      case 'lc':
      case 'vc':
      case 'gd':
      case 'bb':
      case 'ag':
      case 'aw':
      case 'cw':
      case 'vi':
      case 'vg':
        return 48;
      default:
        return 65;
    }
  }

  double _eastWestStretch(CountryMapConfig country) {
    switch (country.id) {
      case 'jm':
      case 'do':
      case 'ht':
      case 'pr':
      case 'aw':
      case 'cw':
      case 'bs':
        return 1.55;
      case 'gy':
      case 'bb':
      case 'lc':
      case 'dm':
      case 'vc':
      case 'gd':
        return 0.84;
      default:
        return 1.1;
    }
  }
}

const String _caribbeanMapStyle = '''
[
  {
    "featureType": "administrative.locality",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.province",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {"visibility": "on"},
      {"color": "#d5e9f7"}
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.stroke",
    "stylers": [
      {"visibility": "on"},
      {"color": "#0b1f33"},
      {"weight": 2}
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "elementType": "all",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape",
    "elementType": "geometry",
    "stylers": [{"color": "#1f2a44"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#0c3d63"}]
  },
  {
    "featureType": "water",
    "elementType": "labels",
    "stylers": [{"visibility": "off"}]
  }
]
''';
