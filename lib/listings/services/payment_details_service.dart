import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';

class PaymentDetailsService {
  final FirebaseFirestore _firestore;

  PaymentDetailsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payment_details')
        .doc('profile');
  }

  DocumentReference<Map<String, dynamic>> _publicRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payment_details')
        .doc('public');
  }

  /// Stream the private payment details profile
  Stream<PaymentDetailsProfile> streamProfile(String uid) {
    return _profileRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const PaymentDetailsProfile();
      }
      return PaymentDetailsProfile.fromJson(snapshot.data());
    });
  }

  /// Stream the public payment details snapshot
  Stream<PaymentDetailsPublic> streamPublic(String uid) {
    return _publicRef(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const PaymentDetailsPublic();
      }
      return PaymentDetailsPublic.fromJson(snapshot.data());
    });
  }

  /// Get private profile once
  Future<PaymentDetailsProfile> getProfile(String uid) async {
    final snapshot = await _profileRef(uid).get();
    if (!snapshot.exists) {
      return const PaymentDetailsProfile();
    }
    return PaymentDetailsProfile.fromJson(snapshot.data());
  }

  /// Get public snapshot once
  Future<PaymentDetailsPublic> getPublic(String uid) async {
    final snapshot = await _publicRef(uid).get();
    if (!snapshot.exists) {
      return const PaymentDetailsPublic();
    }
    return PaymentDetailsPublic.fromJson(snapshot.data());
  }

  /// Save payment details profile and update public snapshot
  Future<void> saveProfile(String uid, PaymentDetailsProfile profile) async {
    final batch = _firestore.batch();

    // Save private profile
    batch.set(_profileRef(uid), profile.toJson(), SetOptions(merge: true));

    // Generate and save public snapshot
    final publicSnapshot = generatePublicSnapshot(profile);
    batch.set(_publicRef(uid), publicSnapshot.toJson(), SetOptions(merge: true));

    await batch.commit();
  }

  /// Generate public snapshot from private profile
  /// Respects displayMode and enabled flags
  PaymentDetailsPublic generatePublicSnapshot(PaymentDetailsProfile profile) {
    // If disabled or private mode, return empty public snapshot
    if (!profile.isEnabled || profile.displayMode == PaymentDisplayMode.private) {
      return const PaymentDetailsPublic();
    }

    // Otherwise, include enabled payment methods
    return PaymentDetailsPublic.fromProfile(profile);
  }

  /// Delete payment details (both private and public)
  Future<void> deletePaymentDetails(String uid) async {
    final batch = _firestore.batch();
    batch.delete(_profileRef(uid));
    batch.delete(_publicRef(uid));
    await batch.commit();
  }

  /// Check if user has payment details configured
  Future<bool> hasPaymentDetails(String uid) async {
    final profile = await getProfile(uid);
    return profile.isEnabled && profile.hasAnyPaymentMethod;
  }
}
