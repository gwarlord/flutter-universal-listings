# Rental Bookings Badge Count Fix

## Issue
Rental notification badges were not working in the app, while Chats and Orders badges worked correctly.

## Root Cause
**Collection name mismatch** in Firebase Cloud Functions:

- **Flutter App** uses: `rental_bookings` (snake_case)
- **Attention Tracking Cloud Functions** were watching: `rentalBookings` (camelCase)

This mismatch meant:
1. When a rental booking is created in Firestore, the `rental_bookings` collection trigger fires
2. But the notification sends correctly
3. However, the attention badge count update function never fires because it's listening to the wrong collection name (`rentalBookings`)
4. Result: Badge count stays at 0

## Solution Applied

### Files Modified:
1. **functions/src/attention_tracking.ts**
   - Line 188: Changed `onRentalBookingStatusChangedUpdateAttention` to watch `"rental_bookings/{bookingId}"` instead of `"rentalBookings/{bookingId}"`
   - Line 250: Changed `onRentalBookingCreatedUpdateAttention` to watch `"rental_bookings/{bookingId}"` instead of `"rentalBookings/{bookingId}"`

2. **functions/package.json**
   - Added missing dependencies: `@google-cloud/vision`, `@google-cloud/storage`, `sharp`, `uuid`

3. **functions/src/photo_enhancement.ts**
   - Fixed import: Changed `import * as sharp from "sharp"` to `import sharp from "sharp"` (default import)
   - Fixed TypeScript error in metadata handling
   - Fixed Sharp modulate() invalid property

### Functions Updated:

**onRentalBookingStatusChangedUpdateAttention**
```typescript
export const onRentalBookingStatusChangedUpdateAttention = functions.firestore
  .document("rental_bookings/{bookingId}")  // ← Fixed: was "rentalBookings/{bookingId}"
  .onUpdate(...)
```

**onRentalBookingCreatedUpdateAttention**
```typescript
export const onRentalBookingCreatedUpdateAttention = functions.firestore
  .document("rental_bookings/{bookingId}")  // ← Fixed: was "rentalBookings/{bookingId}"
  .onCreate(...)
```

## How It Works After Fix

1. **New rental booking created** → `rental_bookings/{bookingId}` document created in Firestore
2. **onCreate trigger fires** → `onRentalBookingCreatedUpdateAttention` function runs
3. **Attention count incremented** → Updates `users/{userId}/attention/state` document with `counts.rentals++`
4. **Badge updates in UI** → AttentionCubit receives Firestore update and emits new state
5. **Badge displays correctly** → Drawer shows rental count badge like Chats and Orders

## Deployment Required

To apply these changes, deploy the Cloud Functions:

```bash
cd functions
npm install  # Already done
npm run build  # Already done
firebase deploy --only functions
```

Or use:
```bash
npm run deploy
```

## Testing After Deployment

1. Create a new rental booking for your listing
2. Check if the "Rentals" badge count updates in the drawer
3. Navigate to Rentals screen and verify the count resets when viewed
4. Test status changes (confirm, cancel) to ensure updates increment count

## Verification Checklist

- ✅ Collection names match between app and Cloud Functions
- ✅ TypeScript compiles successfully
- ✅ Both onCreate and onUpdate functions use correct collection name
- ✅ Ready for deployment to Firebase
