# Send Code Function Debug Setup

## Overview
Comprehensive debugging has been added to trace the "Send Code" function flow for phone authentication.

## Debug Points Added

### 1. **phone_number_input_screen.dart** - Button Click Handler
- **Location**: Send Code button `onPressed` callback
- **Logs**:
  - Button press confirmation
  - Current phone number, validation state, and EULA acceptance status
  - Format: `[PhoneNumberInputScreen] Send Code button pressed`

### 2. **phone_number_input_bloc.dart** - Validation Event Handler
- **Location**: `ValidateFieldsEvent` handler
- **Logs**:
  - Event received with all validation flags
  - Form validation result (passed/failed)
  - Each validation check: phone valid, EULA accepted, form fields
  - Error reasons if validation fails
  - Format: `[PhoneNumberInputBloc] ValidateFieldsEvent - ...`

### 3. **phone_number_input_bloc.dart** - Phone Verification Event
- **Location**: `VerifyPhoneNumberEvent` handler
- **Logs**:
  - Phone number being verified
  - Success confirmation when request sent
  - Catches and logs any exceptions with full stack trace
  - Format: `[PhoneNumberInputBloc] Starting phone verification for: ...`

### 4. **phone_number_input_bloc.dart** - Callback Methods
Enhanced all four verification callbacks:

- **`onPhoneVerificationCompleted`**: Auto-verification success
- **`onPhoneVerificationFailed`**: Error with Firebase error code and message
- **`onPhoneCodeSent`**: Confirmation with verification ID and force resending token
- **`onPhoneCodeAutoRetrievalTimeout`**: Timeout event with verification ID

### 5. **auth_firebase.dart** - Firebase Verification Call
- **Location**: `verifyPhoneNumber()` method in AuthenticationRepository implementation
- **Logs**:
  - Phone number being sent to Firebase
  - Each callback invocation with relevant IDs/tokens
  - Detailed error information
  - Try-catch wrapping all exceptions
  - Format: `[AuthFirebase] ...`

## Debug Log Flow

When user clicks "Send Code", you'll see logs in this order:

```
[PhoneNumberInputScreen] Send Code button pressed
[PhoneNumberInputScreen] Phone: +1234567890, Valid: true, EULA: true
[PhoneNumberInputBloc] ValidateFieldsEvent - isPhoneValid: true, acceptEula: true, isLogin: false
[PhoneNumberInputBloc] Form validation passed
[PhoneNumberInputBloc] All validations passed, saving form
[PhoneNumberInputBloc] Starting phone verification for: +1234567890
[PhoneNumberInputBloc] Phone verification request sent successfully
[AuthFirebase] Starting phone verification for: +1234567890
[AuthFirebase] Code sent successfully - VerificationId: abc123...
[PhoneNumberInputBloc] Code sent successfully - VerificationId: abc123..., ForceResendingToken: null
```

## Common Issues to Look For in Debug Output

1. **Button not registering**: No initial logs
   - Check: Touch/click handlers, button enabled state

2. **Validation failure**: Logs stop at `Form validation failed`
   - Check: Required fields empty, phone format, EULA checkbox

3. **Phone verification not starting**: Logs show `ValidFieldsState` but no Firebase logs
   - Check: BlocListener not triggering next event, context issues

4. **Firebase rejection**: See `Phone verification failed` with error code
   - Check: Phone number format, Firebase configuration, region restrictions

5. **No callback triggered**: Request sent but no `Code sent` logs
   - Check: Firebase timeout (30 sec), network issues, FCM setup (Android)

## How to View Logs

1. **Android Studio / IntelliJ**: View → Tool Windows → Logcat
   - Filter: `[PhoneNumberInputScreen]|[PhoneNumberInputBloc]|[AuthFirebase]`

2. **VS Code**: Debug Console or Terminal
   - Filter output for debug prefixes

3. **Flutter DevTools**: Logging tab
   - Filter: `Phone` or `Auth`

## Files Modified

- `lib/listings/ui/auth/phone_auth/number_input/phone_number_input_screen.dart`
- `lib/listings/ui/auth/phone_auth/number_input/phone_number_input_bloc.dart`
- `lib/listings/ui/auth/api/firebase/auth_firebase.dart`

## Next Steps

1. Build and run the app
2. Navigate to the phone authentication screen
3. Click "Send Code"
4. Check the debug console for the log sequence above
5. Share any missing/unexpected logs to identify the failure point
