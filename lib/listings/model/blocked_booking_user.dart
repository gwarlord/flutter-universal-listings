import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user blocked by a specific lister from making
/// booking/rental requests.  Scoped to one lister — not platform-wide.
class BlockedBookingUser {
  final String listerId;
  final String blockedUserId;
  final DateTime blockedAt;
  final String? reason;
  final bool active;

  const BlockedBookingUser({
    required this.listerId,
    required this.blockedUserId,
    required this.blockedAt,
    this.reason,
    this.active = true,
  });

  factory BlockedBookingUser.fromJson(Map<String, dynamic> json) {
    return BlockedBookingUser(
      listerId: json['listerId'] as String? ?? '',
      blockedUserId: json['blockedUserId'] as String? ?? '',
      blockedAt: _parseDate(json['blockedAt']),
      reason: json['reason'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Map<String, dynamic> toJson() => {
        'listerId': listerId,
        'blockedUserId': blockedUserId,
        'blockedAt': Timestamp.fromDate(blockedAt),
        'reason': reason,
        'active': active,
      };

  BlockedBookingUser copyWith({bool? active, String? reason}) {
    return BlockedBookingUser(
      listerId: listerId,
      blockedUserId: blockedUserId,
      blockedAt: blockedAt,
      reason: reason ?? this.reason,
      active: active ?? this.active,
    );
  }
}
