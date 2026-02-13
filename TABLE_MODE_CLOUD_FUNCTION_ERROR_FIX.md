# Table Mode Cloud Function Error Fix

## Problem
The `summonWaiter` Cloud Function was returning a generic `[firebase_functions/internal] INTERNAL` error instead of meaningful error messages to the Flutter client.

### Error Details
```
[firebase_functions/internal] INTERNAL
Stack Trace:
#0 CloudFunctionsHostApi.call
#1 MethodChannelHttpsCallable.call
#2 HttpsCallable.call
#3 TableModeFirebase.summonWaiter (table_mode_firebase.dart:211:7)
#4 _OrderDetailScreenState._summonWaiter (order_detail_screen.dart:1341:7)
```

## Root Cause
The table mode Cloud Functions in Firebase lacked comprehensive error handling. When an unexpected error occurred during function execution (not wrapped in `HttpsError`), Firebase would return a generic `INTERNAL` error instead of the actual error details. This made debugging very difficult.

### Issues Identified
1. **No try-catch blocks** on Cloud Functions
2. **Missing error logging** for unexpected exceptions
3. **No defensive coding** for edge cases (null checks, type validation)
4. **Unhandled errors in helper functions** (`logSessionEvent`, `sendPushNotification`)

## Solution
Added comprehensive error handling to all table mode Cloud Functions with:

### 1. Try-Catch Error Handler Pattern
Each function now wraps its logic in a try-catch block:
```typescript
export const functionName = functions.https.onCall(async (data, context) => {
  try {
    // Main function logic
    return { success: true };
  } catch (error: any) {
    // Log the actual error for Firebase Logs
    functions.logger.error("functionName error", {
      error: error.message || String(error),
      code: error.code,
      stack: error.stack,
    });
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Convert unexpected errors to proper HttpsError with details
    throw new functions.https.HttpsError(
      "internal",
      `Failed to [action]: ${error.message || String(error)}`
    );
  }
});
```

### 2. Defensive Data Validation
- Added null/undefined checks for critical data
- Proper type validation for function parameters
- Safe property access with fallback values

### 3. Error Logging
Each catch block logs:
- Error message
- Error code
- Stack trace
- Contextual information (sessionId, listingId, etc.)

### 4. Functions Updated
All 9 table mode Cloud Functions now have error handling:
1. `setTableModeSettings` - Listing configuration
2. `upsertTable` - Table CRUD operations
3. `deactivateTable` - Table status management
4. `createTableSession` - Customer session creation
5. `assignWaiterToSession` - Staff assignment
6. **`summonWaiter`** - Waiter summoning (primary fix)
7. `acknowledgeSummon` - Staff acknowledgment
8. `requestBill` - Bill request handling
9. `closeTableSession` - Session closure

## Specific Fixes in summonWaiter

### Before
```typescript
export const summonWaiter = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }
  
  // ... no error handling for following operations
  const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
  // Could throw uncaught error
  const lastSummonAt = sessionData?.lastSummonAt?.toDate(); // Could fail silently
  await logSessionEvent(...); // Could throw
  await sendPushNotification(...); // Could throw
});
```

### After
```typescript
export const summonWaiter = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    
    // Defensive data access
    let lastSummonAt: Date | null = null;
    if (sessionData.lastSummonAt) {
      try {
        lastSummonAt = sessionData.lastSummonAt.toDate?.() || sessionData.lastSummonAt;
      } catch (e) {
        functions.logger.warn("Failed to parse lastSummonAt", { lastSummonAt: sessionData.lastSummonAt });
      }
    }
    
    // Graceful push notification failure (doesn't crash function)
    if (Array.isArray(assignedStaff) && assignedStaff.length > 0) {
      for (const staff of assignedStaff) {
        if (staff && staff.uid) {
          try {
            await sendPushNotification(...);
          } catch (pushError) {
            functions.logger.warn("Failed to send push notification", { 
              staffUid: staff.uid, 
              error: (pushError as any).message 
            });
          }
        }
      }
    }
    
    return { success: true };
  } catch (error: any) {
    functions.logger.error("summonWaiter error", { 
      error: error.message || String(error),
      code: error.code,
      stack: error.stack 
    });
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      "internal",
      `Failed to summon waiter: ${error.message || String(error)}`
    );
  }
});
```

## Key Improvements

1. **Better Error Messages**: Clients now receive descriptive error messages with context
2. **Server Logging**: Errors are logged in Firebase Cloud Functions logs for debugging
3. **Non-blocking Operations**: Push notifications don't crash the entire function
4. **Type Safety**: Defensive checks prevent null/undefined errors
5. **Consistent Pattern**: All functions follow the same error handling pattern

## Testing
After deploying the updated functions:

1. **Error Cases Now Report Properly**:
   - Invalid session ID → "Session not found"
   - Non-customer trying to summon → "Only session customer can summon waiter"
   - Cooldown exceeded → "Please wait X seconds before summoning again"
   - Unexpected error → "Failed to summon waiter: [actual error message]"

2. **Check Firebase Logs**:
   Functions → summonWaiter → Logs will show:
   ```
   {
     "severity": "ERROR",
     "message": "summonWaiter error",
     "error": "Could not read property 'toDate' of undefined",
     "code": undefined,
     "stack": "..."
   }
   ```

3. **Flutter Logging**:
   The Flutter app will now receive properly typed error responses instead of INTERNAL:
   ```dart
   // Before: [firebase_functions/internal] INTERNAL
   // After: [firebase_functions/internal] Failed to summon waiter: Could not read property 'toDate' of undefined
   ```

## Files Modified
- `functions/src/tableMode.ts` - Source TypeScript
- `functions/lib/tableMode.js` - Generated JavaScript (auto-compiled)

## Deployment
To deploy these changes to Firebase:
```bash
firebase deploy --only functions
```

This will deploy all 9 table mode functions with improved error handling.
