# Rental Booking Push Notifications

## Overview
Push notifications are automatically sent for rental booking events to keep both listers and customers informed.

## Notification Types

### 1. New Rental Booking (`new_rental_booking`)
**Recipient:** Lister  
**Trigger:** When a customer creates a new rental booking  
**Title:** "🚗 New Rental Booking"  
**Body:** "{CustomerName} requested a rental from {ListingTitle} ({DateRange})"

### 2. Rental Confirmed (`rental_confirmed`)
**Recipient:** Customer  
**Trigger:** When lister confirms the booking  
**Title:** "✅ Rental Booking Confirmed"  
**Body:** "Your rental booking for {ListingTitle} has been confirmed!"

### 3. Rental Cancelled (`rental_cancelled`)
**Recipient:** The other party (customer or lister)  
**Trigger:** When either party cancels the booking  
**Title:** "❌ Rental Booking Cancelled"  
**Body:** "The rental booking for {ListingTitle} has been cancelled"

### 4. Rental Started (`rental_started`)
**Recipient:** Customer  
**Trigger:** When booking status changes to "active"  
**Title:** "🚘 Rental Started"  
**Body:** "Your rental period for {ListingTitle} has started. Enjoy!"

### 5. Rental Completed (`rental_completed`)
**Recipient:** Customer  
**Trigger:** When booking status changes to "completed"  
**Title:** "✨ Rental Complete"  
**Body:** "Your rental of {ListingTitle} is complete. Thank you!"

## Cloud Functions

### `onRentalBookingCreated`
- **Trigger:** Firestore onCreate for `rental_bookings/{bookingId}`
- **Function:** Sends notification to lister when new booking is created
- **Location:** `functions/src/rental_booking_notifications.ts`

### `onRentalBookingStatusChanged`
- **Trigger:** Firestore onUpdate for `rental_bookings/{bookingId}`
- **Function:** Sends appropriate notification based on status change
- **Location:** `functions/src/rental_booking_notifications.ts`

## Notification Data Payload

All notifications include the following data fields:
```json
{
  "type": "new_rental_booking|rental_confirmed|rental_cancelled|rental_started|rental_completed",
  "bookingId": "string",
  "listingId": "string",
  "customerId": "string (for new bookings)",
  "status": "string (for status changes)",
  "click_action": "FLUTTER_NOTIFICATION_CLICK"
}
```

## Android Channel Configuration

**Channel ID:** `rental_bookings`  
**Sound:** Default  
**Priority:** High

## iOS Configuration

**Sound:** Default  
**Badge:** Incremented by 1

## User Preferences

Users can disable push notifications in their settings:
- Settings > Push Notifications toggle
- Notifications respect the `settings.allowPushNotifications` field

## Testing

1. Create a rental booking as a customer
2. Lister should receive a notification
3. Lister confirms/cancels booking
4. Customer should receive status update notification

## Requirements

- User must have a valid FCM `pushToken` in Firestore
- User must have push notifications enabled in settings
- App must be configured to handle notification clicks (see `main.dart`)

## Deployment

Functions are automatically deployed with:
```bash
firebase deploy --only functions
```

Or specifically:
```bash
firebase deploy --only functions:onRentalBookingCreated,functions:onRentalBookingStatusChanged
```
