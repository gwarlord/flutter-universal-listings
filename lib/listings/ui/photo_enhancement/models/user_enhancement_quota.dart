/// Tracks monthly enhancement quota for a specific user
class UserEnhancementQuota {
  /// User ID
  final String userId;

  /// Calendar year
  final int year;

  /// Calendar month (0-indexed: 0 = January)
  final int month;

  /// Number of full enhancements used (0-10)
  int enhancementsUsed;

  /// Number of previews used (0-10)
  int previewsUsed;

  /// Total allowed per month
  static const int monthlyLimit = 10;

  /// When this quota resets
  final DateTime monthResetDate;

  /// Timestamp of last enhancement in this quota period
  DateTime? lastEnhancementAt;

  /// Timestamp of last preview in this quota period
  DateTime? lastPreviewAt;

  UserEnhancementQuota({
    required this.userId,
    required this.year,
    required this.month,
    this.enhancementsUsed = 0,
    this.previewsUsed = 0,
    DateTime? monthResetDate,
    this.lastEnhancementAt,
    this.lastPreviewAt,
  }) : monthResetDate = monthResetDate ?? _calculateMonthResetDate(year, month);

  /// Check if enhancement quota is available
  bool hasEnhancementQuotaAvailable() {
    return enhancementsUsed < monthlyLimit;
  }

  /// Check if enhancement quota is exhausted
  bool isEnhancementQuotaExhausted() {
    return enhancementsUsed >= monthlyLimit;
  }

  /// Check if preview quota is available
  bool hasPreviewQuotaAvailable() {
    return previewsUsed < monthlyLimit;
  }

  /// Check if preview quota is exhausted
  bool isPreviewQuotaExhausted() {
    return previewsUsed >= monthlyLimit;
  }

  /// Get remaining enhancement quota
  int getRemainingEnhancementQuota() {
    return (monthlyLimit - enhancementsUsed).clamp(0, monthlyLimit);
  }

  /// Get remaining preview quota
  int getRemainingPreviewQuota() {
    return (monthlyLimit - previewsUsed).clamp(0, monthlyLimit);
  }

  /// Increment enhancement usage count
  void incrementEnhancementUsage() {
    if (enhancementsUsed < monthlyLimit) {
      enhancementsUsed++;
      lastEnhancementAt = DateTime.now();
    }
  }

  /// Increment preview usage count
  void incrementPreviewUsage() {
    if (previewsUsed < monthlyLimit) {
      previewsUsed++;
      lastPreviewAt = DateTime.now();
    }
  }

  /// Check if quota needs reset based on current date
  bool needsReset() {
    final now = DateTime.now();
    return now.isAfter(monthResetDate);
  }

  /// Reset quota for new month (returns new instance)
  UserEnhancementQuota resetQuota() {
    final now = DateTime.now();
    final nextResetDate = now.month == 12
        ? DateTime(now.year + 1, 1, 1, 0, 0, 0)
        : DateTime(now.year, now.month + 1, 1, 0, 0, 0);

    return UserEnhancementQuota(
      userId: userId,
      year: now.year,
      month: now.month - 1, // 0-indexed (0 = January)
      enhancementsUsed: 0,
      previewsUsed: 0,
      monthResetDate: nextResetDate,
      lastEnhancementAt: null,
      lastPreviewAt: null,
    );
  }

  /// Get usage status as human-readable string
  String getQuotaStatusString() {
    return 'Enhancements: $enhancementsUsed/$monthlyLimit | Previews: $previewsUsed/$monthlyLimit';
  }

  /// Get usage schedule info
  String getScheduleInfo() {
    return 'Quota resets on ${monthResetDate.month}/${monthResetDate.day}';
  }

  /// Convert to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'year': year,
      'month': month,
      'enhancementsUsed': enhancementsUsed,
      'previewsUsed': previewsUsed,
      'monthResetDate': monthResetDate.toIso8601String(),
      'lastEnhancementAt': lastEnhancementAt?.toIso8601String(),
      'lastPreviewAt': lastPreviewAt?.toIso8601String(),
    };
  }

  /// Create from Firestore document
  factory UserEnhancementQuota.fromJson(Map<String, dynamic> json) {
    return UserEnhancementQuota(
      userId: json['userId'] ?? '',
      year: json['year'] ?? DateTime.now().year,
      month: json['month'] ?? DateTime.now().month - 1,
      enhancementsUsed: json['enhancementsUsed'] ?? 0,
      previewsUsed: json['previewsUsed'] ?? 0,
      monthResetDate: json['monthResetDate'] != null
          ? DateTime.parse(json['monthResetDate'])
          : _calculateMonthResetDate(
              json['year'] ?? DateTime.now().year,
              json['month'] ?? DateTime.now().month - 1,
            ),
      lastEnhancementAt: json['lastEnhancementAt'] != null
          ? DateTime.parse(json['lastEnhancementAt'])
          : null,
      lastPreviewAt: json['lastPreviewAt'] != null
          ? DateTime.parse(json['lastPreviewAt'])
          : null,
    );
  }

  @override
  String toString() =>
      'UserEnhancementQuota(userId: $userId, enhancements: $enhancementsUsed/$monthlyLimit, previews: $previewsUsed/$monthlyLimit)';
}

/// Calculate the reset date for a given month
DateTime _calculateMonthResetDate(int year, int month) {
  // month is 0-indexed, so we add 1 to get the calendar month
  // Then add 1 more to get the first day of the next month
  final nextMonth = month + 2; // 0-indexed month + 1 + 1 for next month

  if (nextMonth > 12) {
    return DateTime(year + 1, nextMonth - 12, 1, 0, 0, 0);
  } else {
    return DateTime(year, nextMonth, 1, 0, 0, 0);
  }
}
