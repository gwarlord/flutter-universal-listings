import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';

/// Handles writing phone verification state to the user's Firestore profile.
/// The OTP flow itself is handled by Firebase Auth (verifyPhoneNumber / signInWithCredential).
class PhoneVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Marks the user's phone as verified and stores the number.
  /// Call this after a successful Firebase phone credential has been confirmed.
  Future<void> markPhoneAsVerified({
    required String userId,
    required String phoneNumber,
  }) async {
    await _firestore.collection(usersCollection).doc(userId).update({
      'phoneNumber': phoneNumber,
      'phoneVerified': true,
      'phoneVerifiedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns whether the user's phone is verified according to Firestore.
  Future<bool> isPhoneVerified(String userId) async {
    try {
      final doc =
          await _firestore.collection(usersCollection).doc(userId).get();
      return (doc.data()?['phoneVerified'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
