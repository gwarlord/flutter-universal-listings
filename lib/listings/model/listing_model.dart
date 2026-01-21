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
  bool allowQuantitySelection; // ✅ Allow customers to select quantity
  bool useTimeBlocks; // ✅ Enable time block bookings
  bool allowMultipleBookingsPerDay; // ✅ Allow multiple bookings on same day
  List<String> timeBlocks; // ✅ Available time slots (e.g., "09:00-10:00", "10:00-11:00")
  bool enableCustomQuestions; // ✅ Toggle for custom booking questions
  List<String> customQuestions; // ✅ Questions asked during booking

  /// ✅ Digital Service Menu
  List<ServiceItem> services;

  /// ✅ Blocked Dates for Bookings
  List<int> blockedDates; // Stored as milliseconds since epoch

  /// Chat
  bool chatEnabled;

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
  String? verificationMethod; // 'auto', 'manual', or null
  int? verifiedAt; // Timestamp in seconds
  String? verifiedBy; // User ID of admin who verified (if manual)
  String? verificationReason; // Reason for manual verification or auto-verification rule met

  /// Reviews
  num reviewsCount;
  num reviewsSum;

  /// Analytics
  int viewCount;

  /// Region
  String countryCode;

  /// Featured
  bool isFeatured;
  int? featuredUntil; // Timestamp in seconds, null = no expiration
  String? featuredBy; // 'auto-premium', 'admin', or admin user ID

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
    this.allowQuantitySelection = false,
    this.useTimeBlocks = false,
    this.allowMultipleBookingsPerDay = false,
    this.timeBlocks = const [],
    this.enableCustomQuestions = false,
    this.customQuestions = const [],
    this.services = const [],
    this.blockedDates = const [],
    this.chatEnabled = true,
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
    this.verificationMethod,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationReason,
    this.reviewsCount = 0,
    this.reviewsSum = 0,
    this.viewCount = 0,
    this.countryCode = '',
    this.isFeatured = false,
    this.featuredUntil,
    this.featuredBy,
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
      allowQuantitySelection: json['allowQuantitySelection'] ?? false,
      useTimeBlocks: json['useTimeBlocks'] ?? false,
      allowMultipleBookingsPerDay: json['allowMultipleBookingsPerDay'] ?? false,
      timeBlocks: List<String>.from(json['timeBlocks'] ?? []),
      enableCustomQuestions: json['enableCustomQuestions'] ?? false,
      customQuestions: List<String>.from(json['customQuestions'] ?? []),
      services: (json['services'] as List? ?? [])
          .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      blockedDates: List<int>.from(json['blockedDates'] ?? []),
      chatEnabled: json['chatEnabled'] ?? true,
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
      verificationMethod: json['verificationMethod'],
      verifiedAt: json['verifiedAt'],
      verifiedBy: json['verifiedBy'],
      verificationReason: json['verificationReason'],
      reviewsCount: json['reviewsCount'] ?? 0,
      reviewsSum: json['reviewsSum'] ?? 0,
      viewCount: json['viewCount'] ?? 0,
      countryCode: json['countryCode'] ?? '',
      isFeatured: json['isFeatured'] ?? false,
      featuredUntil: json['featuredUntil'],
      featuredBy: json['featuredBy'],
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
      'allowQuantitySelection': allowQuantitySelection,
      'useTimeBlocks': useTimeBlocks,
      'allowMultipleBookingsPerDay': allowMultipleBookingsPerDay,
      'timeBlocks': timeBlocks,
      'enableCustomQuestions': enableCustomQuestions,
      'customQuestions': customQuestions,
      'services': services.map((e) => e.toJson()).toList(),
      'blockedDates': blockedDates,
      'chatEnabled': chatEnabled,
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
      'verificationMethod': verificationMethod,
      'verifiedAt': verifiedAt,
      'verifiedBy': verifiedBy,
      'verificationReason': verificationReason,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
      'viewCount': viewCount,
      'countryCode': countryCode,
      'isFeatured': isFeatured,
      'featuredUntil': featuredUntil,
      'featuredBy': featuredBy,
    };
  }

  ListingModel copyWith({
    String? id,
    String? authorID,
    String? authorName,
    String? authorProfilePic,
    String? categoryID,
    String? categoryPhoto,
    String? categoryTitle,
    int? createdAt,
    String? title,
    String? description,
    String? place,
    double? latitude,
    double? longitude,
    String? photo,
    List<String>? photos,
    List<String>? videos,
    String? price,
    String? currencyCode,
    String? phone,
    String? email,
    String? website,
    String? openingHours,
    bool? bookingEnabled,
    String? bookingUrl,
    bool? allowQuantitySelection,
    bool? useTimeBlocks,
    bool? allowMultipleBookingsPerDay,
    List<String>? timeBlocks,
    bool? enableCustomQuestions,
    List<String>? customQuestions,
    List<ServiceItem>? services,
    List<int>? blockedDates,
    bool? chatEnabled,
    String? instagram,
    String? facebook,
    String? tiktok,
    String? whatsapp,
    String? youtube,
    String? x,
    Map<String, dynamic>? filters,
    bool? isApproved,
    bool? suspended,
    bool? verified,
    num? reviewsCount,
    num? reviewsSum,
    String? countryCode,
  }) {
    return ListingModel(
      id: id ?? this.id,
      authorID: authorID ?? this.authorID,
      authorName: authorName ?? this.authorName,
      authorProfilePic: authorProfilePic ?? this.authorProfilePic,
      categoryID: categoryID ?? this.categoryID,
      categoryPhoto: categoryPhoto ?? this.categoryPhoto,
      categoryTitle: categoryTitle ?? this.categoryTitle,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      description: description ?? this.description,
      place: place ?? this.place,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photo: photo ?? this.photo,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      price: price ?? this.price,
      currencyCode: currencyCode ?? this.currencyCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      bookingEnabled: bookingEnabled ?? this.bookingEnabled,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      allowQuantitySelection: allowQuantitySelection ?? this.allowQuantitySelection,
      useTimeBlocks: useTimeBlocks ?? this.useTimeBlocks,
      allowMultipleBookingsPerDay: allowMultipleBookingsPerDay ?? this.allowMultipleBookingsPerDay,
      timeBlocks: timeBlocks ?? this.timeBlocks,
      enableCustomQuestions: enableCustomQuestions ?? this.enableCustomQuestions,
      customQuestions: customQuestions ?? this.customQuestions,
      services: services ?? this.services,
      blockedDates: blockedDates ?? this.blockedDates,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      whatsapp: whatsapp ?? this.whatsapp,
      youtube: youtube ?? this.youtube,
      x: x ?? this.x,
      filters: filters ?? this.filters,
      isApproved: isApproved ?? this.isApproved,
      suspended: suspended ?? this.suspended,
      verified: verified ?? this.verified,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      reviewsSum: reviewsSum ?? this.reviewsSum,
      countryCode: countryCode ?? this.countryCode,
    );
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
