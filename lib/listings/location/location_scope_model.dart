// lib/listings/location/location_scope_model.dart

/// Represents the three main modes for filtering content by geographic scope
enum LocationScopeMode {
  /// Show content from user's selected or home country (with soft or strict filtering)
  local,
  
  /// Show content from all Caribbean countries
  caribbean,
  
  /// Show content based on user's GPS location (with fallback to local/home)
  nearby,
}

extension LocationScopeModeExtension on LocationScopeMode {
  String toJson() {
    switch (this) {
      case LocationScopeMode.local:
        return 'local';
      case LocationScopeMode.caribbean:
        return 'caribbean';
      case LocationScopeMode.nearby:
        return 'nearby';
    }
  }

  static LocationScopeMode fromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'local':
        return LocationScopeMode.local;
      case 'caribbean':
        return LocationScopeMode.caribbean;
      case 'nearby':
        return LocationScopeMode.nearby;
      default:
        return LocationScopeMode.local; // Default to local
    }
  }
}

/// Encapsulates all location scope settings for filtering content
class LocationScope {
  /// Current scope mode
  final LocationScopeMode mode;
  
  /// User's home country from signup (ISO-2 code)
  final String? homeCountry;
  
  /// Currently selected country for local mode (ISO-2 code)
  /// Falls back to homeCountry if null
  final String? selectedCountry;
  
  /// Whether to use strict filtering (hard filter) or soft ranking
  /// Only applicable in local mode
  final bool strictLocalOnly;

  const LocationScope({
    this.mode = LocationScopeMode.local,
    this.homeCountry,
    this.selectedCountry,
    this.strictLocalOnly = false,
  });

  /// Get the effective country code to use for filtering/ranking
  /// Returns null if mode is caribbean (show all countries)
  String? getEffectiveCountry({String? inferredCountry}) {
    switch (mode) {
      case LocationScopeMode.caribbean:
        return null; // No country filter in Caribbean mode
        
      case LocationScopeMode.local:
        return selectedCountry ?? homeCountry;
        
      case LocationScopeMode.nearby:
        // Try inferred country from GPS, fall back to selected or home
        return inferredCountry ?? selectedCountry ?? homeCountry;
    }
  }

  /// Check if this scope represents "show all" (Caribbean mode)
  bool get isShowingAll => mode == LocationScopeMode.caribbean;

  /// Check if we should apply strict filtering (hard country == filter)
  bool get shouldApplyStrictFilter => mode == LocationScopeMode.local && strictLocalOnly;

  /// Get display label for current scope
  String getDisplayLabel({String? countryName}) {
    switch (mode) {
      case LocationScopeMode.caribbean:
        return 'Caribbean';
      case LocationScopeMode.local:
        return countryName ?? selectedCountry ?? homeCountry ?? 'Local';
      case LocationScopeMode.nearby:
        return 'Nearby';
    }
  }

  LocationScope copyWith({
    LocationScopeMode? mode,
    String? homeCountry,
    String? selectedCountry,
    bool? strictLocalOnly,
  }) {
    return LocationScope(
      mode: mode ?? this.mode,
      homeCountry: homeCountry ?? this.homeCountry,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      strictLocalOnly: strictLocalOnly ?? this.strictLocalOnly,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationScopeMode': mode.toJson(),
      'homeCountry': homeCountry,
      'selectedCountry': selectedCountry,
      'strictLocalOnly': strictLocalOnly,
    };
  }

  factory LocationScope.fromJson(Map<String, dynamic> json) {
    return LocationScope(
      mode: LocationScopeModeExtension.fromJson(json['locationScopeMode'] as String?),
      homeCountry: json['homeCountry'] as String?,
      selectedCountry: json['selectedCountry'] as String?,
      strictLocalOnly: json['strictLocalOnly'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationScope &&
        other.mode == mode &&
        other.homeCountry == homeCountry &&
        other.selectedCountry == selectedCountry &&
        other.strictLocalOnly == strictLocalOnly;
  }

  @override
  int get hashCode {
    return Object.hash(mode, homeCountry, selectedCountry, strictLocalOnly);
  }
}
