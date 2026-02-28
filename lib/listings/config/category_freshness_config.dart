/// Category-based freshness configuration
/// Different listing types have different appropriate lifespans
class CategoryFreshnessConfig {
  /// Freshness periods by category in days
  static const Map<String, int> periods = {
    // Short-term listings (urgent/time-sensitive)
    'deals': 30,
    'flash_sales': 14,
    'events': 14,
    'limited_offers': 21,
    'seasonal': 30,
    
    // Standard listings (regular business)
    'restaurants': 90,
    'services': 90,
    'products': 90,
    'retail': 90,
    'beauty': 90,
    'fitness': 90,
    'automotive': 90,
    'home_services': 90,
    
    // Long-term listings (stable, less frequent changes)
    'real_estate': 120,
    'rentals': 120,
    'property_management': 120,
    'professionals': 180,
    'healthcare': 120,
    'education': 120,
    'legal_services': 180,
    
    // Very short-term (daily updates expected)
    'daily_specials': 7,
    'market_fresh': 7,
  };

  /// Get freshness period for a category
  static int getDaysForCategory(String? category, {int defaultDays = 90}) {
    if (category == null || category.isEmpty) {
      return defaultDays;
    }
    return periods[category.toLowerCase()] ?? defaultDays;
  }

  /// Check if category is time-sensitive
  static bool isTimeSensitive(String? category) {
    if (category == null) return false;
    final days = getDaysForCategory(category);
    return days <= 30;
  }

  /// Get freshness category tier
  static String getFreshnessTier(String? category) {
    final days = getDaysForCategory(category);
    if (days <= 14) return 'urgent';
    if (days <= 30) return 'short';
    if (days <= 90) return 'standard';
    if (days <= 120) return 'long';
    return 'extended';
  }

  /// Get recommended refresh frequency message
  static String getRefreshGuidance(String? category) {
    final days = getDaysForCategory(category);
    
    if (days <= 7) {
      return 'Update daily to keep this listing active';
    } else if (days <= 14) {
      return 'Update weekly to keep this listing fresh';
    } else if (days <= 30) {
      return 'Update monthly to maintain visibility';
    } else if (days <= 90) {
      return 'Refresh every 3 months to stay active';
    } else {
      return 'Refresh every 4-6 months to stay visible';
    }
  }

  /// Get warning offset days for category
  static Map<String, int> getWarningOffsets(String? category) {
    final totalDays = getDaysForCategory(category);
    
    // For time-sensitive listings, give earlier warnings
    if (totalDays <= 14) {
      return {
        'first': 3,  // 3 days before
        'second': 1, // 1 day before
      };
    } else if (totalDays <= 30) {
      return {
        'first': 7,  // 7 days before
        'second': 2, // 2 days before
      };
    } else {
      return {
        'first': 10, // 10 days before
        'second': 1, // 1 day before
      };
    }
  }

  /// All available categories with their settings
  static List<CategoryInfo> getAllCategories() {
    return periods.entries.map((entry) {
      return CategoryInfo(
        id: entry.key,
        name: _formatCategoryName(entry.key),
        days: entry.value,
        tier: getFreshnessTier(entry.key),
        guidance: getRefreshGuidance(entry.key),
      );
    }).toList()
      ..sort((a, b) => a.days.compareTo(b.days));
  }

  static String _formatCategoryName(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

/// Category information model
class CategoryInfo {
  final String id;
  final String name;
  final int days;
  final String tier;
  final String guidance;

  const CategoryInfo({
    required this.id,
    required this.name,
    required this.days,
    required this.tier,
    required this.guidance,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'days': days,
      'tier': tier,
      'guidance': guidance,
    };
  }
}
