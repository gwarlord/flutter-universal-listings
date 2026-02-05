import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for predefined suspension reasons
enum SuspensionReason {
  breachOfPolicy,
  suspiciousActivity,
  violentOrHarassiveBehavior,
  fraudulent,
  spamOrMislabeling,
  paymentIssues,
  otherViolation,
}

extension SuspensionReasonExt on SuspensionReason {
  String get displayName {
    switch (this) {
      case SuspensionReason.breachOfPolicy:
        return 'Breach of Policy';
      case SuspensionReason.suspiciousActivity:
        return 'Suspicious Activity';
      case SuspensionReason.violentOrHarassiveBehavior:
        return 'Violent or Harassing Behavior';
      case SuspensionReason.fraudulent:
        return 'Fraudulent Activity';
      case SuspensionReason.spamOrMislabeling:
        return 'Spam or Mislabeling';
      case SuspensionReason.paymentIssues:
        return 'Payment Issues';
      case SuspensionReason.otherViolation:
        return 'Other Violation';
    }
  }

  String get toFirestore => toString().split('.').last;
}

/// Stores suspension details
class SuspensionInfo {
  final bool isSuspended;
  final SuspensionReason? reason;
  final String? reasonText; // Custom reason text
  final DateTime? suspendedAt;
  final String? suspendedBy; // Admin user ID
  final DateTime? unsuspendedAt;
  final String? unsuspendedBy;

  SuspensionInfo({
    required this.isSuspended,
    this.reason,
    this.reasonText,
    this.suspendedAt,
    this.suspendedBy,
    this.unsuspendedAt,
    this.unsuspendedBy,
  });

  factory SuspensionInfo.fromJson(Map<String, dynamic> json) {
    return SuspensionInfo(
      isSuspended: json['isSuspended'] ?? false,
      reason: json['reason'] != null
          ? SuspensionReason.values.firstWhere(
              (e) => e.toFirestore == json['reason'],
              orElse: () => SuspensionReason.otherViolation,
            )
          : null,
      reasonText: json['reasonText'],
      suspendedAt: json['suspendedAt'] is Timestamp
          ? (json['suspendedAt'] as Timestamp).toDate()
          : json['suspendedAt'] != null
              ? DateTime.parse(json['suspendedAt'])
              : null,
      suspendedBy: json['suspendedBy'],
      unsuspendedAt: json['unsuspendedAt'] is Timestamp
          ? (json['unsuspendedAt'] as Timestamp).toDate()
          : json['unsuspendedAt'] != null
              ? DateTime.parse(json['unsuspendedAt'])
              : null,
      unsuspendedBy: json['unsuspendedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isSuspended': isSuspended,
      'reason': reason?.toFirestore,
      'reasonText': reasonText,
      'suspendedAt': suspendedAt,
      'suspendedBy': suspendedBy,
      'unsuspendedAt': unsuspendedAt,
      'unsuspendedBy': unsuspendedBy,
    };
  }

  SuspensionInfo copyWith({
    bool? isSuspended,
    SuspensionReason? reason,
    String? reasonText,
    DateTime? suspendedAt,
    String? suspendedBy,
    DateTime? unsuspendedAt,
    String? unsuspendedBy,
  }) {
    return SuspensionInfo(
      isSuspended: isSuspended ?? this.isSuspended,
      reason: reason ?? this.reason,
      reasonText: reasonText ?? this.reasonText,
      suspendedAt: suspendedAt ?? this.suspendedAt,
      suspendedBy: suspendedBy ?? this.suspendedBy,
      unsuspendedAt: unsuspendedAt ?? this.unsuspendedAt,
      unsuspendedBy: unsuspendedBy ?? this.unsuspendedBy,
    );
  }
}
