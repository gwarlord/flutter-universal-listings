# Deployment Verification Checklist

**Deployment Date:** February 27, 2026  
**System:** Enhanced Listing Freshness with Activity Tracking

---

## ✅ Pre-Launch Verification Steps

### Cloud Functions Deployment
- [ ] Go to Firebase Console → Cloud Functions
- [ ] Verify `processActivityAutoRefresh` exists and is enabled
- [ ] Verify `bulkRefreshListings` exists and is enabled
- [ ] Check `processListingFreshness` shows recent executions
- [ ] Check function logs have no critical errors
- [ ] Memory usage appears normal (< 256MB)

### Firestore Rules
- [ ] Go to Firebase Console → Firestore → Rules
- [ ] Verify rules file is deployed and compiled
- [ ] Check activity tracking rules are visible
- [ ] No rule errors in the Rules tab

### Flutter App Compilation
- [ ] Run `flutter analyze` - no errors
- [ ] Run `flutter pub get` - all dependencies resolve
- [ ] Code compiles without warnings specific to freshness features
- [ ] No import errors in modified files

### Database Structure
- [ ] Check `listings/{listingId}/activities` subcollection exists
- [ ] Verify `listings/{listingId}/metadata/activity_score` field structure
- [ ] Confirm `listings/{listingId}/auto_refreshes` subcollection exists

---

## 🧪 Functional Testing

### Test 1: Activity Recording - Booking
**Steps:**
1. Open app and login as test user
2. Browse to a listing
3. Create a booking for that listing
4. Wait 2-3 seconds
5. Go to Firebase Console → Firestore
6. Navigate to `listings/{listingId}/activities`

**Expected Result:**
- [ ] New activity document created with type "booking"
- [ ] customerId matches current user
- [ ] timestamp is recent
- [ ] value = 10

### Test 2: Activity Recording - Review
**Steps:**
1. Login as test user who has made a booking
2. Submit a review (4-5 stars)
3. Navigate to Firestore listings activities

**Expected Result:**
- [ ] New activity document with type "review"
- [ ] customerId matches reviewer
- [ ] Rating is stored correctly

### Test 3: Activity Recording - Message
**Steps:**
1. Login as customer
2. Start a chat with a lister about a listing
3. Send a message
4. Check Firestore

**Expected Result:**
- [ ] Activity created in listings/{listingId}/activities
- [ ] Type = "message"
- [ ] Only customer messages create activities (not lister replies)

### Test 4: Activity Recording - Tap/Save
**Steps:**
1. Login as customer
2. Find a listing
3. Click the tap/vouch button
4. Check Firestore listings activities

**Expected Result:**
- [ ] New activity with type "save"
- [ ] customerId = current user
- [ ] value = 1

### Test 5: Activity Score Calculation
**Steps:**
1. Record 2-3 activities for a test listing
2. Go to `listings/{testListingId}/metadata/activity_score`
3. Manually trigger cloud function (optional)

**Expected Result:**
- [ ] `score30Days` > 0
- [ ] `score7Days` > 0 (if within 7 days)
- [ ] Activity breakdown counts are accurate
- [ ] `activityLevel` = "HIGH", "MEDIUM", or "LOW"

### Test 6: Freshness Badge on Listing Card
**Steps:**
1. Open app to My Listings screen
2. Verify listing cards are displaying

**Expected Result:**
- [ ] Fresh listings show green "FRESH" badge
- [ ] Listings expiring in 2-30 days show amber/orange color
- [ ] Listings expiring in 1-10 days show "X DAYS" text
- [ ] No errors in console

### Test 7: Freshness Dashboard Access
**Steps:**
1. Go to Profile menu
2. Look for "Listing Freshness" option
3. Tap on "Listing Freshness"

**Expected Result:**
- [ ] Dashboard loads successfully
- [ ] All listings are displayed
- [ ] Listings are categorized correctly (Urgent, Warning, Fresh, etc.)
- [ ] Color coding matches status
- [ ] No loading errors

### Test 8: Dashboard Categories
**Steps:**
1. In freshness dashboard
2. Look at listing organization

**Expected Result:**
- [ ] Urgent Attention section (≤10 days) - RED
- [ ] Needs Refresh Soon (11-30 days) - ORANGE
- [ ] Active & Fresh (>30 days) - GREEN
- [ ] Never Expire - BLUE
- [ ] Hidden Listings - GREY

### Test 9: Single Listing Refresh
**Steps:**
1. In My Listings, long-tap a listing
2. Or tap refresh button
3. Complete verification checklist (optional)
4. Confirm refresh

**Expected Result:**
- [ ] Listing hideAt timestamp updated
- [ ] Verification data saved (if provided)
- [ ] Success message shown
- [ ] Dashboard updates to show new expiry

### Test 10: Bulk Refresh
**Steps:**
1. Open Listing Freshness dashboard
2. Select 3-5 urgent listings
3. Click "Refresh X listings"
4. Confirm bulk refresh

**Expected Result:**
- [ ] All selected listings refreshed
- [ ] Each retains appropriate freshness period
- [ ] Success notification shown
- [ ] No individual confirmations needed

### Test 11: Category-Based Periods
**Steps:**
1. Create/view listings in different categories:
   - Daily specials → 7 days
   - Deals → 30 days
   - Restaurants → 90 days
   - Real Estate → 120 days
2. Check freshness.days field in Firestore

**Expected Result:**
- [ ] Each listing has correct days value
- [ ] Matches category configuration
- [ ] Days are applied on creation or refresh

### Test 12: Auto-Refresh Trigger
**Steps:**
1. Create test listing with high engagement
2. Record 3+ bookings OR 2 reviews + 5 messages
3. Go to Firebase Console → Cloud Functions
4. Find `processActivityAutoRefresh`
5. Click "Testing" tab (if available) or wait 12 hours
6. Or run: `firebase functions:shell` → `processActivityAutoRefresh()`

**Expected Result:**
- [ ] Function executes without errors
- [ ] Listing hideAt timestamp updated
- [ ] Auto-refresh record created in auto_refreshes subcollection
- [ ] Notification sent to lister

### Test 13: Notifications
**Steps:**
1. After auto-refresh is triggered
2. Check lister's email or push notifications

**Expected Result:**
- [ ] Email notification received
- [ ] Push notification appears (if enabled)
- [ ] includes activity breakdown
- [ ] Shows new expiration date

### Test 14: Data Integrity
**Steps:**
1. Monitor database for 1-2 hours
2. Check for any activity recording failures
3. Verify no duplicate activities

**Expected Result:**
- [ ] 1 activity record per customer action
- [ ] All timestamps accurate
- [ ] No orphaned or incomplete records
- [ ] No unauthorized access in logs

---

## 📊 Performance Testing

### Test 15: Dashboard Load Time
**Steps:**
1. Measure time to load dashboard
2. With 10, 50, 100+ listings
3. Monitor memory usage

**Expected Result:**
- [ ] Dashboard loads in < 2 seconds (10 listings)
- [ ] Dashboard loads in < 5 seconds (100 listings)
- [ ] No memory leaks on repeated loads
- [ ] Smooth scrolling with many listings

### Test 16: Activity Recording Latency
**Steps:**
1. Record activity and time it
2. Check Firestore confirmation
3. Test with 10 concurrent operations

**Expected Result:**
- [ ] Activity recorded within 2-5 seconds
- [ ] No timing issues with concurrent writes
- [ ] No duplicate records from retries

### Test 17: Auto-Refresh Function Performance
**Steps:**
1. Monitor function execution time
2. Test with 100+ eligible listings
3. Check function logs

**Expected Result:**
- [ ] Completes within timeout (540s)
- [ ] Memory under 256MB
- [ ] No timeouts or errors
- [ ] Execution time < 5 minutes for 1000+ listings

---

## 🔐 Security Testing

### Test 18: Firestore Rule Enforcement
**Steps:**
1. Try to write activity as non-owner
2. Try to modify activity_score directly
3. Try to create auto_refresh as customer

**Expected Result:**
- [ ] ✅ Customer can write own activity
- [ ] ❌ Cannot write another's activity
- [ ] ❌ Cannot modify activity_score
- [ ] ❌ Cannot modify auto_refreshes
- [ ] ✅ Cloud functions can modify (via service account)

### Test 19: Data Privacy
**Steps:**
1. Check activity data is only readable by owner
2. Verify lister can see their listings' activities
3. Verify customer can only see their own activities

**Expected Result:**
- [ ] Lister can read their listing's activities
- [ ] Customer cannot see other customer activities
- [ ] Data is properly scoped

### Test 20: Authentication Requirement
**Steps:**
1. Try to access dashboard without login
2. Try to call bulkRefreshListings without auth token

**Expected Result:**
- [ ] ❌ Cannot access dashboard while logged out
- [ ] ❌ Cloud function requires authentication
- [ ] Proper error messages shown

---

## 📋 Documentation Verification

### Test 21: Documentation Completeness
- [ ] ENHANCED_FRESHNESS_IMPLEMENTATION.md exists and is complete
- [ ] FRESHNESS_INTEGRATION_GUIDE.md has step-by-step instructions
- [ ] FRESHNESS_QUICK_REFERENCE.md has quick lookup tables
- [ ] DEPLOYMENT_SUMMARY.md this document is complete
- [ ] Code has inline comments explaining activity tracking

---

## 🚀 Final Sign-Off

### Code Quality
- [ ] No compilation errors
- [ ] No import warnings
- [ ] Proper null safety throughout
- [ ] No commented-out debug code
- [ ] Consistent code style

### Feature Completeness  
- [ ] All 8 components implemented
- [ ] All integration points working
- [ ] All UI elements functional
- [ ] All cloud functions deployed

### Testing Status
- [ ] Activity recording: PASS
- [ ] Dashboard: PASS
- [ ] Auto-refresh: PASS
- [ ] Notifications: PASS
- [ ] Security rules: PASS
- [ ] Performance: PASS

### Ready for Production: **[ ] YES / [ ] NO**

If NO, list blocking issues:
```
1. 
2.
3.
```

---

## ✅ Handoff Checklist

Before handing off to QA or going live:

- [ ] All tests above have passed
- [ ] No known issues or blockers
- [ ] Documentation reviewed and complete
- [ ] Team aware of new features
- [ ] Marketing/comms plan in place
- [ ] Monitor/alert setup complete
- [ ] Rollback plan documented
- [ ] Support team trained

---

## 📞 Troubleshooting Quick Links

If tests fail, reference these files:

| Issue | Reference |
|-------|-----------|
| Activity not recording | Check app logs + Firestore rules |
| Dashboard not loading | FRESHNESS_INTEGRATION_GUIDE.md line 335 |
| Auto-refresh not working | See TROUBLESHOOTING section |
| Performance issues | QUICK_REFERENCE.md - Configuration |
| UI problems | Check widget imports in my_listings_screen.dart |

---

**Test Date:** _______________  
**Tested By:** _______________  
**QA Approved:** _______________  
**Ready for Production:** **[ ] YES**

---
