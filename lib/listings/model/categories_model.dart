class CategoriesModel {
  final String id;
  final String slug;
  final String title;
  final String photo;
  final bool isActive;
  final int sortOrder;
  final String? parentSlug;
  final List<String> synonyms;

  CategoriesModel({
    required this.id,
    this.slug = '',
    required this.title,
    required this.photo,
    required this.isActive,
    required this.sortOrder,
    this.parentSlug,
    this.synonyms = const [],
  });

  factory CategoriesModel.fromJson(
      Map<String, dynamic> json, {
        required String id,
      }) {
    final title = (json['title'] ?? json['name'] ?? '') as String;
    final rawSlug = (json['slug'] ?? '').toString().trim();
    final normalizedSlug = rawSlug.isEmpty ? _slugify(title).ifEmpty(id) : rawSlug;

    final photo = (json['photo'] ??
        json['photoUrl'] ??
        json['image'] ??
        json['icon'] ??
        '') as String;

    final rawParentSlug = (json['parentSlug'] ?? '').toString().trim();
    final parsedParentSlug = rawParentSlug.isEmpty ? null : rawParentSlug;

    final rawSynonyms = json['synonyms'];
    final parsedSynonyms = rawSynonyms is List
        ? rawSynonyms
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    return CategoriesModel(
      id: id,
      slug: normalizedSlug,
      title: title,
      photo: photo,
      isActive: (json['isActive'] ?? true) as bool,
      sortOrder: (json['sortOrder'] ?? 0) as int,
      parentSlug: parsedParentSlug,
      synonyms: parsedSynonyms,
    );
  }

  static String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'&'), 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized;
  }

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'title': title,
    'photo': photo,
    'isActive': isActive,
    'sortOrder': sortOrder,
    if (parentSlug != null && parentSlug!.isNotEmpty) 'parentSlug': parentSlug,
    if (synonyms.isNotEmpty) 'synonyms': synonyms,
  };
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
