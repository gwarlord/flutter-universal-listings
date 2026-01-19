# RevenueCat Quick Start Guide

## ✅ What's Already Done

Your CaribTap app is **fully integrated** with RevenueCat! Here's what's already working:

1. ✅ **SDK installed** - `purchases_flutter` & `purchases_ui_flutter`
2. ✅ **Service layer complete** - All subscription logic implemented
3. ✅ **Beautiful paywall** - Using RevenueCat's pre-built UI
4. ✅ **Customer center** - For subscription management
5. ✅ **Auto-initialization** - Starts after user login
6. ✅ **Firestore sync** - Subscription status auto-updates
7. ✅ **UI integration** - Upgrade dialogs and locked features work

## 🚀 To Make It Live (5 Steps)

### Step 1: Configure RevenueCat Dashboard (15 minutes)
```
1. Go to https://app.revenuecat.com/
2. Create project "CaribTap"
3. Add your iOS bundle ID & Android package name
4. Create entitlement: "CaribTap Pro"
5. Get your production API key
```

### Step 2: Create Products (20 minutes)

**In App Store Connect (iOS):**
- Create subscription products: `monthly`, `yearly`, `lifetime`
- Set prices: $19.99/mo, $199.99/yr, $399.99 one-time

**In Google Play Console (Android):**
- Create same subscriptions with same product IDs

**In RevenueCat Dashboard:**
- Link all products to "CaribTap Pro" entitlement

### Step 3: Replace Test Key (1 minute)

Open `lib/listings/services/revenue_cat_service.dart`:

```dart
// REPLACE THIS LINE:
static const String _apiKey = 'test_AMaNdtgDOKfMOeVXCijLXaZAXoM';

// WITH YOUR PRODUCTION KEY:
static const String _apiKey = 'your_production_api_key_here';
```

### Step 4: Design Your Paywall (10 minutes)

In RevenueCat dashboard:
1. Go to **Paywalls**
2. Create/customize paywall design
3. Add feature list:
   - Unlimited listings
   - Booking services
   - Priority support
   - Advanced analytics

### Step 5: Test! (10 minutes)

**iOS Testing:**
```bash
# Create sandbox tester in App Store Connect
# Settings > App Store > Sandbox Account > Sign in
flutter run -d ios
```

**Android Testing:**
```bash
# Add your email to license testers in Google Play Console
flutter run -d android
```

## 🎯 How It Works Now

### User Flow
```
1. User taps locked feature
2. Dialog: "Upgrade Required" → "Upgrade Now"
3. Beautiful paywall opens (RevenueCat UI)
4. User selects monthly/yearly/lifetime
5. Native payment sheet appears
6. Purchase completes
7. "Welcome to CaribTap Pro!" 🎉
8. Features unlock instantly
```

### In Your Code

**Check subscription status:**
```dart
final hasPro = await RevenueCatService().hasCaribTapPro();
```

**Show paywall:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PaywallScreen(currentUser: user),
  ),
);
```

**Manage subscription:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => CustomerCenterScreen(currentUser: user),
  ),
);
```

## 📋 Production Checklist

Before going live:
- [ ] Replace test API key with production key
- [ ] Test purchases with real money (small amounts)
- [ ] Test on iOS sandbox
- [ ] Test on Android license testing
- [ ] Test restore purchases
- [ ] Verify Firestore updates correctly
- [ ] Add Terms of Service link
- [ ] Add Privacy Policy link
- [ ] Test subscription cancellation
- [ ] Monitor RevenueCat dashboard

## 🐛 Common Issues & Fixes

### "No offerings available"
**Fix:** Wait 15-30 mins after creating products. Check product IDs match exactly.

### "Purchase failed"
**Fix:** 
- iOS: Ensure sandbox tester signed in
- Android: Check email added to license testers

### "Entitlement not showing"
**Fix:** Verify product is attached to "CaribTap Pro" entitlement in RevenueCat dashboard

## 📱 Test Commands

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Run on device
flutter run -d <device-id>

# Check RevenueCat logs
# Enable in RevenueCatService.dart (already enabled in debug mode)
```

## 🎉 You're Ready!

Everything is implemented and ready. Just:
1. Complete dashboard setup
2. Replace API key
3. Test purchases
4. Launch! 🚀

For detailed instructions, see: [REVENUECAT_INTEGRATION_COMPLETE.md](REVENUECAT_INTEGRATION_COMPLETE.md)

## 📚 Key Files

- `lib/listings/services/revenue_cat_service.dart` - All subscription logic
- `lib/listings/ui/subscription/paywall_screen.dart` - Beautiful paywall
- `lib/listings/ui/subscription/customer_center_screen.dart` - Subscription management
- `lib/listings/ui/auth/login/login_screen.dart` - Auto-initialization on login
- `lib/listings/model/listings_user.dart` - Subscription fields & helpers

## 💡 Pro Tips

1. **Use test mode first** - Test with your current test key before switching to production
2. **Test restore purchases** - Critical for users switching devices
3. **Monitor the dashboard** - RevenueCat dashboard shows real-time subscription data
4. **Handle edge cases** - Network errors, failed payments, etc. (already implemented!)
5. **Caribbean payments work great** - USD, cards, Apple Pay, Google Pay all supported

Need help? Open [REVENUECAT_INTEGRATION_COMPLETE.md](REVENUECAT_INTEGRATION_COMPLETE.md) for the full guide!
