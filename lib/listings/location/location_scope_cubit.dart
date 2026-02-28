// lib/listings/location/location_scope_cubit.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/location/location_scope_service.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';

/// State for LocationScopeCubit
class LocationScopeState extends Equatable {
  final LocationScope scope;
  final String? inferredCountry; // Country inferred from GPS
  final bool hasLocationPermission;
  final bool isLoading;
  final String? error;

  const LocationScopeState({
    required this.scope,
    this.inferredCountry,
    this.hasLocationPermission = false,
    this.isLoading = false,
    this.error,
  });

  LocationScopeState copyWith({
    LocationScope? scope,
    String? inferredCountry,
    bool? hasLocationPermission,
    bool? isLoading,
    String? error,
  }) {
    return LocationScopeState(
      scope: scope ?? this.scope,
      inferredCountry: inferredCountry ?? this.inferredCountry,
      hasLocationPermission: hasLocationPermission ?? this.hasLocationPermission,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get the effective country code for filtering/ranking
  String? get effectiveCountry => scope.getEffectiveCountry(inferredCountry: inferredCountry);

  @override
  List<Object?> get props => [scope, inferredCountry, hasLocationPermission, isLoading, error];
}

/// Cubit for managing location scope state and user interactions
class LocationScopeCubit extends Cubit<LocationScopeState> {
  final LocationScopeService _service;
  String? userId;
  Timer? _firestoreDebounceTimer;

  LocationScopeCubit({
    required LocationScopeService service,
    this.userId,
  })  : _service = service,
        super(const LocationScopeState(
          scope: LocationScope(),
          isLoading: true,
        ));

  /// Update userId (call when user logs in)
  void setUserId(String uid) {
    userId = uid;
  }

  /// Initialize location scope: load from local cache, then sync with Firestore
  Future<void> init() async {
    try {
      debugPrint('[LocationScopeCubit] Initializing...');
      emit(state.copyWith(isLoading: true));

      // Step 1: Load from local cache for fast UI
      final localScope = await _service.loadFromLocal();
      
      // Step 2: Load home country from Firestore (if user is logged in)
      String? homeCountry;
      if (userId != null) {
        homeCountry = await _service.getHomeCountry(userId!);
      }

      // Step 3: Merge local cache with home country
      LocationScope currentScope;
      if (localScope != null) {
        currentScope = localScope.copyWith(homeCountry: homeCountry);
        debugPrint('[LocationScopeCubit] Loaded from local cache');
      } else {
        // No local cache - use defaults with home country
        currentScope = LocationScope(
          mode: LocationScopeMode.local,
          homeCountry: homeCountry,
          selectedCountry: null, // Will fall back to homeCountry
          strictLocalOnly: false,
        );
        debugPrint('[LocationScopeCubit] No local cache, using defaults');
      }

      emit(state.copyWith(
        scope: currentScope,
        isLoading: false,
      ));

      // Step 4: Sync with Firestore in background (if user is logged in)
      if (userId != null) {
        _syncWithFirestore();
      }

      // Step 5: If mode is nearby, check location permission and infer country
      if (currentScope.mode == LocationScopeMode.nearby) {
        _checkLocationPermissionAndInfer();
      }
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeCubit] Error during init: $e');
      debugPrint(stackTrace.toString());
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to load location settings',
      ));
    }
  }

  /// Sync with Firestore (load remote settings and apply if more recent)
  Future<void> _syncWithFirestore() async {
    if (userId == null) return;

    try {
      final firestoreScope = await _service.loadFromFirestore(userId!);
      
      if (firestoreScope != null) {
        // Apply Firestore settings (assumes Firestore is source of truth)
        final mergedScope = firestoreScope.copyWith(
          homeCountry: firestoreScope.homeCountry ?? state.scope.homeCountry,
        );
        
        emit(state.copyWith(scope: mergedScope));
        
        // Also update local cache to match Firestore
        await _service.saveToLocal(mergedScope);
        
        debugPrint('[LocationScopeCubit] Synced with Firestore');
      }
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeCubit] Error syncing with Firestore: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Quick toggle between Caribbean and Local modes
  Future<void> toggleQuick() async {
    final currentMode = state.scope.mode;
    final newMode = currentMode == LocationScopeMode.caribbean
        ? LocationScopeMode.local
        : LocationScopeMode.caribbean;

    debugPrint('[LocationScopeCubit] Quick toggle: $currentMode -> $newMode');

    await setMode(newMode);
  }

  /// Set the location scope mode
  Future<void> setMode(LocationScopeMode mode) async {
    final newScope = state.scope.copyWith(mode: mode);
    await _updateScope(newScope);

    // If switching to nearby mode, check location permission
    if (mode == LocationScopeMode.nearby) {
      _checkLocationPermissionAndInfer();
    }
  }

  /// Set the selected country for local mode
  Future<void> setCountry(String? countryCode) async {
    // Validate country code
    if (countryCode != null && !CaribbeanCountries.isAllowedCode(countryCode)) {
      debugPrint('[LocationScopeCubit] Invalid country code: $countryCode');
      emit(state.copyWith(error: 'Invalid country code'));
      return;
    }

    final newScope = state.scope.copyWith(selectedCountry: countryCode);
    await _updateScope(newScope);
  }

  /// Set strict local only mode
  Future<void> setStrictLocalOnly(bool strict) async {
    final newScope = state.scope.copyWith(strictLocalOnly: strict);
    await _updateScope(newScope);
  }

  /// Use home country as selected country
  Future<void> useHomeCountry() async {
    final homeCountry = state.scope.homeCountry;
    if (homeCountry == null) {
      debugPrint('[LocationScopeCubit] No home country set');
      emit(state.copyWith(error: 'No home country available'));
      return;
    }

    await setCountry(homeCountry);
  }

  /// Request location permission and infer country from GPS
  Future<void> requestLocationPermissionAndInfer() async {
    try {
      debugPrint('[LocationScopeCubit] Requesting location permission...');

      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationScopeCubit] Location services are disabled');
        emit(state.copyWith(
          hasLocationPermission: false,
          error: 'Location services are disabled',
        ));
        // Fall back to local mode
        await setMode(LocationScopeMode.local);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationScopeCubit] Location permission denied');
          emit(state.copyWith(
            hasLocationPermission: false,
            error: 'Location permission denied',
          ));
          // Fall back to local mode
          await setMode(LocationScopeMode.local);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationScopeCubit] Location permission denied forever');
        emit(state.copyWith(
          hasLocationPermission: false,
          error: 'Location permission permanently denied. Please enable in settings.',
        ));
        // Fall back to local mode
        await setMode(LocationScopeMode.local);
        return;
      }

      // Permission granted, get location
      emit(state.copyWith(hasLocationPermission: true));
      await _inferCountryFromLocation();
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeCubit] Error requesting location permission: $e');
      debugPrint(stackTrace.toString());
      emit(state.copyWith(
        hasLocationPermission: false,
        error: 'Failed to access location',
      ));
    }
  }

  /// Check location permission status and infer country if granted
  Future<void> _checkLocationPermissionAndInfer() async {
    try {
      final permission = await Geolocator.checkPermission();
      final hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      emit(state.copyWith(hasLocationPermission: hasPermission));

      if (hasPermission) {
        await _inferCountryFromLocation();
      } else {
        debugPrint('[LocationScopeCubit] No location permission, requesting...');
        await requestLocationPermissionAndInfer();
      }
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeCubit] Error checking location permission: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Infer country from GPS location
  Future<void> _inferCountryFromLocation() async {
    try {
      debugPrint('[LocationScopeCubit] Inferring country from location...');

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      debugPrint('[LocationScopeCubit] Got position: ${position.latitude}, ${position.longitude}');

      // TODO: Implement reverse geocoding or country lookup from lat/lng
      // For now, we'll use a simple approximation based on Caribbean lat/lng bounds
      final inferredCountry = _inferCountryFromCoordinates(position.latitude, position.longitude);

      if (inferredCountry != null) {
        debugPrint('[LocationScopeCubit] Inferred country: $inferredCountry');
        emit(state.copyWith(inferredCountry: inferredCountry));
      } else {
        debugPrint('[LocationScopeCubit] Could not infer country from coordinates');
      }
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeCubit] Error inferring country from location: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Simple country inference from coordinates (basic approximation)
  /// In a production app, you'd use a proper reverse geocoding service
  String? _inferCountryFromCoordinates(double lat, double lng) {
    // Very rough approximations for some Caribbean countries
    // This is a placeholder - in production, use proper reverse geocoding
    
    // Jamaica
    if (lat >= 17.7 && lat <= 18.6 && lng >= -78.4 && lng <= -76.2) {
      return 'JM';
    }
    // Trinidad and Tobago
    if (lat >= 10.0 && lat <= 11.4 && lng >= -62.0 && lng <= -60.5) {
      return 'TT';
    }
    // Barbados  
    if (lat >= 13.0 && lat <= 13.4 && lng >= -59.7 && lng <= -59.4) {
      return 'BB';
    }
    // Puerto Rico
    if (lat >= 17.9 && lat <= 18.5 && lng >= -67.3 && lng <= -65.2) {
      return 'PR';
    }
    // Dominican Republic
    if (lat >= 17.5 && lat <= 19.9 && lng >= -72.0 && lng <= -68.3) {
      return 'DO';
    }
    // Haiti
    if (lat >= 18.0 && lat <= 20.1 && lng >= -74.5 && lng <= -71.6) {
      return 'HT';
    }
    // Cuba
    if (lat >= 19.8 && lat <= 23.3 && lng >= -85.0 && lng <= -74.0) {
      return 'CU';
    }
    // Bahamas
    if (lat >= 20.9 && lat <= 27.3 && lng >= -79.3 && lng <= -72.7) {
      return 'BS';
    }

    // If not found, return null (will fall back to selected or home country)
    return null;
  }

  /// Internal method to update scope and persist changes
  Future<void> _updateScope(LocationScope newScope) async {
    emit(state.copyWith(scope: newScope, error: null));

    // Save to local cache immediately
    await _service.saveToLocal(newScope);

    // Debounce Firestore writes to avoid spam
    if (userId != null) {
      _firestoreDebounceTimer?.cancel();
      _firestoreDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _service.saveToFirestore(userId!, newScope).catchError((e) {
          debugPrint('[LocationScopeCubit] Error saving to Firestore: $e');
        });
      });
    }
  }

  @override
  Future<void> close() {
    _firestoreDebounceTimer?.cancel();
    return super.close();
  }
}
