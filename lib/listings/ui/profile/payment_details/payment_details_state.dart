part of 'payment_details_cubit.dart';

abstract class PaymentDetailsState extends Equatable {
  const PaymentDetailsState();

  const factory PaymentDetailsState.initial() = PaymentDetailsInitial;
  const factory PaymentDetailsState.loading() = PaymentDetailsLoading;
  const factory PaymentDetailsState.loaded(PaymentDetailsProfile profile) = PaymentDetailsLoaded;
  const factory PaymentDetailsState.saving(PaymentDetailsProfile profile) = PaymentDetailsSaving;
  const factory PaymentDetailsState.saved(PaymentDetailsProfile profile) = PaymentDetailsSaved;
  const factory PaymentDetailsState.error(String message, [PaymentDetailsProfile? profile]) = PaymentDetailsError;

  @override
  List<Object?> get props => [];
}

class PaymentDetailsInitial extends PaymentDetailsState {
  const PaymentDetailsInitial();
}

class PaymentDetailsLoading extends PaymentDetailsState {
  const PaymentDetailsLoading();
}

class PaymentDetailsLoaded extends PaymentDetailsState {
  final PaymentDetailsProfile profile;

  const PaymentDetailsLoaded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PaymentDetailsSaving extends PaymentDetailsState {
  final PaymentDetailsProfile profile;

  const PaymentDetailsSaving(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PaymentDetailsSaved extends PaymentDetailsState {
  final PaymentDetailsProfile profile;

  const PaymentDetailsSaved(this.profile);

  @override
  List<Object?> get props => [profile];
}

class PaymentDetailsError extends PaymentDetailsState {
  final String message;
  final PaymentDetailsProfile? profile;

  const PaymentDetailsError(this.message, [this.profile]);

  @override
  List<Object?> get props => [message, profile];
}
