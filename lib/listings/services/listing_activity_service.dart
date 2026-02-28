import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/listing_activity.dart';

/// Service for tracking and managing listing activity for freshness
class ListingActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a customer activity on a listing
  Future<void> recordActivity({
    required String listingId,
    required String activityType,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final activity = ListingActivity.create(
        listingId: listingId,
        type: activityType,
        customerId: customerId,
        metadata: metadata,
      );

      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('activities')
          .add(activity.toJson());

      // Update aggregate immediately for high-value activities
      if (activity.value >= 5) {
        await _updateActivityScoreImmediate(listingId);
      }
    } catch (e) {
      print('Error recording activity: $e');
    }
  }

  /// Get activity score for a listing
  Future<ListingActivityScore?> getActivityScore(String listingId) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('metadata')
          .doc('activity_score')
          .get();

      if (!doc.exists) {
        return null;
      }

      return ListingActivityScore.fromJson(doc.data()!);
    } catch (e) {
      print('Error getting activity score: $e');
      return null;
    }
  }

  /// Calculate and update activity score
  Future<ListingActivityScore> calculateActivityScore(String listingId) async {
    final now = Timestamp.now();
    final thirtyDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 30)),
    );
    final sevenDaysAgo = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    // Query activities
    final activitiesSnapshot = await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('activities')
        .where('timestamp', isGreaterThan: thirtyDaysAgo)
        .get();

    int score30Days = 0;
    int score7Days = 0;
    int totalBookings = 0;
    int totalReviews = 0;
    int totalMessages = 0;
    int totalSaves = 0;
    int totalShares = 0;
    Timestamp? lastActivityAt;

    for (final doc in activitiesSnapshot.docs) {
      final activity = ListingActivity.fromJson(doc.data());
      
      score30Days += activity.value;
      
      if (activity.timestamp.compareTo(sevenDaysAgo) >= 0) {
        score7Days += activity.value;
      }

      // Count by type
      switch (activity.type) {
        case 'booking':
          totalBookings++;
          break;
        case 'review':
          totalReviews++;
          break;
        case 'message':
          totalMessages++;
          break;
        case 'save':
          totalSaves++;
          break;
        case 'share':
          totalShares++;
          break;
      }

      if (lastActivityAt == null ||
          activity.timestamp.compareTo(lastActivityAt) > 0) {
        lastActivityAt = activity.timestamp;
      }
    }

    final activityScore = ListingActivityScore(
      listingId: listingId,
      score30Days: score30Days,
      score7Days: score7Days,
      totalBookings: totalBookings,
      totalReviews: totalReviews,
      totalMessages: totalMessages,
      totalSaves: totalSaves,
      totalShares: totalShares,
      lastActivityAt: lastActivityAt ?? now,
      calculatedAt: now,
    );

    // Save to Firestore
    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('metadata')
        .doc('activity_score')
        .set(activityScore.toJson());

    return activityScore;
  }

  /// Update activity score immediately (for high-value activities)
  Future<void> _updateActivityScoreImmediate(String listingId) async {
    try {
      await calculateActivityScore(listingId);
    } catch (e) {
      print('Error updating activity score: $e');
    }
  }

  /// Check if listing qualifies for auto-refresh
  Future<bool> qualifiesForAutoRefresh(String listingId) async {
    final score = await getActivityScore(listingId);
    if (score == null) {
      await calculateActivityScore(listingId);
      final newScore = await getActivityScore(listingId);
      return newScore?.qualifiesForAutoRefresh ?? false;
    }
    return score.qualifiesForAutoRefresh;
  }

  /// Get recent activities for a listing
  Future<List<ListingActivity>> getRecentActivities(
    String listingId, {
    int limit = 50,
    int? days,
  }) async {
    try {
      Query query = _firestore
          .collection('listings')
          .doc(listingId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (days != null) {
        final cutoffDate = Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: days)),
        );
        query = query.where('timestamp', isGreaterThan: cutoffDate);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ListingActivity.fromJson(data);
        })
          .toList();
    } catch (e) {
      print('Error getting recent activities: $e');
      return [];
    }
  }

  /// Get activity breakdown by type
  Future<Map<String, int>> getActivityBreakdown(
    String listingId, {
    int days = 30,
  }) async {
    final activities = await getRecentActivities(listingId, days: days);
    
    final breakdown = <String, int>{
      'booking': 0,
      'review': 0,
      'message': 0,
      'save': 0,
      'share': 0,
      'view': 0,
    };

    for (final activity in activities) {
      if (breakdown.containsKey(activity.type)) {
        breakdown[activity.type] = breakdown[activity.type]! + 1;
      }
    }

    return breakdown;
  }

  /// Record booking activity
  Future<void> recordBooking(String listingId, String customerId) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'booking',
      customerId: customerId,
      metadata: {'timestamp': DateTime.now().toIso8601String()},
    );
  }

  /// Record review activity
  Future<void> recordReview(
    String listingId,
    String customerId,
    double rating,
  ) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'review',
      customerId: customerId,
      metadata: {'rating': rating},
    );
  }

  /// Record message activity
  Future<void> recordMessage(String listingId, String customerId) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'message',
      customerId: customerId,
    );
  }

  /// Record save activity
  Future<void> recordSave(String listingId, String customerId) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'save',
      customerId: customerId,
    );
  }

  /// Record share activity
  Future<void> recordShare(
    String listingId,
    String customerId,
    String platform,
  ) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'share',
      customerId: customerId,
      metadata: {'platform': platform},
    );
  }

  /// Record view activity
  Future<void> recordView(String listingId, String? customerId) async {
    await recordActivity(
      listingId: listingId,
      activityType: 'view',
      customerId: customerId,
    );
  }

  /// Batch calculate activity scores for multiple listings
  Future<Map<String, ListingActivityScore>> batchCalculateScores(
    List<String> listingIds,
  ) async {
    final scores = <String, ListingActivityScore>{};
    
    for (final listingId in listingIds) {
      try {
        final score = await calculateActivityScore(listingId);
        scores[listingId] = score;
      } catch (e) {
        print('Error calculating score for $listingId: $e');
      }
    }
    
    return scores;
  }
}
