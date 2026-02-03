import 'package:bloc/bloc.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:meta/meta.dart';

part 'verify_email_event.dart';
part 'verify_email_state.dart';

class VerifyEmailBloc extends Bloc<VerifyEmailEvent, VerifyEmailState> {
  final AuthenticationBloc _authenticationBloc;

  VerifyEmailBloc(this._authenticationBloc) : super(VerifyEmailInitial()) {
    on<SendVerificationCodeEvent>((event, emit) async {
      emit(ResendingState());
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: event.email,
            password: event.password,
          );
        }
        final callable = FirebaseFunctions.instance.httpsCallable('sendVerificationCode');
        await callable.call({'email': FirebaseAuth.instance.currentUser?.email});
        emit(ResendSuccessState(message: 'Verification code sent! Check your email.'));
      } catch (e) {
        String errorMessage = 'Failed to send code';
        if (e is FirebaseFunctionsException) {
          errorMessage = e.message ?? errorMessage;
        }
        emit(ResendFailureState(errorMessage: errorMessage));
      }
      emit(VerifyEmailInitial());
    });

    on<VerifyCodeEvent>((event, emit) async {
      emit(CheckingVerificationState());
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: event.email,
            password: event.password,
          );
        }
        final callable = FirebaseFunctions.instance.httpsCallable('verifyEmailCode');
        await callable.call({'code': event.code});
        
        // Reload the current user to get updated verification status
        await FirebaseAuth.instance.currentUser?.reload();
        
        // Re-login to update authentication state and continue to app
        _authenticationBloc.add(
          LoginWithEmailAndPasswordEvent(
            email: event.email,
            password: event.password,
          ),
        );
        
        emit(VerifySuccessState(message: 'Email verified successfully!'));
      } catch (e) {
        String errorMessage = 'Invalid verification code';
        if (e is FirebaseFunctionsException) {
          errorMessage = e.message ?? errorMessage;
        }
        emit(VerifyFailureState(errorMessage: errorMessage));
      }
      emit(VerifyEmailInitial());
    });
  }
}
