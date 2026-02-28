import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks customer engagement with a listing for activity-based freshness
class ListingActivity {
  final String id;
  final String listingId;
  final String type; // 'booking', 'review', 'message', 'save', 'share', 'view'
  final String? customerId;
  final Timestamp timestamp;
  final int value; // Activity weight (booking=10, review=5, message=3, etc.)
  final Map<String, dynamic>? metadata;

  const ListingActivity({
    required this.id,
    required this.listingId,
    required this.type,
    this.customerId,
    required this.timestamp,
    required this.value,
    this.metadata,
  });

  factory ListingActivity.fromJson(Map<String, dynamic> json) {
    return ListingActivity(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      type: json['type'] ?? '',
      customerId: json['customerId'],
      timestamp: json['timestamp'] is Timestamp
          ? json['timestamp']
          : Timestamp.now(),
      value: json['value'] ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'type': type,
      'customerId': customerId,
      'timestamp': timestamp,
      'value': value,
      'metadata': metadata,
    };
  }

  /// Get activity value based on type
  static int getValueForType(String type) {
    const values = {
      'booking': 10,
      'review': 5,
      'message': 3,
      'share': 2,
      'save': 1,
      'view': 0, // Tracked but no value
    };
    return values[type] ?? 0;
  }

  /// Create activity record
  factory ListingActivity.create({
    required String listingId,
    required String type,
    String? customerId,
    Map<String, dynamic>? metadata,
  }) {
    return ListingActivity(
      id: '', // Will be set by Firestore
      listingId: listingId,
      type: type,
      customerId: customerId,
      timestamp: Timestamp.now(),
      value: getValueForType(type),
      metadata: metadata,
    );
  }
}

/// Aggregated activity score for a listing
class ListingActivityScore {
  final String listingId;
  final int score30Days; // Activity score in last 30 days
  final int score7Days; // Activity score in last 7 days
  final int totalBookings;
  final int totalReviews;
  final int totalMessages;
  final int totalSaves;
  final int totalShares;
  final Timestamp lastActivityAt;
  final Timestamp calculatedAt;

  const ListingActivityScore({
    required this.listingId,
    required this.score30Days,
    required this.score7Days,
    required this.totalBookings,
    required this.totalReviews,
    required this.totalMessages,
    required this.totalSaves,
    required this.totalShares,
    required this.lastActivityAt,
    required this.calculatedAt,
  });

  factory ListingActivityScore.fromJson(Map<String, dynamic> json) {
    return ListingActivityScore(
      listingId: json['listingId'] ?? '',
      score30Days: json['score30Days'] ?? 0,
      score7Days: json['score7Days'] ?? 0,
      totalBookings: json['totalBookings'] ?? 0,
      totalReviews: json['totalReviews'] ?? 0,
      totalMessages: json['totalMessages'] ?? 0,
      totalSaves: json['totalSaves'] ?? 0,
      totalShares: json['totalShares'] ?? 0,
      lastActivityAt: json['lastActivityAt'] is Timestamp
          ? json['lastActivityAt']
          : Timestamp.now(),
      calculatedAt: json['calculatedAt'] is Timestamp
          ? json['calculatedAt']
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'score30Days': score30Days,
      'score7Days': score7Days,
      'totalBookings': totalBookings,
      'totalReviews': totalReviews,
      'totalMessages': totalMessages,
      'totalSaves': totalSaves,
      'totalShares': totalShares,
      'lastActivityAt': lastActivityAt,
      'calculatedAt': calculatedAt,
    };
  }

  /// Check if listing qualifies for auto-refresh
  bool get qualifiesForAutoRefresh {
    // High recent activity (30-day threshold)
    if (score30Days >= 20) return true;
    
    // Very high recent activity (7-day threshold)
    if (score7Days >= 15) return true;
    
    // Multiple bookings
    if (totalBookings >= 3) return true;
    
    // Good mix of engagement
    if (totalReviews >= 2 && totalMessages >= 5) return true;
    
    return false;
  }

  /// Get activity level description
  String get activityLevel {
    if (score30Days >= 30) return 'Very High';
    if (score30Days >= 20) return 'High';
    if (score30Days >= 10) return 'Medium';
    if (score30Days >= 5) return 'Low';
    return 'Minimal';
  }

  /// Get activity badge color
  String get badgeColor {
    if (score30Days >= 30) return '#4CAF50'; // Green
    if (score30Days >= 20) return '#8BC34A'; // Light Green
    if (score30Days >= 10) return '#FFC107'; // Amber
    if (score30Days >= 5) return '#FF9800'; // Orange
    return '#9E9E9E'; // Grey
  }
}

/// Auto-refresh record tracking
class ListingAutoRefresh {
  final String id;
  final String listingId;
  final Timestamp refreshedAt;
  final String reason; // 'customer_engagement', 'high_activity', etc.
  final int activityScore;
  final Map<String, dynamic>? activityBreakdown;
  final bool notificationSent;

  const ListingAutoRefresh({
    required this.id,
    required this.listingId,
    required this.refreshedAt,
    required this.reason,
    required this.activityScore,
    this.activityBreakdown,
    required this.notificationSent,
  });

  factory ListingAutoRefresh.fromJson(Map<String, dynamic> json) {
    return ListingAutoRefresh(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      refreshedAt: json['refreshedAt'] is Timestamp
          ? json['refreshedAt']
          : Timestamp.now(),
      reason: json['reason'] ?? '',
      activityScore: json['activityScore'] ?? 0,
      activityBreakdown: json['activityBreakdown'] as Map<String, dynamic>?,
      notificationSent: json['notificationSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'refreshedAt': refreshedAt,
      'reason': reason,
      'activityScore': activityScore,
      'activityBreakdown': activityBreakdown,
      'notificationSent': notificationSent,
    };
  }
}
