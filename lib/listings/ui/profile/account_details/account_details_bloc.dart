import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/phone_number_utils.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/ui/auth/reauth_user/reauth_user_bloc.dart';
import 'package:caribtap/listings/ui/profile/api/firebase/profile_firebase.dart';
import 'package:caribtap/listings/ui/profile/api/profile_repository.dart';

part 'account_details_event.dart';

part 'account_details_state.dart';

class AccountDetailsBloc
    extends Bloc<AccountDetailsEvent, AccountDetailsState> {
  final ProfileRepository profileRepository;
  ListingsUser currentUser;

  AccountDetailsBloc(
      {required this.profileRepository, required this.currentUser})
      : super(AccountDetailsInitial()) {
    on<ValidateFieldsEvent>((event, emit) async {
      if (event.key.currentState?.validate() ?? false) {
        event.key.currentState!.save();
        emit(ValidFieldsState());
      } else {
        emit(AccountFieldsRequiredState());
      }
    });
    on<TryToSubmitDataEvent>((event, emit) async {
      final normalizedPhone = await normalizePhoneForCountry(
        event.phoneNumber,
        event.countryCode,
      );
      if (normalizedPhone == null) {
        emit(AccountValidationErrorState(
          phoneValidationMessage(event.countryCode),
        ));
        return;
      }

      if (profileRepository is ProfileFirebaseUtils) {
        AuthProviders? authProvider =
            await (profileRepository as ProfileFirebaseUtils)
                .getUserAuthProvider();
        if (authProvider == AuthProviders.phone &&
            normalizePhoneForVerification(currentUser.phoneNumber) !=
                normalizedPhone) {
          emit(ReauthRequiredState(
            authProvider: authProvider!,
            data: normalizedPhone,
          ));
        } else if (authProvider == AuthProviders.password &&
            currentUser.email != event.emailAddress) {
          emit(ReauthRequiredState(
            authProvider: authProvider!,
            data: event.emailAddress,
          ));
        } else {
          emit(UpdatingDataState());
          add(UpdateUserDataEvent(
            firstName: event.firstName,
            lastName: event.lastName,
            emailAddress: event.emailAddress,
            phoneNumber: normalizedPhone,
            countryCode: event.countryCode,
          ));
        }
      } else {
        emit(UpdatingDataState());
        add(UpdateUserDataEvent(
          firstName: event.firstName,
          lastName: event.lastName,
          emailAddress: event.emailAddress,
          phoneNumber: normalizedPhone,
          countryCode: event.countryCode,
        ));
      }
    });
    on<UpdateUserDataEvent>((event, emit) async {
      final previousPhone = await normalizePhoneForCountry(
            currentUser.phoneNumber,
            currentUser.countryCode,
          ) ??
          normalizePhoneForVerification(currentUser.phoneNumber);
      final nextPhone = await normalizePhoneForCountry(
            event.phoneNumber,
            event.countryCode,
          ) ??
          normalizePhoneForVerification(event.phoneNumber);
      final phoneChanged = previousPhone != nextPhone;

      currentUser.firstName = event.firstName;
      currentUser.lastName = event.lastName;
      currentUser.email = event.emailAddress;
      currentUser.phoneNumber = event.phoneNumber;
      currentUser.countryCode = event.countryCode;

      // Trust rule: a changed phone number must be re-verified.
      if (phoneChanged) {
        currentUser.phoneVerified = false;
        currentUser.phoneVerifiedAt = null;
      }

      await profileRepository.updateCurrentUser(currentUser);
      emit(UserDataUpdatedState(updatedUser: currentUser));
    });
  }
}
