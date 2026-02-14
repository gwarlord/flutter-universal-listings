import 'package:cloud_firestore/cloud_firestore.dart';

/// Module keys for attention badges
enum AttentionModule {
  conversations,
  myOrders,
  orderRequests,
  rentals,
  myBookings,
  bookingRequests,
}

extension AttentionModuleExt on AttentionModule {
  String get key {
    switch (this) {
      case AttentionModule.conversations:
        return 'conversations';
      case AttentionModule.myOrders:
        return 'myOrders';
      case AttentionModule.orderRequests:
        return 'orderRequests';
      case AttentionModule.rentals:
        return 'rentals';
      case AttentionModule.myBookings:
        return 'myBookings';
      case AttentionModule.bookingRequests:
        return 'bookingRequests';
    }
  }

  static AttentionModule fromKey(String key) {
    switch (key) {
      case 'conversations':
        return AttentionModule.conversations;
      case 'myOrders':
        return AttentionModule.myOrders;
      case 'orderRequests':
        return AttentionModule.orderRequests;
      case 'rentals':
        return AttentionModule.rentals;
      case 'myBookings':
        return AttentionModule.myBookings;
      case 'bookingRequests':
        return AttentionModule.bookingRequests;
      default:
        return AttentionModule.conversations;
    }
  }
}

class AttentionStateModel {
  /// Last time user opened each module (for badge logic)
  final Map<String, Timestamp?> lastSeen;

  /// Unread/update counts per module
  final Map<String, int> counts;

  /// Last update timestamp
  final Timestamp? updatedAt;

  AttentionStateModel({
    required this.lastSeen,
    required this.counts,
    this.updatedAt,
  });

  /// Get unread count for a module
  int getCountForModule(AttentionModule module) {
    return counts[module.key] ?? 0;
  }

  /// Check if a module has new updates
  bool hasUpdatesForModule(AttentionModule module) {
    return getCountForModule(module) > 0;
  }

  /// Check if any module has updates
  bool get globalHasAttention {
    return counts.values.any((count) => count > 0);
  }

  /// Get count for display (0-9+)
  String getDisplayCount(AttentionModule module) {
    final count = getCountForModule(module);
    if (count == 0) return '';
    if (count > 99) return '99+';
    return count.toString();
  }

  factory AttentionStateModel.fromJson(Map<String, dynamic> json) {
    final lastSeenData = json['lastSeen'] as Map<String, dynamic>? ?? {};
    final countsData = json['counts'] as Map<String, dynamic>? ?? {};

    return AttentionStateModel(
      lastSeen: lastSeenData.map((key, value) {
        return MapEntry(
          key,
          value is Timestamp ? value : null,
        );
      }),
      counts: countsData.map((key, value) {
        return MapEntry(
          key,
          (value as num?)?.toInt() ?? 0,
        );
      }),
      updatedAt: json['updatedAt'] is Timestamp
          ? json['updatedAt']
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastSeen': lastSeen,
      'counts': counts,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  @override
  String toString() => 'AttentionStateModel(globalHasAttention: $globalHasAttention, counts: $counts)';
}
