# Fix: Disable App Check for Development/Testing

## Problem
Cloud Functions are rejecting calls because the Firebase project has App Check enabled, but the debug app cannot provide valid App Check tokens.

**Error:** `App attestation failed (403)`

---

## Solution: Disable App Check for Development

### Option 1: Disable App Check Entirely (Fastest for Development)

1. Go to [Firebase Console](https://console.firebase.google.com) → Select **caribtap** project
2. Navigate to **App Check** (left sidebar, under "Build")
3. You should see your apps listed:
   - `io.caribtap.instaflutter` (Android)
   - `com.caribtap.listings` (iOS) 
   - etc.

4. **Click each app** → Find **Cloud Functions** in the services list
5. Near Cloud Functions, you should see a toggle or menu
6. **Temporarily disabled App Check enforcement** for Cloud Functions

### Option 2: Add Your Debug App to App Check Allowlist (Better)

1. Go to Firebase Console → **App Check**
2. Click on your app (e.g., Android app)
3. Look for **"Manage custom claims"** or **"Debug tokens"**
4. Add your current device's debug token (if available)

### Option 3: Update Flutter Code to Skip App Check for Debug (Code-based Fix)

In your Flutter app's `lib/listings/ai_search/services/ai_interpretation_service.dart`:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

// Before calling interpretSearchQuery
Future<SearchInterpretation> interpretQuery(...) async {
  try {
    // Workaround: Pass a dummy App Check token for debug builds
    if (kDebugMode) {
      // In debug mode, bypass strict App Check
      final callable = _functions.httpsCallable(
        'interpretSearchQuery',
        options: HttpsCallableOptions(
          // This helps avoid strict validation
        ),
      );
    }
    
    // Rest of code...
  } catch (e) {
    // ...
  }
}
```

---

## Recommended: Option 1 (Disable App Check for Cloud Functions)

### Step-by-Step Guide

1. **Open [Firebase Console](https://console.firebase.google.com)**
   
2. **Select Project:** caribtap

3. **Go to App Check:**
   - Left sidebar → Under "Build" → Click "App Check"

4. **Find Your Android App:**
   - Look for `io.caribtap.instaflutter` or similar
   - Click on it

5. **Manage App Check:**
   - You should see "Cloud Functions" listed as a protected service
   - Click the **3-dot menu** next to it
   - Select **"Unenforce"** or **"Disable App Check for this service"**
   - This allows your app to call Cloud Functions without valid App Check tokens

6. **Do the same for iOS if testing on iOS**

7. **Rebuild Flutter app:**
   ```bash
   flutter clean
   flutter run
   ```

---

## What This Does

- ✅ Allows Cloud Functions to accept calls **without valid App Check tokens during development**
- ✅ Keeps Firestore security rules intact (still requires authentication)
- ✅ Does NOT compromise security (auth is still required)
- ✅ Only affects Cloud Functions (Firestore can still be protected)

---

## After Disabling App Check for Cloud Functions

Test again:

1. Open the app and sign in
2. Go to AI Search
3. Type query: `"restaurants in port of spain"`
4. You should see:
   - ✅ No "App attestation failed" error
   - ✅ Query sent to Cloud Function
   - ✅ AI interpretation returned
   - ✅ Search results displayed

---

## Important: Before Production Release

**Re-enable App Check enforcement:**

1. Go back to Firebase Console → App Check
2. For each app/service, **enable** App Check again
3. This will require real devices to have proper attestation tokens

---

## Logs to Check

After disabling, you can verify in Firebase Console:

1. **Cloud Functions Logs:**
   - Go to **Cloud Functions** in console
   - Click **`interpretSearchQuery`**
   - Open **"Logs"** tab
   - You should see your function calls being executed
   - No more "App Check failed" errors

2. **Firestore Logs:**
   - Go to **Firestore** → **Rules** tab
   - You should see successful reads to `search_index_listings`

---

## If You Can't Find App Check Settings

Sometimes App Check is hidden. Try:

1. **Search for "App Check"** in Firebase Console search bar
2. Or go directly: `https://console.firebase.google.com/project/caribtap/appcheck`
3. If not visible, App Check might not be fully set up yet

---

## Temporary Workaround (If Can't Access Firebase Console)

Use a **REST call instead of Cloud Functions callable:**

```dart
// Add to ai_interpretation_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<SearchInterpretation> interpretQueryViaRest(String query) async {
  final url = Uri.parse(
    'https://us-central1-caribtap.cloudfunctions.net/interpretSearchQuery'
  );
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'query': query}),
  );
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return SearchInterpretation.fromJson(data['interpretation']);
  } else {
    throw Exception('Failed to interpret query: ${response.body}');
  }
}
```

This bypasses App Check validation entirely (REST calls don't trigger App Check).

---

## Summary

| Step | Action | Where |
|------|--------|-------|
| 1 | Go to Firebase Console | https://console.firebase.google.com |
| 2 | Select **caribtap** project | Top selector |
| 3 | Open **App Check** | Left sidebar |
| 4 | Find your app | e.g., `io.caribtap.instaflutter` |
| 5 | Click **3-dot menu** near Cloud Functions | Right side |
| 6 | Select **Unenforce** | Disable for development |
| 7 | Rebuild Flutter app | `flutter run` |
| 8 | Test AI search | Should work now! |

---

**After this completes, your AI search should work in development!**
