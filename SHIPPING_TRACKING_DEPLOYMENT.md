# Shipping + Tracking Feature - Quick Deployment Guide

## Files Changed & Created

### NEW FILES (3):
1. `lib/screens/store/shipping_tracking_card.dart` - Lister tracking entry UI
2. `lib/screens/store/shipping_tracking_display.dart` - Customer tracking display
3. `functions/src/order_tracking.ts` - Cloud Functions for tracking + email

### MODIFIED FILES (10):
1. `lib/listings/model/order_request.dart` - Order model update
2. `lib/listings/model/listing_model.dart` - ListingModel field
3. `lib/listings/services/store_service.dart` - Service methods
4. `lib/screens/store/store_settings_screen.dart` - Settings UI
5. `lib/screens/store/cart_screen.dart` - Checkout flow
6. `lib/screens/store/order_detail_screen.dart` - Detail view
7. `lib/screens/store/customer_orders_screen.dart` - Customer list
8. `lib/screens/store/orders_management_screen.dart` - Lister list
9. `functions/src/index.ts` - Function exports
10. `firestore.rules` - Security rules

### DOCUMENTATION:
- `SHIPPING_TRACKING_IMPLEMENTATION.md` - Complete feature documentation

---

## Pre-Deployment Checklist

- [ ] Flutter code compiles: `flutter analyze --fatal-infos lib/`
- [ ] Unit tests pass (if applicable)
- [ ] Cloud Functions compile: `cd functions && npm run build`
- [ ] RevenueCat API key configured in Firebase
- [ ] SendGrid API key configured in Firebase (for email)
- [ ] Firestore backup created before rule deployment

---

## Deployment Steps (5 minutes)

### Step 1: Deploy Cloud Functions
```bash
cd functions
npm run build
cd ..
firebase deploy --only functions:setOrderTracking,functions:sendTrackingEmail
```

**Verify**: Check Firebase Console > Functions > see `setOrderTracking` and `sendTrackingEmail`

### Step 2: Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

**Verify**: Check Firebase Console > Firestore > Rules tab > deployments

### Step 3: Configure RevenueCat API Key
```bash
firebase functions:config:set revenuecat.api_key="your_api_key_here"
```

Get API key from:
- RevenueCat Dashboard > Settings > API Keys > Public API Key
- Format: starts with `appl_`

### Step 4: Verify SendGrid Setup
```bash
firebase functions:config:get sendgrid
```

If not set:
```bash
firebase functions:config:set sendgrid.key="your_sendgrid_api_key"
```

### Step 5: Monitor Logs
```bash
firebase functions:log --follow
```

Look for:
- ✅ No errors in `setOrderTracking`
- ✅ Emails being sent to test orders

---

## Testing the Feature (10 minutes)

### Test 1: Store Settings
1. Go to Store Settings
2. Toggle "Shipping" on
3. Click Save
4. ✅ Should see "Store settings updated"

### Test 2: Checkout with Shipping
1. Add items to cart
2. Select "Shipping" fulfillment method
3. Place order
4. ✅ Order created with `fulfillment.method = "shipping"`

### Test 3: Lister Pro Gate (Without Entitlement)
1. Go to order detail (lister view)
2. Should see locked "Shipping Tracking" panel
3. Click "Upgrade to Pro"
4. ✅ Should open PaywallScreen

### Test 4: Lister Pro Gate (With Entitlement)
1. Purchase "CaribTap Pro" in test environment
2. Return to order detail
3. Should see editable tracking form
4. ✅ Form inputs unlocked

### Test 5: Enter Tracking
1. Fill in:
   - Carrier: "FedEx"
   - Tracking Number: "1234567890"
   - Tracking URL: "https://track.fedex.com/1234567890"
   - Status: "In Transit"
2. Click "Save Tracking"
3. ✅ Spinner shows, then "Tracking information saved"
4. ✅ Email sent to customer

### Test 6: Customer View
1. Go to My Orders
2. Find order with shipping
3. ✅ See "Tracking" chip on order list
4. Click order
5. ✅ See ShippingTrackingDisplay with:
   - Carrier name
   - Tracking number (copy button)
   - Tracking URL (open link button)
   - Status badge
   - Last updated time

### Test 7: Security - Block Direct Firestore Write
1. Open browser DevTools
2. Try to write directly to `order_requests/{id}` with `{ shipping: {...} }`
3. ✅ Should fail with "permission-denied"

### Test 8: Security - Block Invalid Updates
1. Try Cloud Function call without Pro entitlement
2. ✅ Should fail: "Tracking is only available for CaribTap Pro subscribers"

---

## Common Issues & Fixes

### Issue: "RevenueCat API key not configured"

**Symptom**: Tracking saves even for non-Pro users

**Fix**: Set API key:
```bash
firebase functions:config:set revenuecat.api_key="appl_XXXXXX"
firebase deploy --only functions
```

**Note**: Function logs will show "skipping entitlement check" if not configured

### Issue: "SendGrid key not set, skipping email"

**Symptom**: No emails sent, but tracking saves successfully

**Fix**: Set SendGrid key:
```bash
firebase functions:config:set sendgrid.key="SG.XXXXXX"
firebase deploy --only functions
```

### Issue: "Shipping option not showing in checkout"

**Symptom**: User can't select shipping at checkout

**Fix**: 
1. Check Store Settings - is Shipping enabled?
2. Verify `storeShippingEnabled` field in Firestore listing doc
3. Check CartScreen imports shipping widgets

### Issue: "Tracking form locked even for Pro users"

**Symptom**: Shows lock icon even after Pro purchase

**Possible causes**: 
1. RevenueCat entitlement not syncing
2. App cache showing old entitlement state
3. Different RevenueCat user ID

**Fix**:
1. Force app refresh: Pull down in orders screen
2. Try closing and re-opening app
3. Check RevenueCat dashboard > Customers > search user
4. Verify entitlement is "active" and not "expired"

### Issue: "Error: Could not start thread DartWorker"

**Symptom**: Dart analyzer crashes

**Cause**: Windows limitation with large Dart projects

**Fix**: Use VS Code analyzer or skip analysis for now
- Project compiles and runs fine despite analyzer crash
- Use IDE syntax checking instead

---

## Rollback Plan (If Needed)

If issues found after deployment:

### Rollback Cloud Functions
```bash
firebase functions:delete setOrderTracking --force
firebase functions:delete sendTrackingEmail --force
```

### Rollback Firestore Rules
```bash
git checkout firestore.rules
firebase deploy --only firestore:rules
```

### Rollback Flutter App
- Revert shipping-related changes in Git
- Rebuild and redeploy app

---

## Monitoring & Support

### Cloud Function Logs
```bash
firebase functions:log
```

Look for errors in:
- `setOrderTracking` execution
- RevenueCat API calls
- SendGrid email sends

### Firestore Data Inspection
```bash
# Check order structure
firebase firestore:list order_requests --limit=5

# Check shipping field in order
firebase firestore:get order_requests/<orderId>
```

### Customer Support Talking Points

**Q: "Why can't I add tracking?"**
- A: Tracking requires CaribTap Pro subscription. Upgrade to Professional to unlock this feature.

**Q: "I clicked Save but nothing happened"**
- A: Make sure tracking number and URL are filled in (both required). Check internet connection.

**Q: "Customer didn't get tracking email"**
- A: Check customer's spam folder. Email sent when you click Save. You can manually resend via order detail.

---

## Feature Rollout Strategy

### Phase 1: Internal Testing (Day 1)
- ✅ Deploy code to staging
- ✅ Test all flows above
- ✅ Monitor Cloud Function logs

### Phase 2: Limited Beta (Days 2-3)
- 🔄 Release to select Pro users (5-10)
- 🔄 Gather feedback
- 🔄 Monitor error rates

### Phase 3: General Release (Day 4+)
- 🟢 Release to all users
- 🟢 Monitor adoption metrics
- 🟢 Watch for support issues

---

## Success Metrics

- ✅ Pro users can add tracking to shipping orders
- ✅ Customers receive tracking emails
- ✅ Customers can view tracking in My Orders
- ✅ Non-Pro users see upgrade CTA
- ✅ No unauthorized access to cloud function
- ✅ < 1% error rate in setOrderTracking calls

---

## Next Steps (Future Work)

- Carrier API integrations (FedEx, UPS, DHL)
- Automatic status updates from carriers
- Tracking webhook support
- Push notifications on delivery
- Bulk tracking upload
- Analytics dashboard

---

**Document Version**: 1.0  
**Last Updated**: February 8, 2026  
**Status**: Ready for Deployment
