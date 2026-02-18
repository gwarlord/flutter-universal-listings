import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/model/attention_state_model.dart';

class AttentionService {
  final FirebaseFirestore _firestore;
  String? _currentUserId;

  AttentionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Initialize service with user ID
  void initialize(String userId) {
    _currentUserId = userId;
    debugPrint('✅ AttentionService initialized for user: $userId');
  }

  /// Dispose service (cancel streams if needed)
  void dispose() {
    _currentUserId = null;
    debugPrint('🛑 AttentionService disposed');
  }

  /// Listen to attention state changes
  Stream<AttentionStateModel> listenToAttentionState() {
    if (_currentUserId == null) {
      debugPrint('⚠️ AttentionService: No user ID initialized');
      return Stream.value(AttentionStateModel(
        lastSeen: {},
        counts: {},
      ));
    }

    return _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('attention')
        .doc('state')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        debugPrint('📝 AttentionService: Document does not exist yet for $_currentUserId. Returning default state.');
        return AttentionStateModel(
          lastSeen: {},
          counts: {},
        );
      }

      try {
        final model = AttentionStateModel.fromJson(snapshot.data()!);
        debugPrint('📊 AttentionService: Parsed attention state update: $model');
        return model;
      } catch (e, s) {
        debugPrint('❌ AttentionService: Error parsing attention state: $e\n$s');
        return AttentionStateModel(
          lastSeen: {},
          counts: {},
        );
      }
    }).handleError((error, stackTrace) {
      debugPrint('❌ AttentionService: Error listening to attention state stream: $error\n$stackTrace');
      return AttentionStateModel(
        lastSeen: {},
        counts: {},
      );
    });
  }

  /// Mark a module as seen (call when user opens the screen)
  Future<void> markModuleAsSeen(AttentionModule module) async {
    if (_currentUserId == null) {
      debugPrint('⚠️ AttentionService: No user ID initialized');
      return;
    }

    try {
      debugPrint('👁️ AttentionService: Marking ${module.key} as seen via Cloud Function');
      
      // Call Cloud Function to mark as seen - must specify region where functions are deployed
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('markAttentionModuleAsSeen');
      
      final result = await callable.call({
        'moduleKey': module.key,
      });

      debugPrint('✅ AttentionService: Module ${module.key} marked as seen successfully: ${result.data}');
    } catch (e, s) {
      debugPrint('⚠️ AttentionService: Error calling markModuleAsSeen function: $e\n$s');
      // Don't throw - this is non-critical
    }
  }

  /// Force refresh of attention state (rarely needed)
  Future<AttentionStateModel> fetchAttentionStateOnce() async {
    if (_currentUserId == null) {
      debugPrint('⚠️ AttentionService: No user ID initialized');
      return AttentionStateModel(lastSeen: {}, counts: {});
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('attention')
          .doc('state')
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        return AttentionStateModel(lastSeen: {}, counts: {});
      }

      return AttentionStateModel.fromJson(snapshot.data()!);
    } catch (e, s) {
      debugPrint('❌ AttentionService: Error fetching attention state once: $e\n$s');
      return AttentionStateModel(lastSeen: {}, counts: {});
    }
  }

  /// Get user ID
  String? get currentUserId => _currentUserId;
}
