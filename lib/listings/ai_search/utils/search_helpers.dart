import 'package:flutter/material.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';
import 'package:caribtap/listings/ai_search/utils/search_constants.dart';

/// Helper functions for search UI
class SearchHelpers {
  /// Build explainability chip from label
  static ExplainabilityChip buildChip(String label) {
    switch (label.toLowerCase()) {
      case 'near you':
        return ExplainabilityChip(
          label: label,
          icon: Icons.location_on,
          color: SearchConstants.nearYouChipColor,
        );
      case 'vouched':
      case 'verified':
        return ExplainabilityChip(
          label: label,
          icon: Icons.verified,
          color: SearchConstants.vouchedChipColor,
        );
      case 'top rated':
      case 'highly rated':
        return ExplainabilityChip(
          label: label,
          icon: Icons.star,
          color: SearchConstants.topRatedChipColor,
        );
      case 'popular':
        return ExplainabilityChip(
          label: label,
          icon: Icons.trending_up,
          color: SearchConstants.popularChipColor,
        );
      case 'open now':
        return ExplainabilityChip(
          label: label,
          icon: Icons.access_time,
          color: SearchConstants.openNowChipColor,
        );
      case 'delivery':
        return ExplainabilityChip(
          label: label,
          icon: Icons.delivery_dining,
          color: SearchConstants.deliveryChipColor,
        );
      case 'featured':
        return ExplainabilityChip(
          label: label,
          icon: Icons.workspace_premium,
          color: SearchConstants.featuredChipColor,
        );
      case 'ending soon':
        return ExplainabilityChip(
          label: label,
          icon: Icons.schedule,
          color: SearchConstants.endingSoonChipColor,
        );
      case 'new':
        return ExplainabilityChip(
          label: label,
          icon: Icons.fiber_new,
          color: SearchConstants.newChipColor,
        );
      default:
        return ExplainabilityChip(
          label: label,
          icon: Icons.info_outline,
          color: SearchConstants.matchesKeywordChipColor,
        );
    }
  }

  /// Format distance for display
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null) return '';

    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  /// Format rating for display
  static String formatRating(double rating, int reviewCount) {
    return '⭐ ${rating.toStringAsFixed(1)} ($reviewCount)';
  }

  /// Format price range
  static String formatPriceRange(double? min, double? max) {
    if (min == null && max == null) return '';
    if (min == null) return 'Up to \$${max!.round()}';
    if (max == null) return 'From \$${min.round()}';
    return '\$${min.round()} - \$${max.round()}';
  }

  /// Get category icon
  static IconData getCategoryIcon(String? category) {
    if (category == null) return Icons.category;

    switch (category.toLowerCase()) {
      case 'restaurants':
      case 'food':
        return Icons.restaurant;
      case 'hair & beauty':
      case 'beauty':
        return Icons.content_cut;
      case 'automotive':
      case 'cars':
        return Icons.directions_car;
      case 'real estate':
      case 'property':
        return Icons.home;
      case 'hotels':
      case 'accommodation':
        return Icons.hotel;
      case 'events':
        return Icons.event;
      case 'health':
      case 'medical':
        return Icons.local_hospital;
      case 'shopping':
      case 'retail':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  /// Show error snackbar
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SearchConstants.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SearchConstants.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info snackbar
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: SearchConstants.primarySearchColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
