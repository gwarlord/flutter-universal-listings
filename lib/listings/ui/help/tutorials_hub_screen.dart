import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';
import 'package:caribtap/listings/model/tutorial_article.dart';
import 'package:caribtap/listings/services/tutorial_content_service.dart';
import 'package:caribtap/listings/ui/help/tutorial_article_screen.dart';

class TutorialsHubScreen extends StatefulWidget {
  const TutorialsHubScreen({super.key});

  @override
  State<TutorialsHubScreen> createState() => _TutorialsHubScreenState();
}

class _TutorialsHubScreenState extends State<TutorialsHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<TutorialArticle> _allArticles = <TutorialArticle>[];
  String _loadedLanguageCode = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = context.locale.languageCode;
    if (_loadedLanguageCode != languageCode) {
      _loadedLanguageCode = languageCode;
      _allArticles =
          TutorialContentService.getArticles(languageCode: languageCode);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final filtered = _filteredArticles();
    final grouped = _groupByCategory(filtered);

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Tutorials'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value.trim();
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search tutorials'.tr(),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Text(
                      'No tutorials found'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final category = grouped.keys.elementAt(index);
                      final articles = grouped[category] ?? <TutorialArticle>[];

                      return _CategorySection(
                        category: category,
                        articles: articles,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<TutorialArticle> _filteredArticles() {
    if (_query.isEmpty) return _allArticles;

    final query = _query.toLowerCase();
    return _allArticles.where((article) {
      return article.title.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query);
    }).toList();
  }

  Map<String, List<TutorialArticle>> _groupByCategory(
      List<TutorialArticle> articles) {
    final grouped = <String, List<TutorialArticle>>{};
    for (final article in articles) {
      grouped
          .putIfAbsent(article.category, () => <TutorialArticle>[])
          .add(article);
    }
    return grouped;
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<TutorialArticle> articles;

  const _CategorySection({required this.category, required this.articles});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Text(
              category.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ...List.generate(articles.length, (index) {
            final article = articles[index];
            final showDivider = index != articles.length - 1;

            return Column(
              children: [
                ListTile(
                  title: Text(
                    article.title.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      article.summary.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.mutedText,
                            height: 1.3,
                          ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TutorialArticleScreen(article: article),
                      ),
                    );
                  },
                ),
                if (showDivider)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            );
          }),
        ],
      ),
    );
  }
}
