import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:instaflutter/listings/model/redemption_model.dart';
import 'package:instaflutter/listings/services/redemption_service.dart';

// --- States ---
abstract class RedemptionState extends Equatable {
  const RedemptionState();
  @override
  List<Object?> get props => [];
}

class RedemptionInitial extends RedemptionState {}
class RedemptionStatusLoading extends RedemptionState {}
class AlreadyRedeemed extends RedemptionState {
  final Redemption redemption;
  const AlreadyRedeemed(this.redemption);
  @override
  List<Object?> get props => [redemption];
}
class NotRedeemed extends RedemptionState {}

class RedemptionInProgress extends RedemptionState {}
class RedemptionSuccess extends RedemptionState {}
class RedemptionFailure extends RedemptionState {
  final String error;
  const RedemptionFailure(this.error);
   @override
  List<Object?> get props => [error];
}


// --- Cubit ---
class RedemptionCubit extends Cubit<RedemptionState> {
  final RedemptionService _redemptionService;

  RedemptionCubit(this._redemptionService) : super(RedemptionInitial());

  Future<void> checkRedemptionStatus(String dealId) async {
    emit(RedemptionStatusLoading());
    final redemption = await _redemptionService.getRedemption(dealId);
    if (redemption != null) {
      emit(AlreadyRedeemed(redemption));
    } else {
      emit(NotRedeemed());
    }
  }

  Future<void> redeemDeal(String dealId) async {
    emit(RedemptionInProgress());
    final success = await _redemptionService.redeemDeal(dealId);
    if (success) {
      emit(RedemptionSuccess());
      // After success, re-check the status to update UI permanently
      await checkRedemptionStatus(dealId);
    } else {
      emit(const RedemptionFailure('Could not redeem offer. Please check your connection.'));
      // Revert to NotRedeemed to allow another attempt
      emit(NotRedeemed());
    }
  }
}
