import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/api/table_mode_repository.dart';
import 'package:caribtap/listings/model/table_mode_models.dart';

class TableModeFirebase implements TableModeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ========================================================================
  // TABLE MODE SETTINGS
  // ========================================================================

  @override
  Future<void> setTableModeSettings({
    required String listingId,
    required bool tableModeEnabled,
    required int summonCooldownSeconds,
    required int sessionMaxMinutes,
  }) async {
    try {
      final callable = _functions.httpsCallable('setTableModeSettings');
      await callable.call({
        'listingId': listingId,
        'tableModeEnabled': tableModeEnabled,
        'summonCooldownSeconds': summonCooldownSeconds,
        'sessionMaxMinutes': sessionMaxMinutes,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.setTableModeSettings error: $e $s');
      rethrow;
    }
  }

  @override
  Future<TableModeSettings?> getTableModeSettings({
    required String listingId,
  }) async {
    try {
      final doc = await _firestore.collection('listings').doc(listingId).get();
      if (!doc.exists) return null;

      final data = doc.data();
      return TableModeSettings.fromJson(data?['tableMode']);
    } catch (e, s) {
      debugPrint('TableModeFirebase.getTableModeSettings error: $e $s');
      return null;
    }
  }

  // ========================================================================
  // TABLES MANAGEMENT
  // ========================================================================

  @override
  Future<String> upsertTable({
    required String listingId,
    String? tableId,
    required String tableName,
    String? tableCodePublic,
    bool regenerateSecret = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('upsertTable');
      final result = await callable.call({
        'listingId': listingId,
        if (tableId != null) 'tableId': tableId,
        'tableName': tableName,
        if (tableCodePublic != null) 'tableCodePublic': tableCodePublic,
        if (regenerateSecret) 'regenerateSecret': true,
      });

      return result.data['tableId'] as String;
    } catch (e, s) {
      debugPrint('TableModeFirebase.upsertTable error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> deactivateTable({
    required String listingId,
    required String tableId,
    required bool isActive,
  }) async {
    try {
      final callable = _functions.httpsCallable('deactivateTable');
      await callable.call({
        'listingId': listingId,
        'tableId': tableId,
        'isActive': isActive,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.deactivateTable error: $e $s');
      rethrow;
    }
  }

  @override
  Future<List<TableModel>> getTables({
    required String listingId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('tables')
          .orderBy('tableName')
          .get();

      return snapshot.docs
          .map((doc) => TableModel.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e, s) {
      debugPrint('TableModeFirebase.getTables error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<TableModel>> streamTables({
    required String listingId,
  }) {
    return _firestore
        .collection('listings')
        .doc(listingId)
        .collection('tables')
        .orderBy('tableName')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TableModel.fromJson(doc.id, doc.data())).toList());
  }

  @override
  Future<TableModel?> getTable({
    required String listingId,
    required String tableId,
  }) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('tables')
          .doc(tableId)
          .get();

      if (!doc.exists) return null;
      return TableModel.fromJson(doc.id, doc.data()!);
    } catch (e, s) {
      debugPrint('TableModeFirebase.getTable error: $e $s');
      return null;
    }
  }

  // ========================================================================
  // TABLE SESSIONS
  // ========================================================================

  @override
  Future<String> createTableSession({
    required String listingId,
    required String mode,
    String? tableId,
    String? secret,
    String? tableCodePublic,
  }) async {
    try {
      final callable = _functions.httpsCallable('createTableSession');
      final result = await callable.call({
        'listingId': listingId,
        'mode': mode,
        if (tableId != null) 'tableId': tableId,
        if (secret != null) 'secret': secret,
        if (tableCodePublic != null) 'tableCodePublic': tableCodePublic,
      });

      return result.data['sessionId'] as String;
    } catch (e, s) {
      debugPrint('TableModeFirebase.createTableSession error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> assignWaiterToSession({
    required String sessionId,
    required List<String> waiterUids,
  }) async {
    try {
      final callable = _functions.httpsCallable('assignWaiterToSession');
      await callable.call({
        'sessionId': sessionId,
        'waiterUids': waiterUids,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.assignWaiterToSession error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> summonWaiter({
    required String sessionId,
    required String purpose,
  }) async {
    try {
      final callable = _functions.httpsCallable('summonWaiter');
      await callable.call({
        'sessionId': sessionId,
        'purpose': purpose,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.summonWaiter error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> acknowledgeSummon({
    required String sessionId,
  }) async {
    try {
      final callable = _functions.httpsCallable('acknowledgeSummon');
      await callable.call({
        'sessionId': sessionId,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.acknowledgeSummon error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> requestBill({
    required String sessionId,
    required String paymentMethod,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestBill');
      await callable.call({
        'sessionId': sessionId,
        'paymentMethod': paymentMethod,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.requestBill error: $e $s');
      rethrow;
    }
  }

  @override
  Future<void> closeTableSession({
    required String sessionId,
  }) async {
    try {
      final callable = _functions.httpsCallable('closeTableSession');
      await callable.call({
        'sessionId': sessionId,
      });
    } catch (e, s) {
      debugPrint('TableModeFirebase.closeTableSession error: $e $s');
      rethrow;
    }
  }

  @override
  Future<TableSessionModel?> getTableSession({
    required String sessionId,
  }) async {
    try {
      final doc = await _firestore.collection('table_sessions').doc(sessionId).get();

      if (!doc.exists) return null;
      return TableSessionModel.fromJson(doc.id, doc.data()!);
    } catch (e, s) {
      debugPrint('TableModeFirebase.getTableSession error: $e $s');
      return null;
    }
  }

  @override
  Stream<TableSessionModel> streamTableSession({
    required String sessionId,
  }) {
    return _firestore
        .collection('table_sessions')
        .doc(sessionId)
        .snapshots()
        .map((doc) => TableSessionModel.fromJson(doc.id, doc.data()!));
  }

  @override
  Future<List<TableSessionModel>> getListingSessions({
    required String listingId,
    String? status,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('table_sessions')
          .where('listingId', isEqualTo: listingId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => TableSessionModel.fromJson(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, s) {
      debugPrint('TableModeFirebase.getListingSessions error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<TableSessionModel>> streamListingSessions({
    required String listingId,
    String? status,
  }) {
    Query query = _firestore
        .collection('table_sessions')
        .where('listingId', isEqualTo: listingId)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => TableSessionModel.fromJson(doc.id, doc.data() as Map<String, dynamic>))
        .toList());
  }

  @override
  Future<TableSessionModel?> getCustomerActiveSession({
    required String listingId,
    required String customerUid,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('table_sessions')
          .where('listingId', isEqualTo: listingId)
          .where('customerUid', isEqualTo: customerUid)
          .where('status', whereIn: ['PENDING', 'ACTIVE'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return TableSessionModel.fromJson(snapshot.docs.first.id, snapshot.docs.first.data());
    } catch (e, s) {
      debugPrint('TableModeFirebase.getCustomerActiveSession error: $e $s');
      return null;
    }
  }

  // ========================================================================
  // SESSION EVENTS
  // ========================================================================

  @override
  Future<List<SessionEventModel>> getSessionEvents({
    required String sessionId,
    int limit = 100,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('table_sessions')
          .doc(sessionId)
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => SessionEventModel.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e, s) {
      debugPrint('TableModeFirebase.getSessionEvents error: $e $s');
      return [];
    }
  }

  @override
  Stream<List<SessionEventModel>> streamSessionEvents({
    required String sessionId,
  }) {
    return _firestore
        .collection('table_sessions')
        .doc(sessionId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SessionEventModel.fromJson(doc.id, doc.data())).toList());
  }
}

// Global instance
final tableModeRepository = TableModeFirebase();
