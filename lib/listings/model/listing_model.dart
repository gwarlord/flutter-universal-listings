import 'package:cloud_firestore/cloud_firestore.dart';

class ListingModel {
  /// REQUIRED
  String id;

  /// Author
  String authorID;
  String authorName;
  String authorProfilePic;

  /// Category
  String categoryID;
  String categoryPhoto;
  String categoryTitle;

  /// Core
  int createdAt;
  String title;
  String description;
  String place;
  double latitude;
  double longitude;

  /// Media
  String photo; // PRIMARY image (used everywhere)
  List<String> photos;
  List<String> videos;

  /// Optional
  String price; // Changed back to String to match your existing Firestore data and UI logic
  String currencyCode;
  String phone;
  String email;
  String website;
  String openingHours;

  /// Booking
  bool bookingEnabled;
  String bookingUrl;

  /// ✅ Digital Service Menu
  List<ServiceItem> services;

  /// ✅ Blocked Dates for Bookings
  List<int> blockedDates; // Stored as milliseconds since epoch

  /// Social Media
  String instagram;
  String facebook;
  String tiktok;
  String whatsapp;
  String youtube;
  String x; // Twitter

  /// Filters / meta
  Map<String, dynamic> filters;
  bool isApproved;
  bool suspended;
  bool verified;

  /// Reviews
  num reviewsCount;
  num reviewsSum;

  /// Region
  String countryCode;

  /// UI-only
  bool isFav = false;

  ListingModel({
    this.id = '',
    this.authorID = '',
    this.authorName = '',
    this.authorProfilePic = '',
    this.categoryID = '',
    this.categoryPhoto = '',
    this.categoryTitle = '',
    int? createdAt,
    this.title = '',
    this.description = '',
    this.place = '',
    this.latitude = 0,
    this.longitude = 0,
    this.photo = '',
    this.photos = const [],
    this.videos = const [],
    this.price = '',
    this.currencyCode = 'USD',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.openingHours = '',
    this.bookingEnabled = false,
    this.bookingUrl = '',
    this.services = const [],
    this.blockedDates = const [],
    this.instagram = '',
    this.facebook = '',
    this.tiktok = '',
    this.whatsapp = '',
    this.youtube = '',
    this.x = '',
    this.filters = const {},
    this.isApproved = false,
    this.suspended = false,
    this.verified = false,
    this.reviewsCount = 0,
    this.reviewsSum = 0,
    this.countryCode = '',
  }) : createdAt = createdAt ?? Timestamp.now().seconds;

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['id'] ?? '',
      authorID: json['authorID'] ?? '',
      authorName: json['authorName'] ?? '',
      authorProfilePic: json['authorProfilePic'] ?? '',
      categoryID: json['categoryID'] ?? '',
      categoryPhoto: json['categoryPhoto'] ?? '',
      categoryTitle: json['categoryTitle'] ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).seconds
          : (json['createdAt'] ?? Timestamp.now().seconds),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      place: json['place'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      photo: json['photo'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      price: json['price']?.toString() ?? '',
      currencyCode: json['currencyCode']?.toString() ?? 'USD',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      website: json['website'] ?? '',
      openingHours: json['openingHours'] ?? '',
      bookingEnabled: json['bookingEnabled'] ?? false,
      bookingUrl: json['bookingUrl'] ?? '',
      services: (json['services'] as List? ?? [])
          .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      blockedDates: List<int>.from(json['blockedDates'] ?? []),
      instagram: json['instagram'] ?? '',
      facebook: json['facebook'] ?? '',
      tiktok: json['tiktok'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      youtube: json['youtube'] ?? '',
      x: json['x'] ?? '',
      filters: Map<String, dynamic>.from(json['filters'] ?? {}),
      isApproved: json['isApproved'] ?? false,
      suspended: json['suspended'] ?? false,
      verified: json['verified'] ?? false,
      reviewsCount: json['reviewsCount'] ?? 0,
      reviewsSum: json['reviewsSum'] ?? 0,
      countryCode: json['countryCode'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorID': authorID,
      'authorName': authorName,
      'authorProfilePic': authorProfilePic,
      'categoryID': categoryID,
      'categoryPhoto': categoryPhoto,
      'categoryTitle': categoryTitle,
      'createdAt': createdAt,
      'title': title,
      'description': description,
      'place': place,
      'latitude': latitude,
      'longitude': longitude,
      'photo': photo,
      'photos': photos,
      'videos': videos,
      'price': price,
      'currencyCode': currencyCode,
      'phone': phone,
      'email': email,
      'website': website,
      'openingHours': openingHours,
      'bookingEnabled': bookingEnabled,
      'bookingUrl': bookingUrl,
      'services': services.map((e) => e.toJson()).toList(),
      'blockedDates': blockedDates,
      'instagram': instagram,
      'facebook': facebook,
      'tiktok': tiktok,
      'whatsapp': whatsapp,
      'youtube': youtube,
      'x': x,
      'filters': filters,
      'isApproved': isApproved,
      'suspended': suspended,
      'verified': verified,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
      'countryCode': countryCode,
    };
  }
}

class ServiceItem {
  String name;
  double price;
  String duration; // e.g. "30 mins", "1 hour"
  int quantity;

  ServiceItem({
    required this.name,
    required this.price,
    this.duration = '',
    this.quantity = 1,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'duration': duration,
      'quantity': quantity,
    };
  }
}
