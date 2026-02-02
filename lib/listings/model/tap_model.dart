import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for tap reasons
enum TapReason {
  usedService('USED_SERVICE', 'Used their service'),
  knowPersonally('KNOW_PERSONALLY', 'Know them personally'),
  seenTheirWork('SEEN_THEIR_WORK', 'Seen their work');

  final String value;
  final String displayText;
  
  const TapReason(this.value, this.displayText);
  
  static TapReason? fromString(String? value) {
    if (value == null) return null;
    try {
      return TapReason.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// Enum for tap badge levels
enum TapBadge {
  none('none', 'Not Verified', 0),
  communityVouched('community_vouched', 'Community Vouched', 10),
  communityVerified('community_verified', 'Community Verified', 50);

  final String value;
  final String displayText;
  final int threshold;
  
  const TapBadge(this.value, this.displayText, this.threshold);
  
  static TapBadge fromTapCount(int tapCount) {
    if (tapCount >= 50) return TapBadge.communityVerified;
    if (tapCount >= 10) return TapBadge.communityVouched;
    return TapBadge.none;
  }
  
  static TapBadge? fromString(String? value) {
    if (value == null) return null;
    try {
      return TapBadge.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// Model representing a single tap (vouch) for a listing
class TapModel {
  String userId;
  String listingId;
  int createdAt; // Timestamp in seconds
  TapReason? reason;

  TapModel({
    required this.userId,
    required this.listingId,
    int? createdAt,
    this.reason,
  }) : createdAt = createdAt ?? Timestamp.now().seconds;

  factory TapModel.fromJson(Map<String, dynamic> json) {
    return TapModel(
      userId: json['userId'] ?? '',
      listingId: json['listingId'] ?? '',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).seconds
          : (json['createdAt'] ?? Timestamp.now().seconds),
      reason: TapReason.fromString(json['reason']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'listingId': listingId,
      'createdAt': createdAt,
      'reason': reason?.value,
    };
  }
}
