part of 'verify_email_bloc.dart';

@immutable
abstract class VerifyEmailState {}

class VerifyEmailInitial extends VerifyEmailState {}

class ResendingState extends VerifyEmailState {}

class ResendSuccessState extends VerifyEmailState {
  final String message;

  ResendSuccessState({required this.message});
}

class ResendFailureState extends VerifyEmailState {
  final String errorMessage;

  ResendFailureState({required this.errorMessage});
}

class CheckingVerificationState extends VerifyEmailState {}

class VerifySuccessState extends VerifyEmailState {
  final String message;

  VerifySuccessState({required this.message});
}

class VerifyFailureState extends VerifyEmailState {
  final String errorMessage;

  VerifyFailureState({required this.errorMessage});
}
