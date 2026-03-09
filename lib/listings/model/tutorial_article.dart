import 'package:flutter/foundation.dart';

@immutable
class TutorialArticle {
  final String id;
  final String title;
  final String category;
  final String summary;
  final String whatThisDoes;
  final String whoShouldUseIt;
  final List<String> steps;
  final List<String> tips;
  final List<String> commonIssues;

  const TutorialArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.whatThisDoes,
    required this.whoShouldUseIt,
    required this.steps,
    required this.tips,
    required this.commonIssues,
  });

  TutorialArticle copyWith({
    String? id,
    String? title,
    String? category,
    String? summary,
    String? whatThisDoes,
    String? whoShouldUseIt,
    List<String>? steps,
    List<String>? tips,
    List<String>? commonIssues,
  }) {
    return TutorialArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      summary: summary ?? this.summary,
      whatThisDoes: whatThisDoes ?? this.whatThisDoes,
      whoShouldUseIt: whoShouldUseIt ?? this.whoShouldUseIt,
      steps: steps ?? this.steps,
      tips: tips ?? this.tips,
      commonIssues: commonIssues ?? this.commonIssues,
    );
  }
}
