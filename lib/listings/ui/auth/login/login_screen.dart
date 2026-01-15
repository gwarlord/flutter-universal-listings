import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/login/login_bloc.dart';
import 'package:instaflutter/listings/ui/auth/phone_auth/number_input/phone_number_input_screen.dart';
import 'package:instaflutter/listings/ui/auth/reset_password/reset_password_screen.dart';
import 'package:instaflutter/listings/ui/auth/signup/sign_up_screen.dart';
import 'package:instaflutter/listings/ui/container/container_screen.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart' as apple;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State createState() {
    return _LoginScreen();
  }
}

class _LoginScreen extends State<LoginScreen> {
  final GlobalKey<FormState> _key = GlobalKey();
  AutovalidateMode _validate = AutovalidateMode.disabled;
  String? email, password;
  bool _obscurePassword = true;

  InputDecoration _inputDecoration(BuildContext context, String hint,
      {IconData? icon}) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginBloc>(
      create: (context) => LoginBloc(),
      child: Builder(builder: (context) {
        return Scaffold(
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
          child: MultiBlocListener(
            listeners: [
              BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, state) {
                  context.read<LoadingCubit>().hideLoading();
                  if (state.authState == AuthState.authenticated) {
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
                            'Couldn\'t login, Please try again.'.tr());
                  }
                },
              ),
              BlocListener<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state is ValidLoginFieldsState) {
                    context.read<LoadingCubit>().showLoading(
                          context,
                          'Logging in, Please wait...'.tr(),
                          false,
                          Color(colorPrimary),
                        );
                    context.read<AuthenticationBloc>().add(
                          LoginWithEmailAndPasswordEvent(
                            email: email!,
                            password: password!,
                          ),
                        );
                  }
                },
              ),
            ],
            child: BlocBuilder<LoginBloc, LoginState>(
              buildWhen: (old, current) =>
                  current is LoginFailureState && old != current,
              builder: (context, state) {
                if (state is LoginFailureState) {
                  _validate = AutovalidateMode.onUserInteraction;
                }
                return Form(
                  key: _key,
                  autovalidateMode: _validate,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Welcome back',
                        style: TextStyle(
                          color: isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ).tr(),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue'.tr(),
                        style: TextStyle(
                          color: isDarkMode(context)
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDarkMode(context) ? Colors.black : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                textAlignVertical: TextAlignVertical.center,
                                textInputAction: TextInputAction.next,
                                validator: validateEmail,
                                onSaved: (String? val) {
                                  email = val;
                                },
                                style: TextStyle(
                                    fontSize: 18.0,
                                    color: isDarkMode(context)
                                        ? Colors.white
                                        : Colors.grey.shade900),
                                keyboardType: TextInputType.emailAddress,
                                cursorColor: Color(colorPrimary),
                                decoration: _inputDecoration(context, 'Email Address'.tr(),
                                    icon: Icons.email_outlined),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                textAlignVertical: TextAlignVertical.center,
                                obscureText: _obscurePassword,
                                validator: validatePassword,
                                onSaved: (String? val) {
                                  password = val;
                                },
                                onFieldSubmitted: (password) => context
                                    .read<LoginBloc>()
                                    .add(ValidateLoginFieldsEvent(_key)),
                                textInputAction: TextInputAction.done,
                                style: TextStyle(
                                    fontSize: 18.0,
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
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                              ),

                      /// forgot password text, navigates user to ResetPasswordScreen
                      /// and this is only visible when logging with email and password
                      Padding(
                        padding: const EdgeInsets.only(top: 16, right: 24),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () =>
                                push(context, const ResetPasswordScreen()),
                            child: Text(
                              'Forgot password?'.tr(),
                              style: const TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1),
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            right: 40.0, left: 40.0, top: 40),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
                            backgroundColor: Color(colorPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              side: BorderSide(
                                color: Color(colorPrimary),
                              ),
                            ),
                          ),
                          child: Text(
                            'Log In'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () => context
                              .read<LoginBloc>()
                              .add(ValidateLoginFieldsEvent(_key)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'OR',
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Colors.white
                                    : Colors.black),
                          ).tr(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            right: 40.0, left: 40.0, bottom: 20),
                        child: ElevatedButton.icon(
                          label: const Text(
                            'Facebook Login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ).tr(),
                          icon: Image.asset(
                            'assets/images/facebook_logo.png',
                            color: Colors.white,
                            height: 24,
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => push(
                                            context, const ResetPasswordScreen()),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ).tr(),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        backgroundColor: Color(colorPrimary),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14.0),
                                        ),
                                      ),
                                      child: Text(
                                        'Log In'.tr(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      onPressed: () => context
                                          .read<LoginBloc>()
                                          .add(ValidateLoginFieldsEvent(_key)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              label: const Text(
                                'Facebook Login',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ).tr(),
                              icon: Image.asset(
                                'assets/images/facebook_logo.png',
                                color: Colors.white,
                                height: 24,
                                width: 24,
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: const Color(facebookButtonColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                              ),
                              onPressed: () {
                                context.read<LoadingCubit>().showLoading(
                                      context,
                                      'Logging in, Please wait...'.tr(),
                                      false,
                                      Color(colorPrimary),
                                    );
                                context
                                    .read<AuthenticationBloc>()
                                    .add(LoginWithFacebookEvent());
                              },
                            ),
                            const SizedBox(height: 12),
                            if (apple.TheAppleSignIn.isSupported)
                              ElevatedButton.icon(
                                label: const Text(
                                  'Sign in with Apple',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ).tr(),
                                icon: const Icon(Icons.apple, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.0),
                                  ),
                                ),
                                onPressed: () => context
                                    .read<AuthenticationBloc>()
                                    .add(LoginWithAppleEvent()),
                              ),
                            const SizedBox(height: 24),
                            Center(
                              child: TextButton(
                                onPressed: () => pushReplacement(context, const SignUpScreen()),
                                child: RichText(
                                  text: TextSpan(
                                    text: 'Don\'t have an account? '.tr(),
                                    style: TextStyle(
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontSize: 15,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sign Up'.tr(),
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
                                );
                            context.read<AuthenticationBloc>().add(
                                  LoginWithFacebookEvent(),
                                );
                          },
                )),
              )),
                      ),
                      FutureBuilder<bool>(
                        future: apple.TheAppleSignIn.isAvailable(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator.adaptive();
                          }
                          if (!snapshot.hasData || (snapshot.data != true)) {
                            return Container();
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  right: 40.0, left: 40.0, bottom: 20),
                              child: apple.AppleSignInButton(
                                  cornerRadius: 25.0,
                                  type: apple.ButtonType.signIn,
                                  style: isDarkMode(context)
                                      ? apple.ButtonStyle.white
                                      : apple.ButtonStyle.black,
                                  onPressed: () {
                                    context.read<LoadingCubit>().showLoading(
                                          context,
                                          'Logging in, Please wait...'.tr(),
                                          false,
                                          Color(colorPrimary),
                                        );
                                    context.read<AuthenticationBloc>().add(
                                          LoginWithAppleEvent(),
                                        );
                                  }),
                            );
                          }
                        },
                      ),

                      InkWell(
                        onTap: () {
                          pushReplacement(context,
                              const PhoneNumberInputScreen(isLogin: true));
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              'Login with phone number'.tr(),
                              style: const TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 1),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
