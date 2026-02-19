import 'package:equatable/equatable.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';
import 'package:caribtap/listings/ai_search/models/search_interpretation.dart';
import 'package:caribtap/listings/ai_search/models/saved_search.dart';

/// Base state for AI search
abstract class AiSearchState extends Equatable {
  const AiSearchState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AiSearchInitial extends AiSearchState {
  const AiSearchInitial();
}

/// Loading state
class AiSearchLoading extends AiSearchState {
  final String? message;

  const AiSearchLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// Loaded state with results
class AiSearchLoaded extends AiSearchState {
  final List<SearchResult> results;
  final SearchInterpretation interpretation;
  final String originalQuery;
  final bool hasMore;

  const AiSearchLoaded({
    required this.results,
    required this.interpretation,
    required this.originalQuery,
    this.hasMore = false,
  });

  AiSearchLoaded copyWith({
    List<SearchResult>? results,
    SearchInterpretation? interpretation,
    String? originalQuery,
    bool? hasMore,
  }) {
    return AiSearchLoaded(
      results: results ?? this.results,
      interpretation: interpretation ?? this.interpretation,
      originalQuery: originalQuery ?? this.originalQuery,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  List<Object?> get props => [results, interpretation, originalQuery, hasMore];
}

/// Error state
class AiSearchError extends AiSearchState {
  final String message;
  final bool canRetry;
  final String? originalQuery;

  const AiSearchError({
    required this.message,
    this.canRetry = true,
    this.originalQuery,
  });

  @override
  List<Object?> get props => [message, canRetry, originalQuery];
}

/// Rate limit exceeded state
class AiSearchRateLimitExceeded extends AiSearchState {
  final String message;
  final int remaining;
  final String? upgradeMessage;
  final String originalQuery;

  const AiSearchRateLimitExceeded({
    required this.message,
    required this.remaining,
    this.upgradeMessage,
    required this.originalQuery,
  });

  @override
  List<Object?> get props => [message, remaining, upgradeMessage, originalQuery];
}

// ===== Saved Searches States =====

/// Saved searches base state
abstract class SavedSearchesState extends Equatable {
  const SavedSearchesState();

  @override
  List<Object?> get props => [];
}

/// Initial state for saved searches
class SavedSearchesInitial extends SavedSearchesState {
  const SavedSearchesInitial();
}

/// Loading saved searches
class SavedSearchesLoading extends SavedSearchesState {
  const SavedSearchesLoading();
}

/// Saved searches loaded
class SavedSearchesLoaded extends SavedSearchesState {
  final List<SavedSearch> searches;

  const SavedSearchesLoaded({required this.searches});

  @override
  List<Object?> get props => [searches];
}

/// Error loading saved searches
class SavedSearchesError extends SavedSearchesState {
  final String message;

  const SavedSearchesError({required this.message});

  @override
  List<Object?> get props => [message];
}
