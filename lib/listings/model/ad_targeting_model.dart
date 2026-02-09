import 'package:cloud_firestore/cloud_firestore.dart';

/// Targeting configuration for advertisement delivery
class AdTargeting {
  /// Target specific countries (empty = all countries)
  final List<String> locations;
  
  /// Target specific categories (empty = all categories)
  final List<String> categories;
  
  /// Audience type filters
  final List<String> audienceTypes;
  
  /// Minimum age (null = no minimum)
  final int? ageMin;
  
  /// Maximum age (null = no maximum)
  final int? ageMax;
  
  /// Target genders (empty or ["all"] = all genders)
  final List<String> genders;
  
  /// Keywords to match user interests/search history
  final List<String> includeKeywords;
  
  /// Keywords to exclude from targeting
  final List<String> excludeKeywords;

  /// Alias for audienceTypes for easier access
  List<String> get audience => audienceTypes;

  const AdTargeting({
    this.locations = const [],
    this.categories = const [],
    this.audienceTypes = const ['ALL'],
    this.ageMin,
    this.ageMax,
    this.genders = const [],
    this.includeKeywords = const [],
    this.excludeKeywords = const [],
  });

  /// Creates an instance with no targeting restrictions (all users)
  factory AdTargeting.all() => const AdTargeting(
    audienceTypes: ['ALL'],
  );

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() => {
    'locations': locations,
    'categories': categories,
    'audienceTypes': audienceTypes,
    'ageMin': ageMin,
    'ageMax': ageMax,
    'genders': genders,
    'includeKeywords': includeKeywords,
    'excludeKeywords': excludeKeywords,
  };

  /// Create from Firestore document
  factory AdTargeting.fromMap(Map<String, dynamic> map) {
    return AdTargeting(
      locations: List<String>.from(map['locations'] ?? []),
      categories: List<String>.from(map['categories'] ?? []),
      audienceTypes: List<String>.from(map['audienceTypes'] ?? ['ALL']),
      ageMin: map['ageMin'] as int?,
      ageMax: map['ageMax'] as int?,
      genders: List<String>.from(map['genders'] ?? []),
      includeKeywords: List<String>.from(map['includeKeywords'] ?? []),
      excludeKeywords: List<String>.from(map['excludeKeywords'] ?? []),
    );
  }

  /// Generate a human-readable summary of targeting
  String getSummary() {
    final parts = <String>[];
    
    if (audienceTypes.contains('ALL')) {
      parts.add('All Users');
    } else {
      if (audienceTypes.contains('INTEREST_BASED')) parts.add('Interest-based');
      if (audienceTypes.contains('NEAR_ME')) parts.add('Nearby users');
      if (audienceTypes.contains('SIMILAR_VIEWERS')) parts.add('Similar viewers');
      if (audienceTypes.contains('FAVORITES')) parts.add('Users who favorite');
    }
    
    if (locations.isNotEmpty) {
      parts.add('${locations.length} location${locations.length > 1 ? 's' : ''}');
    }
    
    if (categories.isNotEmpty) {
      parts.add('${categories.length} categor${categories.length > 1 ? 'ies' : 'y'}');
    }
    
    if (ageMin != null || ageMax != null) {
      if (ageMin != null && ageMax != null) {
        parts.add('Ages $ageMin-$ageMax');
      } else if (ageMin != null) {
        parts.add('Ages $ageMin+');
      } else if (ageMax != null) {
        parts.add('Ages up to $ageMax');
      }
    }
    
    if (genders.isNotEmpty && !genders.contains('all')) {
      parts.add(genders.join(', '));
    }
    
    return parts.isEmpty ? 'All Users' : parts.join(' • ');
  }

  /// Check if this targeting is unrestricted (targets all users)
  bool get isUnrestricted {
    return audienceTypes.contains('ALL') &&
        locations.isEmpty &&
        categories.isEmpty &&
        ageMin == null &&
        ageMax == null &&
        (genders.isEmpty || genders.contains('all')) &&
        includeKeywords.isEmpty;
  }

  /// Creates a copy with modified fields
  AdTargeting copyWith({
    List<String>? locations,
    List<String>? categories,
    List<String>? audienceTypes,
    int? ageMin,
    int? ageMax,
    List<String>? genders,
    List<String>? includeKeywords,
    List<String>? excludeKeywords,
  }) {
    return AdTargeting(
      locations: locations ?? this.locations,
      categories: categories ?? this.categories,
      audienceTypes: audienceTypes ?? this.audienceTypes,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      genders: genders ?? this.genders,
      includeKeywords: includeKeywords ?? this.includeKeywords,
      excludeKeywords: excludeKeywords ?? this.excludeKeywords,
    );
  }
}

/// Predefined audience type constants
class AudienceType {
  static const String all = 'ALL';
  static const String interestBased = 'INTEREST_BASED';
  static const String nearMe = 'NEAR_ME';
  static const String similarViewers = 'SIMILAR_VIEWERS';
  static const String favorites = 'FAVORITES';
  
  static const List<String> allTypes = [
    all,
    interestBased,
    nearMe,
    similarViewers,
    favorites,
  ];
  
  static String getDisplayName(String type) {
    switch (type) {
      case all:
        return 'All Users';
      case interestBased:
        return 'Interest-based (viewed similar listings)';
      case nearMe:
        return 'Users near selected locations';
      case similarViewers:
        return 'People who viewed similar content';
      case favorites:
        return 'Users who favorite listings';
      default:
        return type;
    }
  }
}
