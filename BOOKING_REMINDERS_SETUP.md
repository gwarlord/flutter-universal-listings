# Booking Reminder System - Configuration & Testing Guide

## Overview
This guide covers the setup, deployment, and testing of the booking reminder notification system for the CaribTap Flutter app. The system automatically sends email and push notifications to customers 24 hours and 1 hour before their booking start time.

---

## Architecture

### Components
1. **Cloud Functions (TypeScript)** - Scheduled job + Firestore triggers
2. **SendGrid** - Email delivery
3. **Firebase Cloud Messaging (FCM)** - Push notifications
4. **Firestore** - Booking data + reminder tracking
5. **Flutter App** - Deep linking + settings UI

### Reminder Flow
1. Customer creates a booking with `checkInDate`
2. Cloud Function initializes reminder fields (`reminder24hSentAt`, `reminder1hSentAt`)
3. Scheduled function runs every 10 minutes
4. Queries bookings with `checkInDate` in the reminder window
5. Sends email + push if reminder hasn't been sent yet
6. Marks reminder as sent with timestamp

---

## Configuration

### 1. Firebase Functions Configuration

#### Set Environment Variables
```bash
cd functions

# Set SendGrid API Key
firebase functions:config:set sendgrid.key="YOUR_SENDGRID_API_KEY"

# Set App URL (for deep links in emails)
firebase functions:config:set app.url="https://caribtap.com"

# View current config
firebase functions:config:get
```

#### Alternative: Use .env for local testing
Create `functions/.env` (do NOT commit):
```
SENDGRID_KEY=SG.xxxxxxxxxxxxx
APP_URL=https://caribtap.com
```

### 2. SendGrid Setup

1. **Create SendGrid Account**
   - Go to [sendgrid.com](https://sendgrid.com)
   - Sign up or log in
   
2. **Create API Key**
   - Navigate to Settings > API Keys
   - Click "Create API Key"
   - Name: "CaribTap Booking Reminders"
   - Permissions: "Full Access" or "Mail Send"
   - Copy the API key (you'll only see it once!)

3. **Verify Sender Domain (Important for deliverability)**
   - Go to Settings > Sender Authentication
   - Authenticate your domain (caribtap.com)
   - Or set up Single Sender Verification for testing

4. **Set API Key in Firebase**
   ```bash
   firebase functions:config:set sendgrid.key="SG.your_api_key_here"
   ```

### 3. Firebase Cloud Messaging (FCM)

FCM is already configured in your app. Ensure:
- Users' FCM tokens are saved to `users/{uid}.pushToken`
- Tokens are refreshed on app start and when changed
- Android notification channel is created:
  ```dart
  channelId: 'booking_reminders'
  channelName: 'Booking Reminders'
  importance: Importance.high
  ```

### 4. Firestore Indexes

The scheduled function queries bookings. Create indexes if needed:

#### Index 1: Bookings by listing
- Collection: `listings/{listingId}/bookings`
- Fields: `status` (Ascending), `checkInDate` (Ascending)

#### Index 2: (Optional) If using rental_bookings
- Collection: `rental_bookings`
- Fields: `status` (Ascending), `startTime` (Ascending)

**To create indexes:**
1. Run the function and check Firebase Console logs for index creation links
2. Or manually create in Firebase Console > Firestore > Indexes

### 5. Timezone Support

The system supports timezone-aware reminders. When creating bookings, set the `timezone` field:

```dart
BookingModel(
  // ... other fields
  timezone: 'America/Port_of_Spain',  // IANA timezone string
)
```

If no timezone is provided, defaults to `America/Port_of_Spain`.

---

## Deployment

### 1. Build Functions
```bash
cd functions
npm install
npm run build
```

### 2. Deploy Functions
```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific functions
firebase deploy --only functions:sendBookingReminders,functions:onBookingCreated,functions:onBookingUpdated
```

### 3. Verify Deployment
```bash
# Check function logs
firebase functions:log --only sendBookingReminders

# In Firebase Console:
# Functions > sendBookingReminders > Logs
```

### 4. Deploy Flutter App
```bash
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

---

## Testing

### Test Scenario 1: 1-Hour Reminder (Quick Test)

#### Setup:
1. Create a test booking with `checkInDate` **65 minutes from now**
2. Booking must have `status: "confirmed"`
3. Customer must have valid email and FCM token

#### Steps:
```dart
// In Flutter app or Firestore Console
final checkInDate = DateTime.now().add(Duration(minutes: 65));

FirebaseFirestore.instance
  .collection('listings')
  .doc('test-listing-id')
  .collection('bookings')
  .add({
    'customerId': 'test-user-id',
    'customerName': 'Test User',
    'customerEmail': 'test@example.com',
    'listersUserId': 'lister-uid',
    'listingTitle': 'Test Listing',
    'checkInDate': checkInDate.toIso8601String(),
    'checkOutDate': checkInDate.add(Duration(days: 1)).toIso8601String(),
    'status': 'confirmed',
    'numberOfGuests': 2,
    'totalPrice': 100,
    'currency': 'USD',
    'timezone': 'America/Port_of_Spain',
    'reminder24hSentAt': null,
    'reminder1hSentAt': null,
  });
```

#### Verification:
1. **Within 10 minutes:**
   - Check Firebase Functions logs for reminder execution
   - Customer receives email (check inbox/spam)
   - Customer receives push notification
   
2. **In Firestore:**
   - Booking document shows `reminder1hSentAt: <timestamp>`
   
3. **Email Content:**
   - Subject: "Reminder: Your booking is in 1 hour"
   - Body shows listing name, check-in date/time, guest count
   - "View Booking Details" button links to app

4. **Push Notification:**
   - Title: "Booking Reminder"
   - Body: "Your booking for [Listing] is in 1 hour..."
   - Tap opens booking detail screen

### Test Scenario 2: 24-Hour Reminder

#### Setup:
Create booking with `checkInDate` **24 hours + 5 minutes from now**

```dart
final checkInDate = DateTime.now().add(Duration(hours: 24, minutes: 5));
```

Schedule will send reminder within next 10-minute cycle.

### Test Scenario 3: Rescheduled Booking

#### Test reminder reset on date change:
1. Create booking 25 hours ahead
2. Wait for 24h reminder to send (verify `reminder24hSentAt` is set)
3. Update booking `checkInDate` to 26 hours ahead
4. Verify `reminder24hSentAt` is reset to `null`
5. 24h reminder will be sent again at new time

### Test Scenario 4: User Preferences

#### Test opt-out:
1. User navigates to Settings > Booking Reminders
2. Disable "Email Reminders" or "Push Reminders"
3. Create booking 1 hour ahead
4. Verify disabled channels are not used

```dart
// Update user settings
FirebaseFirestore.instance.collection('users').doc(userId).update({
  'settings.bookingEmailReminders': false,  // Disable email
});
```

### Test Scenario 5: Cancelled Booking

1. Create booking 1 hour ahead
2. Cancel booking: update `status: "cancelled"`
3. Verify NO reminder is sent (check logs)

---

## Local Testing with Emulator

### 1. Start Firebase Emulators
```bash
cd functions
firebase emulators:start
```

This starts:
- Firestore Emulator
- Functions Emulator
- (Pub/Sub for scheduled functions)

### 2. Point Flutter App to Emulator
```dart
// In main.dart
await Firebase.initializeApp();

if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

### 3. Trigger Scheduled Function Manually
```bash
# Invoke sendBookingReminders
curl -X POST http://localhost:5001/caribtap/us-central1/sendBookingReminders
```

### 4. View Emulator Logs
Open: http://localhost:4000

---

## Monitoring & Logs

### Firebase Console
1. **Functions Logs:**
   - Firebase Console > Functions > sendBookingReminders > Logs
   - Look for:
     - "🔍 Checking 24h reminders" or "🔍 Checking 1h reminders"
     - "📧 Sending 24h reminder for booking..."
     - "✅ Email reminder sent" or "❌ Error sending..."

2. **Firestore Documents:**
   - Check `reminder24hSentAt` and `reminder1hSentAt` timestamps
   - Verify they're only set once per reminder

3. **SendGrid Dashboard:**
   - Go to sendgrid.com > Activity
   - Search for recipient email
   - View delivery status, opens, clicks

### Common Issues

#### Issue: Reminders not sending
**Check:**
1. Firestore query is finding bookings:
   - status == "confirmed"
   - checkInDate in correct window
2. Reminder fields are `null` (not already sent)
3. Customer has email and/or pushToken
4. User notification preferences are enabled

#### Issue: Email not arriving
**Check:**
1. SendGrid API key is valid
2. Sender email is verified in SendGrid
3. Check spam folder
4. View SendGrid Activity Feed for errors

#### Issue: Push notification not arriving
**Check:**
1. User's `pushToken` is valid and up-to-date
2. FCM configuration in Flutter is correct
3. Android notification channel exists (`booking_reminders`)
4. User has granted notification permissions

#### Issue: Function timeout
**Increase timeout in function config:**
```typescript
export const sendBookingReminders = functions
  .runWith({ timeoutSeconds: 540 })  // 9 minutes (max)
  .pubsub
  .schedule("every 10 minutes")
  .onRun(...)
```

---

## Firestore Security Rules

Add rules to prevent tampering with reminder fields:

```javascript
// In firestore.rules
match /listings/{listingId}/bookings/{bookingId} {
  allow read: if request.auth.uid != null &&
              (request.auth.uid == resource.data.customerId ||
               request.auth.uid == get(/databases/$(database)/documents/listings/$(listingId)).data.authorID);
  
  allow create: if request.auth.uid != null &&
                request.auth.uid == request.resource.data.customerId;
  
  // Customers can update their own bookings but NOT reminder fields
  allow update: if request.auth.uid == resource.data.customerId &&
                !('reminder24hSentAt' in request.resource.data.diff(resource.data).affectedKeys()) &&
                !('reminder1hSentAt' in request.resource.data.diff(resource.data).affectedKeys());
  
  // Listers can update status and reminder fields
  allow update: if request.auth.uid == get(/databases/$(database)/documents/listings/$(listingId)).data.authorID;
}
```

---

## Cost Estimates

### SendGrid
- Free tier: 100 emails/day
- Paid: $19.95/month for 50,000 emails

### Firebase Functions
- Free tier: 2M invocations/month, 400K GB-seconds
- Scheduled function runs every 10 minutes = ~4,380 invocations/month (well within free tier)
- Minimal memory usage, typically <128MB

### FCM
- Completely free

### Firestore
- Reads: 2 reads per booking check (booking doc + user doc)
- Writes: 3 writes per reminder sent (booking + 2 user subcollections)
- With 100 bookings/day, ~6,600 reads/day (~200K/month, within free tier)

---

## Customization

### Adjust Reminder Times
In `functions/src/booking_reminders.ts`:

```typescript
// Change from 24h to 48h
const REMINDER_24H = 48 * 60 * 60 * 1000;

// Add 3-hour reminder
const REMINDER_3H = 3 * 60 * 60 * 1000;
await processReminders(nowTimestamp, REMINDER_3H, "3h");

// Adjust window tolerance
const REMINDER_WINDOW = 15 * 60 * 1000;  // ±15 minutes
```

### Customize Email Template
Edit `buildReminderEmailTemplate()` in `booking_reminders.ts`:
- Change colors, fonts, layout
- Add more booking details
- Include custom branding

### Add SMS Reminders
Integrate Twilio:
```typescript
import twilio from 'twilio';

const client = twilio(accountSid, authToken);

await client.messages.create({
  body: `Reminder: Your booking at ${listing} is in ${timeLabel}`,
  to: customer.phoneNumber,
  from: '+1234567890'
});
```

---

## Production Checklist

- [ ] SendGrid domain verified
- [ ] SendGrid API key configured in Firebase
- [ ] Firebase Functions deployed
- [ ] Firestore indexes created
- [ ] Security rules updated
- [ ] FCM notification channels configured in Android
- [ ] Deep linking configured for iOS and Android
- [ ] Settings UI tested (enable/disable reminders)
- [ ] Test bookings created and reminders received
- [ ] Monitoring dashboard set up
- [ ] Email templates reviewed for branding
- [ ] Error handling and logging verified

---

## Support & Troubleshooting

### View Function Logs
```bash
firebase functions:log
```

### Debug Specific Booking
Check Firestore Console for:
- Booking status
- Reminder sent timestamps
- User email and push token
- Timezone field

### Test SendGrid Connection
```bash
# In functions/
npm install
npm run build
node -e "
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey('YOUR_API_KEY');
sgMail.send({
  to: 'test@example.com',
  from: 'bookings@caribtap.com',
  subject: 'Test',
  text: 'SendGrid is working!'
}).then(() => console.log('✅ Sent')).catch(console.error);
"
```

---

## Summary

The booking reminder system is production-ready with:
- ✅ Idempotent reminder sending (no duplicates)
- ✅ Email + Push notifications
- ✅ User preference controls
- ✅ Timezone-aware formatting
- ✅ Automatic rescheduling support
- ✅ Deep linking to booking details
- ✅ Comprehensive logging and error handling

**Next Steps:**
1. Configure SendGrid API key
2. Deploy Cloud Functions
3. Test with a booking 65 minutes ahead
4. Monitor logs and verify delivery
5. Roll out to production!
