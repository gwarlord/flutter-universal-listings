import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/ad_targeting_model.dart';

class DealAdModel {
  final String id;
  final String listerId;
  final String listingId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
  final String caption;
  final int durationDays;
  final double pricePaid;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'approved', 'rejected', 'expired'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? reviewerId;
  final String authorID;
  final String adType; // 'advert' or 'promo'
  final List<String> visibilityCountries; // List of country codes, empty = all
  final AdTargeting targeting; // Enhanced targeting configuration
  final String? targetingSummary; // Precomputed summary for quick display

  // Expiry & Timing
  final DateTime? scheduleAt; // Optional scheduled start time
  final DateTime expireAt; // Required: when the deal expires

  // Redemption & Analytics
  final String redemptionType; // 'PROMO_CODE' or 'IN_APP_CLAIM', default 'IN_APP_CLAIM'
  final String? promoCode; // Only used if redemptionType == 'PROMO_CODE'
  final int? redemptionLimitTotal; // null = unlimited
  final int? redemptionLimitPerUser; // null = unlimited
  final int redemptionCountTotal; // Current count, default 0
  final int viewCount; // Analytics: how many times viewed
  final int saveCount; // Analytics: how many times saved
  final int claimCount; // Analytics: how many times claimed

  DealAdModel({
    required this.id,
    required this.listerId,
    required this.listingId,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    required this.caption,
    required this.durationDays,
    required this.pricePaid,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.reviewerId,
    required this.authorID,
    this.adType = 'promo',
    this.visibilityCountries = const [],
    AdTargeting? targeting,
    this.targetingSummary,
    this.scheduleAt,
    required this.expireAt,
    this.redemptionType = 'IN_APP_CLAIM',
    this.promoCode,
    this.redemptionLimitTotal,
    this.redemptionLimitPerUser,
    this.redemptionCountTotal = 0,
    this.viewCount = 0,
    this.saveCount = 0,
    this.claimCount = 0,
  }) : targeting = targeting ?? AdTargeting.all();

  Map<String, dynamic> toMap() => {
    'id': id,
    'listerId': listerId,
    'listingId': listingId,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'thumbnailUrl': thumbnailUrl,
    'caption': caption,
    'durationDays': durationDays,
    'pricePaid': pricePaid,
    'startDate': startDate,
    'endDate': endDate,
    'status': status,
    'createdAt': createdAt,
    'approvedAt': approvedAt,
    'reviewerId': reviewerId,
    'authorID': authorID,
    'adType': adType,
    'visibilityCountries': visibilityCountries,
    'targeting': targeting.toMap(),
    'targetingSummary': targetingSummary ?? targeting.getSummary(),
    'scheduleAt': scheduleAt,
    'expireAt': expireAt,
    'redemptionType': redemptionType,
    'promoCode': promoCode,
    'redemptionLimitTotal': redemptionLimitTotal,
    'redemptionLimitPerUser': redemptionLimitPerUser,
    'redemptionCountTotal': redemptionCountTotal,
    'viewCount': viewCount,
    'saveCount': saveCount,
    'claimCount': claimCount,
  };

  factory DealAdModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DealAdModel(
      id: doc.id,
      listerId: data['listerId'] ?? '',
      listingId: data['listingId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      caption: data['caption'] ?? '',
      durationDays: data['durationDays'] ?? 0,
      pricePaid: (data['pricePaid'] as num?)?.toDouble() ?? 0.0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      reviewerId: data['reviewerId'],
      authorID: data['authorID'] ?? '',
      adType: data['adType'] ?? 'promo',
      visibilityCountries: List<String>.from(data['visibilityCountries'] ?? []),
      targeting: data['targeting'] != null 
          ? AdTargeting.fromMap(data['targeting'] as Map<String, dynamic>)
          : AdTargeting.all(),
      targetingSummary: data['targetingSummary'] as String?,
      scheduleAt: data['scheduleAt'] != null ? (data['scheduleAt'] as Timestamp).toDate() : null,
      expireAt: (data['expireAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 365)),
      redemptionType: data['redemptionType'] ?? 'IN_APP_CLAIM',
      promoCode: data['promoCode'] as String?,
      redemptionLimitTotal: data['redemptionLimitTotal'] as int?,
      redemptionLimitPerUser: data['redemptionLimitPerUser'] as int?,
      redemptionCountTotal: data['redemptionCountTotal'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      saveCount: data['saveCount'] ?? 0,
      claimCount: data['claimCount'] ?? 0,
    );
  }

  /// Check if deal is currently active (visible to users)
  bool get isActive {
    final now = DateTime.now();
    // Check schedule time
    if (scheduleAt != null && now.isBefore(scheduleAt!)) {
      return false; // Not yet scheduled
    }
    // Check expiry
    if (now.isAfter(expireAt)) {
      return false; // Expired
    }
    // Check approval status
    if (status != 'approved') {
      return false;
    }
    return true;
  }

  /// Check if deal has expired
  bool get isExpired {
    return DateTime.now().isAfter(expireAt);
  }

  /// Check if deal is scheduled but not yet active
  bool get isScheduled {
    return scheduleAt != null && DateTime.now().isBefore(scheduleAt!);
  }

  /// Check if redemption limit reached
  bool get isRedempionLimitReached {
    if (redemptionLimitTotal == null) return false;
    return redemptionCountTotal >= redemptionLimitTotal!;
  }

  /// Check if deal is sold out
  bool get isSoldOut {
    return isRedempionLimitReached && redemptionLimitTotal != null && redemptionLimitTotal! > 0;
  }

  /// Get time remaining until expiry in human-readable format
  String getTimeRemainingString() {
    final now = DateTime.now();
    final diff = expireAt.difference(now);
    
    if (diff.isNegative) return 'Expired';
    
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    
    if (days > 0) {
      if (days == 1 && hours < 12) return 'Ending today';
      return 'Ends in ${days}d ${hours}h';
    }
    if (hours > 0) return 'Ends in ${hours}h ${minutes}m';
    if (minutes > 0) return 'Ends in ${minutes}m';
    return 'Expires soon';
  }

  /// Check if deal ends today
  bool get endingToday {
    final now = DateTime.now();
    return expireAt.year == now.year &&
        expireAt.month == now.month &&
        expireAt.day == now.day;
  }
}
