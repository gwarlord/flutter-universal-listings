import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';

/// Service to manage deal analytics and performance metrics
class DealAnalyticsService {
  final _firestore = FirebaseFirestore.instance;
  final _adsRef = FirebaseFirestore.instance.collection('deal_ads');

  /// Get analytics for a specific deal
  Future<DealAnalytics> getDealAnalytics(String dealId) async {
    try {
      final doc = await _adsRef.doc(dealId).get();
      if (!doc.exists) {
        return DealAnalytics.empty();
      }

      final deal = DealAdModel.fromDoc(doc);
      final redemptionCount = await _getRedemptionCount(dealId);

      return DealAnalytics(
        dealId: dealId,
        viewCount: deal.viewCount,
        saveCount: deal.saveCount,
        claimCount: deal.claimCount,
        redemptionCountTotal: deal.redemptionCountTotal,
        redemptionCountByUser: redemptionCount,
        redemptionLimitTotal: deal.redemptionLimitTotal,
        isSoldOut: deal.isSoldOut,
        isActive: deal.isActive,
      );
    } catch (e) {
      print('Error getting deal analytics: $e');
      return DealAnalytics.empty();
    }
  }

  /// Get all analytics for a user's deals
  Future<List<DealAnalytics>> getUserDealanalytics(String userId) async {
    try {
      final snapshot = await _adsRef
          .where('listerId', isEqualTo: userId)
          .get();

      List<DealAnalytics> analyticsList = [];

      for (var doc in snapshot.docs) {
        final deal = DealAdModel.fromDoc(doc);
        final redemptionCount = await _getRedemptionCount(doc.id);

        analyticsList.add(DealAnalytics(
          dealId: doc.id,
          viewCount: deal.viewCount,
          saveCount: deal.saveCount,
          claimCount: deal.claimCount,
          redemptionCountTotal: deal.redemptionCountTotal,
          redemptionCountByUser: redemptionCount,
          redemptionLimitTotal: deal.redemptionLimitTotal,
          isSoldOut: deal.isSoldOut,
          isActive: deal.isActive,
          dealCaption: deal.caption,
        ));
      }

      return analyticsList;
    } catch (e) {
      print('Error getting user deal analytics: $e');
      return [];
    }
  }

  /// Get unique redemption count (number of users who claimed)
  Future<int> _getRedemptionCount(String dealId) async {
    try {
      final snapshot = await _adsRef
          .doc(dealId)
          .collection('redemptions')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting redemption count: $e');
      return 0;
    }
  }

  /// Get all users who claimed a deal
  Future<List<String>> getClaimedByUsers(String dealId) async {
    try {
      final snapshot = await _adsRef
          .doc(dealId)
          .collection('redemptions')
          .get();

      return snapshot.docs.map((doc) => doc['userId'] as String).toList();
    } catch (e) {
      print('Error getting claimed by users: $e');
      return [];
    }
  }

  /// Stream analytics for real-time updates
  Stream<DealAnalytics> streamDealAnalytics(String dealId) {
    return _adsRef.doc(dealId).snapshots().asyncMap((doc) async {
      if (!doc.exists) {
        return DealAnalytics.empty();
      }

      final deal = DealAdModel.fromDoc(doc);
      final redemptionCount = await _getRedemptionCount(dealId);

      return DealAnalytics(
        dealId: dealId,
        viewCount: deal.viewCount,
        saveCount: deal.saveCount,
        claimCount: deal.claimCount,
        redemptionCountTotal: deal.redemptionCountTotal,
        redemptionCountByUser: redemptionCount,
        redemptionLimitTotal: deal.redemptionLimitTotal,
        isSoldOut: deal.isSoldOut,
        isActive: deal.isActive,
        dealCaption: deal.caption,
      );
    });
  }

  /// Get engagement metrics (views to claim ratio, etc.)
  Future<EngagementMetrics> getEngagementMetrics(String dealId) async {
    try {
      final doc = await _adsRef.doc(dealId).get();
      if (!doc.exists) {
        return EngagementMetrics.empty();
      }

      final deal = DealAdModel.fromDoc(doc);
      final usersWhoRedeemed = await _getRedemptionCount(dealId);

      final viewToSaveRatio = deal.viewCount > 0
          ? (deal.saveCount / deal.viewCount * 100).toStringAsFixed(2)
          : '0.00';

      final viewToClaimRatio = deal.viewCount > 0
          ? (deal.claimCount / deal.viewCount * 100).toStringAsFixed(2)
          : '0.00';

      final saveToClaimRatio = deal.saveCount > 0
          ? (deal.claimCount / deal.saveCount * 100).toStringAsFixed(2)
          : '0.00';

      return EngagementMetrics(
        saleRate: viewToClaimRatio,
        saveRate: viewToSaveRatio,
        redemptionRate: saveToClaimRatio,
        uniqueUsers: usersWhoRedeemed,
        averageRedemptionsPerUser: usersWhoRedeemed > 0
            ? (deal.redemptionCountTotal / usersWhoRedeemed).toStringAsFixed(2)
            : '0.00',
      );
    } catch (e) {
      print('Error getting engagement metrics: $e');
      return EngagementMetrics.empty();
    }
  }
}

/// Model for deal analytics data
class DealAnalytics {
  final String dealId;
  final int viewCount;
  final int saveCount;
  final int claimCount;
  final int redemptionCountTotal;
  final int redemptionCountByUser; // Unique users
  final int? redemptionLimitTotal;
  final bool isSoldOut;
  final bool isActive;
  final String? dealCaption;

  DealAnalytics({
    required this.dealId,
    required this.viewCount,
    required this.saveCount,
    required this.claimCount,
    required this.redemptionCountTotal,
    required this.redemptionCountByUser,
    this.redemptionLimitTotal,
    required this.isSoldOut,
    required this.isActive,
    this.dealCaption,
  });

  factory DealAnalytics.empty() {
    return DealAnalytics(
      dealId: '',
      viewCount: 0,
      saveCount: 0,
      claimCount: 0,
      redemptionCountTotal: 0,
      redemptionCountByUser: 0,
      isSoldOut: false,
      isActive: false,
    );
  }

  int get redemptionRemaining {
    if (redemptionLimitTotal == null) return -1; // Unlimited
    return redemptionLimitTotal! - redemptionCountTotal;
  }
}

/// Model for engagement metrics
class EngagementMetrics {
  final String saleRate; // % of viewers who claimed
  final String saveRate; // % of viewers who saved
  final String redemptionRate; // % of savers who claimed
  final int uniqueUsers; // Number of unique users who claimed
  final String averageRedemptionsPerUser; // Avg claims per user

  EngagementMetrics({
    required this.saleRate,
    required this.saveRate,
    required this.redemptionRate,
    required this.uniqueUsers,
    required this.averageRedemptionsPerUser,
  });

  factory EngagementMetrics.empty() {
    return EngagementMetrics(
      saleRate: '0.00',
      saveRate: '0.00',
      redemptionRate: '0.00',
      uniqueUsers: 0,
      averageRedemptionsPerUser: '0.00',
    );
  }
}
