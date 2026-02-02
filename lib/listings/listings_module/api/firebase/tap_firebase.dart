import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:instaflutter/listings/constants/tap_constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/listings_module/api/tap_repository.dart';
import 'package:instaflutter/listings/model/tap_model.dart';

/// Firebase implementation of TapRepository
class TapFirebase extends TapRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  Future<bool> createTap({
    required String listingId,
    required String userId,
    TapReason? reason,
  }) async {
    try {
      final tapModel = TapModel(
        userId: userId,
        listingId: listingId,
        reason: reason,
      );

      // Create the tap document
      await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .doc(userId)
          .set(tapModel.toJson());

      debugPrint('✅ Tap created: $listingId by $userId');
      return true;
    } catch (e, st) {
      debugPrint('❌ createTap() ERROR: $e');
      debugPrint('Stack trace: $st');
      return false;
    }
  }

  @override
  Future<bool> removeTap({
    required String listingId,
    required String userId,
  }) async {
    try {
      await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .doc(userId)
          .delete();

      debugPrint('✅ Tap removed: $listingId by $userId');
      return true;
    } catch (e, st) {
      debugPrint('❌ removeTap() ERROR: $e');
      debugPrint('Stack trace: $st');
      return false;
    }
  }

  @override
  Future<bool> hasUserTapped({
    required String listingId,
    required String userId,
  }) async {
    try {
      final doc = await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('❌ hasUserTapped() ERROR: $e');
      return false;
    }
  }

  @override
  Future<int> getTapCount({required String listingId}) async {
    try {
      final snapshot = await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ getTapCount() ERROR: $e');
      // Fallback: query all documents and count
      try {
        final snapshot = await firestore
            .collection(cfg.listingsCollection)
            .doc(listingId)
            .collection(tapsSubcollection)
            .get();
        return snapshot.docs.length;
      } catch (e2) {
        debugPrint('❌ getTapCount() fallback ERROR: $e2');
        return 0;
      }
    }
  }

  @override
  Future<TapModel?> getUserTap({
    required String listingId,
    required String userId,
  }) async {
    try {
      final doc = await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return TapModel.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('❌ getUserTap() ERROR: $e');
      return null;
    }
  }

  @override
  Future<List<TapModel>> getListingTaps({required String listingId}) async {
    try {
      final snapshot = await firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .collection(tapsSubcollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return TapModel.fromJson(doc.data());
            } catch (e) {
              debugPrint('Failed to parse tap ${doc.id}: $e');
              return null;
            }
          })
          .whereType<TapModel>()
          .toList();
    } catch (e) {
      debugPrint('❌ getListingTaps() ERROR: $e');
      return [];
    }
  }
}
