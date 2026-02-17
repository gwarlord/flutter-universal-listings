import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/suspension_info.dart';
import 'rental_config.dart';

const int listingFreshnessDefaultDays = 90;

class ListingFreshness {
  final bool enabled;
  final int days;
  final Timestamp lastRefreshedAt;
  final Timestamp hideAt;
  final String status;
  final Timestamp? warn10SentAt;
  final Timestamp? warn1SentAt;
  final Timestamp? hiddenNotifiedAt;
  final bool exempt;

  const ListingFreshness({
    required this.enabled,
    required this.days,
    required this.lastRefreshedAt,
    required this.hideAt,
    required this.status,
    this.warn10SentAt,
    this.warn1SentAt,
    this.hiddenNotifiedAt,
    required this.exempt,
  });

  factory ListingFreshness.defaultForCreatedAt(int createdAtSeconds) {
    final now = Timestamp.fromMillisecondsSinceEpoch(createdAtSeconds * 1000);
    final hideAt = Timestamp.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch +
          (listingFreshnessDefaultDays * 24 * 60 * 60 * 1000),
    );
    return ListingFreshness(
      enabled: true,
      days: listingFreshnessDefaultDays,
      lastRefreshedAt: now,
      hideAt: hideAt,
      status: 'ACTIVE',
      warn10SentAt: null,
      warn1SentAt: null,
      hiddenNotifiedAt: null,
      exempt: false,
    );
  }

  factory ListingFreshness.fromJson(
    Map<String, dynamic>? json, {
    required int createdAtSeconds,
  }) {
    if (json == null) {
      return ListingFreshness.defaultForCreatedAt(createdAtSeconds);
    }

    final enabled = json['enabled'] ?? true;
    final days = (json['days'] is int)
      ? json['days'] as int
      : int.tryParse(json['days']?.toString() ?? '') ??
        listingFreshnessDefaultDays;
    final lastRefreshedAt = _parseTimestamp(
          json['lastRefreshedAt'],
          fallbackSeconds: createdAtSeconds,
        ) ??
        Timestamp.fromMillisecondsSinceEpoch(createdAtSeconds * 1000);
    final hideAt = _parseTimestamp(
          json['hideAt'],
          fallbackSeconds: lastRefreshedAt.seconds + (days * 24 * 60 * 60),
        ) ??
        Timestamp.fromMillisecondsSinceEpoch(
          lastRefreshedAt.millisecondsSinceEpoch +
              (days * 24 * 60 * 60 * 1000),
        );

    return ListingFreshness(
      enabled: enabled == true,
      days: days,
      lastRefreshedAt: lastRefreshedAt,
      hideAt: hideAt,
      status: json['status'] ?? 'ACTIVE',
      warn10SentAt: _parseTimestamp(json['warn10SentAt']),
      warn1SentAt: _parseTimestamp(json['warn1SentAt']),
      hiddenNotifiedAt: _parseTimestamp(json['hiddenNotifiedAt']),
      exempt: json['exempt'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'days': days,
      'lastRefreshedAt': lastRefreshedAt,
      'hideAt': hideAt,
      'status': status,
      'warn10SentAt': warn10SentAt,
      'warn1SentAt': warn1SentAt,
      'hiddenNotifiedAt': hiddenNotifiedAt,
      'exempt': exempt,
    };
  }

  int? get daysRemaining {
    final now = DateTime.now();
    final remaining = hideAt.toDate().difference(now);
    return remaining.inSeconds <= 0 ? 0 : (remaining.inHours / 24).ceil();
  }

  bool get isExpired => hideAt.toDate().isBefore(DateTime.now());

  ListingFreshness copyWithExempt(bool value) {
    return ListingFreshness(
      enabled: enabled,
      days: days,
      lastRefreshedAt: lastRefreshedAt,
      hideAt: hideAt,
      status: status,
      warn10SentAt: warn10SentAt,
      warn1SentAt: warn1SentAt,
      hiddenNotifiedAt: hiddenNotifiedAt,
      exempt: value,
    );
  }

  static Timestamp? _parseTimestamp(
    dynamic value, {
    int? fallbackSeconds,
  }) {
    if (value is Timestamp) {
      return value;
    }
    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (fallbackSeconds != null) {
      return Timestamp.fromMillisecondsSinceEpoch(fallbackSeconds * 1000);
    }
    return null;
  }
}

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
  String logo; // Business/listing logo (square mini logo)

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

  /// Store (Premium Feature)
  bool storeEnabled;
  String? storeMode; // "external_url" | "internal_catalog" | "both"
  String storeUrl;
  String? storeCurrencyCode; // Defaults to listing.currencyCode
  bool storeDeliveryEnabled;
  bool storePickupEnabled;
  bool storeDineInEnabled; // Dining in at restaurant
  bool storeShippingEnabled; // Shipping/carrier fulfillment
  double storeShippingFee; // Shipping cost (0 for free shipping)
  int storeLeadTimeHours; // Minimum lead time for orders
  Timestamp? storeUpdatedAt;
  
  /// Lister tier snapshot - CRITICAL for rules & UI performance
  /// This is set when the listing is saved and indicates the owner's tier at that time
  String listerTierSnapshot; // "free" | "professional" | "premium"

  /// Payments Settings
  Map<String, dynamic> payments; // { acceptProofOfPayment: bool }

  /// Social Media
  String instagram;
  String facebook;
  String tiktok;
  String whatsapp;
  String youtube;
  String x; // Twitter

  /// Filters / meta
  Map<String, dynamic> filters;
  ListingFreshness freshness;
  bool isApproved;
  bool suspended;
  bool hidden; // Allows lister to hide their listing from public view
  bool isFlagged;
  SuspensionInfo? suspensionInfo;
  bool verified;
  String? verificationMethod; // 'auto', 'manual', or null
  int? verifiedAt; // Timestamp in seconds
  String? verifiedBy; // User ID of admin who verified (if manual)
  String? verificationReason; // Reason for manual verification or auto-verification rule met

  /// Reviews
  num reviewsCount;
  num reviewsSum;

  /// Taps (Community Vouching)
  int tapCount;
  String tapBadge; // 'none', 'community_vouched', 'community_verified'

  /// Analytics
  int viewCount;

  /// Region
  String countryCode;

  /// Featured
  bool isFeatured;
  int? featuredUntil; // Timestamp in seconds, null = no expiration
  String? featuredBy; // 'auto-premium', 'admin', or admin user ID

  /// Menu (Food & Beverage)
  bool menuEnabled;
  String menuMode;
  String menuCurrencyCode;
  Timestamp? menuUpdatedAt;
  List<Map<String, dynamic>> menuUploads;
  List<Map<String, dynamic>> menuSections;

  /// Rentals (Premium Feature)
  RentalConfig? rentalConfig;

  /// Multi-Location Brands
  String? brandId; // Links this listing to a brand (location-scoped)
  String? locationLabel; // Custom label like "KFC – Maraval" (optional)

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
    this.logo = '',
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
    this.storeEnabled = false,
    this.storeMode,
    this.storeUrl = '',
    String? storeCurrencyCode,
    this.storeDeliveryEnabled = false,
    this.storePickupEnabled = true,
    this.storeDineInEnabled = false,
    this.storeShippingEnabled = false,
    this.storeShippingFee = 0.0,
    this.storeLeadTimeHours = 24,
    this.storeUpdatedAt,
    this.listerTierSnapshot = 'free',
    Map<String, dynamic>? payments,
    this.instagram = '',
    this.facebook = '',
    this.tiktok = '',
    this.whatsapp = '',
    this.youtube = '',
    this.x = '',
    this.filters = const {},
    ListingFreshness? freshness,
    this.isApproved = false,
    this.suspended = false,
    this.hidden = false,
    this.isFlagged = false,
    this.suspensionInfo,
    this.verified = false,
    this.verificationMethod,
    this.verifiedAt,
    this.verifiedBy,
    this.verificationReason,
    this.reviewsCount = 0,
    this.reviewsSum = 0,
    this.tapCount = 0,
    this.tapBadge = 'none',
    this.viewCount = 0,
    this.countryCode = '',
    this.isFeatured = false,
    this.featuredUntil,
    this.featuredBy,
    this.menuEnabled = false,
    this.menuMode = "both",
    String? menuCurrencyCode,
    this.menuUpdatedAt,
    List<Map<String, dynamic>>? menuUploads,
    List<Map<String, dynamic>>? menuSections,
    this.rentalConfig,
    this.brandId,
    this.locationLabel,
    })  : payments = payments ?? {'acceptProofOfPayment': false},
        menuCurrencyCode = menuCurrencyCode ?? currencyCode,
        storeCurrencyCode = storeCurrencyCode ?? currencyCode,
        menuUploads = menuUploads ?? [],
        menuSections = menuSections ?? [],
      createdAt = createdAt ?? Timestamp.now().seconds,
      freshness = freshness ??
        ListingFreshness.defaultForCreatedAt((createdAt ?? Timestamp.now().seconds) > 10000000000 
          ? ((createdAt ?? Timestamp.now().seconds) ~/ 1000).toInt()
          : (createdAt ?? Timestamp.now().seconds).toInt());

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    int createdAtSeconds;
    if (json['createdAt'] is Timestamp) {
      createdAtSeconds = (json['createdAt'] as Timestamp).seconds;
    } else if (json['createdAt'] != null) {
      final rawValue = json['createdAt'] as num;
      // If value > 10 billion, it's likely in milliseconds, convert to seconds
      createdAtSeconds = rawValue > 10000000000 
          ? (rawValue / 1000).round() 
          : rawValue.toInt();
    } else {
      createdAtSeconds = Timestamp.now().seconds;
    }

    return ListingModel(
      id: json['id'] ?? '',
      authorID: json['authorID'] ?? '',
      authorName: json['authorName'] ?? '',
      authorProfilePic: json['authorProfilePic'] ?? '',
      categoryID: json['categoryID'] ?? '',
      categoryPhoto: json['categoryPhoto'] ?? '',
      categoryTitle: json['categoryTitle'] ?? '',
        createdAt: createdAtSeconds,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      place: json['place'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      photo: json['photo'] ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      logo: json['logo'] ?? '',
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
      storeEnabled: json['storeEnabled'] ?? false,
      storeMode: json['storeMode'],
      storeUrl: json['storeUrl'] ?? '',
      storeCurrencyCode: json['storeCurrencyCode'] ?? json['currencyCode'] ?? 'USD',
      storeDeliveryEnabled: json['storeDeliveryEnabled'] ?? false,
      storePickupEnabled: json['storePickupEnabled'] ?? true,
      storeDineInEnabled: json['storeDineInEnabled'] ?? false,
      storeShippingEnabled: json['storeShippingEnabled'] ?? false,
      storeShippingFee: (json['storeShippingFee'] ?? 0).toDouble(),
      storeLeadTimeHours: json['storeLeadTimeHours'] ?? 24,
      storeUpdatedAt: json['storeUpdatedAt'],
      listerTierSnapshot: json['listerTierSnapshot'] ?? 'free',
      payments: Map<String, dynamic>.from(json['payments'] ?? {'acceptProofOfPayment': false}),
      instagram: json['instagram'] ?? '',
      facebook: json['facebook'] ?? '',
      tiktok: json['tiktok'] ?? '',
      whatsapp: json['whatsapp'] ?? '',
      youtube: json['youtube'] ?? '',
      x: json['x'] ?? '',
      filters: Map<String, dynamic>.from(json['filters'] ?? {}),
      freshness: ListingFreshness.fromJson(
        (json['freshness'] as Map?)?.cast<String, dynamic>(),
        createdAtSeconds: createdAtSeconds,
      ),
      isApproved: json['isApproved'] ?? false,
      suspended: json['suspended'] ?? false,
      hidden: json['hidden'] ?? false,
      isFlagged: json['isFlagged'] ?? false,
        suspensionInfo: json['suspensionInfo'] != null
          ? SuspensionInfo.fromJson(json['suspensionInfo'] as Map<String, dynamic>)
          : null,
      verified: json['verified'] ?? false,
      verificationMethod: json['verificationMethod'],
      verifiedAt: json['verifiedAt'],
      verifiedBy: json['verifiedBy'],
      verificationReason: json['verificationReason'],
      reviewsCount: json['reviewsCount'] ?? 0,
      reviewsSum: json['reviewsSum'] ?? 0,
      tapCount: json['tapCount'] ?? 0,
      tapBadge: json['tapBadge'] ?? 'none',
      viewCount: json['viewCount'] ?? 0,
      countryCode: json['countryCode'] ?? '',
      isFeatured: json['isFeatured'] ?? false,
      featuredUntil: json['featuredUntil'],
      featuredBy: json['featuredBy'],
        menuEnabled: json['menuEnabled'] ?? false,
        menuMode: json['menuMode'] ?? "both",
        menuCurrencyCode: json['menuCurrencyCode'] ?? json['currencyCode'] ?? 'USD',
        menuUpdatedAt: json['menuUpdatedAt'],
        menuUploads: (json['menuUploads'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
        menuSections: (json['menuSections'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
        brandId: json['brandId'],
        locationLabel: json['locationLabel'],
        rentalConfig: json['rentalConfig'] != null 
            ? RentalConfig.fromJson(json['rentalConfig'] as Map<String, dynamic>)
            : null,
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
      'logo': logo,
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
      'storeEnabled': storeEnabled,
      'storeMode': storeMode,
      'storeUrl': storeUrl,
      'storeCurrencyCode': storeCurrencyCode,
      'storeDeliveryEnabled': storeDeliveryEnabled,
      'storePickupEnabled': storePickupEnabled,
      'storeDineInEnabled': storeDineInEnabled,
      'storeShippingEnabled': storeShippingEnabled,
      'storeShippingFee': storeShippingFee,
      'storeLeadTimeHours': storeLeadTimeHours,
      'storeUpdatedAt': storeUpdatedAt,
      'listerTierSnapshot': listerTierSnapshot,
      'payments': payments,
      'instagram': instagram,
      'facebook': facebook,
      'tiktok': tiktok,
      'whatsapp': whatsapp,
      'youtube': youtube,
      'x': x,
      'filters': filters,
      'freshness': freshness.toJson(),
      'isApproved': isApproved,
      'suspended': suspended,
      'hidden': hidden,
      'isFlagged': isFlagged,
      'suspensionInfo': suspensionInfo?.toJson(),
      'verified': verified,
      'verificationMethod': verificationMethod,
      'verifiedAt': verifiedAt,
      'verifiedBy': verifiedBy,
      'verificationReason': verificationReason,
      'reviewsCount': reviewsCount,
      'reviewsSum': reviewsSum,
      'tapCount': tapCount,
      'tapBadge': tapBadge,
      'viewCount': viewCount,
      'countryCode': countryCode,
      'isFeatured': isFeatured,
      'featuredUntil': featuredUntil,
      'featuredBy': featuredBy,
        'menuEnabled': menuEnabled,
        'menuMode': menuMode,
        'menuCurrencyCode': menuCurrencyCode,
        'menuUpdatedAt': menuUpdatedAt,
        'menuUploads': menuUploads,
        'menuSections': menuSections,
        'rentalConfig': rentalConfig?.toJson(),
        'brandId': brandId,
        'locationLabel': locationLabel,
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
    String? logo,
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
    bool? storeEnabled,
    String? storeUrl,
    String? instagram,
    String? facebook,
    String? tiktok,
    String? whatsapp,
    String? youtube,
    String? x,
    Map<String, dynamic>? filters,
    ListingFreshness? freshness,
    bool? isApproved,
    bool? suspended,
    bool? hidden,
    bool? isFlagged,
    SuspensionInfo? suspensionInfo,
    bool? verified,
    num? reviewsCount,
    num? reviewsSum,
    int? tapCount,
    String? tapBadge,
    String? countryCode,
    RentalConfig? rentalConfig,
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
      logo: logo ?? this.logo,
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
      storeEnabled: storeEnabled ?? this.storeEnabled,
      storeUrl: storeUrl ?? this.storeUrl,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      tiktok: tiktok ?? this.tiktok,
      whatsapp: whatsapp ?? this.whatsapp,
      youtube: youtube ?? this.youtube,
      x: x ?? this.x,
      filters: filters ?? this.filters,
      freshness: freshness ?? this.freshness,
      isApproved: isApproved ?? this.isApproved,
      suspended: suspended ?? this.suspended,
      hidden: hidden ?? this.hidden,
      isFlagged: isFlagged ?? this.isFlagged,
      suspensionInfo: suspensionInfo ?? this.suspensionInfo,
      verified: verified ?? this.verified,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      reviewsSum: reviewsSum ?? this.reviewsSum,
      tapCount: tapCount ?? this.tapCount,
      tapBadge: tapBadge ?? this.tapBadge,
      rentalConfig: rentalConfig ?? this.rentalConfig,
      brandId: brandId ?? this.brandId,
      locationLabel: locationLabel ?? this.locationLabel,
      countryCode: countryCode ?? this.countryCode,
    );
  }
}

class ServiceItem {
  String name;
  String description; // ✅ Added short description
  double price;
  String duration; // e.g. "30 mins", "1 hour"
  int quantity;

  ServiceItem({
    required this.name,
    this.description = '',
    required this.price,
    this.duration = '',
    this.quantity = 1,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? '',
      quantity: json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'quantity': quantity,
    };
  }
}
