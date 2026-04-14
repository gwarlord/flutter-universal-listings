import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages enhancement quota for listings
class QuotaManager {
  final FirebaseFirestore _firestore;

  static const String quotaCollection = 'enhancement_quotas';

  QuotaManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get quota for a listing (creates if doesn't exist)
  Future<EnhancementQuota> getQuota(String listingId) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection(quotaCollection).doc(listingId);

      final doc = await docRef.get();

      if (!doc.exists) {
        // Return a synthetic quota locally. Creation is handled server-side
        // during successful saves because rules do not allow client writes.
        return EnhancementQuota(
          listingId: listingId,
          year: now.year,
          month: now.month - 1, // 0-indexed
          usedCount: 0,
        );
      }

      final quota =
          EnhancementQuota.fromJson(doc.data() as Map<String, dynamic>);

      // Check if we need to reset for new month
      if (quota.needsReset()) {
        // Return reset value locally; server-side quota writes happen on save.
        return quota.resetQuota();
      }

      return quota;
    } catch (e) {
      rethrow;
    }
  }

  /// Increment quota usage
  Future<void> incrementQuota(String listingId) async {
    // Quota increments are handled server-side in saveEnhancementVariant.
    return;
  }

  /// Check if quota is available without incrementing
  Future<bool> hasQuotaAvailable(String listingId) async {
    try {
      final quota = await getQuota(listingId);
      return quota.hasQuotaAvailable();
    } catch (e) {
      rethrow;
    }
  }

  /// Get remaining quota count
  Future<int> getRemainingQuota(String listingId) async {
    try {
      final quota = await getQuota(listingId);
      return quota.getRemainingQuota();
    } catch (e) {
      rethrow;
    }
  }

  /// Get quota status as human-readable string
  Future<String> getQuotaStatus(String listingId) async {
    try {
      final quota = await getQuota(listingId);
      return quota.getQuotaStatusString();
    } catch (e) {
      rethrow;
    }
  }

  /// Manually reset quota (admin/testing only)
  Future<void> resetQuota(String listingId) async {
    // Admin/testing reset should be handled server-side to respect rules.
    return;
  }

  /// Get quotas for multiple listings
  Future<Map<String, EnhancementQuota>> getQuotasBatch(
      List<String> listingIds) async {
    try {
      final quotas = <String, EnhancementQuota>{};

      for (final listingId in listingIds) {
        quotas[listingId] = await getQuota(listingId);
      }

      return quotas;
    } catch (e) {
      rethrow;
    }
  }

  /// Stream quota changes in real-time
  Stream<EnhancementQuota> streamQuota(String listingId) {
    try {
      return _firestore
          .collection(quotaCollection)
          .doc(listingId)
          .snapshots()
          .map((doc) {
        if (!doc.exists) {
          return EnhancementQuota(
            listingId: listingId,
            year: DateTime.now().year,
            month: DateTime.now().month - 1,
            usedCount: 0,
          );
        }
        return EnhancementQuota.fromJson(doc.data() as Map<String, dynamic>);
      });
    } catch (e) {
      rethrow;
    }
  }
}
