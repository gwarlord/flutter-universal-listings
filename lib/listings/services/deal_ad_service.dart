import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart'; // Changed import to ListingsUser

class DealAdService {
  final _adsRef = FirebaseFirestore.instance.collection('deal_ads');
  final _usersRef = FirebaseFirestore.instance.collection('users'); // New reference to users collection

  Future<void> submitAd(DealAdModel ad) async {
    await _adsRef.doc(ad.id).set(ad.toMap());
    // Notifications are sent server-side by Cloud Functions when the ad is approved.
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
      (snap) {
        final now = DateTime.now();
        return snap.docs
            .map((doc) => DealAdModel.fromDoc(doc))
            .where((ad) {
              // Filter out expired deals
              if (ad.isExpired) return false;
              // Filter out scheduled deals (not yet active)
              if (ad.isScheduled) return false;
              return true;
            })
            .toList();
      },
    );
  }

  /// Get all active deals (not expired, not scheduled, approved)
  Stream<List<DealAdModel>> getActiveDealAds() {
    return _adsRef.where('status', isEqualTo: 'approved').snapshots().map(
      (snap) {
        return snap.docs
            .map((doc) => DealAdModel.fromDoc(doc))
            .where((ad) => ad.isActive)
            .toList();
      },
    );
  }

  // New method to get ads by user ID
  Stream<List<DealAdModel>> getAdsByUserId(String userId) {
    return _adsRef.where('listerId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots().map(
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

  /// Increment view count for a deal
  Future<void> incrementViewCount(String dealId) async {
    try {
      await _adsRef.doc(dealId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count for deal $dealId: $e');
    }
  }

  /// Increment save count for a deal
  Future<void> incrementSaveCount(String dealId, {required bool isSaving}) async {
    try {
      await _adsRef.doc(dealId).update({
        'saveCount': FieldValue.increment(isSaving ? 1 : -1),
      });
    } catch (e) {
      print('Error updating save count for deal $dealId: $e');
    }
  }

  /// Increment claim count and redemption count (with transaction support)
  Future<bool> claimDeal(String dealId, String userId) async {
    try {
      final result = await FirebaseFirestore.instance.runTransaction((transaction) async {
        final dealRef = _adsRef.doc(dealId);
        final dealDoc = await transaction.get(dealRef);
        final deal = DealAdModel.fromDoc(dealDoc);

        // Check if deal is approved
        if (deal.status != 'approved') {
          return false;
        }

        // Check redemption limits
        if (deal.isRedempionLimitReached) {
          return false; // Limit reached
        }

        // Check per-user limit - read redemption doc inside transaction
        final redemptionRef = dealRef.collection('redemptions').doc(userId);
        final redemptionDoc = await transaction.get(redemptionRef);
        final userRedemptionCount = redemptionDoc.exists 
            ? ((redemptionDoc.data()?['redemptionNumber'] as int?) ?? 0)
            : 0;
        
        if (deal.redemptionLimitPerUser != null && 
            userRedemptionCount >= deal.redemptionLimitPerUser!) {
          return false; // User limit reached
        }

        // Increment counters
        transaction.update(dealRef, {
          'claimCount': FieldValue.increment(1),
          'redemptionCountTotal': FieldValue.increment(1),
        });

        // Record the redemption - use set with merge to update without overwriting
        transaction.set(
          redemptionRef,
          {
            'userId': userId,
            'dealId': dealId,
            'lastClaimedAt': FieldValue.serverTimestamp(),
            'redemptionNumber': (userRedemptionCount + 1),
          },
          SetOptions(merge: true), // Merge to preserve any existing fields
        );

        return true;
      });

      return result as bool;
    } catch (e) {
      print('Error claiming deal $dealId for user $userId: $e');
      return false;
    }
  }

  /// Get user's redemption count for a specific deal
  Future<int> _getUserRedemptionCount(String dealId, String userId) async {
    try {
      // Read the user's redemption document directly (no query needed)
      final redemptionDoc = await _adsRef
          .doc(dealId)
          .collection('redemptions')
          .doc(userId)
          .get();
      
      if (!redemptionDoc.exists) {
        return 0;
      }
      
      // Get the redemptionNumber field which tracks how many times this user has redeemed
      final data = redemptionDoc.data();
      return (data?['redemptionNumber'] as int?) ?? 0;
    } catch (e) {
      print('Error getting user redemption count: $e');
      return 0;
    }
  }

  /// Check if user has already claimed a deal
  Future<bool> hasUserClaimedDeal(String dealId, String userId) async {
    try {
      final doc = await _adsRef.doc(dealId).collection('redemptions').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking if user claimed deal: $e');
      return false;
    }
  }

  /// Get all deals (including expired) for admin/owner view
  Stream<List<DealAdModel>> getAllAdsByUserId(String userId) {
    return _adsRef
        .where('listerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList());
  }
}
