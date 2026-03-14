import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/services/phone_verification_service.dart';

/// Standalone phone-verification screen used within the booking/rental trust
/// gate.  Does **not** change the user's Firebase Auth sign-in method — it only
/// sends an OTP to confirm the phone number and then writes
/// `phoneVerified = true` to the user's Firestore profile.
///
/// Returns `true` via [Navigator.pop] when verification succeeds.
class PhoneVerificationForBookingScreen extends StatefulWidget {
  const PhoneVerificationForBookingScreen({Key? key}) : super(key: key);

  @override
  State<PhoneVerificationForBookingScreen> createState() =>
      _PhoneVerificationForBookingScreenState();
}

class _PhoneVerificationForBookingScreenState
    extends State<PhoneVerificationForBookingScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  _Step _step = _Step.enterPhone;
  bool _isLoading = false;
  String? _errorText;

  // Phone input
  String _fullPhoneNumber = '';
  bool _isPhoneValid = false;
  PhoneNumber _initialPhoneNumber = PhoneNumber();

  // Code input
  String _verificationId = '';
  int? _resendToken;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  final TextEditingController _codeController = TextEditingController();

  final PhoneVerificationService _verificationService =
      PhoneVerificationService();

  @override
  void initState() {
    super.initState();
    _initialPhoneNumber = _fallbackInitialPhoneNumber();
    _resolveInitialPhoneNumber();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  PhoneNumber _fallbackInitialPhoneNumber() {
    final localeCountryCode =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (localeCountryCode == null || localeCountryCode.isEmpty) {
      return PhoneNumber();
    }

    return PhoneNumber(isoCode: localeCountryCode.toUpperCase());
  }

  Future<void> _resolveInitialPhoneNumber() async {
    var initialPhone = _initialPhoneNumber;

    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      final authPhoneNumber = currentUser?.phoneNumber?.trim() ?? '';
      String profilePhoneNumber = '';
      String? profileIsoCode;

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection(usersCollection)
            .doc(currentUser.uid)
            .get();
        final data = userDoc.data();
        profileIsoCode = _extractProfileIsoCode(data);
        profilePhoneNumber =
            ((data?["phoneNumber"] as String?)?.trim() ?? '')
                .isNotEmpty
            ? (data?["phoneNumber"] as String).trim()
            : ((data?["phone"] as String?)?.trim() ?? '');
      }

      if (profileIsoCode != null) {
        initialPhone = PhoneNumber(isoCode: profileIsoCode);
      }

      final preferredPhoneNumber =
          authPhoneNumber.isNotEmpty ? authPhoneNumber : profilePhoneNumber;
      final normalizedPhoneNumber =
          _normalizePhoneNumber(preferredPhoneNumber);

      if (normalizedPhoneNumber.isNotEmpty) {
        try {
          initialPhone = await PhoneNumber.getRegionInfoFromPhoneNumber(
            normalizedPhoneNumber,
          );
        } catch (_) {
          initialPhone = profileIsoCode != null
              ? PhoneNumber(
                  isoCode: profileIsoCode,
                  phoneNumber: normalizedPhoneNumber,
                )
              : initialPhone;
        }
      }

      if (!mounted) return;
      setState(() {
        _initialPhoneNumber = initialPhone;
        _fullPhoneNumber = initialPhone.phoneNumber ?? '';
        _isPhoneValid = _fullPhoneNumber.isNotEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialPhoneNumber = initialPhone;
      });
    }
  }

  String _normalizePhoneNumber(String rawPhoneNumber) {
    final trimmed = rawPhoneNumber.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('+')) return trimmed;

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    return '+$digitsOnly';
  }

  String? _extractProfileIsoCode(Map<String, dynamic>? data) {
    if (data == null) return null;

    final candidates = [
      data['selectedCountry'],
      data['homeCountry'],
      data['countryCode'],
    ];

    for (final candidate in candidates) {
      final value = (candidate as String?)?.trim().toUpperCase() ?? '';
      if (value.length == 2) {
        return value;
      }
    }

    return null;
  }

  // ── Firebase Phone Auth ───────────────────────────────────────────────────

  Future<void> _sendCode() async {
    if (!_isPhoneValid || _fullPhoneNumber.isEmpty) {
      setState(() => _errorText = 'Please enter a valid phone number.'.tr());
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (auth.PhoneAuthCredential credential) async {
          // Automatic verification (Android SMS-autofill).
          await _confirmCredential(credential);
        },
        verificationFailed: (auth.FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorText = _friendlyError(e);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isLoading = false;
            _step = _Step.enterCode;
          });
          _startCooldown();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Failed to send verification code. Please try again.'.tr();
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    if (code.length < 6) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final credential = auth.PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: code,
      );
      await _confirmCredential(credential);
    } on auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = _friendlyError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Verification failed. Please try again.'.tr();
      });
    }
  }

  Future<void> _confirmCredential(auth.PhoneAuthCredential credential) async {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Session expired. Please log in again.'.tr();
      });
      return;
    }

    // Try to link the phone credential to the current account.
    // If the phone is already associated with a different (or same) account,
    // the OTP was still valid — we still treat that as successfully verified.
    try {
      await currentUser.linkWithCredential(credential);
    } on auth.FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' &&
          e.code != 'provider-already-linked' &&
          e.code != 'account-exists-with-different-credential') {
        // Genuinely invalid OTP.
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorText = _friendlyError(e);
        });
        return;
      }
      // Phone is already linked / used by another account — the OTP was valid.
    }

    // Mark verified in Firestore.
    try {
      await _verificationService.markPhoneAsVerified(
        userId: currentUser.uid,
        phoneNumber: _fullPhoneNumber,
      );
    } catch (_) {
      // Firestore write failure is non-fatal — the user sees success but the
      // guard will re-check on next attempt.
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Show brief success banner then pop with true.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone verified successfully!'.tr()),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pop(true);
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Clear any snackbars and pop immediately to avoid animating snackbars
    // on a deactivated scaffold (causes ValueListenableBuilder build scope errors).
    ScaffoldMessenger.of(context).clearSnackBars();
    Navigator.of(context).pop(true);
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  void _startCooldown() {
    _cooldownSeconds = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) t.cancel();
      });
    });
  }

  String _friendlyError(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid.'.tr();
      case 'invalid-verification-code':
        return 'Incorrect code. Please check and try again.'.tr();
      case 'session-expired':
        return 'The verification code has expired. Please resend.'.tr();
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.'.tr();
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.'.tr();
      default:
        return e.message ?? 'Verification failed. Please try again.'.tr();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Color(colorPrimary);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verify Phone Number'.tr()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _step == _Step.enterPhone
                ? _buildPhoneStep(primary, isDark)
                : _buildCodeStep(primary, isDark),
      ),
    );
  }

  Widget _buildPhoneStep(Color primary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.verified_user_outlined, size: 56, color: primary),
          const SizedBox(height: 24),
          Text(
            'Verify phone to continue'.tr(),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Phone verification is required before sending booking or rental requests. This helps protect listers and reduce spam activity.'
                .tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your verified phone number will be visible to the lister for request-related contact.'
                .tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black38,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          InternationalPhoneNumberInput(
            key: ValueKey(
              '${_initialPhoneNumber.isoCode ?? ''}:${_initialPhoneNumber.phoneNumber ?? ''}',
            ),
            onInputChanged: (PhoneNumber number) {
              _fullPhoneNumber = number.phoneNumber ?? '';
            },
            onInputValidated: (bool valid) {
              setState(() => _isPhoneValid = valid);
            },
            selectorConfig: const SelectorConfig(
              selectorType: PhoneInputSelectorType.DIALOG,
            ),
            ignoreBlank: false,
            autoValidateMode: AutovalidateMode.disabled,
            initialValue: _initialPhoneNumber,
            textStyle: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
            inputDecoration: InputDecoration(
              labelText: 'Phone number'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isPhoneValid ? _sendCode : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Send verification code'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep(Color primary, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.sms_outlined, size: 56, color: primary),
          const SizedBox(height: 24),
          Text(
            'Enter verification code'.tr(),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'We sent a 6-digit code to $_fullPhoneNumber'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          PinCodeTextField(
            appContext: context,
            controller: _codeController,
            length: 6,
            keyboardType: TextInputType.number,
            animationType: AnimationType.fade,
            pinTheme: PinTheme(
              shape: PinCodeFieldShape.box,
              borderRadius: BorderRadius.circular(8),
              fieldHeight: 56,
              fieldWidth: 46,
              activeFillColor: isDark ? Colors.grey[800] : Colors.white,
              selectedFillColor:
                  isDark ? Colors.grey[700] : Colors.grey.shade100,
              inactiveFillColor:
                  isDark ? Colors.grey[850] : Colors.grey.shade50,
              activeColor: primary,
              selectedColor: primary,
              inactiveColor:
                  isDark ? Colors.grey[600]! : Colors.grey.shade300,
            ),
            enableActiveFill: true,
            onCompleted: _verifyCode,
            onChanged: (_) {
              if (_errorText != null) setState(() => _errorText = null);
            },
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: _cooldownSeconds > 0
                ? Text(
                    'Resend code in $_cooldownSeconds s'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black38,
                      fontSize: 13,
                    ),
                  )
                : TextButton(
                    onPressed: () {
                      _codeController.clear();
                      setState(() {
                        _step = _Step.enterPhone;
                        _errorText = null;
                      });
                      _sendCode();
                    },
                    child: Text('Resend code'.tr()),
                  ),
          ),
        ],
      ),
    );
  }
}

enum _Step { enterPhone, enterCode }
