import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:caribtap/listings/model/attention_state_model.dart';
import 'package:caribtap/listings/services/attention_service.dart';

part 'attention_state.dart';

class AttentionCubit extends Cubit<AttentionState> {
  final AttentionService attentionService;
  StreamSubscription<AttentionStateModel>? _attentionStreamSub;

  AttentionCubit({required this.attentionService})
      : super(const AttentionState.initial());

  /// Start listening to attention state updates
  void startListening() {
    debugPrint('🔊 AttentionCubit: Starting to listen to attention state');
    
    _attentionStreamSub?.cancel();
    
    _attentionStreamSub = attentionService
        .listenToAttentionState()
        .listen(
          (attentionState) {
            debugPrint('📨 AttentionCubit received update: $attentionState');
            emit(AttentionState.loaded(attentionState));
          },
          onError: (error, stackTrace) {
            debugPrint('❌ Error in attention stream: $error\n$stackTrace');
            emit(AttentionState.error(error.toString()));
          },
        );
  }

  /// Stop listening to updates
  void stopListening() {
    debugPrint('🔇 AttentionCubit: Stopping listener');
    _attentionStreamSub?.cancel();
  }

  /// Mark a module as seen
  Future<void> markModuleAsSeen(AttentionModule module) async {
    debugPrint('✋ AttentionCubit: Marking ${module.key} as seen');

    // Optimistically clear the badge in local state immediately so the UI
    // updates right away without waiting for the Firestore round-trip.
    final current = state.attentionState;
    if (current != null) {
      final updatedCounts = Map<String, int>.from(current.counts)
        ..[module.key] = 0;
      emit(AttentionState.loaded(
        AttentionStateModel(
          lastSeen: current.lastSeen,
          counts: updatedCounts,
          updatedAt: current.updatedAt,
        ),
      ));
    }

    // Then persist to Firestore via Cloud Function (stream will confirm later)
    await attentionService.markModuleAsSeen(module);
  }

  /// Refresh attention state once
  Future<void> refreshOnce() async {
    debugPrint('🔄 AttentionCubit: Refreshing attention state');
    try {
      final state = await attentionService.fetchAttentionStateOnce();
      emit(AttentionState.loaded(state));
    } catch (e) {
      debugPrint('❌ Error refreshing: $e');
      emit(AttentionState.error(e.toString()));
    }
  }

  @override
  Future<void> close() {
    debugPrint('🚫 AttentionCubit: Closing');
    _attentionStreamSub?.cancel();
    return super.close();
  }
}
