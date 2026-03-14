import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/services/blocked_user_repository.dart';

enum BookingAccessStatus {
  /// User is allowed to proceed with the request.
  allowed,

  /// No Firebase Auth session — redirect to login/auth flow.
  requiresLogin,

  /// Logged in but phone not verified — show verification gate.
  requiresPhoneVerification,

  /// The specific lister has blocked this user from requests.
  blockedByLister,
}

class BookingAccessCheckResult {
  final BookingAccessStatus status;

  /// UID of the current user, available when status ≠ requiresLogin.
  final String? userId;

  const BookingAccessCheckResult({required this.status, this.userId});

  bool get isAllowed => status == BookingAccessStatus.allowed;
}

/// Gate that must be checked before any booking/rental request is submitted.
/// Checks login state, phone verification, and lister-specific blocks.
class BookingAccessGuard {
  final BlockedUserRepository _blockedUserRepository = BlockedUserRepository();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<BookingAccessCheckResult> checkCanCreateRequest({
    required String listerId,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const BookingAccessCheckResult(
        status: BookingAccessStatus.requiresLogin,
      );
    }

    final uid = firebaseUser.uid;

    // Check phone verification from Firestore user document.
    try {
      final userDoc =
          await _firestore.collection(usersCollection).doc(uid).get();
      final data = userDoc.data() ?? {};
      final phoneVerified = data['phoneVerified'] as bool? ?? false;
      if (!phoneVerified) {
        return BookingAccessCheckResult(
          status: BookingAccessStatus.requiresPhoneVerification,
          userId: uid,
        );
      }
    } catch (_) {
      // Fail safe — cannot read user doc → require verification.
      return BookingAccessCheckResult(
        status: BookingAccessStatus.requiresPhoneVerification,
        userId: uid,
      );
    }

    // Check lister-specific block.
    final isBlocked = await _blockedUserRepository.isUserBlockedByLister(
      listerId: listerId,
      userId: uid,
    );
    if (isBlocked) {
      return BookingAccessCheckResult(
        status: BookingAccessStatus.blockedByLister,
        userId: uid,
      );
    }

    return BookingAccessCheckResult(
      status: BookingAccessStatus.allowed,
      userId: uid,
    );
  }
}
