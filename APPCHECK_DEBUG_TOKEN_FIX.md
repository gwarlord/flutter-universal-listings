# Fix: "App attestation failed" Error When Toggling Table Mode

## Problem
When toggling "Manage Table Mode" on the Collaborators screen, you get:
```
W/FirebaseContextProvider: Error getting App Check token. 
Error: com.google.firebase.FirebaseException: Error returned from API. code: 403
body: App attestation failed.
```

## Root Cause
Your app's **debug token has not been registered** in Firebase Console. Even though App Check is correctly configured in your Flutter code, Firebase doesn't recognize the debug token yet.

## Quick Fix (Development Only) - 2 Steps

### Step 1: Get Your Debug Token
1. Open Android Studio
2. Run your app: `flutter run -v`
3. Watch the Android logcat for a message like:
   ```
   D/FirebaseAppCheck: Firebase App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
   ```
4. **Copy this token**

Alternatively, run:
```bash
adb logcat | grep -i "appcheck.*debug.*token"
```

### Step 2: Register Token in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your **CaribTap** project
3. Navigate to **Build** (left sidebar) → **App Check**
4. Under your **Android app** section, click **Manage debug tokens**
5. Click **Add debug token**
6. Paste your token from Step 1
7. Give it a name (e.g., "Dev Phone - Pixel 6")
8. Click **Save**

### Step 3: Restart App
1. Stop the app completely
2. Rebuild: `flutter clean && flutter pub get && flutter run`
3. Try toggling "Manage Table Mode" again ✅

---

## If Debug Token Still Doesn't Work

### Option A: Disable App Check Enforcement Temporarily
For development, you can disable enforcement:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. **Build** → **App Check**
3. Scroll to **Enforcement**
4. Toggle **OFF** for "Cloud Functions"
5. This allows requests without valid tokens (dev only!)

### Option B: Get Debug Token from Logcat
If you can't find the token, use this command:
```bash
adb logcat -c
flutter run
adb logcat > logcat.txt
```
Then search `logcat.txt` for "Firebase App Check debug token"

---

## Production Setup
For production (App Store/Play Store):

1. Your app must be signed with your release keystore
2. Google Play Integrity API will automatically handle attestation
3. No manual token registration needed
4. App Check enforcement will work automatically

---

## Verification Checklist

- [ ] Debug token copied from logcat
- [ ] Token registered in Firebase Console → App Check
- [ ] App restarted after registration
- [ ] Can toggle "Manage Table Mode" without error

## Why This Happens

Firebase App Check implements device attestation for security:
- **Debug mode** uses special debug tokens that you must manually register
- **Release mode** uses Play Integrity API (automatic)
- Without registration, Firebase rejects requests with `403: App attestation failed`

Your code is already correct—you just need to complete the Firebase Console setup!

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Token doesn't appear in logcat | Ensure app is in debug mode; check that Firebase App Check is initialized |
| Token appears but still getting 403 | Verify exact token copied correctly (no spaces); wait 30 seconds after registering |
| Multiple debug tokens | Each device/emulator gets its own token; register all you're testing with |
| Still fails on emulator | Some emulators have issues; use a physical device instead |

---

## Related Files
- [APP_CHECK_SETUP.md](APP_CHECK_SETUP.md) - Full App Check documentation
- [lib/main.dart](lib/main.dart#L265) - App Check initialization code
- [lib/listings/listings_module/api/firebase/collaboration_firebase.dart](lib/listings/listings_module/api/firebase/collaboration_firebase.dart#L91) - Cloud Function call that triggers App Check

---

**After completing these steps, toggling Table Mode will work without errors!** ✅
