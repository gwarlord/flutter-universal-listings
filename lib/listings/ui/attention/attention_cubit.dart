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
