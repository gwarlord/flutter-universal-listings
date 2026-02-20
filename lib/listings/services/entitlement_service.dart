import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/model/entitlement_subscription.dart';

class EntitlementService {
  static final EntitlementService _instance = EntitlementService._internal();

  factory EntitlementService() => _instance;

  EntitlementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ValueNotifier<EntitlementSubscription?> entitlementNotifier =
      ValueNotifier<EntitlementSubscription?>(null);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  String? _currentUserId;

  void startListening(String userId) {
    if (_currentUserId == userId && _subscription != null) {
      return;
    }

    stopListening();
    _currentUserId = userId;
    _subscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('entitlements')
        .doc('subscription')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        entitlementNotifier.value = null;
        return;
      }
      entitlementNotifier.value = EntitlementSubscription.fromFirestore(snapshot);
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _currentUserId = null;
    entitlementNotifier.value = null;
  }

  Stream<EntitlementSubscription?> watchEntitlement(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('entitlements')
        .doc('subscription')
        .snapshots()
        .map((snapshot) =>
            snapshot.exists ? EntitlementSubscription.fromFirestore(snapshot) : null);
  }

  Future<EntitlementSubscription?> fetchEntitlement(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('entitlements')
        .doc('subscription')
        .get();
    if (!snapshot.exists) {
      return null;
    }
    return EntitlementSubscription.fromFirestore(snapshot);
  }

  EntitlementSubscription? get currentEntitlement => entitlementNotifier.value;
}
