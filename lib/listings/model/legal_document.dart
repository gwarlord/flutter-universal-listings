import 'package:flutter/foundation.dart';

@immutable
class LegalSection {
  final String heading;
  final List<String> paragraphs;
  final List<String> bulletPoints;

  const LegalSection({
    required this.heading,
    required this.paragraphs,
    this.bulletPoints = const <String>[],
  });

  LegalSection copyWith({
    String? heading,
    List<String>? paragraphs,
    List<String>? bulletPoints,
  }) {
    return LegalSection(
      heading: heading ?? this.heading,
      paragraphs: paragraphs ?? this.paragraphs,
      bulletPoints: bulletPoints ?? this.bulletPoints,
    );
  }
}

@immutable
class LegalDocument {
  final String id;
  final String title;
  final String shortDescription;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.sections,
  });

  LegalDocument copyWith({
    String? title,
    String? shortDescription,
    List<LegalSection>? sections,
  }) {
    return LegalDocument(
      id: id,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      sections: sections ?? this.sections,
    );
  }
}
