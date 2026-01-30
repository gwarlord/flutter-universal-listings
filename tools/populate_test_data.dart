import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Populate Firestore with high-quality demo data for CaribTap.
/// - Creates curated demo listings that exercise: booking, time blocks,
///   custom questions, blocked dates, services, socials, ecommerce, media.
/// - Uses deterministic IDs (demo_*) so it can be safely re-run and purged.
class TestDataPopulator {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();
  static final _random = Random();

  /// Toggle this to true if you want many random listings in addition to the 6 curated.
  static const bool createExtraRandomListings = false;

  /// How many extra random listings to create (if enabled).
  static const int extraRandomListingCount = 20;

  /// Demo author user id. Keep stable so the same “owner” shows across listings.
  static const String demoAuthorId = 'demo_author_caribtap';

  /// Collection names (single source of truth)
  static const String usersColl = 'users';
  static const String listingsColl = 'listings';
  static const String categoriesColl = 'categories';
  static const String adsColl = 'deal_ads';
  static const String channelsColl = 'channels';

  // Countries (kept for random users; curated listings use TT to match your screenshots)
  static const List<Map<String, String>> countries = [
    {'code': 'JM', 'name': 'Jamaica'},
    {'code': 'TT', 'name': 'Trinidad and Tobago'},
    {'code': 'BB', 'name': 'Barbados'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'LC', 'name': 'Saint Lucia'},
    {'code': 'GY', 'name': 'Guyana'},
  ];

  // Profile pics for seeded users (safe public)
  static const List<String> profilePics = [
    'https://randomuser.me/api/portraits/men/11.jpg',
    'https://randomuser.me/api/portraits/women/12.jpg',
    'https://randomuser.me/api/portraits/men/13.jpg',
    'https://randomuser.me/api/portraits/women/14.jpg',
    'https://randomuser.me/api/portraits/men/15.jpg',
  ];

  // Placeholder images (replace with your Firebase Storage download URLs for realism)
  static const List<String> placeholderImages = [
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900',
    'https://images.unsplash.com/photo-1521791136064-7986c2959213?w=900',
    'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=900',
    'https://images.unsplash.com/photo-1493238507151-c35a50d60135?w=900',
    'https://images.unsplash.com/photo-1566417713940-fe7c737a9ef2?w=900',
  ];

  // Placeholder videos (replace with your Firebase Storage videos if desired)
  static const List<String> placeholderVideos = [
    'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  ];

  static Future<void> populateAll() async {
    print('🚀 Starting data population (curated demo pack)...');

    // 1) Ensure demo author exists (stable user)
    await _upsertDemoAuthor();

    // 2) Create additional normal test users (optional; useful for chats/reviews testing)
    final userIds = await _createUsers(10);

    // 3) Load categories for ID mapping
    final categoryMap = await _getCategoryMap(); // title -> {id, photo}

    // 4) Create curated listings (6)
    final curatedListingIds = await _createCuratedListings(categoryMap);

    // 5) Optionally create random listings too (keep off unless you want volume)
    List<String> randomListingIds = [];
    if (createExtraRandomListings) {
      final categoryIds = categoryMap.values.map((e) => e['id']!).toList();
      randomListingIds = await _createRandomListings(userIds, categoryIds, extraRandomListingCount);
    }

    final allListingIds = [...curatedListingIds, ...randomListingIds];

    // 6) Ads + chats
    await _createAds(userIds, allListingIds, 10);
    await _createChats(userIds, allListingIds);

    print('✅ Population complete! Curated: ${curatedListingIds.length}, Random: ${randomListingIds.length}');
  }

  /// Map categoryTitle -> {'id': <docId>, 'photo': <categoryPhoto>}
  static Future<Map<String, Map<String, String>>> _getCategoryMap() async {
    final snap = await _db.collection(categoriesColl).get();
    final map = <String, Map<String, String>>{};
    for (final d in snap.docs) {
      final data = d.data();
      final title = (data['title'] ?? data['name'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      map[title] = {
        'id': d.id,
        'photo': (data['photo'] ?? data['image'] ?? data['categoryPhoto'] ?? '').toString(),
      };
    }
    return map;
  }

  static Future<void> _upsertDemoAuthor() async {
    await _db.collection(usersColl).doc(demoAuthorId).set({
      'id': demoAuthorId,
      'userID': demoAuthorId,
      'firstName': 'CaribTap',
      'lastName': 'Demo',
      'email': 'demo.author@caribtap.example',
      'phoneNumber': '+18685550000',
      'profilePictureURL': profilePics.first,
      'active': true,
      'isAdmin': true, // optional; set false if you don’t want admin
      'subscriptionTier': 'premium',
      'countryCode': 'TT',
      'settings': {'allowPushNotifications': true},
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<List<String>> _createUsers(int count) async {
    final ids = <String>[];
    for (int i = 0; i < count; i++) {
      final id = 'demo_user_${_uuid.v4().substring(0, 8)}';
      final country = countries[_random.nextInt(countries.length)];
      await _db.collection(usersColl).doc(id).set({
        'id': id,
        'userID': id,
        'firstName': 'Demo',
        'lastName': 'User $i',
        'email': 'demo.user$i@caribtap.example',
        'phoneNumber': '+1868555${1000 + i}',
        'profilePictureURL': profilePics[i % profilePics.length],
        'active': true,
        'isAdmin': false,
        'subscriptionTier': i % 3 == 0 ? 'premium' : 'free',
        'countryCode': country['code'],
        'settings': {'allowPushNotifications': true},
        'createdAt': FieldValue.serverTimestamp(),
      });
      ids.add(id);
    }
    return ids;
  }

  /// Creates exactly 6 “showcase” listings with full schema.
  /// Uses deterministic IDs (demo_listing_*) so you can re-run without duplicates.
  static Future<List<String>> _createCuratedListings(Map<String, Map<String, String>> categoryMap) async {
    final nowEpoch = Timestamp.now().seconds;

    String catIdFor(String preferredTitle) {
      // If your categories collection uses different titles, this will fall back gracefully.
      if (categoryMap.containsKey(preferredTitle)) return categoryMap[preferredTitle]!['id']!;
      // fallback to any category
      if (categoryMap.isNotEmpty) return categoryMap.values.first['id']!;
      return 'misc';
    }

    String catPhotoFor(String preferredTitle) {
      if (categoryMap.containsKey(preferredTitle)) return categoryMap[preferredTitle]!['photo'] ?? '';
      if (categoryMap.isNotEmpty) return categoryMap.values.first['photo'] ?? '';
      return '';
    }

    // Helper for generating a Firestore-friendly listing payload based on your schema.
    Map<String, dynamic> baseListing({
      required String id,
      required String title,
      required String categoryTitle,
      required String place,
      required double lat,
      required double lng,
      required String description,
      required List<Map<String, dynamic>> services,
      required List<String> photos,
      required String coverPhoto,
      required String logo,
      required List<String> videos,
      bool bookingEnabled = true,
      bool useTimeBlocks = true,
      bool enableCustomQuestions = true,
      List<String> customQuestions = const [],
      List<String> timeBlocks = const [],
      List<dynamic> blockedDates = const [],
      bool storeEnabled = false,
      String storeUrl = '',
      Map<String, dynamic> filters = const {},
      String phone = '',
      String whatsapp = '',
      String email = '',
      String website = '',
      String instagram = '',
      String facebook = '',
      String tiktok = '',
      String youtube = '',
      String x = '',
      String openingHours = '',
      String currencyCode = 'TTD',
      String countryCode = 'TT',
    }) {
      return {
        'id': id,
        'title': title,

        'authorID': demoAuthorId,
        'authorName': 'CaribTap Demo',
        'authorProfilePic': '',

        'countryCode': countryCode,
        'currencyCode': currencyCode,
        'price': '',

        'categoryID': catIdFor(categoryTitle),
        'categoryTitle': categoryTitle,
        'categoryPhoto': catPhotoFor(categoryTitle),

        'place': place,
        'latitude': lat,
        'longitude': lng,

        'description': description,
        'openingHours': openingHours,
        'filters': filters,

        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'website': website,

        'instagram': instagram,
        'facebook': facebook,
        'tiktok': tiktok,
        'youtube': youtube,
        'x': x,

        'storeEnabled': storeEnabled,
        'storeUrl': storeUrl,

        'services': services,

        'logo': logo,
        'photo': coverPhoto,
        'photos': photos,
        'videos': videos,

        'bookingEnabled': bookingEnabled,
        'bookingUrl': '',

        'useTimeBlocks': useTimeBlocks,
        'timeBlocks': timeBlocks,
        'allowMultipleBookingsPerDay': true,
        'allowQuantitySelection': true,

        'enableCustomQuestions': enableCustomQuestions,
        'customQuestions': customQuestions,

        'blockedDates': blockedDates,

        'chatEnabled': true,

        'isApproved': true,
        'verified': true,
        'verifiedAt': null,
        'verifiedBy': null,
        'verificationMethod': null,
        'verificationReason': null,

        'isFeatured': false,
        'featuredBy': null,
        'featuredUntil': null,

        'suspended': false,

        'reviewsCount': 0,
        'reviewsSum': 0,
        'viewCount': 0,

        'createdAt': nowEpoch,
      };
    }

    final curated = <Map<String, dynamic>>[
      // 1) Skilled trade
      baseListing(
        id: 'demo_listing_swiftfix',
        title: 'SwiftFix Mobile Repairs',
        categoryTitle: 'Electronics & Repairs',
        place: 'Aranguez, San Juan, Trinidad and Tobago',
        lat: 10.6572,
        lng: -61.4546,
        description:
            'Fast, reliable smartphone repairs for iPhone and Android devices. Screen, battery, and charging port fixes—often same day. Mobile call-outs available in select areas.',
        services: [
          {'name': 'Screen Replacement', 'price': 250, 'duration': '45 mins', 'quantity': 1},
          {'name': 'Battery Replacement', 'price': 180, 'duration': '30 mins', 'quantity': 1},
          {'name': 'Charging Port Repair', 'price': 220, 'duration': '45 mins', 'quantity': 1},
        ],
        timeBlocks: const ['09:00-10:00', '10:00-11:00', '13:00-14:00', '15:00-16:00'],
        customQuestions: const ['Phone model?', 'What issue are you having?'],
        photos: [placeholderImages[3], placeholderImages[4]],
        coverPhoto: placeholderImages[3],
        logo: placeholderImages[2],
        videos: [placeholderVideos[0]],
        openingHours: 'Monday: 9:am → 6:pm Tuesday: 9:am → 6:pm Wednesday: 9:am → 6:pm Thursday: 9:am → 6:pm Friday: 9:am → 6:pm Saturday: 10:am → 3:pm Sunday: Closed',
        phone: '18685552104',
        whatsapp: '18685552104',
        email: 'swiftfix.tt@caribtap.example',
        instagram: 'https://instagram.com/swiftfix_tt',
        filters: const {
          'Payment': 'Cash,Bank Transfer',
          'Service Type': 'Appointment Required',
          'Parking': 'Street',
        },
      ),

      // 2) Small business services
      baseListing(
        id: 'demo_listing_freshnest',
        title: 'FreshNest Home Cleaning',
        categoryTitle: 'Home Services',
        place: 'Chaguanas, Trinidad and Tobago',
        lat: 10.5168,
        lng: -61.4115,
        description:
            'Professional residential and Airbnb cleaning services. One-time deep cleans or weekly upkeep. Eco-friendly products available on request.',
        services: [
          {'name': 'Standard Home Cleaning', 'price': 200, 'duration': '2 hrs', 'quantity': 1},
          {'name': 'Deep Cleaning', 'price': 350, 'duration': '4 hrs', 'quantity': 1},
          {'name': 'Airbnb Turnover', 'price': 180, 'duration': '1.5 hrs', 'quantity': 1},
        ],
        timeBlocks: const ['08:00-10:00', '10:00-12:00', '13:00-15:00'],
        customQuestions: const ['House or apartment?', 'How many bedrooms?'],
        photos: [placeholderImages[0], placeholderImages[1], placeholderImages[2]],
        coverPhoto: placeholderImages[0],
        logo: placeholderImages[1],
        videos: [placeholderVideos[1]],
        openingHours: 'Monday: 8:am → 5:pm Tuesday: 8:am → 5:pm Wednesday: 8:am → 5:pm Thursday: 8:am → 5:pm Friday: 8:am → 5:pm Saturday: 9:am → 2:pm Sunday: Closed',
        phone: '18685553321',
        whatsapp: '18685553321',
        email: 'bookings@freshnesttt.example',
        website: 'https://freshnesttt.example',
        filters: const {
          'Business Type': 'Professional Service',
          'Service Type': 'Appointment Required',
          'Payment': 'Cash,Bank Transfer',
          'Delivery': 'Delivery,Pickup',
        },
      ),

      // 3) Electrician
      baseListing(
        id: 'demo_listing_powerline',
        title: 'PowerLine Electrical Services',
        categoryTitle: 'Skilled Trade',
        place: 'Diego Martin, Trinidad and Tobago',
        lat: 10.7363,
        lng: -61.5543,
        description:
            'Certified electrician offering residential and small commercial electrical services. Safe, compliant, and reliable—emergency call-outs available.',
        services: [
          {'name': 'Electrical Inspection', 'price': 150, 'duration': '1 hr', 'quantity': 1},
          {'name': 'Outlet Installation', 'price': 120, 'duration': '45 mins', 'quantity': 1},
          {'name': 'Emergency Repair', 'price': 0, 'duration': '1 hr', 'quantity': 1},
        ],
        timeBlocks: const ['09:00-10:00', '11:00-12:00', '14:00-15:00'],
        customQuestions: const ['Residential or commercial?', 'Is power currently off?'],
        photos: [placeholderImages[1], placeholderImages[3]],
        coverPhoto: placeholderImages[1],
        logo: placeholderImages[4],
        videos: [placeholderVideos[2]],
        openingHours: 'Monday: 9:am → 6:pm Tuesday: 9:am → 6:pm Wednesday: 9:am → 6:pm Thursday: 9:am → 6:pm Friday: 9:am → 6:pm Saturday: 10:am → 2:pm Sunday: Closed',
        phone: '18685558872',
        whatsapp: '18685558872',
        email: 'powerlinett@caribtap.example',
        filters: const {
          'Payment': 'Cash,Bank Transfer',
          'Service Type': 'Appointment Required',
          'Parking': 'Street',
        },
      ),

      // 4) Barber
      baseListing(
        id: 'demo_listing_crownfade',
        title: 'CrownFade Barbershop',
        categoryTitle: 'Beauty & Grooming',
        place: 'Arima, Trinidad and Tobago',
        lat: 10.6286,
        lng: -61.2822,
        description:
            'Modern grooming for men and boys. Precision fades, beard shaping, and clean finishes in a relaxed environment.',
        services: [
          {'name': 'Adult Haircut', 'price': 80, 'duration': '30 mins', 'quantity': 1},
          {'name': 'Beard Trim', 'price': 40, 'duration': '15 mins', 'quantity': 1},
          {'name': 'Kids Cut', 'price': 60, 'duration': '25 mins', 'quantity': 1},
        ],
        timeBlocks: const ['10:00-10:30', '10:30-11:00', '11:00-11:30', '11:30-12:00'],
        customQuestions: const ['Adult or kids cut?', 'Any special requests?'],
        photos: [placeholderImages[4], placeholderImages[3]],
        coverPhoto: placeholderImages[4],
        logo: placeholderImages[0],
        videos: [placeholderVideos[0]],
        openingHours: 'Monday: 10:am → 7:pm Tuesday: 10:am → 7:pm Wednesday: 10:am → 7:pm Thursday: 10:am → 7:pm Friday: 10:am → 8:pm Saturday: 10:am → 6:pm Sunday: Closed',
        phone: '18685554409',
        whatsapp: '18685554409',
        instagram: 'https://instagram.com/crownfade.tt',
        tiktok: 'https://tiktok.com/@crownfade',
        email: 'crownfade@caribtap.example',
        filters: const {
          'Service Type': 'Appointment Required',
          'Payment': 'Cash,Bank Transfer',
          'Parking': 'Street',
        },
      ),

      // 5) Catering + ecommerce enabled
      baseListing(
        id: 'demo_listing_islandflavour',
        title: 'IslandFlavour Catering',
        categoryTitle: 'Food & Beverage',
        place: 'Couva, Trinidad and Tobago',
        lat: 10.4221,
        lng: -61.4690,
        description:
            'Authentic Caribbean catering for events, parties, and corporate functions. Fresh ingredients, bold flavours, unforgettable service.',
        services: [
          {'name': 'Small Event Catering (20 pax)', 'price': 1200, 'duration': '4 hrs', 'quantity': 1},
          {'name': 'Corporate Lunch Trays', 'price': 25, 'duration': 'per unit', 'quantity': 1},
          {'name': 'Custom Menu Consultation', 'price': 0, 'duration': '30 mins', 'quantity': 1},
        ],
        timeBlocks: const ['09:00-10:00', '10:00-11:00', '11:00-12:00'],
        customQuestions: const ['Event date?', 'How many guests?'],
        photos: [placeholderImages[0], placeholderImages[2], placeholderImages[1]],
        coverPhoto: placeholderImages[2],
        logo: placeholderImages[3],
        videos: [placeholderVideos[1]],
        openingHours: 'Monday: 9:am → 5:pm Tuesday: 9:am → 5:pm Wednesday: 9:am → 5:pm Thursday: 9:am → 5:pm Friday: 9:am → 5:pm Saturday: 10:am → 2:pm Sunday: Closed',
        phone: '18685551234',
        whatsapp: '18685551234',
        email: 'orders@islandflavourtt.example',
        instagram: 'https://instagram.com/islandflavour.tt',
        storeEnabled: true,
        storeUrl: 'https://islandflavourtt.example/store',
        filters: const {
          'Delivery': 'Delivery,Pickup',
          'Payment': 'Cash,Bank Transfer',
        },
      ),

      // 6) Digital services
      baseListing(
        id: 'demo_listing_pixelwave',
        title: 'PixelWave Digital Studio',
        categoryTitle: 'Digital & Creative',
        place: 'Port of Spain, Trinidad and Tobago',
        lat: 10.6603,
        lng: -61.5086,
        description:
            'Freelance digital services including logo design, social media graphics, and simple websites for small businesses. Quick turnaround and professional results.',
        services: [
          {'name': 'Logo Design', 'price': 500, 'duration': '3 days', 'quantity': 1},
          {'name': 'Social Media Kit', 'price': 350, 'duration': '2 days', 'quantity': 1},
          {'name': 'One-Page Website', 'price': 1200, 'duration': '5 days', 'quantity': 1},
        ],
        timeBlocks: const ['09:00-10:00', '12:00-13:00', '16:00-17:00'],
        customQuestions: const ['What’s your business name?', 'Do you have a logo already?'],
        photos: [placeholderImages[1], placeholderImages[2], placeholderImages[4]],
        coverPhoto: placeholderImages[1],
        logo: placeholderImages[2],
        videos: [placeholderVideos[2]],
        openingHours: 'Monday: 10:am → 6:pm Tuesday: 10:am → 6:pm Wednesday: 10:am → 6:pm Thursday: 10:am → 6:pm Friday: 10:am → 6:pm Saturday: Closed Sunday: Closed',
        phone: '18685559876',
        whatsapp: '18685559876',
        email: 'hello@pixelwave.tt',
        website: 'https://pixelwave.tt',
        instagram: 'https://instagram.com/pixelwave.tt',
        facebook: 'https://facebook.com/pixelwave.tt',
        tiktok: '',
        youtube: '',
        x: '',
        filters: const {
          'Business Type': 'Professional Service',
          'Service Type': 'Appointment Required',
          'Payment': 'Cash,Bank Transfer',
        },
      ),
    ];

    // Batch write: idempotent upserts
    final batch = _db.batch();
    for (final listing in curated) {
      final id = listing['id'] as String;
      final ref = _db.collection(listingsColl).doc(id);
      batch.set(ref, listing, SetOptions(merge: true));
    }
    await batch.commit();

    return curated.map((e) => e['id'] as String).toList();
  }

  static Future<List<String>> _createRandomListings(List<String> userIds, List<String> categoryIds, int count) async {
    final ids = <String>[];
    for (int i = 0; i < count; i++) {
      final id = 'demo_random_${_uuid.v4()}';
      final authorId = userIds[_random.nextInt(userIds.length)];
      final categoryId = categoryIds.isNotEmpty ? categoryIds[_random.nextInt(categoryIds.length)] : 'misc';
      final country = countries[_random.nextInt(countries.length)];

      await _db.collection(listingsColl).doc(id).set({
        'id': id,
        'authorID': authorId,
        'authorName': 'Demo Author $i',
        'categoryID': categoryId,
        'categoryTitle': 'Demo Category',
        'title': 'Demo Listing #$i in ${country['name']}',
        'description': 'Auto-generated listing for volume testing.',
        'place': '${country['name']} City Center',
        'countryCode': country['code'],
        'price': '${_random.nextInt(500) + 50}',
        'currencyCode': 'USD',
        'photo': placeholderImages[_random.nextInt(placeholderImages.length)],
        'photos': [
          placeholderImages[_random.nextInt(placeholderImages.length)],
          placeholderImages[_random.nextInt(placeholderImages.length)],
        ],
        'videos': [],
        'logo': '',
        'isApproved': true,
        'suspended': false,
        'verified': _random.nextBool(),
        'isFeatured': i % 5 == 0,
        'reviewsCount': _random.nextInt(10),
        'reviewsSum': _random.nextInt(50),
        'viewCount': _random.nextInt(1000),
        'createdAt': Timestamp.now().seconds,
        'latitude': 18.0 + _random.nextDouble(),
        'longitude': -76.0 - _random.nextDouble(),
        'bookingEnabled': _random.nextBool(),
        'useTimeBlocks': false,
        'enableCustomQuestions': false,
        'customQuestions': [],
        'timeBlocks': [],
        'blockedDates': [],
        'services': [],
        'filters': {},
        'storeEnabled': false,
        'storeUrl': '',
        'phone': '',
        'whatsapp': '',
        'email': '',
        'website': '',
        'instagram': '',
        'facebook': '',
        'tiktok': '',
        'youtube': '',
        'x': '',
        'openingHours': '',
        'chatEnabled': true,
      }, SetOptions(merge: true));

      ids.add(id);
    }
    return ids;
  }

  static Future<void> _createAds(List<String> userIds, List<String> listingIds, int count) async {
    if (listingIds.isEmpty) return;

    for (int i = 0; i < count; i++) {
      final id = 'demo_ad_${_uuid.v4()}';
      final listerId = userIds[_random.nextInt(userIds.length)];
      final listingId = listingIds[_random.nextInt(listingIds.length)];
      final isVideo = _random.nextBool();

      await _db.collection(adsColl).doc(id).set({
        'id': id,
        'listerId': listerId,
        'authorID': listerId,
        'listingId': listingId,
        'mediaType': isVideo ? 'video' : 'image',
        'mediaUrl': isVideo
            ? placeholderVideos[_random.nextInt(placeholderVideos.length)]
            : placeholderImages[_random.nextInt(placeholderImages.length)],
        'caption': 'Demo Deal: limited-time offer!',
        'status': 'approved',
        'adType': i % 2 == 0 ? 'promo' : 'advert',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'createdAt': Timestamp.now(),
        'pricePaid': 70.0,
        'durationDays': 7,
      }, SetOptions(merge: true));
    }
  }

  static Future<void> _createChats(List<String> userIds, List<String> listingIds) async {
    if (userIds.length < 10 || listingIds.isEmpty) return;

    for (int i = 0; i < 5; i++) {
      final channelId = 'demo_channel_${_uuid.v4()}';
      final user1Id = userIds[i];
      final user2Id = userIds[i + 5];
      final listingId = listingIds[_random.nextInt(listingIds.length)];

      await _db.collection(channelsColl).doc(channelId).set({
        'id': channelId,
        'channelID': channelId,
        'participantIds': [user1Id, user2Id],
        'lastMessage': 'Hi, is this still available?',
        'lastMessageDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'listingId': listingId,
      }, SetOptions(merge: true));

      await _db.collection(channelsColl).doc(channelId).collection('thread').add({
        'id': _uuid.v4(),
        'content': 'Hello! I saw your listing on CaribTap. Can I book a slot?',
        'senderID': user1Id,
        'recipientID': user2Id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Purges only demo_* documents (safe).
  static Future<void> purgeDemoData() async {
    print('🔥 Purging demo data...');
    final collections = [usersColl, listingsColl, adsColl, channelsColl];

    for (final coll in collections) {
      final snap = await _db.collection(coll).get();
      for (final doc in snap.docs) {
        if (doc.id.startsWith('demo_') || doc.id == demoAuthorId) {
          await doc.reference.delete();
        }
      }
    }
    print('🧹 Purge complete!');
  }
}
