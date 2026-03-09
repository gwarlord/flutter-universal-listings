import 'package:equatable/equatable.dart';
import 'search_filter.dart';

/// AI interpretation of a search query
class SearchInterpretation extends Equatable {
  final String intent;
  final String contentType;
  final SearchFilters filters;
  final String naturalLanguageSummary;
  final List<String>? suggestedRefinements;

  const SearchInterpretation({
    required this.intent,
    required this.contentType,
    required this.filters,
    required this.naturalLanguageSummary,
    this.suggestedRefinements,
  });

  factory SearchInterpretation.fromJson(Map<String, dynamic> json) {
    final intentRaw = json['intent'];
    final contentTypeRaw = json['contentType'];
    final summaryRaw = json['naturalLanguageSummary'];

    final filtersRaw = json['filters'];
    final filtersMap = filtersRaw is Map<String, dynamic>
      ? filtersRaw
      : <String, dynamic>{};

    final suggestedRaw = json['suggestedRefinements'];
    final suggested = suggestedRaw is List
      ? suggestedRaw.map((e) => e.toString()).toList()
      : null;

    return SearchInterpretation(
      intent: intentRaw is String ? intentRaw : (intentRaw?.toString() ?? 'browse'),
      contentType: contentTypeRaw is String
        ? contentTypeRaw
        : (contentTypeRaw?.toString() ?? 'listing'),
      filters: SearchFilters.fromJson(filtersMap),
      naturalLanguageSummary:
        summaryRaw is String ? summaryRaw : (summaryRaw?.toString() ?? ''),
      suggestedRefinements: suggested,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'contentType': contentType,
      'filters': filters.toJson(),
      'naturalLanguageSummary': naturalLanguageSummary,
      if (suggestedRefinements != null) 'suggestedRefinements': suggestedRefinements,
    };
  }

  SearchInterpretation copyWith({
    String? intent,
    String? contentType,
    SearchFilters? filters,
    String? naturalLanguageSummary,
    List<String>? suggestedRefinements,
  }) {
    return SearchInterpretation(
      intent: intent ?? this.intent,
      contentType: contentType ?? this.contentType,
      filters: filters ?? this.filters,
      naturalLanguageSummary: naturalLanguageSummary ?? this.naturalLanguageSummary,
      suggestedRefinements: suggestedRefinements ?? this.suggestedRefinements,
    );
  }

  @override
  List<Object?> get props => [
        intent,
        contentType,
        filters,
        naturalLanguageSummary,
        suggestedRefinements,
      ];
}
