import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';
import 'deal_notification_service.dart';

/// Service to manage user's saved/claimed deals
/// Uses users/{uid}/savedDeals/{dealId} subcollection structure
class SavedDealService {
  final _firestore = FirebaseFirestore.instance;

  /// Save a deal for the user
  Future<void> saveDeal(String userId, String dealId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .doc(dealId)
          .set({
        'dealId': dealId,
        'savedAt': FieldValue.serverTimestamp(),
        'notifyBefore': true, // Default: enable notifications
      });

      // Schedule notification for deal expiry (24 hours before)
      try {
        final dealDoc = await _firestore
            .collection('deal_ads')
            .doc(dealId)
            .get();
        
        if (dealDoc.exists) {
          final deal = DealAdModel.fromDoc(dealDoc);
          await DealNotificationService.scheduleDealEndingSoonNotification(
            deal,
            userId,
          );
        }
      } catch (e) {
        print('⚠️ Error scheduling notification for deal $dealId: $e');
        // Don't rethrow - notification failure shouldn't prevent saving
      }
    } catch (e) {
      print('Error saving deal: $e');
      rethrow;
    }
  }

  /// Remove a saved deal
  Future<void> unsaveDeal(String userId, String dealId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .doc(dealId)
          .delete();
    } catch (e) {
      print('Error removing saved deal: $e');
      rethrow;
    }
  }

  /// Check if a deal is saved
  Future<bool> isDealSaved(String userId, String dealId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .doc(dealId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Error checking if deal is saved: $e');
      return false;
    }
  }

  /// Get all saved deals for a user (as DealAdModel objects)
  Stream<List<DealAdModel>> getSavedDeals(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedDeals')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<DealAdModel> deals = [];
      
      for (var doc in snapshot.docs) {
        final dealId = doc['dealId'] as String;
        try {
          final dealDoc = await _firestore
              .collection('deal_ads')
              .doc(dealId)
              .get();
          
          if (dealDoc.exists) {
            deals.add(DealAdModel.fromDoc(dealDoc));
          }
        } catch (e) {
          print('Error fetching saved deal $dealId: $e');
        }
      }
      
      return deals;
    });
  }

  /// Get count of saved deals
  Future<int> getSavedDealsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting saved deals count: $e');
      return 0;
    }
  }

  /// Toggle notification for a saved deal
  Future<void> toggleNotification(String userId, String dealId, bool notifyBefore) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .doc(dealId)
          .update({
        'notifyBefore': notifyBefore,
      });
    } catch (e) {
      print('Error toggling notification: $e');
      rethrow;
    }
  }

  /// Get deals that are saved by user and ending soon (within 24 hours)
  Future<List<DealAdModel>> getDealsEndingSoon(String userId) async {
    try {
      final now = DateTime.now();
      final in24Hours = now.add(const Duration(hours: 24));

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .where('notifyBefore', isEqualTo: true)
          .get();

      List<DealAdModel> dealsEndingSoon = [];

      for (var doc in snapshot.docs) {
        final dealId = doc['dealId'] as String;
        try {
          final dealDoc = await _firestore
              .collection('deal_ads')
              .doc(dealId)
              .get();

          if (dealDoc.exists) {
            final deal = DealAdModel.fromDoc(dealDoc);
            // Check if deal expires between now and 24 hours from now
            if (deal.expireAt.isAfter(now) && 
                deal.expireAt.isBefore(in24Hours)) {
              dealsEndingSoon.add(deal);
            }
          }
        } catch (e) {
          print('Error checking if deal ends soon: $e');
        }
      }

      return dealsEndingSoon;
    } catch (e) {
      print('Error getting deals ending soon: $e');
      return [];
    }
  }
}
