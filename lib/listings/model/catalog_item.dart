import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogMediaGroup {
  final String key;
  final Map<int, String> matchingValues;
  final List<String> images;

  const CatalogMediaGroup({
    required this.key,
    required this.matchingValues,
    required this.images,
  });
}

String? _normalizedString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String formatVariantSelectionLabel(Map<String, dynamic>? variant,
    {String separator = ', '}) {
  if (variant == null) return '';

  final explicitLabel = _normalizedString(variant['label']);
  if (explicitLabel != null) return explicitLabel;

  final option1Value =
      _normalizedString(variant['option1Value']) ?? _normalizedString(variant['size']);
  final option2Value =
      _normalizedString(variant['option2Value']) ?? _normalizedString(variant['color']);
    final option3Value = _normalizedString(variant['option3Value']);
    final option4Value = _normalizedString(variant['option4Value']);

    return [option1Value, option2Value, option3Value, option4Value]
      .whereType<String>()
      .join(separator);
}

/// Catalog item type
enum CatalogItemType {
  foodDrink('food_drink'),
  product('product'),
  service('service');

  final String value;
  const CatalogItemType(this.value);

  static CatalogItemType fromString(String value) {
    return CatalogItemType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => CatalogItemType.product,
    );
  }
}

/// Catalog item variant (for clothing, etc.)
class CatalogVariant {
  final String sku;
  final String? size;
  final String? color;
  final String? option1Value;
  final String? option2Value;
  final String? option3Value;
  final String? option4Value;
  final String? imageUrl;
  final double price;
  final int stockQty;

  CatalogVariant({
    required this.sku,
    this.size,
    this.color,
    this.option1Value,
    this.option2Value,
    this.option3Value,
    this.option4Value,
    this.imageUrl,
    required this.price,
    this.stockQty = 0,
  });

  String? get effectiveOption1Value => option1Value ?? size;
  String? get effectiveOption2Value => option2Value ?? color;
  String? get effectiveOption3Value => option3Value;
  String? get effectiveOption4Value => option4Value;
  bool get hasImage => _normalizedString(imageUrl) != null;

  String displayLabel({String separator = ' / '}) {
    return [
      effectiveOption1Value,
      effectiveOption2Value,
      effectiveOption3Value,
      effectiveOption4Value,
    ]
        .whereType<String>()
        .join(separator);
  }

  Map<String, dynamic> toSelectionMap({
    String? option1Name,
    String? option2Name,
    String? option3Name,
    String? option4Name,
  }) {
    final label = displayLabel(separator: ', ');
    return {
      'sku': sku,
      'size': size ?? effectiveOption1Value,
      'color': color ?? effectiveOption2Value,
      'option1Name': _normalizedString(option1Name),
      'option2Name': _normalizedString(option2Name),
      'option3Name': _normalizedString(option3Name),
      'option4Name': _normalizedString(option4Name),
      'option1Value': effectiveOption1Value,
      'option2Value': effectiveOption2Value,
      'option3Value': effectiveOption3Value,
      'option4Value': effectiveOption4Value,
      'imageUrl': _normalizedString(imageUrl),
      'price': price,
      'stockQty': stockQty,
      'label': label.isEmpty ? null : label,
    };
  }

  factory CatalogVariant.fromJson(Map<String, dynamic> json) {
    return CatalogVariant(
      sku: json['sku'] ?? '',
      size: _normalizedString(json['size']) ?? _normalizedString(json['option1Value']),
      color: _normalizedString(json['color']) ?? _normalizedString(json['option2Value']),
      option1Value:
          _normalizedString(json['option1Value']) ?? _normalizedString(json['size']),
      option2Value:
          _normalizedString(json['option2Value']) ?? _normalizedString(json['color']),
        option3Value: _normalizedString(json['option3Value']),
        option4Value: _normalizedString(json['option4Value']),
      imageUrl: _normalizedString(json['imageUrl']),
      price: (json['price'] ?? 0).toDouble(),
      stockQty: json['stockQty'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'size': size ?? effectiveOption1Value,
      'color': color ?? effectiveOption2Value,
      'option1Value': effectiveOption1Value,
      'option2Value': effectiveOption2Value,
      'option3Value': effectiveOption3Value,
      'option4Value': effectiveOption4Value,
      'imageUrl': _normalizedString(imageUrl),
      'price': price,
      'stockQty': stockQty,
    };
  }
}

/// Catalog item model for Mini Store
class CatalogItem {
  final String id;
  final CatalogItemType type;
  final String category;
  final String name;
  final String? description;
  final double price;
  final String currencyCode;
  final List<String> photos;
  final List<String> videos;
  final List<String> tags;
  final bool isAvailable;
  final bool trackStock;
  final int stockQty;
  final List<CatalogVariant> variants;
  final String? option1Name;
  final String? option2Name;
  final String? option3Name;
  final String? option4Name;
  final int sortOrder;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  CatalogItem({
    required this.id,
    this.type = CatalogItemType.product,
    this.category = '',
    required this.name,
    this.description,
    required this.price,
    this.currencyCode = 'USD',
    this.photos = const [],
    this.videos = const [],
    this.tags = const [],
    this.isAvailable = true,
    this.trackStock = false,
    this.stockQty = 0,
    this.variants = const [],
    this.option1Name,
    this.option2Name,
    this.option3Name,
    this.option4Name,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  String? get normalizedOption1Name => _normalizedString(option1Name);
  String? get normalizedOption2Name => _normalizedString(option2Name);
  String? get normalizedOption3Name => _normalizedString(option3Name);
  String? get normalizedOption4Name => _normalizedString(option4Name);

  bool get hasFirstVariantOption =>
      variants.any((variant) => variant.effectiveOption1Value != null);
  bool get hasSecondVariantOption =>
      variants.any((variant) => variant.effectiveOption2Value != null);
  bool get hasThirdVariantOption =>
      variants.any((variant) => variant.effectiveOption3Value != null);
  bool get hasFourthVariantOption =>
      variants.any((variant) => variant.effectiveOption4Value != null);

  String get resolvedOption1Name {
    final explicit = normalizedOption1Name;
    if (explicit != null) return explicit;
    if (variants.any((variant) => variant.size != null)) return 'Size';
    return 'Option 1';
  }

  String get resolvedOption2Name {
    final explicit = normalizedOption2Name;
    if (explicit != null) return explicit;
    if (variants.any((variant) => variant.color != null)) return 'Color';
    return 'Option 2';
  }

  String get resolvedOption3Name {
    final explicit = normalizedOption3Name;
    if (explicit != null) return explicit;
    return 'Option 3';
  }

  String get resolvedOption4Name {
    final explicit = normalizedOption4Name;
    if (explicit != null) return explicit;
    return 'Option 4';
  }

  String optionNameForIndex(int index) {
    switch (index) {
      case 1:
        return resolvedOption1Name;
      case 2:
        return resolvedOption2Name;
      case 3:
        return resolvedOption3Name;
      case 4:
        return resolvedOption4Name;
      default:
        return 'Option';
    }
  }

  bool hasOptionAtIndex(int index) {
    switch (index) {
      case 1:
        return hasFirstVariantOption;
      case 2:
        return hasSecondVariantOption;
      case 3:
        return hasThirdVariantOption;
      case 4:
        return hasFourthVariantOption;
      default:
        return false;
    }
  }

  bool optionAffectsImage(int index) {
    if (!hasOptionAtIndex(index)) return false;
    final normalized = optionNameForIndex(index).trim().toLowerCase();
    return !(normalized == 'size' || normalized.contains('size'));
  }

  String? optionValueForVariant(CatalogVariant variant, int index) {
    switch (index) {
      case 1:
        return variant.effectiveOption1Value;
      case 2:
        return variant.effectiveOption2Value;
      case 3:
        return variant.effectiveOption3Value;
      case 4:
        return variant.effectiveOption4Value;
      default:
        return null;
    }
  }

  Map<int, String> imageAffectingValuesForVariant(CatalogVariant variant) {
    final values = <int, String>{};
    for (var index = 1; index <= 4; index++) {
      if (!optionAffectsImage(index)) continue;
      final value = _normalizedString(optionValueForVariant(variant, index));
      if (value != null) {
        values[index] = value;
      }
    }
    return values;
  }

  String mediaGroupKeyForVariant(CatalogVariant variant) {
    final parts = <String>[];
    final values = imageAffectingValuesForVariant(variant);
    for (var index = 1; index <= 4; index++) {
      final value = values[index];
      if (value != null) {
        parts.add('$index=$value');
      }
    }
    return parts.isEmpty ? '__default__' : parts.join('|');
  }

  List<CatalogMediaGroup> get mediaGroups {
    final groups = <String, List<String>>{};
    final matchingValues = <String, Map<int, String>>{};

    for (final variant in variants) {
      final image = _normalizedString(variant.imageUrl);
      if (image == null) continue;

      final key = mediaGroupKeyForVariant(variant);
      final images = groups.putIfAbsent(key, () => <String>[]);
      if (!images.contains(image)) {
        images.add(image);
      }
      matchingValues.putIfAbsent(key, () => imageAffectingValuesForVariant(variant));
    }

    return groups.entries
        .map((entry) => CatalogMediaGroup(
              key: entry.key,
              matchingValues: matchingValues[entry.key] ?? const {},
              images: entry.value,
            ))
        .toList();
  }

  CatalogMediaGroup? resolveMediaGroupForSelection(
    Map<int, String?> selectedValues, {
    CatalogVariant? preferredVariant,
  }) {
    final groups = mediaGroups;
    if (groups.isEmpty) return null;

    final preferredKey =
        preferredVariant != null ? mediaGroupKeyForVariant(preferredVariant) : null;
    if (preferredKey != null) {
      for (final group in groups) {
        if (group.key == preferredKey) return group;
      }
    }

    int scoreGroup(CatalogMediaGroup group) {
      var score = 0;
      for (final entry in group.matchingValues.entries) {
        final selected = _normalizedString(selectedValues[entry.key]);
        if (selected != null && selected == entry.value) {
          score += 10;
        }
      }
      return score;
    }

    groups.sort((a, b) {
      final byScore = scoreGroup(b).compareTo(scoreGroup(a));
      if (byScore != 0) return byScore;
      return a.key.compareTo(b.key);
    });

    return groups.first;
  }

  List<String> get variantImages {
    final seen = <String>{};
    final images = <String>[];
    for (final variant in variants) {
      final image = _normalizedString(variant.imageUrl);
      if (image == null || seen.contains(image)) continue;
      seen.add(image);
      images.add(image);
    }
    return images;
  }

  bool get hasVariantImages => variantImages.isNotEmpty;

  List<String> galleryImagesForSelection(
    Map<int, String?> selectedValues, {
    CatalogVariant? preferredVariant,
  }) {
    final group = resolveMediaGroupForSelection(
      selectedValues,
      preferredVariant: preferredVariant,
    );
    if (group != null && group.images.isNotEmpty) {
      return group.images;
    }
    return preferredGalleryImages;
  }

  List<String> get preferredGalleryImages {
    if (hasVariantImages) {
      final groups = mediaGroups;
      if (groups.isNotEmpty && groups.first.images.isNotEmpty) {
        return groups.first.images;
      }
      return variantImages;
    }
    return photos.where((photo) => _normalizedString(photo) != null).toList();
  }

  String? get primaryDisplayImage {
    final gallery = preferredGalleryImages;
    return gallery.isEmpty ? null : gallery.first;
  }

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      id: json['id'] ?? '',
      type: CatalogItemType.fromString(json['type'] ?? 'product'),
      category: json['category'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      currencyCode: json['currencyCode'] ?? 'USD',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      isAvailable: json['isAvailable'] ?? true,
      trackStock: json['trackStock'] ?? false,
      stockQty: json['stockQty'] ?? 0,
      variants: (json['variants'] as List?)
              ?.map((e) => CatalogVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      option1Name: _normalizedString(json['option1Name']),
      option2Name: _normalizedString(json['option2Name']),
      option3Name: _normalizedString(json['option3Name']),
      option4Name: _normalizedString(json['option4Name']),
      sortOrder: json['sortOrder'] ?? 0,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'category': category,
      'name': name,
      'description': description,
      'price': price,
      'currencyCode': currencyCode,
      'photos': photos,
      'videos': videos,
      'tags': tags,
      'isAvailable': isAvailable,
      'trackStock': trackStock,
      'stockQty': stockQty,
      'variants': variants.map((e) => e.toJson()).toList(),
      'option1Name': normalizedOption1Name,
      'option2Name': normalizedOption2Name,
      'option3Name': normalizedOption3Name,
      'option4Name': normalizedOption4Name,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  CatalogItem copyWith({
    String? id,
    CatalogItemType? type,
    String? category,
    String? name,
    String? description,
    double? price,
    String? currencyCode,
    List<String>? photos,
    List<String>? videos,
    List<String>? tags,
    bool? isAvailable,
    bool? trackStock,
    int? stockQty,
    List<CatalogVariant>? variants,
    String? option1Name,
    String? option2Name,
    String? option3Name,
    String? option4Name,
    int? sortOrder,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return CatalogItem(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currencyCode: currencyCode ?? this.currencyCode,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      tags: tags ?? this.tags,
      isAvailable: isAvailable ?? this.isAvailable,
      trackStock: trackStock ?? this.trackStock,
      stockQty: stockQty ?? this.stockQty,
      variants: variants ?? this.variants,
      option1Name: option1Name ?? this.option1Name,
      option2Name: option2Name ?? this.option2Name,
      option3Name: option3Name ?? this.option3Name,
      option4Name: option4Name ?? this.option4Name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
