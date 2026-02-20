import 'package:cloud_firestore/cloud_firestore.dart';

enum EntitlementStatus {
  active,
  inactive,
  expired,
  canceled,
}

EntitlementStatus entitlementStatusFromString(String? value) {
  switch (value) {
    case 'active':
      return EntitlementStatus.active;
    case 'expired':
      return EntitlementStatus.expired;
    case 'canceled':
      return EntitlementStatus.canceled;
    default:
      return EntitlementStatus.inactive;
  }
}

String entitlementStatusToString(EntitlementStatus status) {
  switch (status) {
    case EntitlementStatus.active:
      return 'active';
    case EntitlementStatus.expired:
      return 'expired';
    case EntitlementStatus.canceled:
      return 'canceled';
    case EntitlementStatus.inactive:
    default:
      return 'inactive';
  }
}

class EntitlementSubscription {
  final String platform;
  final String productId;
  final int tier;
  final EntitlementStatus status;
  final DateTime? expiresAt;
  final bool? willRenew;
  final DateTime? lastVerifiedAt;
  final String? originalTransactionId;
  final String? purchaseTokenHash;
  final DateTime? updatedAt;

  const EntitlementSubscription({
    required this.platform,
    required this.productId,
    required this.tier,
    required this.status,
    required this.expiresAt,
    required this.willRenew,
    required this.lastVerifiedAt,
    required this.originalTransactionId,
    required this.purchaseTokenHash,
    required this.updatedAt,
  });

  bool get isActive {
    if (status != EntitlementStatus.active) {
      return false;
    }
    if (expiresAt == null) {
      return true;
    }
    return expiresAt!.isAfter(DateTime.now());
  }

  factory EntitlementSubscription.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    final expiresAt = data['expiresAt'] as Timestamp?;
    final lastVerifiedAt = data['lastVerifiedAt'] as Timestamp?;
    final updatedAt = data['updatedAt'] as Timestamp?;

    return EntitlementSubscription(
      platform: (data['platform'] as String?) ?? 'unknown',
      productId: (data['productId'] as String?) ?? '',
      tier: (data['tier'] as num?)?.toInt() ?? 0,
      status: entitlementStatusFromString(data['status'] as String?),
      expiresAt: expiresAt?.toDate(),
      willRenew: data['willRenew'] as bool?,
      lastVerifiedAt: lastVerifiedAt?.toDate(),
      originalTransactionId: data['originalTransactionId'] as String?,
      purchaseTokenHash: data['purchaseTokenHash'] as String?,
      updatedAt: updatedAt?.toDate(),
    );
  }
}
