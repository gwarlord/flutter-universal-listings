import 'package:caribtap/listings/ui/photo_enhancement/models/user_enhancement_quota.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages per-user enhancement and preview quotas
class UserQuotaManager {
  final FirebaseFirestore _firestore;

  static const String quotaCollection = 'user_enhancement_quotas';

  UserQuotaManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get quota for a user (creates if doesn't exist)
  Future<UserEnhancementQuota> getQuota(String userId) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection(quotaCollection).doc(userId);

      final doc = await docRef.get();

      if (!doc.exists) {
        // Create new quota for this month
        final newQuota = UserEnhancementQuota(
          userId: userId,
          year: now.year,
          month: now.month - 1, // 0-indexed
          enhancementsUsed: 0,
          previewsUsed: 0,
        );

        await docRef.set(newQuota.toJson());
        return newQuota;
      }

      final quota = UserEnhancementQuota.fromJson(doc.data() as Map<String, dynamic>);

      // Check if we need to reset for new month
      if (quota.needsReset()) {
        final resetQuota = quota.resetQuota();
        await docRef.update(resetQuota.toJson());
        return resetQuota;
      }

      return quota;
    } catch (e) {
      rethrow;
    }
  }

  /// Increment enhancement usage
  Future<void> incrementEnhancementUsage(String userId) async {
    try {
      final quota = await getQuota(userId);

      if (!quota.hasEnhancementQuotaAvailable()) {
        throw Exception('Enhancement quota exhausted for this month');
      }

      quota.incrementEnhancementUsage();
      await _firestore
          .collection(quotaCollection)
          .doc(userId)
          .update(quota.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Increment preview usage
  Future<void> incrementPreviewUsage(String userId) async {
    try {
      final quota = await getQuota(userId);

      if (!quota.hasPreviewQuotaAvailable()) {
        throw Exception('Preview quota exhausted for this month');
      }

      quota.incrementPreviewUsage();
      await _firestore
          .collection(quotaCollection)
          .doc(userId)
          .update(quota.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Check if enhancement quota is available without incrementing
  Future<bool> hasEnhancementQuotaAvailable(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.hasEnhancementQuotaAvailable();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if preview quota is available without incrementing
  Future<bool> hasPreviewQuotaAvailable(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.hasPreviewQuotaAvailable();
    } catch (e) {
      rethrow;
    }
  }

  /// Get remaining enhancement quota count
  Future<int> getRemainingEnhancementQuota(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.getRemainingEnhancementQuota();
    } catch (e) {
      rethrow;
    }
  }

  /// Get remaining preview quota count
  Future<int> getRemainingPreviewQuota(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.getRemainingPreviewQuota();
    } catch (e) {
      rethrow;
    }
  }

  /// Get both usage counts as tuple (enhancements, previews)
  Future<(int enhancements, int previews)> getUsageCounts(String userId) async {
    try {
      final quota = await getQuota(userId);
      return (
        UserEnhancementQuota.monthlyLimit - quota.getRemainingEnhancementQuota(),
        UserEnhancementQuota.monthlyLimit - quota.getRemainingPreviewQuota()
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get quota status as human-readable string
  Future<String> getQuotaStatus(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.getQuotaStatusString();
    } catch (e) {
      rethrow;
    }
  }

  /// Get reset schedule info
  Future<String> getScheduleInfo(String userId) async {
    try {
      final quota = await getQuota(userId);
      return quota.getScheduleInfo();
    } catch (e) {
      rethrow;
    }
  }

  /// Manually reset quota (admin/testing only)
  Future<void> resetQuota(String userId) async {
    try {
      final quota = await getQuota(userId);
      final resetQuota = quota.resetQuota();
      await _firestore
          .collection(quotaCollection)
          .doc(userId)
          .update(resetQuota.toJson());
    } catch (e) {
      rethrow;
    }
  }
}
