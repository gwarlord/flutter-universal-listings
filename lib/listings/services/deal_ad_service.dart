import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';
import 'package:http/http.dart' as http; // New import
import 'dart:convert'; // New import
import 'package:flutter_dotenv/flutter_dotenv.dart'; // New import for .env
import 'package:easy_localization/easy_localization.dart'; // New import for .tr()
import 'package:instaflutter/listings/model/listings_user.dart'; // Changed import to ListingsUser

class DealAdService {
  final _adsRef = FirebaseFirestore.instance.collection('deal_ads');
  final _usersRef = FirebaseFirestore.instance.collection('users'); // New reference to users collection

  Future<void> submitAd(DealAdModel ad) async {
    await _adsRef.doc(ad.id).set(ad.toMap());
    // After submitting the ad, send notifications to admins
    await sendPromotionNotificationToAdmins(ad.caption);
  }

  Future<void> deleteAd(String adId) async {
    await _adsRef.doc(adId).delete();
  }

  Stream<List<DealAdModel>> getPendingAds() {
    return _adsRef.where('status', isEqualTo: 'pending').snapshots().map(
      (snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList(),
    );
  }

  Stream<List<DealAdModel>> getApprovedAds() {
    return _adsRef.where('status', isEqualTo: 'approved').orderBy('approvedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList(),
    );
  }

  Future<void> approveAd(String adId, String reviewerId) async {
    await _adsRef.doc(adId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'reviewerId': reviewerId,
    });
  }

  Future<void> rejectAd(String adId, String reviewerId) async {
    await _adsRef.doc(adId).update({
      'status': 'rejected',
      'approvedAt': FieldValue.serverTimestamp(),
      'reviewerId': reviewerId,
    });
  }

  // New method to send promotion notifications to admins
  Future<void> sendPromotionNotificationToAdmins(String promotionCaption) async {
    try {
      final serverKey = dotenv.env['FCM_SERVER_KEY']; // Assuming FCM_SERVER_KEY is in .env
      if (serverKey == null || serverKey.isEmpty) {
        print('FCM_SERVER_KEY not found in .env. Skipping promotion notification.');
        return;
      }

      final adminUsersSnapshot = await _usersRef
          .where('isAdmin', isEqualTo: true)
          .where('pushToken', isNotEqualTo: null)
          .where('pushToken', isNotEqualTo: '')
          .get();

      if (adminUsersSnapshot.docs.isEmpty) {
        print('No admin users with push tokens found to send promotion notification.');
        return;
      }

      for (var doc in adminUsersSnapshot.docs) {
        final pushToken = doc['pushToken'];
        if (pushToken != null && pushToken.isNotEmpty) {
          final uri = Uri.parse('https://fcm.googleapis.com/fcm/send');
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'key=$serverKey',
          };
          final body = jsonEncode({
            'to': pushToken,
            'priority': 'high',
            'notification': {
              'title': 'New Promotion Uploaded!'.tr(),
              'body': 'A new promotion "$promotionCaption" has been submitted for review.'.tr(),
            },
            'data': {
              'type': 'promotion',
              'adCaption': promotionCaption,
              // You can add more data fields here if needed for specific handling in the app
            },
          });

          final response = await http.post(uri, headers: headers, body: body);

          if (response.statusCode == 200) {
            print('Promotion notification sent to admin: ${doc.id}');
          } else {
            print('Failed to send promotion notification to admin ${doc.id}: ${response.statusCode} ${response.body}');
          }
        }
      }
    } catch (e) {
      print('Error sending promotion notification to admins: $e');
    }
  }
  
  // New method to fetch a single user's details
  Future<ListingsUser?> getUser(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get();
      if (doc.exists) {
        return ListingsUser.fromJson(doc.data()!); 
      }
    } catch (e) {
      print('Error fetching user $userId: $e');
    }
    return null;
  }
}
