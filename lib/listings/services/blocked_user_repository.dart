import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/model/blocked_booking_user.dart';

/// Manages the per-lister block list for booking/rental requests.
/// Collection path: users/{listerId}/blocked_booking_users/{blockedUserId}
class BlockedUserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _blocksRef(String listerId) => _firestore
      .collection(usersCollection)
      .doc(listerId)
      .collection('blocked_booking_users');

  /// Returns true if [userId] is actively blocked by [listerId].
  Future<bool> isUserBlockedByLister({
    required String listerId,
    required String userId,
  }) async {
    if (listerId.isEmpty || userId.isEmpty) return false;
    try {
      final doc = await _blocksRef(listerId).doc(userId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      return data?['active'] as bool? ?? false;
    } catch (_) {
      // Fail open — don't block the user if we can't read the doc.
      return false;
    }
  }

  /// Blocks [blockedUserId] from making future requests to [listerId].
  Future<void> blockUser({
    required String listerId,
    required String blockedUserId,
    String? reason,
  }) async {
    final record = BlockedBookingUser(
      listerId: listerId,
      blockedUserId: blockedUserId,
      blockedAt: DateTime.now(),
      reason: reason,
      active: true,
    );
    await _blocksRef(listerId).doc(blockedUserId).set(record.toJson());
  }

  /// Removes the active block so [blockedUserId] can again request to [listerId].
  Future<void> unblockUser({
    required String listerId,
    required String blockedUserId,
  }) async {
    await _blocksRef(listerId).doc(blockedUserId).update({'active': false});
  }

  /// Streams all actively blocked users for [listerId].
  Stream<List<BlockedBookingUser>> streamBlockedUsers(String listerId) {
    return _blocksRef(listerId)
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                BlockedBookingUser.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }
}
