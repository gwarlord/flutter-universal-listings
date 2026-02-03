# Email Verification Code Setup

## Overview
The app now uses a **6-digit code-based email verification** system instead of clickable links. Users receive a code via email that they copy and paste into the app.

## What Changed

### Backend (Cloud Functions)
- **sendVerificationCode**: Generates a 6-digit code, stores it in Firestore with 10-minute expiry, sends email
- **verifyEmailCode**: Validates the code, updates Firebase Auth `emailVerified` flag
- **cleanupExpiredCodes**: Scheduled function to clean up old verification records daily

### Frontend (Flutter)
- New UI with code input field (6-digit numeric input)
- Updated BLoC events: `SendVerificationCodeEvent`, `VerifyCodeEvent`
- Automatic re-login after successful verification

### Security
- Rate limiting: Max 3 code requests per hour per user
- Max 5 verification attempts per code
- Codes expire after 10 minutes
- Firestore security rules restrict access to Cloud Functions only

## Deployment Status

✅ **Cloud Functions deployed** (sendVerificationCode, verifyEmailCode, cleanupExpiredCodes)
✅ **Firestore security rules deployed**
✅ **Flutter app compiled successfully**

## Setup Email Service

### Option 1: SendGrid (Recommended)

1. **Get SendGrid API Key**:
   - Sign up at https://sendgrid.com
   - Create an API key with "Mail Send" permissions
   - Verify a sender email address

2. **Configure Firebase Functions**:
   ```bash
   firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"
   ```

3. **Update sender email** in `functions/src/email_verification.ts`:
   ```typescript
   from: 'noreply@caribtap.com', // Change to your verified sender
   ```

4. **Redeploy**:
   ```bash
   cd functions
   npm run build
   cd ..
   firebase deploy --only functions
   ```

### Option 2: Firebase Extensions (Alternative)

If you don't want to use SendGrid:

1. Install the "Trigger Email" extension from Firebase Console
2. Update `email_verification.ts` to use the extension instead of SendGrid
3. Or modify the code to log codes to console for development testing

### Development Testing (No Email Service)

The Cloud Function already logs codes to the console when SendGrid is not configured:
```typescript
console.log(`📧 Verification code for ${email}: ${code}`);
```

You can view these logs in:
- Firebase Console → Functions → Logs
- Or run: `firebase functions:log`

## Testing Flow

1. **Sign up** with a new email address
2. **Verify Email screen** appears
3. Tap **"Send verification code"**
4. Check your email for the 6-digit code (or check Firebase logs if in dev mode)
5. **Enter the code** in the app
6. Tap **"Verify Code"**
7. App automatically logs you in and navigates to home screen

## Error Handling

- **"Invalid verification code"**: Code doesn't match or already used
- **"Verification code has expired"**: Code older than 10 minutes
- **"Too many attempts"**: 5+ failed attempts on same code (request new code)
- **"Too many verification attempts"**: 3+ codes requested in 1 hour (wait before trying again)
- **"Failed to send code"**: Email service error (check SendGrid config or logs)

## Firestore Collection

Verification codes are stored in:
```
email_verifications/
  ├── {verificationId}
  │   ├── userId: string
  │   ├── email: string
  │   ├── code: string (6 digits)
  │   ├── createdAt: timestamp
  │   ├── expiresAt: timestamp
  │   ├── verified: boolean
  │   └── attempts: number
```

Old records are automatically cleaned up daily by the `cleanupExpiredCodes` function.

## Advantages Over Link-Based Verification

✅ **No email client prefetching issues** - codes work even if email clients scan links  
✅ **Copy-paste friendly** - users can easily copy code from email to app  
✅ **Mobile-optimized** - no need to handle deep links or app switching  
✅ **Retry-friendly** - users can request multiple codes without confusion  
✅ **Rate limiting** - prevents abuse with configurable limits  
✅ **Expiry handling** - clear 10-minute window with automatic cleanup  

## Next Steps

1. ✅ Deploy functions and rules (DONE)
2. ⚠️ Configure SendGrid API key or alternative email service
3. ⚠️ Test the full verification flow with a real email address
4. ⚠️ Update sender email address in production
5. ⚠️ Monitor Firebase Functions logs for errors
6. ⚠️ Adjust rate limits if needed (see `email_verification.ts`)

## Configuration Options

Edit `functions/src/email_verification.ts` to adjust:

- **Code length**: Currently 6 digits (change `generateVerificationCode()`)
- **Expiry time**: Currently 10 minutes (600000ms)
- **Rate limit**: Currently 3 codes per hour
- **Max attempts**: Currently 5 attempts per code
- **Email template**: Customize HTML/text in `sendVerificationCode()`
- **Sender email**: Change `from` address to your verified domain

## Troubleshooting

### Code not received
- Check Firebase Functions logs: `firebase functions:log`
- Verify SendGrid API key is set: `firebase functions:config:get`
- Check spam/junk folder
- Verify sender email is authorized in SendGrid

### "Function not found" error
- Ensure functions are deployed: `firebase deploy --only functions`
- Check Firebase Console → Functions to see deployed functions

### Firebase Auth emailVerified not updating
- Verify `admin.auth().updateUser()` is being called (check logs)
- User must reload: `FirebaseAuth.instance.currentUser?.reload()`

### Rate limit too strict
- Increase hour window or max requests in `sendVerificationCode()`
- Clear old records: Call `cleanupExpiredCodes` manually

## Support

For issues or questions:
1. Check Firebase Functions logs
2. Review Firestore `email_verifications` collection
3. Test with console.log codes (no SendGrid required)
4. Verify all Cloud Functions deployed successfully
