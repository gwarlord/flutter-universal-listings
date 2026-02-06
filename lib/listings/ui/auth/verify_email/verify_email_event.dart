part of 'verify_email_bloc.dart';

@immutable
abstract class VerifyEmailEvent {}

class SendVerificationCodeEvent extends VerifyEmailEvent {
  final String email;
  final String password;

  SendVerificationCodeEvent({required this.email, required this.password});
}

class VerifyCodeEvent extends VerifyEmailEvent {
  final String code;
  final String email;
  final String password;

  VerifyCodeEvent({
    required this.code,
    required this.email,
    required this.password,
  });
}

class VerifyWithLinkEvent extends VerifyEmailEvent {
  final String email;
  final String password;

  VerifyWithLinkEvent({required this.email, required this.password});
}
