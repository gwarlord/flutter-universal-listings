# RevenueCat Subscription Integration Guide

## Overview
This project uses **RevenueCat** for managing cross-platform subscriptions (iOS, Android, and Web). RevenueCat simplifies subscription management and works well in the Caribbean region.

## Why RevenueCat?
- ✅ **Cross-platform**: iOS, Android, Web
- ✅ **Multiple payment processors**: Apple, Google, Stripe
- ✅ **Caribbean-friendly**: Supports international payments
- ✅ **Easy integration**: Handles receipt validation, webhooks, and renewals
- ✅ **Analytics**: Built-in subscription analytics

---

## Setup Steps

### 1. Create RevenueCat Account
1. Go to [https://app.revenuecat.com/](https://app.revenuecat.com/)
2. Sign up for a free account
3. Create a new project

### 2. Configure App Platforms

#### iOS Setup (App Store)
1. In RevenueCat dashboard, go to **Project Settings > Apps**
2. Click **Add App** > Select **iOS**
3. Enter your **Bundle ID** (found in `ios/Runner.xcodeproj`)
4. Add your **App Store Connect Shared Secret**:
   - Go to [App Store Connect](https://appstoreconnect.apple.com/)
   - Select your app > App Information > App-Specific Shared Secret
   - Generate and copy the secret
   - Paste in RevenueCat

#### Android Setup (Google Play)
1. In RevenueCat dashboard, go to **Project Settings > Apps**
2. Click **Add App** > Select **Android**
3. Enter your **Package Name** (found in `android/app/build.gradle`)
4. Add **Google Play Service Account**:
   - Go to [Google Play Console](https://play.google.com/console/)
   - Settings > API Access
   - Create a service account
   - Download JSON key file
   - Upload to RevenueCat

#### Web Setup (Stripe)
1. Create a [Stripe account](https://stripe.com/) (if you don't have one)
2. In RevenueCat dashboard, go to **Project Settings > Integrations**
3. Click **Connect Stripe**
4. Enter your Stripe API keys:
   - Get keys from [Stripe Dashboard](https://dashboard.stripe.com/apikeys)
   - Use **Test keys** for development
   - Use **Live keys** for production

### 3. Configure Products & Entitlements

#### Create Entitlements
Entitlements are the features users get access to.

1. Go to **Entitlements** in RevenueCat dashboard
2. Create these entitlements:
   - `professional` - For Professional tier features
   - `premium` - For Premium tier features

#### Create Products

##### iOS (App Store Connect)
1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app > In-App Purchases
3. Create **Auto-Renewable Subscriptions**:
   - `pro_monthly` - Professional Monthly ($19.99/month)
   - `pro_yearly` - Professional Yearly ($199.99/year)
   - `premium_monthly` - Premium Monthly ($39.99/month)
   - `premium_yearly` - Premium Yearly ($399.99/year)

##### Android (Google Play Console)
1. Go to [Google Play Console](https://play.google.com/console/)
2. Select your app > Monetize > Subscriptions
3. Create the same subscriptions as iOS

##### Web (Stripe)
1. Go to [Stripe Dashboard](https://dashboard.stripe.com/products)
2. Create **Products** with **Recurring** prices
3. Use the same product IDs as iOS/Android

#### Link Products in RevenueCat
1. Go to **Products** in RevenueCat dashboard
2. For each product, add the store identifiers:
   - App Store ID (iOS)
   - Google Play ID (Android)
   - Stripe Price ID (Web)
3. Attach products to entitlements:
   - Link `pro_monthly` and `pro_yearly` to `professional` entitlement
   - Link `premium_monthly` and `premium_yearly` to `premium` entitlement

### 4. Get API Keys
1. In RevenueCat dashboard, go to **Project Settings > API Keys**
2. Copy these keys:
   - **iOS API Key**
   - **Android API Key**
   - **Public API Key** (for web/general use)

### 5. Add Package to Flutter Project

Add RevenueCat SDK to `pubspec.yaml`:

```yaml
dependencies:
  purchases_flutter: ^6.0.0
```

Run:
```bash
flutter pub get
```

### 6. Update API Keys in Code

Open `lib/listings/services/revenue_cat_service.dart` and replace placeholders:

```dart
static const String _androidApiKey = 'your_android_api_key_here';
static const String _iosApiKey = 'your_ios_api_key_here';
static const String _webStripePublicKey = 'your_stripe_public_key_here';
```

### 7. Uncomment RevenueCat Code

In `lib/listings/services/revenue_cat_service.dart`:
1. Uncomment the `import 'package:purchases_flutter/purchases_flutter.dart';` line
2. Uncomment all the commented RevenueCat method implementations

### 8. Initialize RevenueCat in App

Add to your `main.dart` or after user login:

```dart
import 'package:instaflutter/listings/services/revenue_cat_service.dart';

// After user logs in
await RevenueCatService().initialize(userId: currentUser.userID);
```

### 9. Test Subscriptions

#### iOS Testing
1. Use **Sandbox Tester Accounts** from App Store Connect
2. Go to Settings > App Store > Sandbox Account
3. Sign in with test account

#### Android Testing
1. Add test Gmail accounts in Google Play Console
2. Go to Setup > License Testing
3. Install app and test with test account

#### Web Testing (Stripe)
1. Use Stripe test credit cards:
   - Success: `4242 4242 4242 4242`
   - Decline: `4000 0000 0000 0002`

### 10. Configure Webhooks (Optional but Recommended)

RevenueCat can send webhook events to your backend when subscriptions change.

1. In RevenueCat dashboard, go to **Project Settings > Integrations**
2. Click **Webhooks**
3. Add your server webhook URL
4. Use Firebase Functions to handle webhook events

Example Firebase Function:
```javascript
exports.handleRevenueCatWebhook = functions.https.onRequest(async (req, res) => {
  const event = req.body;
  
  // Update user subscription in Firestore
  if (event.type === 'INITIAL_PURCHASE' || event.type === 'RENEWAL') {
    const userId = event.app_user_id;
    const tier = mapEntitlementToTier(event.entitlements);
    
    await admin.firestore().collection('users').doc(userId).update({
      subscriptionTier: tier,
      subscriptionExpiresAt: new Date(event.expiration_at_ms)
    });
  }
  
  res.status(200).send('OK');
});
```

---

## Usage in App

### Check Subscription Status
```dart
// In any widget with access to currentUser
if (currentUser.hasBookingServices) {
  // Show booking services feature
} else {
  // Show upgrade dialog
}
```

### Navigate to Subscription Screen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SubscriptionScreen(
      currentUser: currentUser,
    ),
  ),
);
```

### Restore Purchases
```dart
final success = await RevenueCatService().restorePurchases(
  userId: currentUser.userID,
);
```

---

## Subscription Tiers

| Tier | Monthly | Yearly | Features |
|------|---------|--------|----------|
| **Free** | $0 | $0 | Up to 3 listings, Basic features |
| **Professional** | $19.99 | $199.99 | Unlimited listings, Booking services, Analytics |
| **Premium** | $39.99 | $399.99 | Everything + Priority support, Advanced analytics |

---

## Caribbean Payment Considerations

### Stripe Payment Methods
For the Caribbean region, enable these payment methods in Stripe:
1. Go to [Stripe Dashboard](https://dashboard.stripe.com/settings/payment_methods)
2. Enable:
   - **Credit Cards** (Visa, Mastercard, Amex)
   - **Debit Cards**
   - **Apple Pay** (for iOS)
   - **Google Pay** (for Android)

### Currency
- Use **USD** for pricing (widely accepted in Caribbean)
- Stripe handles currency conversion automatically
- Customers can pay with local cards that support USD

### Regional Testing
Test with cards from different Caribbean regions:
- Jamaica
- Trinidad & Tobago
- Barbados
- Bahamas

---

## Troubleshooting

### "No offerings available"
- Check that products are created in App Store Connect / Google Play Console
- Verify products are linked in RevenueCat dashboard
- Ensure API keys are correct

### "Purchase failed"
- iOS: Check sandbox tester account is signed in
- Android: Verify test account is added in Google Play Console
- Web: Check Stripe test mode is enabled

### "Subscription not syncing to Firestore"
- Check RevenueCat webhook is configured
- Verify Firebase Functions are deployed
- Check Firebase logs for errors

---

## Production Checklist

Before launching subscriptions in production:

- [ ] Switch to **production API keys** in RevenueCat
- [ ] Use **live Stripe keys** (not test keys)
- [ ] Configure **production webhooks**
- [ ] Test with real credit cards (small amounts)
- [ ] Set up **subscription analytics** in RevenueCat dashboard
- [ ] Configure **customer support** email for subscription issues
- [ ] Add **Terms of Service** and **Privacy Policy** links to subscription screen
- [ ] Test **restore purchases** functionality
- [ ] Test **cancellation** flow
- [ ] Monitor **failed payments** and set up retry logic

---

## Support

- [RevenueCat Documentation](https://docs.revenuecat.com/)
- [RevenueCat Community](https://community.revenuecat.com/)
- [Stripe Documentation](https://stripe.com/docs)
- [Flutter Package](https://pub.dev/packages/purchases_flutter)

---

## Next Steps

1. **Test the subscription flow** in development mode
2. **Update pricing** if needed for Caribbean market
3. **Add more features** to differentiate tiers
4. **Monitor analytics** in RevenueCat dashboard
5. **Optimize conversion** by A/B testing pricing and features
