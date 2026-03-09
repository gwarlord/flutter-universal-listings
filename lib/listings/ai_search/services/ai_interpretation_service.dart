import 'package:caribtap/listings/ai_search/models/search_interpretation.dart';
import 'package:caribtap/listings/ai_search/models/search_filter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for AI interpretation of search queries using a direct HTTPS call.
class AiInterpretationService {
  final Map<String, SearchInterpretation> _cache = {};
  // URL points to the new, cleanly named Cloud Function.
  final String _cloudFunctionUrl =
      'https://us-central1-caribtap.cloudfunctions.net/processSearchQuery';

  AiInterpretationService();

  /// Interpret a natural language search query using the simplified AI backend.
  Future<SearchInterpretation> interpretQuery(
    String query, {
    String contentType = 'listing',
    Map<String, dynamic>? userContext,
  }) async {
    final cacheKey = '$query:$contentType';
    if (_cache.containsKey(cacheKey)) {
      print('✅ Using cached interpretation for: $query');
      return _cache[cacheKey]!;
    }

    try {
      print('🤖 Interpreting query with AI (HTTPS): $query');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to use AI Search.');
      }
      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'query': query}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final interpretation = SearchInterpretation.fromJson(
          data['interpretation'] as Map<String, dynamic>,
        );

        _cache[cacheKey] = interpretation;
        print('✅ AI interpretation complete (via HTTPS)');
        return interpretation;
      } else if (response.statusCode == 429) {
        // Handle rate limit specifically and parse details from the body.
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw RateLimitException(
          message: data['error'] ?? 'Rate limit exceeded',
          details: data['details'] as Map<String, dynamic>?,
        );
      } else {
        print('❌ API error: ${response.statusCode} - ${response.body}');
        // Graceful fallback: keep search usable if AI backend is unavailable.
        return _fallbackInterpretation(query, contentType);
      }
    } catch (e) {
      print('❌ Error interpreting query: $e');
      return _fallbackInterpretation(query, contentType);
    }
  }

  void clearCache() {
    _cache.clear();
  }

  SearchInterpretation _fallbackInterpretation(
    String query,
    String contentType,
  ) {
    final normalized = query.trim();
    final keywords =
        normalized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final interpretation = SearchInterpretation(
      intent: 'find',
      contentType: contentType,
      filters: SearchFilters(
        keywords: keywords.isEmpty ? [normalized] : keywords,
      ),
      naturalLanguageSummary: normalized,
      suggestedRefinements: const [],
    );
    _cache['$query:$contentType'] = interpretation;
    return interpretation;
  }
}

/// Custom exception for rate limit errors.
class RateLimitException implements Exception {
  final String message;
  final Map<String, dynamic>? details;

  RateLimitException({required this.message, this.details});

  int? get retryAfter => details?['retryAfter'] as int?;
  int? get limit => details?['limit'] as int?;
  int? get remaining => details?['remaining'] as int?;

  @override
  String toString() =>
      'RateLimitException: $message (limit: $limit, remaining: $remaining)';
}
