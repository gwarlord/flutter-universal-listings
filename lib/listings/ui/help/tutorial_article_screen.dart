import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';
import 'package:caribtap/listings/model/tutorial_article.dart';

class TutorialArticleScreen extends StatelessWidget {
  final TutorialArticle article;

  const TutorialArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Tutorials'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article.title.tr(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              article.summary.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.mutedText,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 20),
            _InfoCard(
              title: 'What this feature does'.tr(),
              content: article.whatThisDoes.tr(),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Who should use it'.tr(),
              content: article.whoShouldUseIt.tr(),
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Step-by-step instructions'.tr()),
            const SizedBox(height: 10),
            _BulletList(
              items: article.steps,
              numbered: true,
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Tips'.tr()),
            const SizedBox(height: 10),
            _BulletList(items: article.tips),
            const SizedBox(height: 20),
            _SectionTitle(title: 'Common issues'.tr()),
            const SizedBox(height: 10),
            _BulletList(items: article.commonIssues),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;

  const _InfoCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final bool numbered;

  const _BulletList({required this.items, this.numbered = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Column(
      children: List.generate(items.length, (index) {
        final prefix = numbered ? '${index + 1}.' : '\u2022';
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.subtleBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.cardBorder.withOpacity(0.7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  prefix,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  items[index].tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
