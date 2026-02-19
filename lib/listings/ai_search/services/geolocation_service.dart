import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Service for geolocation operations
class GeolocationService {
  /// Get user's current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions permanently denied');
        return null;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Get place name from coordinates (reverse geocoding)
  Future<String?> getPlaceFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Return locality (city/town) or administrative area
        final place = placemark.locality ?? placemark.administrativeArea ?? 'Unknown';
        print('📍 Reverse geocoded to: $place');
        return place;
      }

      return null;
    } catch (e) {
      print('❌ Error reverse geocoding: $e');
      return null;
    }
  }

  /// Get coordinates from place name (forward geocoding)
  Future<Location?> getCoordinatesFromPlace(String place) async {
    try {
      List<Location> locations = await locationFromAddress(place);
      if (locations.isNotEmpty) {
        final location = locations.first;
        print('📍 Geocoded "$place" to: ${location.latitude}, ${location.longitude}');
        return location;
      }
      return null;
    } catch (e) {
      print('❌ Error geocoding place: $e');
      return null;
    }
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }
}
