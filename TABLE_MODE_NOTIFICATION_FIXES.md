# Table Mode Notification System - Complete Fix

## Issues Identified

### Issue 1: Lister Not Notified About Waiter Summons & Bill Requests
**Problem:** When a customer summons a waiter or requests a bill, only the **assigned waiters** receive notifications. The **listing owner/lister** has no way to know about these requests unless a waiter acknowledges them first.

**Impact:** Lister can't respond to urgent customer needs without waiter intervention.

**Location:** 
- `functions/src/tableMode.ts` - `summonWaiter()` & `requestBill()` functions

### Issue 2: FCM Token Field Name Mismatch  
**Problem:** Push notifications don't reach anyone because of a critical field name mismatch:
- **Flutter App** stores: `pushToken` (single string)
- **Cloud Functions** look for: `fcmTokens` (array)
- Result: **No tokens found** → **No notifications sent**

**Impact:** Even if tokens were found, notifications still wouldn't be sent to the lister.

**Locations:**
- `functions/src/tableMode.ts` - `sendPushNotification()` 
- `functions/src/index.ts` - `sendPushNotification()`
- `lib/listings/ui/auth/api/firebase/auth_firebase.dart` - stores as `pushToken`

---

## Solutions Implemented

### Fix 1: Notify Listing Owner About Waiter Summons

**Before:** Only assigned waiters notified
```typescript
// Notify assigned staff (don't fail if this errors)
const assignedStaff = sessionData.assignedStaff || [];
for (const staff of assignedStaff) {
  await sendPushNotification(staff.uid, ...);
}
```

**After:** Both assigned staff AND owner/collaborators notified
```typescript
// Notify assigned staff
const assignedStaff = sessionData.assignedStaff || [];
for (const staff of assignedStaff) {
  await sendPushNotification(staff.uid, ...);
}

// Also notify listing owner and collaborators
const listingSnap = await db.collection("listings").doc(sessionData.listingId).get();
const ownerUid = listingSnap.data()?.authorID;
const notifyOwnerUids: string[] = [];

if (ownerUid) notifyOwnerUids.push(ownerUid);

const collabsSnap = await db
  .collection("listings")
  .doc(sessionData.listingId)
  .collection("collaborators")
  .where("isActive", "==", true)
  .get();

collabsSnap.docs.forEach((doc) => {
  const data = doc.data();
  const permissions = data.permissions || {};
  if (permissions.manageOrders || permissions.manageChats) {
    notifyOwnerUids.push(doc.id);
  }
});

// Send notifications to owner/collaborators
for (const uid of [...new Set(notifyOwnerUids)]) {
  await sendPushNotification(
    uid,
    `Waiter Summon: ${sessionData.tableName || "Table"}`,
    `${sessionData.customerName} needs assistance${purpose ? `: ${purpose}` : ""}`,
    {
      type: "table_session",
      sessionId,
      listingId: sessionData.listingId,
      scope: "LISTING_TABLE_MODE",
      action: "WAITER_SUMMON",
    }
  );
}
```

**Same fix applied to:** `requestBill()` function

---

### Fix 2: Support Both Token Field Names

**Before:** Only looked for `fcmTokens` array
```typescript
const fcmTokens = userSnap.data()?.fcmTokens || [];
if (fcmTokens.length === 0) {
  functions.logger.info("No FCM tokens for user", { recipientUid });
  return;
}
```

**After:** Support both legacy `pushToken` and new `fcmTokens` array
```typescript
const userData = userSnap.data();

// Support both new (fcmTokens array) and legacy (pushToken string) field names
let fcmTokens: string[] = [];

// New format: array of FCM tokens
if (Array.isArray(userData?.fcmTokens) && userData.fcmTokens.length > 0) {
  fcmTokens = userData.fcmTokens;
}
// Legacy format: single pushToken string
else if (userData?.pushToken && typeof userData.pushToken === "string" && userData.pushToken.trim().length > 0) {
  fcmTokens = [userData.pushToken];
}

if (fcmTokens.length === 0) {
  functions.logger.info("No FCM tokens for user", { 
    recipientUid, 
    hasLegacyToken: !!userData?.pushToken, 
    hasNewTokens: !!userData?.fcmTokens 
  });
  return;
}

// Send via multicast with proper error logging
const message: admin.messaging.MulticastMessage = {
  notification: { title, body },
  data,
  tokens: fcmTokens,
};

const response = await messaging.sendMulticast(message);
functions.logger.info("Push sent", {
  recipientUid,
  tokenCount: fcmTokens.length,
  successCount: response.successCount,
  failureCount: response.failureCount,
});
```

**Applied to:** Both `tableMode.ts` and `index.ts` sendPushNotification functions

---

## Notification Flow (After Fix)

### Waiter Summon Notification
1. Customer clicks "Summon Waiter" → calls `summonWaiter()` Cloud Function
2. Function updates session & logs event
3. Notifications sent to:
   - ✅ All assigned waiters (staff)
   - ✅ Listing owner
   - ✅ All collaborators with `manageOrders` or `manageChats` permissions
4. Notifications include:
   - Title: "Waiter Summon: [Table Name]"
   - Body: "[Customer Name] needs assistance: [purpose]"
   - Data: `{ type: "table_session", action: "WAITER_SUMMON", ... }`

### Bill Request Notification
1. Customer clicks "Request Bill" → calls `requestBill()` Cloud Function
2. Function updates session & logs event
3. Notifications sent to:
   - ✅ All assigned waiters (staff)
   - ✅ Listing owner  
   - ✅ All collaborators with `manageOrders` or `manageChats` permissions
4. Notifications include:
   - Title: "Bill Request: [Table Name]"
   - Body: "[Customer Name] requested bill ([payment method])"
   - Data: `{ type: "table_session", action: "BILL_REQUEST", ... }`

---

## Testing Checklist

### To Verify the Fix Works:

1. **Ensure FCM Tokens Are Stored**
   - Check Firebase Console → users collection
   - Should see `pushToken` field populated for users
   - Eventually should transition to `fcmTokens` array

2. **Test Owner Notifications**
   - Have customer summon waiter in their table session
   - Owner should receive notification immediately (not just waiters)
   - Check Firebase Cloud Function Logs for:
     ```
     {
       "severity": "INFO",
       "message": "Push sent",
       "recipientUid": "[owner_uid]",
       "tokenCount": 1,
       "successCount": 1,
       "failureCount": 0
     }
     ```

3. **Test Token Fallback**
   - Existing users with only `pushToken` should still receive notifications
   - New users should eventually get `fcmTokens` array
   - Functions should auto-detect which format is available

4. **Check Logs**
   - Firebase Functions → Logs should show:
     - Which users got notified
     - How many FCM tokens were used
     - Success/failure counts for each notification

---

## Files Modified

1. **functions/src/tableMode.ts**
   - Updated `sendPushNotification()` to support both token formats
   - Updated `summonWaiter()` to notify owner & collaborators
   - Updated `requestBill()` to notify owner & collaborators

2. **functions/src/index.ts**
   - Updated `sendPushNotification()` to support both token formats
   - Enhanced logging for token discovery

3. **Generated JavaScript**
   - `functions/lib/tableMode.js` (auto-compiled)
   - `functions/lib/index.js` (auto-compiled)

---

## Future Improvements

### Short Term
1. **Migrate FCM tokens** - Update Firebase data to use `fcmTokens` array instead of `pushToken` string
   - This provides support for:
     - Multiple devices per user
     - Token rotation without losing notifications
     - Better token management

2. **Update Flutter** - Store FCM tokens in `fcmTokens` array in Cloud Firestore
   - Location: `lib/listings/ui/auth/api/firebase/auth_firebase.dart`
   - Replace `pushToken` string with `fcmTokens` array

### Long Term
1. **Real-time UI Updates** - Listen to table session changes using Firestore listeners
2. **Notification Sound & Vibration** - Configure platform-specific notification settings
3. **Notification Actions** - Add action buttons to notifications (e.g., "Acknowledge" button)
4. **Token Cleanup** - Implement periodic cleanup of invalid/expired FCM tokens

---

## Deployment

### To deploy these fixes:
```bash
firebase deploy --only functions
```

This will deploy both `tableMode.ts` and `index.ts` updates with:
- ✅ Owner notifications for waiter summons
- ✅ Owner notifications for bill requests
- ✅ Support for legacy `pushToken` field
- ✅ Support for new `fcmTokens` array
- ✅ Enhanced error logging
