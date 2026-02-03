import 'package:cloud_firestore/cloud_firestore.dart';

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
  final double price;
  final int stockQty;

  CatalogVariant({
    required this.sku,
    this.size,
    this.color,
    required this.price,
    this.stockQty = 0,
  });

  factory CatalogVariant.fromJson(Map<String, dynamic> json) {
    return CatalogVariant(
      sku: json['sku'] ?? '',
      size: json['size'],
      color: json['color'],
      price: (json['price'] ?? 0).toDouble(),
      stockQty: json['stockQty'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'size': size,
      'color': color,
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
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

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
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
