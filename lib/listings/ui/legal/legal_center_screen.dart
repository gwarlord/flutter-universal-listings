import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';
import 'package:caribtap/listings/model/legal_document.dart';
import 'package:caribtap/listings/services/legal_content_service.dart';
import 'package:caribtap/listings/ui/legal/legal_document_screen.dart';

class LegalCenterScreen extends StatefulWidget {
  const LegalCenterScreen({super.key});

  @override
  State<LegalCenterScreen> createState() => _LegalCenterScreenState();
}

class _LegalCenterScreenState extends State<LegalCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<LegalDocument> _documents = const <LegalDocument>[];
  String _loadedLanguageCode = '';
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = context.locale.languageCode;
    if (_loadedLanguageCode == languageCode) {
      return;
    }

    _loadedLanguageCode = languageCode;
    _documents = LegalContentService.getDocuments(languageCode: languageCode);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final filteredDocuments = _filteredDocuments();

    return Scaffold(
      appBar: AppBar(
        title: Text('Legal'.tr()),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Review CaribTap’s policies, terms, and platform rules.'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.mutedText,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {
                      _query = value.trim();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search legal documents'.tr(),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                    filled: true,
                    fillColor: colors.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
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
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredDocuments.isEmpty
                ? Center(
                    child: Text(
                      'No legal documents found'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.mutedText,
                          ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.of(context).padding.bottom + 20,
                    ),
                    itemCount: filteredDocuments.length,
                    itemBuilder: (context, index) {
                      final document = filteredDocuments[index];
                      return _DocumentCard(document: document);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<LegalDocument> _filteredDocuments() {
    if (_query.isEmpty) {
      return _documents;
    }

    final normalizedQuery = _query.toLowerCase();

    return _documents.where((document) {
      if (document.title.toLowerCase().contains(normalizedQuery) ||
          document.shortDescription.toLowerCase().contains(normalizedQuery)) {
        return true;
      }

      for (final section in document.sections) {
        if (section.heading.toLowerCase().contains(normalizedQuery)) {
          return true;
        }

        for (final paragraph in section.paragraphs) {
          if (paragraph.toLowerCase().contains(normalizedQuery)) {
            return true;
          }
        }

        for (final point in section.bulletPoints) {
          if (point.toLowerCase().contains(normalizedQuery)) {
            return true;
          }
        }
      }

      return false;
    }).toList();
  }
}

class _DocumentCard extends StatelessWidget {
  final LegalDocument document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          document.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            document.shortDescription,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                  height: 1.4,
                ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LegalDocumentScreen(document: document),
            ),
          );
        },
      ),
    );
  }
}
