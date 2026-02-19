import 'package:flutter/material.dart';

/// Constants for AI search UI
class SearchConstants {
  // Colors
  static const Color primarySearchColor = Color(0xFF2196F3);
  static const Color aiIndicatorColor = Color(0xFF9C27B0);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);

  // Chip colors
  static const Color nearYouChipColor = Color(0xFF03A9F4);
  static const Color vouchedChipColor = Color(0xFF2196F3);
  static const Color topRatedChipColor = Color(0xFFFFC107);
  static const Color popularChipColor = Color(0xFFFF5722);
  static const Color openNowChipColor = Color(0xFF4CAF50);
  static const Color deliveryChipColor = Color(0xFF9C27B0);
  static const Color featuredChipColor = Color(0xFFE91E63);
  static const Color endingSoonChipColor = Color(0xFFFF9800);
  static const Color newChipColor = Color(0xFF00BCD4);
  static const Color matchesKeywordChipColor = Color(0xFF607D8B);

  // Example queries
  static const List<String> exampleQueries = [
    '🏪 Shops near me',
    '🍕 Pizza delivery',
    '💇 Barbers open now',
    '⭐ Top rated restaurants',
    '🚗 Car rentals Trinidad',
    '🏨 Hotels in Tobago',
  ];

  // Animations
  static const Duration searchAnimationDuration = Duration(milliseconds: 300);
  static const Duration chipAnimationDuration = Duration(milliseconds: 200);
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  // Sizing
  static const double searchBarHeight = 56.0;
  static const double chipHeight = 32.0;
  static const double resultCardHeight = 140.0;
  static const double filterChipSpacing = 8.0;
}
