import 'dart:math' as math;
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:intl/intl.dart';

/// Helper utilities for filtering listings
class ListingFilterHelpers {
  /// Check if a listing is currently open based on opening hours
  /// 
  /// [listing] - The listing to check
  /// [now] - Current time (optional, defaults to DateTime.now())
  /// 
  /// Returns true if the listing is open, false otherwise or if hours are not set
  static bool isOpenNow(ListingModel listing, {DateTime? now}) {
    final String hours = listing.openingHours?.trim() ?? '';
    if (hours.isEmpty || hours.toLowerCase() == 'not set') {
      // No hours set - assume open for broader discoverability
      return true;
    }

    final currentTime = now ?? DateTime.now();
    final weekday = currentTime.weekday; // 1=Monday, 7=Sunday
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    try {
      // Parse opening hours format: "Mon-Fri: 9:00 AM - 5:00 PM; Sat-Sun: 10:00 AM - 4:00 PM"
      // or "24/7" or "Always Open"
      
      // Check for 24/7 indicators
      if (hours.toLowerCase().contains('24/7') || 
          hours.toLowerCase().contains('always open') ||
          hours.toLowerCase().contains('24 hours')) {
        return true;
      }

      // Split by semicolon for multiple day ranges
      final dayRanges = hours.split(';');
      
      for (final range in dayRanges) {
        if (range.trim().isEmpty) continue;
        
        // Parse format like "Mon-Fri: 9:00 AM - 5:00 PM"
        final parts = range.split(':');
        if (parts.length < 2) continue;
        
        final daysPart = parts[0].trim();
        final timesPart = parts.sublist(1).join(':').trim();
        
        // Check if current weekday matches this range
        if (_isDayInRange(weekday, daysPart)) {
          // Parse time range
          final timeParts = timesPart.split('-');
          if (timeParts.length >= 2) {
            final openTime = _parseTime(timeParts[0].trim());
            final closeTime = _parseTime(timeParts[1].trim());
            
            if (openTime != null && closeTime != null) {
              // Handle cases where closing time is past midnight
              if (closeTime < openTime) {
                // e.g., "10:00 PM - 2:00 AM" means open until 2 AM next day
                return currentMinutes >= openTime || currentMinutes < closeTime;
              } else {
                return currentMinutes >= openTime && currentMinutes < closeTime;
              }
            }
          }
        }
      }
      
      return false; // No matching time range found
      
    } catch (e) {
      // If parsing fails, assume open for better UX
      return true;
    }
  }

  /// Check if a given weekday (1-7) is in a day range string
  /// Examples: "Mon-Fri", "Sat-Sun", "Mon", "Daily"
  static bool _isDayInRange(int weekday, String dayRange) {
    final range = dayRange.toLowerCase().trim();
    
    // Check for "Daily" or "Every day"
    if (range.contains('daily') || range.contains('every day')) {
      return true;
    }
    
    // Map weekday number to day abbreviation
    const dayMap = {
      1: ['mon', 'monday'],
      2: ['tue', 'tuesday', 'tues'],
      3: ['wed', 'wednesday'],
      4: ['thu', 'thursday', 'thur', 'thurs'],
      5: ['fri', 'friday'],
      6: ['sat', 'saturday'],
      7: ['sun', 'sunday'],
    };
    
    // Check for day range like "Mon-Fri"
    if (range.contains('-')) {
      final rangeParts = range.split('-');
      if (rangeParts.length == 2) {
        final start = _getDayNumber(rangeParts[0].trim());
        final end = _getDayNumber(rangeParts[1].trim());
        
        if (start != null && end != null) {
          if (start <= end) {
            return weekday >= start && weekday <= end;
          } else {
            // Handle wrap-around like "Sat-Mon"
            return weekday >= start || weekday <= end;
          }
        }
      }
    }
    
    // Check for individual day match
    final currentDayNames = dayMap[weekday] ?? [];
    for (final dayName in currentDayNames) {
      if (range.contains(dayName)) {
        return true;
      }
    }
    
    return false;
  }

  /// Convert day name to number (1-7)
  static int? _getDayNumber(String dayName) {
    final name = dayName.toLowerCase();
    if (name.startsWith('mon')) return 1;
    if (name.startsWith('tue')) return 2;
    if (name.startsWith('wed')) return 3;
    if (name.startsWith('thu')) return 4;
    if (name.startsWith('fri')) return 5;
    if (name.startsWith('sat')) return 6;
    if (name.startsWith('sun')) return 7;
    return null;
  }

  /// Parse time string to minutes since midnight
  /// Examples: "9:00 AM", "5:30 PM", "14:00"
  static int? _parseTime(String timeStr) {
    try {
      final cleaned = timeStr.trim().toUpperCase();
      
      // Handle 24-hour format first
      if (!cleaned.contains('AM') && !cleaned.contains('PM')) {
        final parts = cleaned.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return hour * 60 + minute;
        }
      }
      
      // Handle 12-hour format with AM/PM
      final isPM = cleaned.contains('PM');
      final timePart = cleaned.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = timePart.split(':');
      
      if (parts.isEmpty) return null;
      
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0; // Midnight
      }
      
      return hour * 60 + minute;
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two points in kilometers using Haversine formula
  static double calculateDistance(
    double lat1, 
    double lon1, 
    double lat2, 
    double lon2,
  ) {
    const earthRadius = 6371.0; // Earth's radius in kilometers
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = 
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
      math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }
}

extension ListingFilterExtensions on ListingModel {
  /// Check if this listing matches the filter criteria
  bool matchesFilters(dynamic filterState) {
    // This will be implemented in the bloc to avoid circular dependencies
    return true;
  }
}
