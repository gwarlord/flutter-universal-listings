import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/services/booking_access_guard.dart';
import 'package:caribtap/listings/ui/phone_verification/phone_verification_for_booking_screen.dart';

/// Runs the [BookingAccessGuard] and handles every non-allowed outcome:
/// - Not logged in → shows login-required dialog.
/// - Phone not verified → navigates to [PhoneVerificationForBookingScreen].
/// - Blocked by lister → shows a polite inline snackbar.
///
/// Returns `true` if the guard passed (or passed after the user verified),
/// `false` otherwise.
///
/// Usage:
/// ```dart
/// final allowed = await checkAndHandleBookingAccess(
///   context: context,
///   listerId: listing.authorID,
/// );
/// if (!allowed) return;
/// // proceed with booking submission …
/// ```
Future<bool> checkAndHandleBookingAccess({
  required BuildContext context,
  required String listerId,
}) async {
  final guard = BookingAccessGuard();
  final result = await guard.checkCanCreateRequest(listerId: listerId);

  if (!context.mounted) return false;

  switch (result.status) {
    case BookingAccessStatus.allowed:
      return true;

    case BookingAccessStatus.requiresLogin:
      _showLoginRequiredDialog(context);
      return false;

    case BookingAccessStatus.requiresPhoneVerification:
      final verified = await _showVerificationGate(context);
      if (verified == true && context.mounted) {
        showSnackBar(context, 'Phone verified successfully!'.tr());
      }
      return verified == true;

    case BookingAccessStatus.blockedByLister:
      showSnackBar(
        context,
        'You cannot make requests to this lister at this time.'.tr(),
      );
      return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

void _showLoginRequiredDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Sign in required'.tr(),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'Please sign in to send a booking or rental request.'.tr(),
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('OK'.tr()),
        ),
      ],
    ),
  );
}

/// Opens the phone verification screen as a full-screen modal.
/// Returns `true` once the user has successfully verified.
Future<bool?> _showVerificationGate(BuildContext context) async {
  return await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PhoneVerificationGateSheet(),
  );
}

// ─── Gate bottom sheet ────────────────────────────────────────────────────────

class _PhoneVerificationGateSheet extends StatelessWidget {
  const _PhoneVerificationGateSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Color(colorPrimary);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900]! : Colors.white;
    final onSurface = isDark ? Colors.white : Colors.black87;
    final onSurfaceMuted = isDark ? Colors.white70 : Colors.black54;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primary.withOpacity(0.12),
                    radius: 24,
                    child: Icon(Icons.verified_user_outlined,
                        color: primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Phone verification required'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                              fontWeight: FontWeight.bold, color: onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Phone verification is required before sending booking or rental requests.'
                    .tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onSurface,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps protect listers and reduce spam activity.'.tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: onSurfaceMuted, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Your verified phone number will be visible to the lister for request-related contact.'
                    .tr(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: onSurfaceMuted, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final verified = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const PhoneVerificationForBookingScreen(),
                      ),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop(verified ?? false);
                  },
                  icon: const Icon(Icons.phone_iphone),
                  label: Text('Verify Phone'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Not now'.tr(),
                    style: TextStyle(color: onSurfaceMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
