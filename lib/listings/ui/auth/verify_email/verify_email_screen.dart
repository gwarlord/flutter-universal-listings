import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/verify_email/verify_email_bloc.dart';
import 'package:caribtap/listings/ui/container/container_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String password;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late TextEditingController _codeController;
  bool _hasAutoSent = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  void _sendVerificationCodeIfNeeded(BuildContext context) {
    if (!_hasAutoSent) {
      _hasAutoSent = true;
      // Automatically send verification code when screen loads
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          context.read<VerifyEmailBloc>().add(
                SendVerificationCodeEvent(
                  email: widget.email,
                  password: widget.password,
                ),
              );
        }
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerifyEmailBloc>(
      create: (context) => VerifyEmailBloc(context.read<AuthenticationBloc>()),
      child: Builder(
        builder: (context) {
          // Automatically send verification code when screen first builds
          _sendVerificationCodeIfNeeded(context);
          
          return MultiBlocListener(
          listeners: [
            BlocListener<AuthenticationBloc, AuthenticationState>(
              listener: (context, state) {
                context.read<LoadingCubit>().hideLoading();
                if (state.authState == AuthState.authenticated) {
                  if (mounted) {
                    pushAndRemoveUntil(
                      context,
                      ContainerWrapperWidget(currentUser: state.user!),
                      false,
                    );
                  }
                } else if (state.authState == AuthState.unauthenticated) {
                  if (state.message != null) {
                    showSnackBar(context, state.message!);
                  }
                }
              },
            ),
            BlocListener<VerifyEmailBloc, VerifyEmailState>(
              listener: (context, state) {
                if (state is VerifyEmailInitial) {
                  context.read<LoadingCubit>().hideLoading();
                } else if (state is ResendingState) {
                  context.read<LoadingCubit>().showLoading(
                        context,
                        'Sending verification code...'.tr(),
                        false,
                        Color(colorPrimary),
                      );
                } else if (state is ResendSuccessState) {
                  context.read<LoadingCubit>().hideLoading();
                  showSnackBar(context, state.message);
                } else if (state is ResendFailureState) {
                  context.read<LoadingCubit>().hideLoading();
                  showSnackBar(context, state.errorMessage);
                } else if (state is CheckingVerificationState) {
                  context.read<LoadingCubit>().showLoading(
                        context,
                        'Verifying...'.tr(),
                        false,
                        Color(colorPrimary),
                      );
                } else if (state is VerifySuccessState) {
                  context.read<LoadingCubit>().hideLoading();
                  showSnackBar(context, state.message);
                } else if (state is VerifyFailureState) {
                  context.read<LoadingCubit>().hideLoading();
                  showSnackBar(context, state.errorMessage);
                }
              },
            ),
          ],
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Verify Email').tr(),
              centerTitle: true,
            ),
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
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 120,
                          color: Color(colorPrimary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Verify your email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode(context) ? Colors.white : Colors.black,
                          ),
                        ).tr(),
                        const SizedBox(height: 16),
                        Text(
                          'A verification email has been sent to:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode(context)
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                        ).tr(),
                        const SizedBox(height: 8),
                        Text(
                          widget.email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(colorPrimary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Once you have clicked the link in your email, tap "I have verified" or enter the 6-digit code below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode(context)
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ).tr(),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.verified_user, color: Colors.white),
                          label: const Text(
                            'I have verified',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ).tr(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                          ),
                          onPressed: () {
                            context.read<VerifyEmailBloc>().add(
                                  VerifyWithLinkEvent(
                                    email: widget.email,
                                    password: widget.password,
                                  ),
                                );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: Colors.grey)),
                            ),
                            Expanded(child: Divider(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: isDarkMode(context)
                                ? Colors.white
                                : Colors.grey.shade900,
                          ),
                          decoration: InputDecoration(
                            hintText: '000000',
                            hintStyle: TextStyle(
                              letterSpacing: 8,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDarkMode(context) ? Colors.grey[900] : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: isDarkMode(context)
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: isDarkMode(context)
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Color(colorPrimary), width: 2),
                            ),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text(
                            'Verify Code',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ).tr(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Color(colorPrimary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                          ),
                          onPressed: () {
                            final code = _codeController.text.trim();
                            if (code.isEmpty) {
                              showSnackBar(context, 'Please enter the verification code.'.tr());
                              return;
                            }
                            if (code.length != 6) {
                              showSnackBar(context, 'Code must be 6 digits.'.tr());
                              return;
                            }
                            context.read<VerifyEmailBloc>().add(
                                  VerifyCodeEvent(
                                    code: code,
                                    email: widget.email,
                                    password: widget.password,
                                  ),
                                );
                          },
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: Icon(
                            Icons.email,
                            color: isDarkMode(context) ? Colors.white : Color(colorPrimary),
                          ),
                          label: Text(
                            'Resend email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode(context) ? Colors.white : Color(colorPrimary),
                            ),
                          ).tr(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: Color(colorPrimary),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                          ),
                          onPressed: () {
                            context.read<VerifyEmailBloc>().add(
                                  SendVerificationCodeEvent(
                                    email: widget.email,
                                    password: widget.password,
                                  ),
                                );
                          },
                        ),
                        const SizedBox(height: 32),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Back to login',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ).tr(),
                        ),
                      ],
                    ),
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
}
