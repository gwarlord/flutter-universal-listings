/// Tracks monthly enhancement quota for a listing
class EnhancementQuota {
  /// The listing ID
  final String listingId;

  /// Calendar year
  final int year;

  /// Calendar month (0-indexed: 0 = January)
  final int month;

  /// Number of enhancements used (0-10)
  int usedCount;

  /// Total allowed per month (always 10)
  static const int monthlyLimit = 10;

  /// When this quota resets
  final DateTime monthResetDate;

  /// Timestamp of last enhancement in this quota period
  DateTime? lastEnhancementAt;

  EnhancementQuota({
    required this.listingId,
    required this.year,
    required this.month,
    this.usedCount = 0,
    DateTime? monthResetDate,
    this.lastEnhancementAt,
  }) : monthResetDate = monthResetDate ?? _calculateMonthResetDate(year, month);

  /// Check if quota is available for this enhancement
  bool hasQuotaAvailable() {
    return usedCount < monthlyLimit;
  }

  /// Check if quota is exhausted
  bool isQuotaExhausted() {
    return usedCount >= monthlyLimit;
  }

  /// Get remaining quota
  int getRemainingQuota() {
    return (monthlyLimit - usedCount).clamp(0, monthlyLimit);
  }

  /// Increment usage count
  void incrementUsage() {
    if (usedCount < monthlyLimit) {
      usedCount++;
      lastEnhancementAt = DateTime.now();
    }
  }

  /// Check if quota needs reset based on current date
  bool needsReset() {
    final now = DateTime.now();
    return now.isAfter(monthResetDate);
  }

  /// Reset quota for new month (returns new instance since fields are final)
  EnhancementQuota resetQuota() {
    final now = DateTime.now();
    final nextResetDate = now.month == 12
        ? DateTime(now.year + 1, 1, 1, 0, 0, 0)
        : DateTime(now.year, now.month + 1, 1, 0, 0, 0);
    
    return EnhancementQuota(
      listingId: listingId,
      year: now.year,
      month: now.month - 1, // 0-indexed (0 = January)
      usedCount: 0,
      monthResetDate: nextResetDate,
      lastEnhancementAt: null,
    );
  }

  /// Create from Firestore document
  factory EnhancementQuota.fromJson(Map<String, dynamic> json) {
    return EnhancementQuota(
      listingId: json['listingId'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      usedCount: json['usedCount'] as int? ?? 0,
      monthResetDate: json['monthResetDate'] != null
          ? DateTime.parse(json['monthResetDate'] as String)
          : null,
      lastEnhancementAt: json['lastEnhancementAt'] != null
          ? DateTime.parse(json['lastEnhancementAt'] as String)
          : null,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'year': year,
      'month': month,
      'usedCount': usedCount,
      'monthResetDate': monthResetDate.toIso8601String(),
      'lastEnhancementAt': lastEnhancementAt?.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  EnhancementQuota copyWith({
    String? listingId,
    int? year,
    int? month,
    int? usedCount,
    DateTime? monthResetDate,
    DateTime? lastEnhancementAt,
  }) {
    return EnhancementQuota(
      listingId: listingId ?? this.listingId,
      year: year ?? this.year,
      month: month ?? this.month,
      usedCount: usedCount ?? this.usedCount,
      monthResetDate: monthResetDate ?? this.monthResetDate,
      lastEnhancementAt: lastEnhancementAt ?? this.lastEnhancementAt,
    );
  }

  /// Get quota status as string (e.g., "3 of 10 remaining")
  String getQuotaStatusString() {
    final remaining = getRemainingQuota();
    return '$remaining of $monthlyLimit remaining';
  }

  /// Static helper to calculate when month quota resets
  static DateTime _calculateMonthResetDate(int year, int month) {
    // Reset date is 1st of next month
    if (month == 11) {
      // December -> January of next year
      return DateTime(year + 1, 1, 1, 0, 0, 0);
    }
    return DateTime(year, month + 2, 1, 0, 0, 0); // 0-indexed month + 2
  }

  /// Get next reset date
  static DateTime getNextResetDate() {
    final now = DateTime.now();
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, 1, 0, 0, 0);
    }
    return DateTime(now.year, now.month + 1, 1, 0, 0, 0);
  }

  @override
  String toString() => 'EnhancementQuota(listing: $listingId, used: $usedCount/$monthlyLimit)';
}
