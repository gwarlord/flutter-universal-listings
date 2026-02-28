import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caribtap/listings/ai_search/models/search_interpretation.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';
import 'package:caribtap/listings/ai_search/models/saved_search.dart';
import 'package:caribtap/listings/ai_search/services/ai_interpretation_service.dart';
import 'package:caribtap/listings/ai_search/services/search_rate_limit_service.dart';
import 'package:caribtap/listings/ai_search/services/geolocation_service.dart';

/// Custom Exception for when the AI search fails and fallback is used
class AiSearchFallbackException implements Exception {
  final String message;
  final dynamic originalException;
  AiSearchFallbackException(this.message, this.originalException);
}

/// Repository for AI-assisted search operations
class AiSearchRepository {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final AiInterpretationService _aiService;
  final SearchRateLimitService _rateLimitService;
  final GeolocationService _geoService;

  AiSearchRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    AiInterpretationService? aiService,
    SearchRateLimitService? rateLimitService,
    GeolocationService? geoService,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _aiService = aiService ?? AiInterpretationService(),
        _rateLimitService = rateLimitService ?? SearchRateLimitService(),
        _geoService = geoService ?? GeolocationService();

  /// Perform AI-assisted search
  Future<List<SearchResult>> search({
    required String query,
    required String userId,
    String contentType = 'listing',
    Map<String, dynamic>? userContext,
  }) async {
    try {
      // 1. Interpret query with AI
      final interpretation = await _aiService.interpretQuery(
        query,
        contentType: contentType,
        userContext: userContext,
      );

      // 2. Get location if needed
      var updatedInterpretation = interpretation;
      if (interpretation.filters.location.useUserLocation) {
        final position = await _geoService.getCurrentLocation();
        if (position != null) {
          updatedInterpretation = interpretation.copyWith(
            filters: interpretation.filters.copyWith(
              location: interpretation.filters.location.copyWith(
                latitude: position.latitude,
                longitude: position.longitude,
              ),
            ),
          );
        }
      }

      // 3. Execute search with Cloud Function (REST HTTPS)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to perform search.');
      }
      final idToken = await user.getIdToken();

      try {
        final searchUrl = 'https://us-central1-caribtap.cloudfunctions.net/searchListingsRest';
        final response = await http.post(
          Uri.parse(searchUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'interpretation': updatedInterpretation.toJson(),
            'contentType': contentType,
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final results = (data['results'] as List<dynamic>?)
                  ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];

          print('✅ Search complete: ${results.length} results');
          return results;
        } else {
            throw Exception('Cloud function failed with status code: ${response.statusCode}');
        }
      } catch (funcError) {
        print('⚠️ Cloud Function search failed: $funcError. Falling back to direct search.');
        // Instead of continuing, we throw a specific exception
        throw AiSearchFallbackException(
            'AI search failed, falling back to keyword search.', funcError);
      }
    } catch (e) {
      if (e is AiSearchFallbackException) {
        rethrow; // rethrow our custom exception
      }
      print('❌ Search error: $e');
      // For other errors, we can also wrap them or rethrow
      rethrow;
    }
  }

  /// Get saved searches for user
  Future<List<SavedSearch>> getSavedSearches(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('saved_searches')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => SavedSearch.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting saved searches: $e');
      return [];
    }
  }

  /// Save a search
  Future<void> saveSearch({
    required String userId,
    required String name,
    required String query,
    required SearchInterpretation interpretation,
    bool notificationsEnabled = false,
  }) async {
    try {
      await _firestore.collection('saved_searches').add({
        'userId': userId,
        'name': name,
        'originalQuery': query,
        'interpretation': interpretation.toJson(),
        'notificationsEnabled': notificationsEnabled,
        'createdAt': FieldValue.serverTimestamp(),
        'lastRunAt': FieldValue.serverTimestamp(),
        'matchCountAtLastRun': 0,
      });

      print('✅ Search saved: $name');
    } catch (e) {
      print('❌ Error saving search: $e');
      rethrow;
    }
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String searchId) async {
    try {
      await _firestore.collection('saved_searches').doc(searchId).delete();
      print('✅ Saved search deleted');
    } catch (e) {
      print('❌ Error deleting saved search: $e');
      rethrow;
    }
  }

  /// Update saved search notifications
  Future<void> updateSavedSearchNotifications(
    String searchId,
    bool enabled,
  ) async {
    try {
      await _firestore.collection('saved_searches').doc(searchId).update({
        'notificationsEnabled': enabled,
      });
      print('✅ Notifications updated for saved search');
    } catch (e) {
      print('❌ Error updating notifications: $e');
      rethrow;
    }
  }

  /// Check rate limit for user
  Future<RateLimitResult> checkRateLimit(String userId) async {
    return _rateLimitService.checkLimit(userId);
  }

  /// Get user's subscription tier
  Future<String> getUserTier(String userId) async {
    return _rateLimitService.getUserTier(userId);
  }
}
