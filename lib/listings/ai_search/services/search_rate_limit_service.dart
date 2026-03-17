import 'package:cloud_firestore/cloud_firestore.dart';

/// Result of a rate limit check
class RateLimitResult {
  final bool allowed;
  final int remaining;
  final String? reason;
  final String? upgradeMessage;

  const RateLimitResult({
    required this.allowed,
    required this.remaining,
    this.reason,
    this.upgradeMessage,
  });
}

/// Service for checking and enforcing search rate limits
class SearchRateLimitService {
  final FirebaseFirestore _firestore;

  SearchRateLimitService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Check if user can perform another AI search
  Future<RateLimitResult> checkLimit(String userId) async {
    try {
      final doc = await _firestore
          .collection('search_rate_limits')
          .doc(userId)
          .get();

      if (!doc.exists) {
        // First search, allow it
        return const RateLimitResult(allowed: true, remaining: 5);
      }

      final data = doc.data()!;
      final tier = data['subscriptionTier'] as String? ?? 'free';
      final requestsToday = data['requestsToday'] as int? ?? 0;
      final currentDayWindow = data['currentDayWindow'] as String?;
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Reset if new day
      if (currentDayWindow != today) {
        return _getLimitForTier(tier);
      }

      final limit = _getDailyLimitForTier(tier);
      final remaining = limit - requestsToday;

      if (remaining <= 0) {
        return RateLimitResult(
          allowed: false,
          remaining: 0,
          reason: 'You\'ve reached your daily AI search limit',
          upgradeMessage: tier == 'free'
              ? 'Upgrade to Professional for 50 searches/day'
              : null,
        );
      }

      return RateLimitResult(
        allowed: true,
        remaining: remaining,
      );
    } catch (e) {
      print('❌ Error checking rate limit: $e');
      // On error, allow the search (fail open)
      return const RateLimitResult(allowed: true, remaining: 5);
    }
  }

  int _getDailyLimitForTier(String tier) {
    switch (tier) {
      case 'pro':
      case 'premium':
        return 50;
      default:
        return 5;
    }
  }

  RateLimitResult _getLimitForTier(String tier) {
    final limit = _getDailyLimitForTier(tier);
    return RateLimitResult(allowed: true, remaining: limit);
  }

  /// Get user's subscription tier
  Future<String> getUserTier(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['subscriptionTier'] as String? ?? 'free';
    } catch (e) {
      print('❌ Error getting user tier: $e');
      return 'free';
    }
  }
}
