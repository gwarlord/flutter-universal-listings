import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CaribbeanCountryOverlaysGeoJson {
  static const String _assetPath =
      'assets/maps/caribbean/caribbean_country_overlays.geojson';

  static Future<Map<String, List<List<LatLng>>>> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final features = (decoded['features'] as List<dynamic>? ?? const <dynamic>[]);

    final overlays = <String, List<List<LatLng>>>{};

    for (final feature in features) {
      if (feature is! Map) continue;
      final featureMap = Map<String, dynamic>.from(feature);
      final properties = featureMap['properties'] is Map
        ? Map<String, dynamic>.from(featureMap['properties'] as Map)
        : const <String, dynamic>{};
      final id = (properties['id'] as String?)?.trim().toLowerCase();
      if (id == null || id.isEmpty) continue;

      final geometry = featureMap['geometry'] is Map
        ? Map<String, dynamic>.from(featureMap['geometry'] as Map)
        : null;
      if (geometry == null) continue;

      final type = geometry['type'] as String?;
      final coords = geometry['coordinates'];

      if (type == 'Polygon' && coords is List<dynamic>) {
        final rings = _parsePolygon(coords);
        if (rings.isNotEmpty) {
          overlays[id] = rings;
        }
      } else if (type == 'MultiPolygon' && coords is List<dynamic>) {
        final rings = <List<LatLng>>[];
        for (final polygon in coords) {
          if (polygon is List<dynamic>) {
            rings.addAll(_parsePolygon(polygon));
          }
        }
        if (rings.isNotEmpty) {
          overlays[id] = rings;
        }
      }
    }

    return overlays;
  }

  static List<List<LatLng>> _parsePolygon(List<dynamic> polygonCoords) {
    final rings = <List<LatLng>>[];
    for (final ring in polygonCoords) {
      if (ring is! List<dynamic>) continue;
      final points = <LatLng>[];
      for (final pair in ring) {
        if (pair is! List<dynamic> || pair.length < 2) continue;
        final lng = _asDouble(pair[0]);
        final lat = _asDouble(pair[1]);
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (points.length >= 3) {
        rings.add(points);
      }
    }
    return rings;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
