import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/deal_ad_quota.dart';

/// Manages monthly deal ad posting quotas per user
/// Handles quota retrieval, usage tracking, and monthly resets
class DealAdQuotaManager {
  final FirebaseFirestore _firestore;

  static const String quotaCollection = 'deal_ad_quotas';

  DealAdQuotaManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get quota for a user, creating if needed
  /// [subscriptionTier] should be 'free', 'professional', or 'premium'
  Future<DealAdQuota> getQuota(
    String userId,
    String subscriptionTier,
  ) async {
    try {
      final normalizedTier = DealAdQuota.normalizeTier(subscriptionTier);
      final now = DateTime.now();
      final docRef = _firestore.collection(quotaCollection).doc(userId);

      final doc = await docRef.get();

      if (!doc.exists) {
        // Create new quota for this month
        final newQuota = DealAdQuota(
          userId: userId,
          year: now.year,
          month: now.month - 1, // 0-indexed
          subscriptionTier: normalizedTier,
          adsPosted: 0,
        );

        await docRef.set(newQuota.toJson());
        return newQuota;
      }

      final quota = DealAdQuota.fromJson(doc.data() as Map<String, dynamic>);

      // Check if we need to reset for new month
      if (quota.needsReset()) {
        final resetQuota = DealAdQuota(
          userId: quota.userId,
          year: now.year,
          month: now.month - 1,
          subscriptionTier: normalizedTier,
          adsPosted: 0,
        );
        await docRef.update({
          'adsPosted': 0,
          'subscriptionTier': normalizedTier,
          'monthResetDate': Timestamp.fromDate(resetQuota.monthResetDate),
          'year': resetQuota.year,
          'month': resetQuota.month,
          'lastAdPostedAt': null,
        });
        return resetQuota;
      }

      // Update subscription tier if it has changed
      if (quota.subscriptionTier != normalizedTier) {
        await docRef.update({'subscriptionTier': normalizedTier});
        return DealAdQuota(
          userId: quota.userId,
          year: quota.year,
          month: quota.month,
          subscriptionTier: normalizedTier,
          adsPosted: quota.adsPosted,
          monthResetDate: quota.monthResetDate,
          lastAdPostedAt: quota.lastAdPostedAt,
        );
      }

      return quota;
    } catch (e) {
      rethrow;
    }
  }

  /// Increment ad posted count for user
  /// Returns true if successful, false if quota exhausted
  Future<bool> incrementAdPosted(String userId, String subscriptionTier) async {
    try {
      final quota = await getQuota(userId, subscriptionTier);

      if (quota.isQuotaExhausted()) {
        return false;
      }

      quota.incrementAdPosted();
      await _firestore
          .collection(quotaCollection)
          .doc(userId)
          .update({'adsPosted': quota.adsPosted, 'lastAdPostedAt': Timestamp.now()});

      return true;
    } catch (e) {
      print('Error incrementing ad posted count: $e');
      return false;
    }
  }

  /// Check if user has remaining quota
  Future<bool> hasRemainingQuota(String userId, String subscriptionTier) async {
    try {
      final quota = await getQuota(userId, subscriptionTier);
      return quota.hasQuotaAvailable();
    } catch (e) {
      print('Error checking quota availability: $e');
      final normalizedTier = DealAdQuota.normalizeTier(subscriptionTier);
      return normalizedTier == 'professional' || normalizedTier == 'premium';
    }
  }

  /// Get remaining quota count
  Future<int> getRemainingQuota(String userId, String subscriptionTier) async {
    try {
      final quota = await getQuota(userId, subscriptionTier);
      return quota.getRemainingQuota();
    } catch (e) {
      print('Error getting remaining quota: $e');
      return 0;
    }
  }

  /// Get quota usage string (e.g., "3/10")
  Future<String> getUsageString(String userId, String subscriptionTier) async {
    try {
      final quota = await getQuota(userId, subscriptionTier);
      return quota.getUsageString();
    } catch (e) {
      print('Error getting usage string: $e');
      final allowance = DealAdQuota.monthlyAllowanceForTier(subscriptionTier);
      return '0/$allowance';
    }
  }

  /// Get reset date string (e.g., "Mar 1")
  Future<String> getResetDateString(String userId, String subscriptionTier) async {
    try {
      final quota = await getQuota(userId, subscriptionTier);
      return quota.getResetDateString();
    } catch (e) {
      print('Error getting reset date string: $e');
      return '';
    }
  }
}
