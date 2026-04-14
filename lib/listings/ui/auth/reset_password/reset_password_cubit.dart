import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/ui/auth/api/authentication_repository.dart';

part 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final AuthenticationRepository authenticationRepository;

  ResetPasswordCubit({required this.authenticationRepository})
      : super(ResetPasswordInitial());

  resetPassword(String email) async {
    try {
      await authenticationRepository.resetPassword(email);
      emit(ResetPasswordDoneState());
    } catch (e) {
      emit(ResetPasswordFailureState(
          errorMessage: e.toString().replaceFirst('Exception: ', '').tr()));
    }
  }

  checkValidField(GlobalKey<FormState> key) {
    if (key.currentState?.validate() ?? false) {
      key.currentState!.save();
      emit(ValidResetPasswordFieldState());
    } else {
      emit(ResetPasswordFailureState(
          errorMessage: 'Invalid email address.'.tr()));
    }
  }
}
