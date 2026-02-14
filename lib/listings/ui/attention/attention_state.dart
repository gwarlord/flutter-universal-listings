part of 'attention_cubit.dart';

class AttentionState extends Equatable {
  const AttentionState._();

  const factory AttentionState.initial() = _AttentionInitial;
  const factory AttentionState.loaded(AttentionStateModel attentionState) = _AttentionLoaded;
  const factory AttentionState.error(String message) = _AttentionError;

  bool get isLoaded => this is _AttentionLoaded;

  AttentionStateModel? get attentionState =>
      this is _AttentionLoaded ? (this as _AttentionLoaded).attentionState : null;

  String? get errorMessage =>
      this is _AttentionError ? (this as _AttentionError).message : null;

  @override
  List<Object?> get props => [
        if (this is _AttentionLoaded) (this as _AttentionLoaded).attentionState,
        if (this is _AttentionError) (this as _AttentionError).message,
      ];
}

class _AttentionInitial extends AttentionState {
  const _AttentionInitial() : super._();
}

class _AttentionLoaded extends AttentionState {
  final AttentionStateModel attentionState;

  const _AttentionLoaded(this.attentionState) : super._();
}

class _AttentionError extends AttentionState {
  final String message;

  const _AttentionError(this.message) : super._();
}
