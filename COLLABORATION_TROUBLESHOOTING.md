# Collaboration Feature - Troubleshooting Summary

## Current Issues

### 1. ✋ App Check Attestation Failure (PRIMARY ISSUE)
```
W/FirebaseContextProvider: Error getting App Check token. 
Error: com.google.firebase.FirebaseException: Error returned from API. 
code: 403 body: App attestation failed.
```

**Root Cause**: Firebase App Check is not properly configured with debug tokens for development.

**Status**: ✅ FIXED in code, requires configuration in Firebase Console

**Files Modified**:
- `lib/main.dart`: Updated App Check initialization to use proper providers
  - Debug builds: `AndroidProvider.debug`
  - Release builds: `AndroidProvider.playIntegrity`

**Action Required**:
1. Run the app and get the debug token from logcat
2. Register the token in Firebase Console > App Check > Manage debug tokens
3. See [APP_CHECK_SETUP.md](./APP_CHECK_SETUP.md) for detailed instructions

---

### 2. 🔍 Cloud Function NOT_FOUND Error
```
CollaborationFirebase.addListingCollaborator error: [firebase_functions/not-found] NOT_FOUND
```

**Possible Causes**:
1. ⚠️ App Check blocking requests before they reach the function (most likely)
2. Functions not deployed to Firebase
3. Function name mismatch

**Available Functions** (verified in `functions/src/collaboration.ts`):
- ✅ `addListingCollaborator`
- ✅ `removeListingCollaborator`
- ✅ `updateListingCollaboratorPermissions`
- ✅ `setOrderStatus`
- ✅ `setOrderFulfillment`
- ✅ `updateListingEditableFields`
- ✅ `setRentalStatus`
- ✅ `setBookingStatus`
- ✅ `sendOrderChatMessage`

**Verification Steps**:

1. **Check if functions are deployed**:
   ```bash
   cd functions
   firebase functions:list
   ```

2. **Deploy if needed**:
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   ```

3. **Check function logs**:
   ```bash
   firebase functions:log --only addListingCollaborator
   ```

---

## Quick Fix Steps

### Option A: Register Debug Token (Recommended)

1. Run app in debug mode
2. Find debug token in logcat:
   ```
   adb logcat | grep -i "FirebaseAppCheck\|debug token"
   ```
3. Go to Firebase Console > App Check > Manage debug tokens
4. Add the token
5. Restart app

### Option B: Temporarily Disable App Check Enforcement

1. Go to Firebase Console > App Check
2. Under "Enforcement", find "Cloud Functions"
3. Toggle enforcement OFF (development only!)
4. Restart app

### Option C: Use Firebase Emulator (Local Development)

```bash
cd functions
npm run serve  # Starts emulator
```

Then in `lib/main.dart`, add after Firebase initialization:
```dart
if (kDebugMode) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

---

## Wired Features Status

### ✅ Completed Integrations

1. **Manage Collaborators**: Added to listing details menu (owner only)
2. **Assigned Listings**: Accessible from My Listings AppBar icon
3. **Assigned Listings Count**: Displayed in Profile screen
4. **Team Chat**: Added to listing details menu with permission checks
5. **Order Chat (Owner/Collaborator)**: Icon button in booking management cards
6. **Activity Log**: Button in Profile with listing picker
7. **Customer Order Chat**: Icon button in My Bookings cards

### ✅ Bug Fixes

1. **ChannelDataModel compilation error**: Removed `isGroupChat` parameter (auto-calculated)

---

## Testing After Fix

Once App Check is configured, test these features:

```dart
// Test 1: Add collaborator
await collaborationApiManager.addCollaborator(
  listingId: 'test_listing_id',
  emailOrUid: 'collaborator@example.com',
  permissions: CollaboratorPermissions.standard(),
);

// Test 2: Access team chat
// In listing details, tap "Team Chat" menu item

// Test 3: View assigned listings
// In My Listings screen, tap the assigned listings icon in AppBar

// Test 4: Order chat
// In booking management, tap chat icon on any booking card
```

---

## References

- [APP_CHECK_SETUP.md](./APP_CHECK_SETUP.md) - Detailed App Check configuration guide
- [COLLABORATION_IMPLEMENTATION.md](./COLLABORATION_IMPLEMENTATION.md) - Full feature documentation
- Firebase Console: https://console.firebase.google.com
