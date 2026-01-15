import 'dart:io';

import 'package:easy_localization/easy_localization.dart' as easy_local;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/phone_auth/number_input/phone_number_input_screen.dart';
import 'package:instaflutter/listings/ui/auth/signUp/sign_up_bloc.dart';
import 'package:instaflutter/listings/ui/container/container_screen.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:instaflutter/constants.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State createState() => _SignUpState();
}

class _SignUpState extends State<SignUpScreen> {
  File? _image;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _key = GlobalKey();
  String? firstName, lastName, email, password, confirmPassword;
  AutovalidateMode _validate = AutovalidateMode.disabled;
  bool acceptEULA = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  InputDecoration _inputDecoration(BuildContext context, String hint,
      {IconData? icon, bool required = false}) {
    final dark = isDarkMode(context);
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Color(colorPrimary)) : null,
      filled: true,
      fillColor: dark ? Colors.grey[900] : Colors.white,
      hintStyle: TextStyle(color: dark ? Colors.grey[500] : Colors.grey[600]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: dark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: dark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Color(colorPrimary), width: 2),
      ),
      labelStyle: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SignUpBloc>(
      create: (context) => SignUpBloc(),
      child: Builder(
        builder: (context) {
          if (Platform.isAndroid) {
            context.read<SignUpBloc>().add(RetrieveLostDataEvent());
          }
          return MultiBlocListener(
            listeners: [
              BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, state) {
                  context.read<LoadingCubit>().hideLoading();
                  if (state.authState == AuthState.authenticated) {
                    if (mounted) {
                      pushAndRemoveUntil(
                          context,
                          ContainerWrapperWidget(
                            currentUser: state.user!,
                          ),
                          false);
                    }
                  } else {
                    showSnackBar(
                        context,
                        state.message ??
                            'Couldn\'t sign up, Please try again.'.tr());
                  }
                },
              ),
              BlocListener<SignUpBloc, SignUpState>(
                listener: (context, state) {
                  if (state is ValidFieldsState) {
                    context.read<LoadingCubit>().showLoading(
                          context,
                          'Creating new account, Please wait...'.tr(),
                          false,
                          Color(colorPrimary),
                        );
                    context.read<AuthenticationBloc>().add(
                        SignupWithEmailAndPasswordEvent(
                            emailAddress: email!,
                            password: password!,
                            image: _image,
                            lastName: lastName,
                            firstName: firstName));
                  } else if (state is SignUpFailureState) {
                    showSnackBar(context, state.errorMessage);
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16),
                child: BlocBuilder<SignUpBloc, SignUpState>(
                  buildWhen: (old, current) =>
                      current is SignUpFailureState && old != current,
                  builder: (context, state) {
                    if (state is SignUpFailureState) {
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
                            Text(
                              'Create new account',
                              style: TextStyle(
                                  color: isDarkMode(context)
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26.0),
                            ).tr(),
                            const SizedBox(height: 6),
                            Text(
                              'Join the community and start listing'.tr(),
                              style: TextStyle(
                                color: isDarkMode(context)
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Stack(
                                children: [
                                  BlocBuilder<SignUpBloc, SignUpState>(
                                    buildWhen: (old, current) =>
                                        current is PictureSelectedState &&
                                        old != current,
                                    builder: (context, state) {
                                      if (state is PictureSelectedState) {
                                        _image = state.imageFile;
                                      }
                                      final img = state is PictureSelectedState
                                          ? state.imageFile
                                          : _image;
                                      return CircleAvatar(
                                        radius: 64,
                                        backgroundColor: Colors.grey.shade300,
                                        backgroundImage: img != null
                                            ? FileImage(img)
                                            : const AssetImage(
                                                    'assets/images/placeholder.jpg')
                                                as ImageProvider,
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: -4,
                                    child: IconButton(
                                      icon: Icon(Icons.camera_alt,
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.black),
                                      onPressed: () => _onCameraClick(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              color: isDarkMode(context)
                                  ? Colors.black
                                  : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      textCapitalization: TextCapitalization.words,
                                      validator: validateName,
                                      onSaved: (String? val) {
                                        firstName = val;
                                      },
                                      textInputAction: TextInputAction.next,
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.grey.shade900),
                                      decoration: _inputDecoration(
                                          context, 'First Name'.tr(),
                                          icon: Icons.person_outline),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      textCapitalization: TextCapitalization.words,
                                      validator: validateName,
                                      onSaved: (String? val) {
                                        lastName = val;
                                      },
                                      textInputAction: TextInputAction.next,
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.grey.shade900),
                                      decoration: _inputDecoration(
                                          context, 'Last Name'.tr(),
                                          icon: Icons.person_outline),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: validateEmail,
                                      onSaved: (String? val) {
                                        email = val;
                                      },
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.grey.shade900),
                                      decoration: _inputDecoration(context, 'Email'.tr(),
                                          icon: Icons.email_outlined),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.next,
                                      controller: _passwordController,
                                      validator: validatePassword,
                                      onSaved: (String? val) {
                                        password = val;
                                      },
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.grey.shade900),
                                      cursorColor: Color(colorPrimary),
                                      decoration: _inputDecoration(context, 'Password'.tr(),
                                          icon: Icons.lock_outline)
                                          .copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: isDarkMode(context)
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => context
                                          .read<SignUpBloc>()
                                          .add(ValidateFieldsEvent(_key,
                                              acceptEula: acceptEULA)),
                                      obscureText: _obscureConfirm,
                                      controller: _confirmPasswordController,
                                      validator: (val) => validateConfirmPassword(
                                          _passwordController.text, val),
                                      onSaved: (String? val) {
                                        confirmPassword = val;
                                      },
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.grey.shade900),
                                      cursorColor: Color(colorPrimary),
                                      decoration: _inputDecoration(
                                              context, 'Confirm Password'.tr(),
                                              icon: Icons.lock_outline)
                                          .copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirm
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: isDarkMode(context)
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscureConfirm = !_obscureConfirm),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(vertical: 14),
                                          backgroundColor: Color(colorPrimary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14.0),
                                          ),
                                        ),
                                        child: Text(
                                          'Sign Up'.tr(),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        onPressed: () => context
                                            .read<SignUpBloc>()
                                            .add(ValidateFieldsEvent(_key,
                                                acceptEula: acceptEULA)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade400,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(
                                    'OR'.tr(),
                                    style: TextStyle(
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                pushReplacement(
                                    context,
                                    const PhoneNumberInputScreen(
                                        isLogin: false));
                              },
                              icon: const Icon(Icons.phone_iphone),
                              label: const Text('Sign up with phone number').tr(),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor:
                                    isDarkMode(context) ? Colors.grey.shade800 : Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                context.read<LoadingCubit>().showLoading(
                                      context,
                                      'Signing up with Google, Please wait...'.tr(),
                                      false,
                                      Color(colorPrimary),
                                    );
                                context
                                    .read<AuthenticationBloc>()
                                    .add(LoginWithGoogleEvent());
                              },
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Sign up with Google').tr(),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(0xFF4285F4),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ListTile(
                              tileColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              trailing: BlocBuilder<SignUpBloc, SignUpState>(
                                buildWhen: (old, current) =>
                                    current is EulaToggleState &&
                                    old != current,
                                builder: (context, state) {
                                  if (state is EulaToggleState) {
                                    acceptEULA = state.eulaAccepted;
                                  }
                                  return Checkbox(
                                    onChanged: (value) =>
                                        context.read<SignUpBloc>().add(
                                              ToggleEulaCheckboxEvent(
                                                eulaAccepted: value!,
                                              ),
                                            ),
                                    activeColor: Color(colorPrimary),
                                    value: acceptEULA,
                                  );
                                },
                              ),
                              title: RichText(
                                textAlign: TextAlign.left,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          'By creating an account you agree to our\n'
                                              .tr(),
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700),
                                    ),
                                    TextSpan(
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                      ),
                                      text: 'Terms of Use'.tr(),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          if (await canLaunchUrl(
                                              Uri.parse(eula))) {
                                            await launchUrl(Uri.parse(eula));
                                          }
                                        },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Already have an account? '.tr(),
                                    style: TextStyle(
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontSize: 15,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sign In'.tr(),
                                        style: TextStyle(
                                          color: Color(colorPrimary),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    ],
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
            )),
          ),
          );
        },
      ),
    );
  }

  _onCameraClick(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (actionSheetContext) => CupertinoActionSheet(
        title: const Text(
          'Add Profile Picture',
          style: TextStyle(fontSize: 15.0),
        ).tr(),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: false,
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<SignUpBloc>().add(ChooseImageFromGalleryEvent());
            },
            child: const Text('Choose from gallery').tr(),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: false,
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<SignUpBloc>().add(CaptureImageByCameraEvent());
            },
            child: const Text('Take a picture').tr(),
          )
        ],
        cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel').tr(),
            onPressed: () => Navigator.pop(actionSheetContext)),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _image = null;
    super.dispose();
  }
}
