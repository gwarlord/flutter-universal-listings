
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// Script to populate Firestore with test data for CaribTap
class TestDataPopulator {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();
  static final _random = Random();

  static const List<Map<String, String>> countries = [
    {'code': 'JM', 'name': 'Jamaica'},
    {'code': 'TT', 'name': 'Trinidad and Tobago'},
    {'code': 'BB', 'name': 'Barbados'},
    {'code': 'BS', 'name': 'Bahamas'},
    {'code': 'LC', 'name': 'Saint Lucia'},
    {'code': 'GY', 'name': 'Guyana'},
  ];

  static const List<String> categories = [
    'Restaurant',
    'Real Estate',
    'Services',
    'Auto',
    'Nightlife',
    'Shopping'
  ];

  static const List<String> profilePics = [
    'https://randomuser.me/api/portraits/men/1.jpg',
    'https://randomuser.me/api/portraits/women/2.jpg',
    'https://randomuser.me/api/portraits/men/3.jpg',
    'https://randomuser.me/api/portraits/women/4.jpg',
    'https://randomuser.me/api/portraits/men/5.jpg',
  ];

  static const List<String> listingImages = [
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500',
    'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=500',
    'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=500', // Replaced 404 image
    'https://images.unsplash.com/photo-1493238507151-c35a50d60135?w=500',
    'https://images.unsplash.com/photo-1566417713940-fe7c737a9ef2?w=500',
  ];

  static Future<void> populateAll() async {
    try {
      debugPrint('🚀 Starting data population...');
      final userIds = await _createUsers(10);
      final categoryIds = await _getCategoryIds();
      final listingIds = await _createListings(userIds, categoryIds, 20);
      await _createAds(userIds, listingIds, 10);
      await _createChats(userIds, listingIds);
      debugPrint('✅ Population complete!');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('❌ PERMISSION ERROR: You must update your Firestore Rules in the Firebase Console to allow Admin writes.');
      } else {
        debugPrint('❌ Population failed: $e');
      }
      rethrow;
    }
  }

  static Future<List<String>> _getCategoryIds() async {
    final snap = await _db.collection('categories').get();
    return snap.docs.map((d) => d.id).toList();
  }

  static Future<List<String>> _createUsers(int count) async {
    List<String> ids = [];
    for (int i = 0; i < count; i++) {
      final id = 'test_user_${_uuid.v4().substring(0, 8)}';
      final country = countries[_random.nextInt(countries.length)];
      await _db.collection('users').doc(id).set({
        'id': id,
        'userID': id,
        'firstName': 'Test',
        'lastName': 'User $i',
        'email': 'testuser$i@example.com',
        'phoneNumber': '+1876555${1000 + i}',
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

  static Future<List<String>> _createListings(List<String> userIds, List<String> categoryIds, int count) async {
    List<String> ids = [];
    for (int i = 0; i < count; i++) {
      final id = _uuid.v4();
      final authorId = userIds[_random.nextInt(userIds.length)];
      final categoryId = categoryIds.isNotEmpty ? categoryIds[_random.nextInt(categoryIds.length)] : 'misc';
      final country = countries[_random.nextInt(countries.length)];
      
      await _db.collection('listings').doc(id).set({
        'id': id,
        'authorID': authorId,
        'authorName': 'Test Author $i',
        'categoryID': categoryId,
        'categoryTitle': categories[_random.nextInt(categories.length)],
        'title': 'Amazing ${categories[_random.nextInt(categories.length)]} in ${country['name']}',
        'description': 'This is a premium test listing located in the heart of ${country['name']}. Highly recommended!',
        'place': '${country['name']} City Center',
        'countryCode': country['code'],
        'price': '${_random.nextInt(500) + 50}',
        'currencyCode': 'USD',
        'photo': listingImages[_random.nextInt(listingImages.length)],
        'photos': [listingImages[_random.nextInt(listingImages.length)], listingImages[_random.nextInt(listingImages.length)]],
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
      });
      ids.add(id);
    }
    return ids;
  }

  static Future<void> _createAds(List<String> userIds, List<String> listingIds, int count) async {
    for (int i = 0; i < count; i++) {
      final id = _uuid.v4();
      final listerId = userIds[_random.nextInt(userIds.length)];
      final listingId = listingIds[_random.nextInt(listingIds.length)];
      final isVideo = _random.nextBool();
      
      await _db.collection('deal_ads').doc(id).set({
        'id': id,
        'listerId': listerId,
        'authorID': listerId,
        'listingId': listingId,
        'mediaType': isVideo ? 'video' : 'image',
        'mediaUrl': isVideo 
            ? 'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
            : listingImages[_random.nextInt(listingImages.length)],
        'caption': 'Flash Deal! Only for today in ${countries[_random.nextInt(countries.length)]['name']}',
        'status': 'approved',
        'adType': i % 2 == 0 ? 'promo' : 'advert',
        'startDate': Timestamp.now(),
        'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'createdAt': Timestamp.now(),
        'pricePaid': 70.0,
        'durationDays': 7,
      });
    }
  }

  static Future<void> _createChats(List<String> userIds, List<String> listingIds) async {
    for (int i = 0; i < 5; i++) {
      final channelId = _uuid.v4();
      final user1Id = userIds[i];
      final user2Id = userIds[i + 5];
      final listingId = listingIds[_random.nextInt(listingIds.length)];

      final channelData = {
        'id': channelId,
        'channelID': channelId,
        'participantIds': [user1Id, user2Id],
        'lastMessage': 'Is this still available?',
        'lastMessageDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'listingId': listingId,
      };

      await _db.collection('channels').doc(channelId).set(channelData);

      await _db.collection('channels').doc(channelId).collection('thread').add({
        'id': _uuid.v4(),
        'content': 'Hello, I saw your listing. Is it available?',
        'senderID': user1Id,
        'recipientID': user2Id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> purgeTestData() async {
    try {
      debugPrint('🔥 Purging test data...');
      final collections = ['users', 'listings', 'deal_ads', 'channels'];
      for (var coll in collections) {
        final snap = await _db.collection(coll).get();
        for (var doc in snap.docs) {
          final data = doc.data();
          if (doc.id.startsWith('test_') || 
              (data['title']?.toString().contains('Amazing') ?? false) ||
              (data['caption']?.toString().contains('Flash Deal') ?? false)) {
            await doc.reference.delete();
          }
        }
      }
      debugPrint('🧹 Purge complete!');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        debugPrint('❌ PERMISSION ERROR: Admin bypass rules missing in Firebase Console.');
      }
      rethrow;
    }
  }
}
