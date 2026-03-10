import 'package:flutter/material.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';
import 'package:caribtap/listings/model/legal_document.dart';

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        children: <Widget>[
          if (document.shortDescription.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.subtleBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.cardBorder),
              ),
              child: Text(
                document.shortDescription,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.mutedText,
                  height: 1.45,
                ),
              ),
            ),
          ...document.sections.map(
            (section) => _SectionCard(section: section),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final LegalSection section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            section.heading,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...section.paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                paragraph,
                style: textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: colors.mutedText,
                ),
              ),
            ),
          ),
          if (section.bulletPoints.isNotEmpty)
            ...section.bulletPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: colors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
