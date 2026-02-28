// lib/listings/location/location_scope_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';

/// Service for persisting and loading location scope preferences
/// Handles both local cache (SharedPreferences) and remote storage (Firestore)
class LocationScopeService {
  static const String _keyMode = 'location_scope_mode';
  static const String _keySelectedCountry = 'location_scope_selected_country';
  static const String _keyStrictLocalOnly = 'location_scope_strict_local_only';
  static const String _keyLastUpdated = 'location_scope_last_updated_epoch';

  final FirebaseFirestore _firestore;
  SharedPreferences? _prefs;

  LocationScopeService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize SharedPreferences (call during app startup)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Load location scope from local SharedPreferences cache
  /// Returns null if no cached data exists
  Future<LocationScope?> loadFromLocal() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      final modeStr = _prefs!.getString(_keyMode);
      if (modeStr == null) return null; // No cached data

      final mode = LocationScopeModeExtension.fromJson(modeStr);
      final selectedCountry = _prefs!.getString(_keySelectedCountry);
      final strictLocalOnly = _prefs!.getBool(_keyStrictLocalOnly) ?? false;

      debugPrint('[LocationScopeService] Loaded from local: mode=$mode, country=$selectedCountry, strict=$strictLocalOnly');

      return LocationScope(
        mode: mode,
        selectedCountry: selectedCountry,
        strictLocalOnly: strictLocalOnly,
        // homeCountry is loaded from Firestore user profile
      );
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error loading from local: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Save location scope to local SharedPreferences cache
  Future<void> saveToLocal(LocationScope scope) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      await Future.wait([
        _prefs!.setString(_keyMode, scope.mode.toJson()),
        _prefs!.setString(_keySelectedCountry, scope.selectedCountry ?? ''),
        _prefs!.setBool(_keyStrictLocalOnly, scope.strictLocalOnly),
        _prefs!.setInt(_keyLastUpdated, DateTime.now().millisecondsSinceEpoch),
      ]);

      debugPrint('[LocationScopeService] Saved to local: mode=${scope.mode}, country=${scope.selectedCountry}, strict=${scope.strictLocalOnly}');
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error saving to local: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Load location scope settings from Firestore user profile
  /// Returns null if user document doesn't exist or has no location scope data
  Future<LocationScope?> loadFromFirestore(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        debugPrint('[LocationScopeService] User document does not exist for uid: $uid');
        return null;
      }

      final data = userDoc.data();
      if (data == null) return null;

      // Extract location scope fields
      final modeStr = data['locationScopeMode'] as String?;
      final homeCountry = data['homeCountry'] as String?;
      final selectedCountry = data['selectedCountry'] as String?;
      final strictLocalOnly = data['strictLocalOnly'] as bool? ?? false;

      // If no mode is set in Firestore, return null (use defaults)
      if (modeStr == null) {
        debugPrint('[LocationScopeService] No location scope data in Firestore for uid: $uid');
        return null;
      }

      final mode = LocationScopeModeExtension.fromJson(modeStr);

      debugPrint('[LocationScopeService] Loaded from Firestore: mode=$mode, home=$homeCountry, selected=$selectedCountry, strict=$strictLocalOnly');

      return LocationScope(
        mode: mode,
        homeCountry: homeCountry,
        selectedCountry: selectedCountry,
        strictLocalOnly: strictLocalOnly,
      );
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error loading from Firestore: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Save location scope settings to Firestore user profile
  /// Uses debounced writes to avoid spam (caller should debounce)
  Future<void> saveToFirestore(String uid, LocationScope scope) async {
    try {
      final updates = <String, dynamic>{
        'locationScopeMode': scope.mode.toJson(),
        'selectedCountry': scope.selectedCountry,
        'strictLocalOnly': scope.strictLocalOnly,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only update homeCountry if it's set (don't overwrite with null)
      if (scope.homeCountry != null) {
        updates['homeCountry'] = scope.homeCountry;
      }

      await _firestore.collection('users').doc(uid).update(updates);

      debugPrint('[LocationScopeService] Saved to Firestore: mode=${scope.mode}, selected=${scope.selectedCountry}, strict=${scope.strictLocalOnly}');
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error saving to Firestore: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Get home country from Firestore user profile
  /// This is typically set during signup and should not change
  Future<String?> getHomeCountry(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) return null;

      final data = userDoc.data();
      if (data == null) return null;

      // Try both homeCountry and countryCode fields (for backwards compatibility)
      return data['homeCountry'] as String? ?? data['countryCode'] as String?;
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error getting home country: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Set home country in Firestore (typically called during signup)
  Future<void> setHomeCountry(String uid, String countryCode) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'homeCountry': countryCode,
        'countryCode': countryCode, // Also update countryCode for backwards compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[LocationScopeService] Set home country: $countryCode');
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error setting home country: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  /// Clear all local cached data
  Future<void> clearLocalCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      await Future.wait([
        _prefs!.remove(_keyMode),
        _prefs!.remove(_keySelectedCountry),
        _prefs!.remove(_keyStrictLocalOnly),
        _prefs!.remove(_keyLastUpdated),
      ]);

      debugPrint('[LocationScopeService] Cleared local cache');
    } catch (e, stackTrace) {
      debugPrint('[LocationScopeService] Error clearing local cache: $e');
      debugPrint(stackTrace.toString());
    }
  }
}
