import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================================
// COLLABORATOR PERMISSIONS
// ============================================================================

class CollaboratorPermissions {
  bool manageOrders;
  bool manageBookings;
  bool manageRentals;
  bool manageChats;
  bool editListing;
  bool changeOrderStatus;
  bool changeFulfillment;
  bool manageTableMode;
  bool deleteListing; // Always false - cannot be changed

  CollaboratorPermissions({
    required this.manageOrders,
    required this.manageBookings,
    required this.manageRentals,
    required this.manageChats,
    required this.editListing,
    required this.changeOrderStatus,
    required this.changeFulfillment,
    required this.manageTableMode,
    this.deleteListing = false,
  });

  factory CollaboratorPermissions.fromJson(Map<String, dynamic> json) {
    return CollaboratorPermissions(
      manageOrders: json['manageOrders'] ?? true,
      manageBookings: json['manageBookings'] ?? true,
      manageRentals: json['manageRentals'] ?? true,
      manageChats: json['manageChats'] ?? true,
      editListing: json['editListing'] ?? true,
      changeOrderStatus: json['changeOrderStatus'] ?? true,
      changeFulfillment: json['changeFulfillment'] ?? true,
      manageTableMode: json['manageTableMode'] ?? false,
      deleteListing: false, // Always false
    );
  }

  factory CollaboratorPermissions.defaultPermissions() {
    return CollaboratorPermissions(
      manageOrders: true,
      manageBookings: true,
      manageRentals: true,
      manageChats: true,
      editListing: true,
      changeOrderStatus: true,
      changeFulfillment: true,
      manageTableMode: false,
      deleteListing: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manageOrders': manageOrders,
      'manageBookings': manageBookings,
      'manageRentals': manageRentals,
      'manageChats': manageChats,
      'editListing': editListing,
      'changeOrderStatus': changeOrderStatus,
      'changeFulfillment': changeFulfillment,
      'manageTableMode': manageTableMode,
      'deleteListing': false, // Always serialize as false
    };
  }

  // Get list of enabled permissions for display
  List<String> get enabledPermissions {
    final List<String> enabled = [];
    if (manageOrders) enabled.add('manageOrders');
    if (manageBookings) enabled.add('manageBookings');
    if (manageRentals) enabled.add('manageRentals');
    if (manageChats) enabled.add('manageChats');
    if (editListing) enabled.add('editListing');
    if (changeOrderStatus) enabled.add('changeOrderStatus');
    if (changeFulfillment) enabled.add('changeFulfillment');
    if (manageTableMode) enabled.add('manageTableMode');
    return enabled;
  }

  CollaboratorPermissions copyWith({
    bool? manageOrders,
    bool? manageBookings,
    bool? manageRentals,
    bool? manageChats,
    bool? editListing,
    bool? changeOrderStatus,
    bool? changeFulfillment,
    bool? manageTableMode,
  }) {
    return CollaboratorPermissions(
      manageOrders: manageOrders ?? this.manageOrders,
      manageBookings: manageBookings ?? this.manageBookings,
      manageRentals: manageRentals ?? this.manageRentals,
      manageChats: manageChats ?? this.manageChats,
      editListing: editListing ?? this.editListing,
      changeOrderStatus: changeOrderStatus ?? this.changeOrderStatus,
      changeFulfillment: changeFulfillment ?? this.changeFulfillment,
      manageTableMode: manageTableMode ?? this.manageTableMode,
      deleteListing: false,
    );
  }
}

// ============================================================================
// COLLABORATOR MODEL
// ============================================================================

class CollaboratorModel {
  String uid;
  bool isActive;
  String role; // 'COLLABORATOR' | 'MANAGER'
  CollaboratorPermissions permissions;
  String addedBy;
  DateTime addedAt;
  DateTime updatedAt;
  String? displayName;
  String? profilePictureUrl;

  CollaboratorModel({
    required this.uid,
    required this.isActive,
    required this.role,
    required this.permissions,
    required this.addedBy,
    required this.addedAt,
    required this.updatedAt,
    this.displayName,
    this.profilePictureUrl,
  });

  factory CollaboratorModel.fromJson(
    String uid,
    Map<String, dynamic> json, {
    String? displayName,
    String? profilePictureUrl,
  }) {
    return CollaboratorModel(
      uid: uid,
      isActive: json['isActive'] ?? true,
      role: json['role'] ?? 'COLLABORATOR',
      permissions: CollaboratorPermissions.fromJson(
        json['permissions'] ?? {},
      ),
      addedBy: json['addedBy'] ?? '',
      addedAt: (json['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      displayName: displayName,
      profilePictureUrl: profilePictureUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'role': role,
      'permissions': permissions.toJson(),
      'addedBy': addedBy,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// ============================================================================
// ASSIGNED LISTING MODEL
// ============================================================================

class AssignedListingModel {
  String listingId;
  String title;
  String ownerUid;
  bool isActive;
  DateTime addedAt;
  List<String> permissionsSummary;
  DateTime? updatedAt;

  AssignedListingModel({
    required this.listingId,
    required this.title,
    required this.ownerUid,
    required this.isActive,
    required this.addedAt,
    required this.permissionsSummary,
    this.updatedAt,
  });

  factory AssignedListingModel.fromJson(
    String listingId,
    Map<String, dynamic> json,
    {String? title,
  }) {
    return AssignedListingModel(
      listingId: listingId,
      title: title ?? 'Listing',
      ownerUid: json['ownerUid'] ?? '',
      isActive: json['isActive'] ?? true,
      addedAt: (json['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      permissionsSummary: List<String>.from(json['permissionsSummary'] ?? []),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'isActive': isActive,
      'addedAt': Timestamp.fromDate(addedAt),
      'permissionsSummary': permissionsSummary,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}

// ============================================================================
// ACTIVITY LOG MODEL
// ============================================================================

class ActivityLogEntry {
  String id;
  String actorUid;
  String? actorName;
  String actorRole; // 'OWNER' | 'COLLABORATOR' | 'ADMIN'
  String actionType; // e.g., 'LISTING_EDITED', 'ORDER_STATUS_CHANGED'
  String targetType; // 'LISTING' | 'ORDER' | 'RENTAL' | 'BOOKING' | 'CHAT' | 'COLLABORATOR'
  String targetId;
  String listingId;
  DateTime createdAt;
  String? note;

  ActivityLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.actionType,
    required this.targetType,
    required this.targetId,
    required this.listingId,
    required this.createdAt,
    this.note,
  });

  factory ActivityLogEntry.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    return ActivityLogEntry(
      id: id,
      actorUid: json['actorUid'] ?? '',
      actorName: json['actorName'],
      actorRole: json['actorRole'] ?? 'COLLABORATOR',
      actionType: json['actionType'] ?? '',
      targetType: json['targetType'] ?? '',
      targetId: json['targetId'] ?? '',
      listingId: json['listingId'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actorUid': actorUid,
      'actorName': actorName,
      'actorRole': actorRole,
      'actionType': actionType,
      'targetType': targetType,
      'targetId': targetId,
      'listingId': listingId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (note != null) 'note': note,
    };
  }

  // Human-readable action label
  String getActionLabel() {
    final labels = <String, String>{
      'LISTING_EDITED': 'Listing Updated',
      'ORDER_STATUS_CHANGED': 'Order Status Changed',
      'FULFILLMENT_UPDATED': 'Fulfillment Updated',
      'RENTAL_STATUS_CHANGED': 'Rental Status Changed',
      'BOOKING_UPDATED': 'Booking Updated',
      'COLLABORATOR_ADDED': 'Collaborator Added',
      'COLLABORATOR_REMOVED': 'Collaborator Removed',
      'COLLABORATOR_PERMISSIONS_UPDATED': 'Permissions Updated',
      'CHAT_MESSAGE_SENT': 'Message Sent',
    };
    return labels[actionType] ?? actionType;
  }

  // Icon for activity type
  String getIconData() {
    final icons = <String, String>{
      'LISTING_EDITED': 'edit',
      'ORDER_STATUS_CHANGED': 'shopping_cart',
      'FULFILLMENT_UPDATED': 'local_shipping',
      'RENTAL_STATUS_CHANGED': 'home',
      'BOOKING_UPDATED': 'calendar_today',
      'COLLABORATOR_ADDED': 'person_add',
      'COLLABORATOR_REMOVED': 'person_remove',
      'COLLABORATOR_PERMISSIONS_UPDATED': 'security',
      'CHAT_MESSAGE_SENT': 'chat',
    };
    return icons[actionType] ?? 'info';
  }
}

// ============================================================================
// LISTING CHAT MODELS
// ============================================================================

class ListingChat {
  String listingId;
  String ownerUid;
  List<String> participantUids;
  DateTime updatedAt;
  String? lastMessage;
  DateTime? lastMessageAt;

  ListingChat({
    required this.listingId,
    required this.ownerUid,
    required this.participantUids,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ListingChat.fromJson(
    String listingChatId,
    Map<String, dynamic> json,
  ) {
    return ListingChat(
      listingId: json['listingId'] ?? listingChatId.replaceFirst('listing_', ''),
      ownerUid: json['ownerUid'] ?? '',
      participantUids: List<String>.from(json['participantUids'] ?? []),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: json['lastMessage'],
      lastMessageAt: (json['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'ownerUid': ownerUid,
      'participantUids': participantUids,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
    };
  }
}

// ============================================================================
// ORDER CHAT MODELS
// ============================================================================

class OrderChat {
  String orderId;
  String listingId;
  String ownerUid;
  String customerUid;
  List<String> participantUids;
  DateTime updatedAt;
  String? lastMessage;
  DateTime? lastMessageAt;

  OrderChat({
    required this.orderId,
    required this.listingId,
    required this.ownerUid,
    required this.customerUid,
    required this.participantUids,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory OrderChat.fromJson(
    String orderChatId,
    Map<String, dynamic> json,
  ) {
    return OrderChat(
      orderId: json['orderId'] ?? orderChatId.replaceFirst('order_', ''),
      listingId: json['listingId'] ?? '',
      ownerUid: json['ownerUid'] ?? '',
      customerUid: json['customerUid'] ?? '',
      participantUids: List<String>.from(json['participantUids'] ?? []),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: json['lastMessage'],
      lastMessageAt: (json['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'listingId': listingId,
      'ownerUid': ownerUid,
      'customerUid': customerUid,
      'participantUids': participantUids,
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
    };
  }
}

// ============================================================================
// COLLABORATION STATE MODEL
// ============================================================================

class CollaborationState {
  final List<CollaboratorModel> collaborators;
  final List<ActivityLogEntry> activityLog;
  final bool isOwner;
  final bool hasPremium;
  final String? currentUserRole; // 'OWNER' or 'COLLABORATOR'

  CollaborationState({
    required this.collaborators,
    required this.activityLog,
    required this.isOwner,
    required this.hasPremium,
    this.currentUserRole,
  });

  bool canManageCollaborators() {
    return isOwner && hasPremium;
  }

  bool canAccessActivityLog() {
    return isOwner || currentUserRole == 'COLLABORATOR';
  }
}
