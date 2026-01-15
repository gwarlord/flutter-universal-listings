import 'dart:io';
import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/api/auth_api_manager.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/phone_auth/code_input/code_input_screen.dart';
import 'package:instaflutter/listings/ui/auth/phone_auth/number_input/phone_number_input_bloc.dart';
import 'package:instaflutter/listings/ui/container/container_screen.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:instaflutter/constants.dart';

File? _image;

class PhoneNumberInputScreen extends StatefulWidget {
  final bool isLogin;

  const PhoneNumberInputScreen({super.key, required this.isLogin});

  @override
  State<PhoneNumberInputScreen> createState() => _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState extends State<PhoneNumberInputScreen> {
  final GlobalKey<FormState> _key = GlobalKey();
  String? firstName, lastName, _phoneNumber;
  bool _isPhoneValid = false;
  AutovalidateMode _validate = AutovalidateMode.disabled;
  bool acceptEULA = true;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PhoneNumberInputBloc>(
      create: (context) =>
          PhoneNumberInputBloc(authenticationRepository: authApiManager),
      child: Builder(
        builder: (context) {
          if (Platform.isAndroid && !widget.isLogin) {
            context.read<PhoneNumberInputBloc>().add(RetrieveLostDataEvent());
          }
          return MultiBlocListener(
            listeners: [
              BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, state) {
                  context.read<LoadingCubit>().hideLoading();
                  if (state.authState == AuthState.authenticated) {
                    context.read<LoadingCubit>().hideLoading();
                    if (mounted) {
                      pushAndRemoveUntil(
                          context,
                          ContainerWrapperWidget(currentUser: state.user!),
                          false);
                    }
                  } else {
                    showSnackBar(
                        context,
                        state.message ??
                            'Phone authentication failed, Please try again.'
                                .tr());
                  }
                },
              ),
              BlocListener<PhoneNumberInputBloc, PhoneNumberInputState>(
                listener: (context, state) {
                  if (state is CodeSentState) {
                    context.read<LoadingCubit>().hideLoading();
                    pushReplacement(
                        context,
                        CodeInputScreen(
                          isLogin: widget.isLogin,
                          verificationID: state.verificationID,
                          phoneNumber: _phoneNumber!,
                          firstName: firstName,
                          lastName: lastName,
                          image: _image,
                        ));
                  } else if (state is PhoneInputFailureState) {
                    context.read<LoadingCubit>().hideLoading();
                    showSnackBar(context, state.errorMessage);
                  } else if (state is AutoPhoneVerificationCompletedState) {
                    context
                        .read<AuthenticationBloc>()
                        .add(LoginWithPhoneNumberEvent(
                          credential: state.credential,
                          phoneNumber: _phoneNumber!,
                          firstName: firstName,
                          lastName: lastName,
                          image: _image,
                        ));
                  }
                },
              ),
            ],
            child: Scaffold(
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode(context)
                        ? [Colors.black, Colors.grey.shade900]
                        : [Colors.white, Colors.grey.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: BlocBuilder<PhoneNumberInputBloc, PhoneNumberInputState>(
                      buildWhen: (old, current) =>
                          current is PhoneInputFailureState && old != current,
                      builder: (context, state) {
                        if (state is PhoneInputFailureState) {
                          _validate = AutovalidateMode.onUserInteraction;
                        }

                        return Form(
                          key: _key,
                          autovalidateMode: _validate,
                          child: GestureDetector(
                            onTap: () => FocusScope.of(context).unfocus(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.arrow_back,
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.black),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    Text(
                                      widget.isLogin ? 'Sign In'.tr() : 'Create Account'.tr(),
                                      style: TextStyle(
                                        color: isDarkMode(context)
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 48,
                                    ),
                                  ],
                                ),

                                /// user profile picture,  this is visible until we verify the
                                /// code in case of sign up with phone number
                                Visibility(
                                  visible: !widget.isLogin,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          BlocBuilder<PhoneNumberInputBloc,
                                              PhoneNumberInputState>(
                                            buildWhen: (old, current) =>
                                                current is PictureSelectedState &&
                                                old != current,
                                            builder: (context, state) {
                                              if (state is PictureSelectedState) {
                                                _image = state.imageFile;
                                              }
                                              return Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Color(colorPrimary),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: SizedBox(
                                                  width: 120,
                                                  height: 120,
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(60),
                                                    child: state is PictureSelectedState
                                                        ? (state.imageFile == null
                                                            ? Image.asset(
                                                                'assets/images/placeholder.jpg',
                                                                fit: BoxFit.cover,
                                                              )
                                                            : Image.file(
                                                                state.imageFile!,
                                                                fit: BoxFit.cover,
                                                              ))
                                                        : Image.asset(
                                                            'assets/images/placeholder.jpg',
                                                            fit: BoxFit.cover,
                                                          ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          FloatingActionButton(
                                            backgroundColor: Color(colorPrimary),
                                            mini: true,
                                            onPressed: () =>
                                                _onCameraClick(context),
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                /// user first name text field , this is visible until we verify the
                                /// code in case of sign up with phone number
                                Visibility(
                                  visible: !widget.isLogin,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Card(
                                      elevation: 0,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade800
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        child: TextFormField(
                                          cursorColor: Color(colorPrimary),
                                          textAlignVertical: TextAlignVertical.center,
                                          validator: validateName,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          onSaved: (String? val) {
                                            firstName = val ?? 'Anonymous';
                                          },
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                            hintText: 'First Name'.tr(),
                                            hintStyle: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(
                                              Icons.person,
                                              color: Color(colorPrimary),
                                              size: 20,
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                /// last name of the user , this is visible until we verify the
                                /// code in case of sign up with phone number
                                Visibility(
                                  visible: !widget.isLogin,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Card(
                                      elevation: 0,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade800
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        child: TextFormField(
                                          validator: validateName,
                                          textAlignVertical: TextAlignVertical.center,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          cursorColor: Color(colorPrimary),
                                          onSaved: (String? val) {
                                            lastName = val ?? 'User';
                                          },
                                          onFieldSubmitted: (_) =>
                                              FocusScope.of(context).nextFocus(),
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                            hintText: 'Last Name'.tr(),
                                            hintStyle: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade600,
                                            ),
                                            border: InputBorder.none,
                                            prefixIcon: Icon(
                                              Icons.person,
                                              color: Color(colorPrimary),
                                              size: 20,
                                            ),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                /// user phone number,  this is visible until we verify the code
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Card(
                                    elevation: 0,
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade800
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      child: InternationalPhoneNumberInput(
                                        autoFocus: widget.isLogin,
                                        autoFocusSearch: true,
                                        onInputChanged: (PhoneNumber number) =>
                                            _phoneNumber = number.phoneNumber,
                                        onInputValidated: (bool value) =>
                                            _isPhoneValid = value,
                                        ignoreBlank: true,
                                        autoValidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        inputDecoration: InputDecoration(
                                          hintText: 'Phone Number'.tr(),
                                          hintStyle: TextStyle(
                                            color: isDarkMode(context)
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade600,
                                          ),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(
                                            Icons.phone,
                                            color: Color(colorPrimary),
                                            size: 20,
                                          ),
                                          isDense: true,
                                        ),
                                        inputBorder: const OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                        ),
                                        selectorConfig: const SelectorConfig(
                                            selectorType:
                                                PhoneInputSelectorType.DIALOG),
                                      ),
                                    ),
                                  ),
                                ),

                                /// the main action button of the screen, this is hidden if we
                                /// received the code from firebase
                                /// the action and the title is base on the state,
                                /// * Sign up with email and password: send email and password to
                                /// firebase
                                /// * Sign up with phone number: submits the phone number to
                                /// firebase and await for code verification
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: BlocListener<PhoneNumberInputBloc,
                                      PhoneNumberInputState>(
                                    listener: (context, state) {
                                      if (state is PhoneInputFailureState) {
                                        showSnackBar(context, state.errorMessage);
                                      } else if (state is ValidFieldsState) {
                                        context.read<LoadingCubit>().showLoading(
                                              context,
                                              'Sending code...'.tr(),
                                              false,
                                              Color(colorPrimary),
                                            );
                                        context.read<PhoneNumberInputBloc>().add(
                                            VerifyPhoneNumberEvent(
                                                phoneNumber: _phoneNumber!));
                                      }
                                    },
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(colorPrimary),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () =>
                                            context.read<PhoneNumberInputBloc>().add(
                                                  ValidateFieldsEvent(
                                                    _key,
                                                    acceptEula: acceptEULA,
                                                    isLogin: widget.isLogin,
                                                    isPhoneValid: _isPhoneValid,
                                                  ),
                                                ),
                                        child: Text(
                                          'Send Code'.tr(),
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                /// Divider
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: isDarkMode(context)
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'OR'.tr(),
                                          style: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade600,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: isDarkMode(context)
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                /// switch between sign up with phone number and email sign up states
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      child: Text(
                                        widget.isLogin
                                            ? 'Login with E-mail and password'.tr()
                                            : 'Sign up with E-mail and password'.tr(),
                                        style: TextStyle(
                                            color: Color(colorPrimary),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            decoration: TextDecoration.underline),
                                      ),
                                    ),
                                  ),
                                ),

                                Visibility(
                                  visible: !widget.isLogin,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Card(
                                      elevation: 0,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade50,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isDarkMode(context)
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            BlocBuilder<PhoneNumberInputBloc,
                                                PhoneNumberInputState>(
                                              buildWhen: (old, current) =>
                                                  current is EulaToggleState &&
                                                  old != current,
                                              builder: (context, state) {
                                                if (state is EulaToggleState) {
                                                  acceptEULA = state.eulaAccepted;
                                                }
                                                return SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: Checkbox(
                                                    onChanged: (value) => context
                                                        .read<PhoneNumberInputBloc>()
                                                        .add(
                                                          ToggleEulaCheckboxEvent(
                                                            eulaAccepted: value!,
                                                          ),
                                                        ),
                                                    activeColor:
                                                        Color(colorPrimary),
                                                    value: acceptEULA,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: RichText(
                                                textAlign: TextAlign.left,
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text:
                                                          'By creating an account you agree to our\n'
                                                              .tr(),
                                                      style: TextStyle(
                                                          color: isDarkMode(context)
                                                              ? Colors.grey.shade300
                                                              : Colors.grey.shade600,
                                                          fontSize: 12),
                                                    ),
                                                    TextSpan(
                                                      style: TextStyle(
                                                        color: Color(colorPrimary),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                      text: 'Terms of Use'.tr(),
                                                      recognizer:
                                                          TapGestureRecognizer()
                                                            ..onTap = () async {
                                                              if (await canLaunchUrl(
                                                                  Uri.parse(eula))) {
                                                                await launchUrl(
                                                                    Uri.parse(eula));
                                                              }
                                                            },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// a set of menu options that appears when trying to select a profile
  /// image from gallery or take a new pic
  _onCameraClick(BuildContext context) {
    showCupertinoModalPopup(
        context: context,
        builder: (actionSheetContext) => CupertinoActionSheet(
              message: const Text(
                'Add profile picture',
                style: TextStyle(fontSize: 15.0),
              ).tr(),
              actions: [
                CupertinoActionSheetAction(
                  isDefaultAction: false,
                  onPressed: () async {
                    Navigator.pop(actionSheetContext);
                    context
                        .read<PhoneNumberInputBloc>()
                        .add(ChooseImageFromGalleryEvent());
                  },
                  child: const Text('Choose from gallery').tr(),
                ),
                CupertinoActionSheetAction(
                  isDestructiveAction: false,
                  onPressed: () async {
                    Navigator.pop(actionSheetContext);
                    context
                        .read<PhoneNumberInputBloc>()
                        .add(CaptureImageByCameraEvent());
                  },
                  child: const Text('Take a picture').tr(),
                )
              ],
              cancelButton: CupertinoActionSheetAction(
                  child: const Text('Cancel').tr(),
                  onPressed: () => Navigator.pop(actionSheetContext)),
            ));
  }
}
