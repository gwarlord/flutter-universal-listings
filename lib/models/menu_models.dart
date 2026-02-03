import 'package:cloud_firestore/cloud_firestore.dart';

class MenuUpload {
  final String id;
  final String url;
  final String? thumbUrl;
  final int sortOrder;
  final Timestamp createdAt;

  MenuUpload({
    required this.id,
    required this.url,
    this.thumbUrl,
    required this.sortOrder,
    required this.createdAt,
  });

  factory MenuUpload.fromJson(Map<String, dynamic> json) => MenuUpload(
    id: json['id'],
    url: json['url'],
    thumbUrl: json['thumbUrl'],
    sortOrder: json['sortOrder'] ?? 0,
    createdAt: json['createdAt'] ?? Timestamp.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    if (thumbUrl != null) 'thumbUrl': thumbUrl,
    'sortOrder': sortOrder,
    'createdAt': createdAt,
  };
}

class MenuItemPhoto {
  final String id;
  final String url;
  final int sortOrder;

  MenuItemPhoto({
    required this.id,
    required this.url,
    required this.sortOrder,
  });

  factory MenuItemPhoto.fromJson(Map<String, dynamic> json) => MenuItemPhoto(
    id: json['id'],
    url: json['url'],
    sortOrder: json['sortOrder'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'sortOrder': sortOrder,
  };
}

class MenuItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currencyCode;
  final List<MenuItemPhoto> photos;
  final List<String>? tags;
  final bool isAvailable;
  final int sortOrder;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currencyCode,
    required this.photos,
    this.tags,
    required this.isAvailable,
    required this.sortOrder,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    price: (json['price'] ?? 0).toDouble(),
    currencyCode: json['currencyCode'] ?? 'USD',
    photos: (json['photos'] as List? ?? []).map((e) => MenuItemPhoto.fromJson(e)).toList(),
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
    isAvailable: json['isAvailable'] ?? true,
    sortOrder: json['sortOrder'] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'price': price,
    'currencyCode': currencyCode,
    'photos': photos.map((e) => e.toJson()).toList(),
    if (tags != null) 'tags': tags,
    'isAvailable': isAvailable,
    'sortOrder': sortOrder,
  };
}

class MenuSection {
  final String id;
  final String title;
  final int sortOrder;
  final List<MenuItem> items;

  MenuSection({
    required this.id,
    required this.title,
    required this.sortOrder,
    required this.items,
  });

  factory MenuSection.fromJson(Map<String, dynamic> json) => MenuSection(
    id: json['id'],
    title: json['title'],
    sortOrder: json['sortOrder'] ?? 0,
    items: (json['items'] as List? ?? []).map((e) => MenuItem.fromJson(e)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sortOrder': sortOrder,
    'items': items.map((e) => e.toJson()).toList(),
  };
}
