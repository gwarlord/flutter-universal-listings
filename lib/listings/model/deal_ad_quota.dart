import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Tracks monthly deal ad posting quota for a specific user by subscription tier
class DealAdQuota {
  /// User ID
  final String userId;

  /// Calendar year
  final int year;

  /// Calendar month (0-indexed: 0 = January)
  final int month;

  /// Number of deal ads posted this month
  int adsPosted;

  /// Subscription tier: 'free', 'professional', 'premium'
  final String subscriptionTier;

  /// When this quota resets (always 1st of next month at 00:00 UTC)
  final DateTime monthResetDate;

  /// Timestamp of last ad posted in this quota period
  DateTime? lastAdPostedAt;

  /// Get monthly allowance based on subscription tier
  /// free: 0, professional: 10, premium: 20
  int get monthlyAllowance {
    return monthlyAllowanceForTier(subscriptionTier);
  }

  static int monthlyAllowanceForTier(String? rawTier) {
    switch (normalizeTier(rawTier)) {
      case 'professional':
        return 10;
      case 'premium':
        return 20;
      default:
        return 0;
    }
  }

  static String normalizeTier(String? rawTier) {
    final value = (rawTier ?? 'free').trim().toLowerCase();
    if (value.contains('premium')) {
      return 'premium';
    }
    if (value.contains('professional') || value.contains('pro')) {
      return 'professional';
    }
    return 'free';
  }

  DealAdQuota({
    required this.userId,
    required this.year,
    required this.month,
    required String subscriptionTier,
    this.adsPosted = 0,
    DateTime? monthResetDate,
    this.lastAdPostedAt,
    })  : subscriptionTier = normalizeTier(subscriptionTier),
      monthResetDate = monthResetDate ?? _calculateMonthResetDate(year, month);

  /// Check if ad posting quota is available
  bool hasQuotaAvailable() {
    return adsPosted < monthlyAllowance;
  }

  /// Check if ad posting quota is exhausted
  bool isQuotaExhausted() {
    return adsPosted >= monthlyAllowance;
  }

  /// Get remaining quota
  int getRemainingQuota() {
    return (monthlyAllowance - adsPosted).clamp(0, monthlyAllowance);
  }

  /// Get usage display string (e.g., "3/10")
  String getUsageString() {
    return '$adsPosted/$monthlyAllowance';
  }

  /// Increment ad posted count
  void incrementAdPosted() {
    if (adsPosted < monthlyAllowance) {
      adsPosted++;
      lastAdPostedAt = DateTime.now();
    }
  }

  /// Check if quota needs reset based on current date
  bool needsReset() {
    final now = DateTime.now();
    return now.isAfter(monthResetDate);
  }

  /// Reset quota for new month (returns new instance)
  DealAdQuota resetQuota() {
    final now = DateTime.now();
    final nextResetDate = now.month == 12
        ? DateTime(now.year + 1, 1, 1, 0, 0, 0)
        : DateTime(now.year, now.month + 1, 1, 0, 0, 0);

    return DealAdQuota(
      userId: userId,
      year: now.year,
      month: now.month - 1, // 0-indexed
      subscriptionTier: subscriptionTier,
      adsPosted: 0,
      monthResetDate: nextResetDate,
      lastAdPostedAt: null,
    );
  }

  /// Get reset date display string (e.g., "Mar 1" for March 1st)
  String getResetDateString() {
    return DateFormat('MMM d').format(monthResetDate);
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'year': year,
      'month': month,
      'adsPosted': adsPosted,
      'subscriptionTier': subscriptionTier,
      'monthResetDate': Timestamp.fromDate(monthResetDate),
      'lastAdPostedAt': lastAdPostedAt != null ? Timestamp.fromDate(lastAdPostedAt!) : null,
    };
  }

  /// Create from Firestore document
  factory DealAdQuota.fromJson(Map<String, dynamic> json) {
    DateTime? monthResetDate;
    if (json['monthResetDate'] != null) {
      final value = json['monthResetDate'];
      if (value is Timestamp) {
        monthResetDate = value.toDate();
      } else if (value is DateTime) {
        monthResetDate = value;
      }
    }

    DateTime? lastAdPostedAt;
    if (json['lastAdPostedAt'] != null) {
      final value = json['lastAdPostedAt'];
      if (value is Timestamp) {
        lastAdPostedAt = value.toDate();
      } else if (value is DateTime) {
        lastAdPostedAt = value;
      }
    }

    return DealAdQuota(
      userId: json['userId'] ?? '',
      year: json['year'] ?? DateTime.now().year,
      month: json['month'] ?? (DateTime.now().month - 1),
      subscriptionTier: normalizeTier(json['subscriptionTier']?.toString()),
      adsPosted: json['adsPosted'] ?? 0,
      monthResetDate: monthResetDate,
      lastAdPostedAt: lastAdPostedAt,
    );
  }

  static DateTime _calculateMonthResetDate(int year, int month) {
    // month is 0-indexed, so next month is (month + 1) + 1 = month + 2
    // unless we're in December (month 11), then it wraps to January of next year
    if (month == 11) {
      return DateTime(year + 1, 1, 1, 0, 0, 0);
    } else {
      return DateTime(year, month + 2, 1, 0, 0, 0);
    }
  }
}
