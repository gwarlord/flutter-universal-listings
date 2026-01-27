import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/api/auth_api_manager.dart';
import 'package:instaflutter/listings/ui/auth/reauth_user/reauth_user_bloc.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart' as apple;
import 'package:instaflutter/constants.dart';

class ReAuthUserScreen extends StatefulWidget {
  final AuthProviders provider;
  final String? currentEmail, newEmail, phoneNumber;
  final bool isDeleteUser;

  const ReAuthUserScreen({
    super.key,
    required this.provider,
    this.currentEmail,
    this.newEmail,
    this.phoneNumber,
    this.isDeleteUser = true,
  });

  @override
  State<ReAuthUserScreen> createState() => _ReAuthUserScreenState();
}

class _ReAuthUserScreenState extends State<ReAuthUserScreen> {
  final TextEditingController _passwordController = TextEditingController();
  late Widget body = const CircularProgressIndicator.adaptive();
  String? _verificationID, smsCode;

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return BlocProvider(
      create: (context) => ReauthUserBloc(
          provider: widget.provider, authenticationRepository: authApiManager),
      child: Builder(builder: (context) {
        return BlocConsumer<ReauthUserBloc, ReauthUserState>(
          listener: (context, state) {
            if (state is CodeSentState) {
              _verificationID = state.verificationID;
            } else if (state is ReauthSuccessfulSate) {
              context.read<LoadingCubit>().hideLoading();
              Navigator.pop(context, true);
            } else if (state is ReauthFailureState) {
              context.read<LoadingCubit>().hideLoading();
              showAlertDialog(
                  context, 'Authentication Error'.tr(), state.errorMessage);
            } else if (state is AutoPhoneVerificationCompletedState) {}
          },
          builder: (context, state) {
            if (state is ReauthUserInitial) {
              switch (state.provider) {
                case AuthProviders.password:
                  body = buildPasswordField(context);
                  break;
                case AuthProviders.phone:
                  context.read<ReauthUserBloc>().add(
                      VerifyPhoneNumberEvent(phoneNumber: widget.phoneNumber!));
                  break;
                case AuthProviders.facebook:
                  body = buildFacebookButton(context);
                  break;
                case AuthProviders.apple:
                  body = buildAppleButton(context);
                  break;
              }
            } else if (state is CodeSentState) {
              body = buildPhoneField(context);
            }

            return Dialog(
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(colorPrimary).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.security_outlined,
                          size: 32, color: Color(colorPrimary)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verify Identity'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please re-authenticate to confirm this action.'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    body,
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget buildPasswordField(BuildContext context) {
    final isDark = isDarkMode(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Password'.tr(),
            hintStyle:
                TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(colorPrimary),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (_passwordController.text.trim().isEmpty) return;
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Verifying...'.tr(),
                    false,
                    Color(colorPrimary),
                  );
              context.read<ReauthUserBloc>().add(
                    PasswordClickEvent(
                      currentEmail: widget.currentEmail!,
                      newEmail: widget.newEmail,
                      password: _passwordController.text.trim(),
                      isDeleteUser: widget.isDeleteUser,
                    ),
                  );
            },
            child: Text(
              'Verify'.tr(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFacebookButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        label: Text(
          'Continue with Facebook'.tr(),
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        icon: Image.asset(
          'assets/images/facebook_logo.png',
          color: Colors.white,
          height: 24,
          width: 24,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(facebookButtonColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          elevation: 0,
        ),
        onPressed: () {
          context.read<LoadingCubit>().showLoading(
                context,
                'Verifying...'.tr(),
                false,
                Color(colorPrimary),
              );
          context.read<ReauthUserBloc>().add(FacebookClickEvent());
        },
      ),
    );
  }

  Widget buildAppleButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apple.TheAppleSignIn.isAvailable(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator.adaptive();
        }
        if (!snapshot.hasData || (snapshot.data != true)) {
          return Center(
              child:
                  Text('Apple sign in is not available on this device.'.tr()));
        } else {
          return SizedBox(
            width: double.infinity,
            height: 50,
            child: apple.AppleSignInButton(
              cornerRadius: 12.0,
              type: apple.ButtonType.continueButton,
              style: isDarkMode(context)
                  ? apple.ButtonStyle.white
                  : apple.ButtonStyle.black,
              onPressed: () {
                context.read<LoadingCubit>().showLoading(
                      context,
                      'Verifying...'.tr(),
                      false,
                      Color(colorPrimary),
                    );
                context.read<ReauthUserBloc>().add(AppleClickEvent());
              },
            ),
          );
        }
      },
    );
  }

  Widget buildPhoneField(BuildContext context) {
    final isDark = isDarkMode(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: PinCodeTextField(
            length: 6,
            appContext: context,
            keyboardType: TextInputType.phone,
            backgroundColor: Colors.transparent,
            textStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
            pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 45,
                fieldWidth: 40,
                activeColor: Color(colorPrimary),
                activeFillColor:
                    isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                selectedFillColor: Colors.transparent,
                selectedColor: Color(colorPrimary),
                inactiveColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                inactiveFillColor: Colors.transparent),
            enableActiveFill: true,
            onCompleted: (code) {
              smsCode = code;
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Verifying...'.tr(),
                    true,
                    Color(colorPrimary),
                  );
              context.read<ReauthUserBloc>().add(SubmitSmsCodeEvent(
                  smsCode: code,
                  verificationID: _verificationID!,
                  isDeleteUser: widget.isDeleteUser));
            },
            onChanged: (value) {
              debugPrint(value);
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
