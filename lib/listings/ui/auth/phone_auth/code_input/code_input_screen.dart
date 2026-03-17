import 'dart:io';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/auth/api/auth_api_manager.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/phone_auth/code_input/code_input_bloc.dart';
import 'package:caribtap/listings/ui/container/container_screen.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sms_autofill/sms_autofill.dart';

class CodeInputScreen extends StatefulWidget {
  final bool isLogin;
  final String verificationID, phoneNumber;
  final String? firstName, lastName;
  final File? image;

  const CodeInputScreen(
      {super.key,
      required this.isLogin,
      required this.verificationID,
      required this.phoneNumber,
      this.firstName = 'Anonymous',
      this.lastName = 'User',
      this.image});

  @override
  State<CodeInputScreen> createState() => _CodeInputScreenState();
}

class _CodeInputScreenState extends State<CodeInputScreen> {
  late String _activeVerificationId;
  late final CodeInputBloc _codeInputBloc;
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  Timer? _resendTimer;
  StreamSubscription<String>? _smsCodeSubscription;
  int _resendCooldown = 30;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _codeInputBloc = CodeInputBloc(authenticationRepository: authApiManager);
    _activeVerificationId = widget.verificationID;
    _startResendCooldown();
    _listenForSmsCode();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _smsCodeSubscription?.cancel();
    _codeInputBloc.close();
    _otpController.dispose();
    _otpFocusNode.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  String _maskPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length <= 4) return value;
    final visible = digits.substring(digits.length - 4);
    return '•••• •••• $visible';
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _listenForSmsCode() async {
    try {
      await SmsAutoFill().listenForCode();
      _smsCodeSubscription?.cancel();
      _smsCodeSubscription = SmsAutoFill().code.listen((code) {
        final normalized = (code ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (normalized.length >= 6) {
          final otp = normalized.substring(0, 6);
          if (_otpController.text != otp) {
            _otpController.text = otp;
            if (mounted) setState(() {});
          }
        }
      });
    } catch (_) {
      // Keep manual entry as fallback when SMS Retriever is unavailable.
    }
  }

  void _submitCode(String code) {
    if (_isSubmitting) return;
    if (code.trim().length < 6) return;

    setState(() => _isSubmitting = true);
    context.read<LoadingCubit>().showLoading(
          context,
          widget.isLogin ? 'Logging in...'.tr() : 'Signing up...'.tr(),
          false,
          Color(colorPrimary),
        );
        _codeInputBloc.add(SubmitCodeEvent(
          code: code.trim(),
          verificationID: _activeVerificationId,
        ));
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _isSubmitting) return;

    context.read<LoadingCubit>().showLoading(
          context,
          'Sending code...'.tr(),
          false,
          Color(colorPrimary),
        );

    try {
      await authApiManager.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        phoneCodeAutoRetrievalTimeout: (String verificationId) {
          _activeVerificationId = verificationId;
        },
        phoneCodeSent: (String verificationId, int? forceResendingToken) {
          _activeVerificationId = verificationId;
          if (mounted) {
            context.read<LoadingCubit>().hideLoading();
            showSnackBar(context, 'A new code has been sent.'.tr());
            _startResendCooldown();
            _listenForSmsCode();
          }
        },
        phoneVerificationFailed: (auth.FirebaseAuthException error) {
          if (mounted) {
            context.read<LoadingCubit>().hideLoading();
            showSnackBar(
              context,
              error.message ?? 'Failed to resend code. Please try again.'.tr(),
            );
          }
        },
        phoneVerificationCompleted: (auth.PhoneAuthCredential credential) {
          if (mounted) {
            context.read<LoadingCubit>().hideLoading();
            context.read<AuthenticationBloc>().add(
                  LoginWithPhoneNumberEvent(
                    credential: credential,
                    phoneNumber: widget.phoneNumber,
                    firstName: widget.firstName,
                    lastName: widget.lastName,
                    image: widget.image,
                  ),
                );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        context.read<LoadingCubit>().hideLoading();
        showSnackBar(context, 'Failed to resend code. Please try again.'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CodeInputBloc>.value(
      value: _codeInputBloc,
      child: Builder(
        builder: (context) {
          return MultiBlocListener(
            listeners: [
              BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, state) {
                  if (_isSubmitting) {
                    setState(() => _isSubmitting = false);
                  }
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
                            'Phone authentication failed, Please try again.'
                                .tr());
                  }
                },
              ),
              BlocListener<CodeInputBloc, CodeInputState>(
                listener: (context, state) {
                  if (state is CodeSubmittedState) {
                    context.read<AuthenticationBloc>().add(
                        LoginWithPhoneNumberEvent(
                            credential: state.credential,
                            phoneNumber: widget.phoneNumber,
                            firstName: widget.firstName,
                            lastName: widget.lastName,
                            image: widget.image));
                  } else if (state is CodeSubmitFailedState) {
                    setState(() => _isSubmitting = false);
                    context.read<LoadingCubit>().hideLoading();
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: GestureDetector(
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: isDarkMode(context)
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Text(
                                widget.isLogin ? 'Sign In'.tr() : 'Create Account'.tr(),
                                style: TextStyle(
                                  color: Color(colorPrimary),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDarkMode(context)
                                  ? Colors.grey.shade900.withOpacity(0.75)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDarkMode(context)
                                    ? Colors.grey.shade800
                                    : Colors.grey.shade200,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: Color(colorPrimary).withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.sms_outlined,
                                        color: Color(colorPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Enter verification code'.tr(),
                                            style: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'We sent a 6-digit code to {}'.tr(
                                                args: [_maskPhone(widget.phoneNumber)]),
                                            style: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.grey.shade400
                                                  : Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                PinCodeTextField(
                                  length: 6,
                                  appContext: context,
                                  controller: _otpController,
                                  focusNode: _otpFocusNode,
                                  autoDisposeControllers: false,
                                  autoDismissKeyboard: true,
                                  keyboardType: TextInputType.number,
                                  backgroundColor: Colors.transparent,
                                  enableActiveFill: true,
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(10),
                                    fieldHeight: 52,
                                    fieldWidth: 44,
                                    activeColor: Color(colorPrimary),
                                    selectedColor: Color(colorPrimary),
                                    activeFillColor: isDarkMode(context)
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade100,
                                    selectedFillColor: isDarkMode(context)
                                      ? Colors.grey.shade900
                                        : Colors.white,
                                    inactiveColor: isDarkMode(context)
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                    inactiveFillColor: Colors.transparent,
                                  ),
                                  onCompleted: _submitCode,
                                  onChanged: (_) {
                                    if (mounted) setState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tip: Keep this screen open to auto-detect the SMS code.'.tr(),
                                  style: TextStyle(
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _otpController.text.trim().length == 6
                                        ? () => _submitCode(_otpController.text)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(colorPrimary),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text('Verify code'.tr()),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _resendCooldown == 0
                                            ? _resendCode
                                            : null,
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Color(colorPrimary)),
                                        ),
                                        child: Text(
                                          _resendCooldown > 0
                                              ? 'Resend in {}s'
                                                  .tr(args: [_resendCooldown.toString()])
                                              : 'Resend code'.tr(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Edit phone number'.tr()),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
