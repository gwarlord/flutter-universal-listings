import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// TABLE MODE SETTINGS (embedded in listing doc)
// ============================================================================

class TableModeSettings {
  bool enabled;
  int summonCooldownSeconds;
  int sessionMaxMinutes;

  TableModeSettings({
    this.enabled = false,
    this.summonCooldownSeconds = 120,
    this.sessionMaxMinutes = 180,
  });

  factory TableModeSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TableModeSettings();
    }
    return TableModeSettings(
      enabled: json['enabled'] ?? false,
      summonCooldownSeconds: json['summonCooldownSeconds'] ?? 120,
      sessionMaxMinutes: json['sessionMaxMinutes'] ?? 180,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'summonCooldownSeconds': summonCooldownSeconds,
      'sessionMaxMinutes': sessionMaxMinutes,
    };
  }
}

// ============================================================================
// TABLE MODEL
// ============================================================================

class TableModel {
  String tableId;
  String tableName;
  String tableCodePublic;
  String tableSecret;
  bool isActive;
  DateTime createdAt;
  DateTime updatedAt;

  TableModel({
    required this.tableId,
    required this.tableName,
    required this.tableCodePublic,
    required this.tableSecret,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TableModel.fromJson(String tableId, Map<String, dynamic> json) {
    return TableModel(
      tableId: tableId,
      tableName: json['tableName'] ?? '',
      tableCodePublic: json['tableCodePublic'] ?? '',
      tableSecret: json['tableSecret'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tableName': tableName,
      'tableCodePublic': tableCodePublic,
      'tableSecret': tableSecret,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Generate QR payload (deep link)
  String generateQRPayload(String listingId) {
    final encodedTableName = Uri.encodeComponent(tableName);
    return 'caribtap://table?listingId=$listingId&tableId=$tableId&tableName=$encodedTableName&secret=$tableSecret';
  }
}

// ============================================================================
// ASSIGNED STAFF MEMBER
// ============================================================================

class AssignedStaff {
  String uid;
  String firstName;
  String photoUrl;
  String role; // "WAITER" | "MANAGER"

  AssignedStaff({
    required this.uid,
    required this.firstName,
    this.photoUrl = '',
    this.role = 'WAITER',
  });

  factory AssignedStaff.fromJson(Map<String, dynamic> json) {
    return AssignedStaff(
      uid: json['uid'] ?? '',
      firstName: json['firstName'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      role: json['role'] ?? 'WAITER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'firstName': firstName,
      'photoUrl': photoUrl,
      'role': role,
    };
  }
}

// ============================================================================
// TABLE SESSION MODEL
// ============================================================================

enum TableSessionStatus {
  PENDING,
  ACTIVE,
  CLOSED,
  REJECTED,
}

extension TableSessionStatusExtension on TableSessionStatus {
  String get value {
    switch (this) {
      case TableSessionStatus.PENDING:
        return 'PENDING';
      case TableSessionStatus.ACTIVE:
        return 'ACTIVE';
      case TableSessionStatus.CLOSED:
        return 'CLOSED';
      case TableSessionStatus.REJECTED:
        return 'REJECTED';
    }
  }

  static TableSessionStatus fromString(String value) {
    switch (value) {
      case 'ACTIVE':
        return TableSessionStatus.ACTIVE;
      case 'CLOSED':
        return TableSessionStatus.CLOSED;
      case 'REJECTED':
        return TableSessionStatus.REJECTED;
      default:
        return TableSessionStatus.PENDING;
    }
  }
}

class TableSessionModel {
  String sessionId;
  String listingId;
  String tableId;
  String tableName;
  String customerUid;
  String customerName;
  String customerPhotoUrl;
  TableSessionStatus status;
  DateTime createdAt;
  DateTime? activatedAt;
  DateTime? closedAt;
  List<AssignedStaff> assignedStaff;
  int summonCooldownSeconds;
  DateTime? lastSummonAt;
  DateTime? lastBillRequestAt;

  TableSessionModel({
    required this.sessionId,
    required this.listingId,
    required this.tableId,
    required this.tableName,
    required this.customerUid,
    required this.customerName,
    this.customerPhotoUrl = '',
    this.status = TableSessionStatus.PENDING,
    required this.createdAt,
    this.activatedAt,
    this.closedAt,
    this.assignedStaff = const [],
    this.summonCooldownSeconds = 120,
    this.lastSummonAt,
    this.lastBillRequestAt,
  });

  factory TableSessionModel.fromJson(String sessionId, Map<String, dynamic> json) {
    final staffList = (json['assignedStaff'] as List?)
            ?.map((s) => AssignedStaff.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return TableSessionModel(
      sessionId: sessionId,
      listingId: json['listingId'] ?? '',
      tableId: json['tableId'] ?? '',
      tableName: json['tableName'] ?? '',
      customerUid: json['customerUid'] ?? '',
      customerName: json['customerName'] ?? '',
      customerPhotoUrl: json['customerPhotoUrl'] ?? '',
      status: TableSessionStatusExtension.fromString(json['status'] ?? 'PENDING'),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activatedAt: (json['activatedAt'] as Timestamp?)?.toDate(),
      closedAt: (json['closedAt'] as Timestamp?)?.toDate(),
      assignedStaff: staffList,
      summonCooldownSeconds: json['summonCooldownSeconds'] ?? 120,
      lastSummonAt: (json['lastSummonAt'] as Timestamp?)?.toDate(),
      lastBillRequestAt: (json['lastBillRequestAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'tableId': tableId,
      'tableName': tableName,
      'customerUid': customerUid,
      'customerName': customerName,
      'customerPhotoUrl': customerPhotoUrl,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'activatedAt': activatedAt != null ? Timestamp.fromDate(activatedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      'assignedStaff': assignedStaff.map((s) => s.toJson()).toList(),
      'summonCooldownSeconds': summonCooldownSeconds,
      'lastSummonAt': lastSummonAt != null ? Timestamp.fromDate(lastSummonAt!) : null,
      'lastBillRequestAt':
          lastBillRequestAt != null ? Timestamp.fromDate(lastBillRequestAt!) : null,
    };
  }

  // Check if summon is on cooldown
  bool get isSummonOnCooldown {
    if (lastSummonAt == null) return false;
    final elapsed = DateTime.now().difference(lastSummonAt!).inSeconds;
    return elapsed < summonCooldownSeconds;
  }

  // Get remaining cooldown seconds
  int get remainingSummonCooldownSeconds {
    if (!isSummonOnCooldown) return 0;
    final elapsed = DateTime.now().difference(lastSummonAt!).inSeconds;
    return summonCooldownSeconds - elapsed;
  }

  // Check if bill request is on cooldown (60 seconds)
  bool get isBillRequestOnCooldown {
    if (lastBillRequestAt == null) return false;
    final elapsed = DateTime.now().difference(lastBillRequestAt!).inSeconds;
    return elapsed < 60;
  }
}

// ============================================================================
// SESSION EVENT MODEL
// ============================================================================

enum SessionEventType {
  SESSION_CREATED,
  SESSION_ACTIVATED,
  WAITER_ASSIGNED,
  WAITER_REASSIGNED,
  WAITER_SUMMONED,
  WAITER_ACKNOWLEDGED,
  BILL_REQUESTED,
  ORDER_PLACED,
  SESSION_CLOSED,
}

extension SessionEventTypeExtension on SessionEventType {
  String get value {
    return toString().split('.').last;
  }

  static SessionEventType fromString(String value) {
    return SessionEventType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SessionEventType.SESSION_CREATED,
    );
  }
}

enum ActorRole {
  CUSTOMER,
  WAITER,
  OWNER,
  COLLABORATOR,
  SYSTEM,
}

extension ActorRoleExtension on ActorRole {
  String get value {
    return toString().split('.').last;
  }

  static ActorRole fromString(String value) {
    return ActorRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActorRole.SYSTEM,
    );
  }
}

class SessionEventModel {
  String eventId;
  SessionEventType type;
  String actorUid;
  ActorRole actorRole;
  DateTime createdAt;
  Map<String, dynamic> metadata;

  SessionEventModel({
    required this.eventId,
    required this.type,
    required this.actorUid,
    required this.actorRole,
    required this.createdAt,
    this.metadata = const {},
  });

  factory SessionEventModel.fromJson(String eventId, Map<String, dynamic> json) {
    return SessionEventModel(
      eventId: eventId,
      type: SessionEventTypeExtension.fromString(json['type'] ?? 'SESSION_CREATED'),
      actorUid: json['actorUid'] ?? '',
      actorRole: ActorRoleExtension.fromString(json['actorRole'] ?? 'SYSTEM'),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'actorUid': actorUid,
      'actorRole': actorRole.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  // Human-readable description
  String getDescription() {
    switch (type) {
      case SessionEventType.SESSION_CREATED:
        return 'Session created';
      case SessionEventType.SESSION_ACTIVATED:
        return 'Session activated';
      case SessionEventType.WAITER_ASSIGNED:
        return 'Waiter assigned';
      case SessionEventType.WAITER_REASSIGNED:
        return 'Waiter reassigned';
      case SessionEventType.WAITER_SUMMONED:
        final purpose = metadata['purpose'] ?? '';
        return 'Waiter summoned${purpose.isNotEmpty ? " ($purpose)" : ""}';
      case SessionEventType.WAITER_ACKNOWLEDGED:
        return 'Waiter acknowledged';
      case SessionEventType.BILL_REQUESTED:
        final method = metadata['paymentMethod'] ?? '';
        return 'Bill requested${method.isNotEmpty ? " ($method)" : ""}';
      case SessionEventType.ORDER_PLACED:
        return 'Order placed';
      case SessionEventType.SESSION_CLOSED:
        return 'Session closed';
    }
  }
}

// ============================================================================
// SUMMON WAITER PURPOSE ENUM
// ============================================================================

enum SummonPurpose {
  ASSISTANCE,
  REFILL,
  QUESTION,
  OTHER,
}

extension SummonPurposeExtension on SummonPurpose {
  String get value {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case SummonPurpose.ASSISTANCE:
        return 'Need Assistance';
      case SummonPurpose.REFILL:
        return 'Refill / More Items';
      case SummonPurpose.QUESTION:
        return 'Have a Question';
      case SummonPurpose.OTHER:
        return 'Other';
    }
  }

  static SummonPurpose fromString(String value) {
    return SummonPurpose.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SummonPurpose.OTHER,
    );
  }
}

// ============================================================================
// PAYMENT METHOD ENUM
// ============================================================================

enum PaymentMethod {
  CASH,
  CARD,
  BANK_TRANSFER,
}

extension PaymentMethodExtension on PaymentMethod {
  String get value {
    return toString().split('.').last.replaceAll('_', ' ');
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.CASH:
        return 'Cash';
      case PaymentMethod.CARD:
        return 'Card';
      case PaymentMethod.BANK_TRANSFER:
        return 'Bank Transfer';
    }
  }

  static PaymentMethod fromString(String value) {
    final normalized = value.toUpperCase().replaceAll(' ', '_');
    return PaymentMethod.values.firstWhere(
      (e) => e.toString().split('.').last == normalized,
      orElse: () => PaymentMethod.CASH,
    );
  }
}
