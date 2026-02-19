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
    return SearchInterpretation(
      intent: json['intent'] as String? ?? 'browse',
      contentType: json['contentType'] as String? ?? 'listing',
      filters: json['filters'] != null
          ? SearchFilters.fromJson(json['filters'] as Map<String, dynamic>)
          : const SearchFilters(),
      naturalLanguageSummary: json['naturalLanguageSummary'] as String? ?? '',
      suggestedRefinements: (json['suggestedRefinements'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
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
