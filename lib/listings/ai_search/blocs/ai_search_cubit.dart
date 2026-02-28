import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/ai_search/blocs/ai_search_state.dart';
import 'package:caribtap/listings/ai_search/repositories/ai_search_repository.dart';
import 'package:caribtap/listings/ai_search/models/search_filter.dart';
import 'package:caribtap/listings/ai_search/models/search_interpretation.dart' as models;
import 'package:caribtap/listings/ai_search/services/ai_interpretation_service.dart';
import 'package:caribtap/listings/listings_module/search/search_bloc.dart';

/// Cubit for managing AI search feature
class AiSearchCubit extends Cubit<AiSearchState> {
  final AiSearchRepository _repository;
  final String userId;
  final SearchBloc? _keywordSearchBloc;

  AiSearchCubit({
    required this.userId,
    AiSearchRepository? repository,
    SearchBloc? keywordSearchBloc,
  })  : _repository = repository ?? AiSearchRepository(),
        _keywordSearchBloc = keywordSearchBloc,
        super(const AiSearchInitial());

  /// Perform AI-assisted search
  Future<void> search(
    String query, {
    String contentType = 'listing',
  }) async {
    if (query.trim().isEmpty) {
      emit(const AiSearchError(message: 'Please enter a search query'));
      return;
    }

    emit(const AiSearchLoading(message: 'Searching...'));

    try {
      // Check rate limit first
      final rateLimit = await _repository.checkRateLimit(userId);
      if (!rateLimit.allowed) {
        emit(AiSearchRateLimitExceeded(
          message: rateLimit.reason ?? 'Rate limit exceeded',
          remaining: rateLimit.remaining,
          upgradeMessage: rateLimit.upgradeMessage,
          originalQuery: query,
        ));
        return;
      }

      // Perform AI search
      final results = await _repository.search(
        query: query,
        userId: userId,
        contentType: contentType,
      );

      // Results include interpretation in metadata
      // For now, create a simple interpretation summary
      final interpretation = models.SearchInterpretation(
        intent: 'browse',
        contentType: contentType,
        filters: const SearchFilters(),
        naturalLanguageSummary: 'Showing results for "$query"',
      );

      emit(AiSearchLoaded(
        results: results,
        interpretation: interpretation,
        originalQuery: query,
        hasMore: results.length >= 50, // Pagination threshold
      ));
    } on RateLimitException catch (e) {
      emit(AiSearchRateLimitExceeded(
        message: e.message,
        remaining: e.remaining ?? 0,
        upgradeMessage: 'Upgrade to Professional for more searches',
        originalQuery: query,
      ));
    } on AiSearchFallbackException catch (e) {
        print('🔄 Falling back to keyword search due to: ${e.originalException}');
        if (_keywordSearchBloc != null) {
            // Dispatch event to keyword search bloc
            _keywordSearchBloc!.add(SearchListingsEvent(query: query));
            emit(AiSearchError(
                message: 'AI Search is unavailable. Switched to keyword search.',
                originalQuery: query,
                isFallback: true,
                canRetry: true,
            ));
        } else {
            emit(AiSearchError(
                message: 'AI Search failed and no fallback is available.',
                originalQuery: query,
                canRetry: true,
            ));
        }
    }
    catch (e) {
      print('❌ Search error in cubit: $e');

      emit(AiSearchError(
        message: 'Failed to search. Please try again.',
        canRetry: true,
        originalQuery: query,
      ));
    }
  }

  /// Refine current search with additional filters
  Future<void> refine({
    String? category,
    PriceRange? priceRange,
    bool? openNow,
    bool? delivery,
    bool? verified,
    double? minRating,
  }) async {
    final currentState = state;
    if (currentState is! AiSearchLoaded) {
      return;
    }

    emit(const AiSearchLoading(message: 'Refining search...'));

    try {
      // Update filters
      final updatedFilters = currentState.interpretation.filters.copyWith(
        category: category ?? currentState.interpretation.filters.category,
        priceRange: priceRange ?? currentState.interpretation.filters.priceRange,
        openNow: openNow ?? currentState.interpretation.filters.openNow,
        delivery: delivery ?? currentState.interpretation.filters.delivery,
        verified: verified ?? currentState.interpretation.filters.verified,
        minRating: minRating ?? currentState.interpretation.filters.minRating,
      );

      final updatedInterpretation = currentState.interpretation.copyWith(
        filters: updatedFilters,
      );

      // Re-search with updated interpretation
      final results = await _repository.search(
        query: currentState.originalQuery,
        userId: userId,
        userContext: {'refinement': true},
      );

      emit(AiSearchLoaded(
        results: results,
        interpretation: updatedInterpretation,
        originalQuery: currentState.originalQuery,
        hasMore: results.length >= 50,
      ));
    } catch (e) {
      print('❌ Refine error: $e');
      // Restore previous state
      emit(currentState);
    }
  }

  /// Reset to initial state
  void reset() {
    emit(const AiSearchInitial());
  }

  /// Retry last failed search
  void retry() {
    if (state is AiSearchError) {
      final errorState = state as AiSearchError;
      if (errorState.originalQuery != null) {
        search(errorState.originalQuery!);
      }
    } else if (state is AiSearchRateLimitExceeded) {
      final rateLimitState = state as AiSearchRateLimitExceeded;
      search(rateLimitState.originalQuery);
    }
  }
}

/// Cubit for managing saved searches
class SavedSearchesCubit extends Cubit<SavedSearchesState> {
  final AiSearchRepository _repository;
  final String userId;

  SavedSearchesCubit({
    required this.userId,
    AiSearchRepository? repository,
  })  : _repository = repository ?? AiSearchRepository(),
        super(const SavedSearchesInitial());

  /// Load saved searches for user
  Future<void> loadSavedSearches() async {
    emit(const SavedSearchesLoading());

    try {
      final searches = await _repository.getSavedSearches(userId);
      emit(SavedSearchesLoaded(searches: searches));
    } catch (e) {
      print('❌ Error loading saved searches: $e');
      emit(const SavedSearchesError(message: 'Failed to load saved searches'));
    }
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String searchId) async {
    try {
      await _repository.deleteSavedSearch(searchId);
      await loadSavedSearches(); // Reload list
    } catch (e) {
      print('❌ Error deleting saved search: $e');
      emit(const SavedSearchesError(message: 'Failed to delete saved search'));
    }
  }

  /// Toggle notifications for a saved search
  Future<void> toggleNotifications(String searchId, bool enabled) async {
    try {
      await _repository.updateSavedSearchNotifications(searchId, enabled);
      await loadSavedSearches(); // Reload list
    } catch (e) {
      print('❌ Error updating notifications: $e');
    }
  }
}
