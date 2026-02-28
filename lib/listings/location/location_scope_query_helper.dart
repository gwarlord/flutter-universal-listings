// lib/listings/location/location_scope_query_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/ui/deals/deal_ad_model.dart';

/// Helper class for applying location scope filtering and ranking to queries
class LocationScopeQueryHelper {
  /// Apply location scope constraints to a Firestore query
  /// Returns the modified query
  /// 
  /// Note: Only applies hard filters when strictLocalOnly is true
  /// For soft localization, filtering happens at the result level
  static Query<Map<String, dynamic>> applyToQuery(
    Query<Map<String, dynamic>> query,
    LocationScope scope,
  ) {
    // Only apply hard filter when in strict local mode
    if (scope.shouldApplyStrictFilter) {
      final country = scope.getEffectiveCountry();
      if (country != null) {
        // Add where clause to filter by country
        return query.where('countryCode', isEqualTo: country);
      }
    }
    
    // For Caribbean mode or soft local mode, don't modify the query
    return query;
  }

  /// Partition listings into local and other based on location scope
  /// Used for soft localization (show local first, then "from other islands")
  static PartitionedListings<ListingModel> partitionListings(
    List<ListingModel> listings,
    LocationScope scope,
  ) {
    // If Caribbean mode or no effective country, return all as local
    final effectiveCountry = scope.getEffectiveCountry();
    if (scope.isShowingAll || effectiveCountry == null) {
      return PartitionedListings(
        local: listings,
        other: [],
        effectiveCountry: null,
      );
    }

    final local = <ListingModel>[];
    final other = <ListingModel>[];

    for (final listing in listings) {
      if (_matchesCountry(listing.countryCode, effectiveCountry)) {
        local.add(listing);
      } else {
        other.add(listing);
      }
    }

    return PartitionedListings(
      local: local,
      other: other,
      effectiveCountry: effectiveCountry,
    );
  }

  /// Partition deal ads into local and other based on location scope
  static PartitionedListings<DealAdModel> partitionDeals(
    List<DealAdModel> deals,
    LocationScope scope,
  ) {
    // If Caribbean mode or no effective country, return all as local
    final effectiveCountry = scope.getEffectiveCountry();
    if (scope.isShowingAll || effectiveCountry == null) {
      return PartitionedListings(
        local: deals,
        other: [],
        effectiveCountry: null,
      );
    }

    final local = <DealAdModel>[];
    final other = <DealAdModel>[];

    for (final deal in deals) {
      // Deal ads use visibilityCountries list
      if (deal.visibilityCountries.contains(effectiveCountry)) {
        local.add(deal);
      } else if (deal.visibilityCountries.isEmpty) {
        // If no visibility countries set, treat as available everywhere (local)
        local.add(deal);
      } else {
        other.add(deal);
      }
    }

    return PartitionedListings(
      local: local,
      other: other,
      effectiveCountry: effectiveCountry,
    );
  }

  /// Check if a listing's country matches the target country
  static bool _matchesCountry(String? listingCountry, String targetCountry) {
    if (listingCountry == null || listingCountry.isEmpty) {
      return false;
    }
    return listingCountry.trim().toUpperCase() == targetCountry.trim().toUpperCase();
  }

  /// Rank/order listings with local first, then others
  /// This is a simple implementation that just concatenates local + other
  /// You could add more sophisticated ranking logic here
  static List<T> rankWithLocalFirst<T>(
    List<T> local,
    List<T> other, {
    int? maxOther,
  }) {
    final result = <T>[];
    result.addAll(local);
    
    // Optionally limit how many "other" items to include
    if (maxOther != null && other.length > maxOther) {
      result.addAll(other.take(maxOther));
    } else {
      result.addAll(other);
    }
    
    return result;
  }

  /// Get filter chips to display under AppBar
  static List<FilterChipData> getFilterChips(LocationScope scope) {
    final chips = <FilterChipData>[];

    if (scope.mode == LocationScopeMode.caribbean) {
      chips.add(FilterChipData(
        label: 'Caribbean',
        icon: null,
        isDismissible: true,
      ));
    } else if (scope.mode == LocationScopeMode.local) {
      final country = scope.selectedCountry ?? scope.homeCountry;
      if (country != null) {
        chips.add(FilterChipData(
          label: country,
          icon: null,
          isDismissible: true,
        ));
        
        if (scope.strictLocalOnly) {
          chips.add(FilterChipData(
            label: 'Strict',
            icon: null,
            isDismissible: false,
          ));
        }
      }
    } else if (scope.mode == LocationScopeMode.nearby) {
      chips.add(FilterChipData(
        label: 'Nearby',
        icon: null,
        isDismissible: true,
      ));
    }

    return chips;
  }
}

/// Data class for partitioned listings
class PartitionedListings<T> {
  final List<T> local;
  final List<T> other;
  final String? effectiveCountry;

  PartitionedListings({
    required this.local,
    required this.other,
    this.effectiveCountry,
  });

  /// Check if we have any local results
  bool get hasLocal => local.isNotEmpty;

  /// Check if we have any other results
  bool get hasOther => other.isNotEmpty;

  /// Get total count
  int get totalCount => local.length + other.length;

  /// Get all items (local + other)
  List<T> get all => [...local, ...other];
}

/// Data for filter chips
class FilterChipData {
  final String label;
  final IconData? icon;
  final bool isDismissible;

  FilterChipData({
    required this.label,
    this.icon,
    this.isDismissible = true,
  });
}
