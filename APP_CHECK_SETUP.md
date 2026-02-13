# Firebase App Check Setup Guide

## Issue
App Check attestation is failing with `403: App attestation failed`, blocking Cloud Function calls.

## Solution

### 1. Get Debug Token (For Development)

Run your app in debug mode and check the Android logcat for a message like:

```
D/FirebaseAppCheck: Firebase App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

**To ensure the token appears in logs**, add this to your app startup (already configured in `main.dart`):

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode 
      ? AndroidProvider.debug 
      : AndroidProvider.playIntegrity,
);
```

### 2. Register Debug Token in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your CaribTap project
3. Navigate to **Build > App Check**
4. Click on your Android app
5. Click **Manage debug tokens**
6. Click **Add debug token**
7. Paste the token from step 1
8. Give it a name (e.g., "Dev Phone - Pixel 6")
9. Click **Save**

### 3. Restart Your App

After registering the debug token:
1. Completely stop the app
2. Clear app data (optional)
3. Rebuild and run: `flutter run`

### 4. Verify App Check is Working

Check logcat for:
```
✅ Firebase App Check activated successfully
```

And verify Cloud Functions work:
```dart
await collaborationApiManager.addCollaborator(...);
```

## Production Setup

For production releases, **Play Integrity API** is automatically used:

1. Ensure your app is signed with your release keystore
2. The SHA-256 fingerprint must be registered in Firebase Console
3. App must be uploaded to Google Play (internal testing track is sufficient)
4. Play Integrity API will handle attestation automatically

## Troubleshooting

### Still getting 403 errors?

1. **Check Firebase Console > App Check**:
   - Verify your app is registered
   - Check if enforcement is enabled (toggle it off for development if needed)

2. **Verify debug token**:
   ```
   adb logcat | grep -i "appcheck\|attestation"
   ```

3. **Check Cloud Functions logs**:
   ```
   firebase functions:log
   ```

4. **Temporarily disable enforcement** (Firebase Console):
   - Go to App Check settings
   - Under "Enforcement", toggle off Cloud Functions
   - This allows requests without valid tokens (development only!)

### Alternative: Use Firebase Emulator

For local development without App Check:

```bash
firebase emulators:start --only functions,firestore
```

Update Flutter app to use emulator:
```dart
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```

## References

- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [Play Integrity API Setup](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [Debug Tokens Guide](https://firebase.google.com/docs/app-check/android/debug-provider)
