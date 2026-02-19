import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/ai_search/models/search_interpretation.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';
import 'package:caribtap/listings/ai_search/models/saved_search.dart';
import 'package:caribtap/listings/ai_search/services/ai_interpretation_service.dart';
import 'package:caribtap/listings/ai_search/services/search_rate_limit_service.dart';
import 'package:caribtap/listings/ai_search/services/geolocation_service.dart';

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

      // 3. Execute search with Cloud Function
      final callable = _functions.httpsCallable('searchListings');
      final result = await callable.call<Map<String, dynamic>>({
        'interpretation': updatedInterpretation.toJson(),
        'contentType': contentType,
      });

      final data = result.data;
      final results = (data['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      print('✅ Search complete: ${results.length} results');
      return results;
    } catch (e) {
      print('❌ Search error: $e');
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
