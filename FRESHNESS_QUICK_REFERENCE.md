# Enhanced Freshness System - Quick Reference

**Last Updated:** February 27, 2026

---

## 🎯 System Overview

**Goal:** Reward active listers with auto-refresh while maintaining listing quality

**Key Philosophy:** Reduce friction for good actors, not add barriers

---

## 📦 Components at a Glance

### Models
| File | Purpose | Key Classes |
|------|---------|-------------|
| `listing_activity.dart` | Track engagement | `ListingActivity`, `ListingActivityScore`, `ListingAutoRefresh` |

### Configuration
| File | Purpose | Key Values |
|------|---------|------------|
| `category_freshness_config.dart` | Category periods | 7-180 days by category |

### Services
| File | Purpose | Key Methods |
|------|---------|-------------|
| `listing_activity_service.dart` | Activity tracking | `recordActivity()`, `calculateActivityScore()`, `qualifiesForAutoRefresh()` |

### UI Widgets
| File | Purpose | Key Widgets |
|------|---------|-------------|
| `freshness_indicators.dart` | Visual status | `FreshnessStatusBadge`, `FreshnessProgressBar`, `ActivityLevelBadge` |
| `listing_refresh_dialogs.dart` | Refresh actions | `ListingRefreshDialog`, `QuickRefreshDialog`, `BulkRefreshDialog` |

### Screens
| File | Purpose |
|------|---------|
| `listing_freshness_dashboard.dart` | Complete management dashboard |

### Cloud Functions
| Function | Schedule | Purpose |
|----------|----------|---------|
| `processActivityAutoRefresh` | Every 12 hours | Auto-refresh engaged listings |
| `bulkRefreshListings` | Callable | Batch refresh multiple listings |

---

## 🔢 Activity Point Values

| Activity Type | Points | Notes |
|---------------|--------|-------|
| Booking | 10 | Highest engagement |
| Review | 5 | Quality feedback |
| Message | 3 | Customer inquiry |
| Share | 2 | Viral reach |
| Save/Favorite | 1 | Interest signal |
| View | 0 | Tracked but not scored |

---

## ⚡ Auto-Refresh Thresholds

Listing qualifies for auto-refresh if **ANY** of these conditions are met:

```
✅ 30-day activity score ≥ 20 points
   OR
✅ 7-day activity score ≥ 15 points
   OR
✅ 3+ bookings in last 30 days
   OR
✅ 2+ reviews AND 5+ messages
```

**Example qualifying scenarios:**
- 2 bookings + 1 review = 10+10+5 = 25 points ✅
- 3 bookings = auto-qualifies ✅
- 4 reviews + 2 messages = 20+6 = 26 points ✅
- 10 saves + 5 messages = 10+15 = 25 points ✅

---

## 📅 Category-Based Freshness Periods

| Category | Days | Rationale |
|----------|------|-----------|
| daily_specials | 7 | Very time-sensitive |
| flash_deals, limited_offers | 7 | Short-term promotions |
| events, concerts | 14 | Event-specific |
| seasonal_items | 14 | Season changes |
| deals, promotions | 30 | Monthly campaigns |
| restaurants, services | 90 | Standard (original) |
| classes, tours | 90 | Regular offerings |
| real_estate, rentals | 120 | Longer-term listings |
| professionals | 180 | Most stable |

**Development Mode:** All categories = 1 day (for testing)

---

## 🎨 Freshness Status Colors

| Status | Color | Days Remaining | Badge |
|--------|-------|----------------|-------|
| Expired | Red | ≤ 0 | 🔴 EXPIRED |
| Critical | Red | 1-1 | 🔴 1 DAY LEFT |
| Urgent | Orange | 2-10 | 🟠 X DAYS |
| Warning | Amber | 11-30 | 🟡 X DAYS |
| Fresh | Green | >30 | 🟢 FRESH |
| Exempt | Blue | ∞ | 🔵 NEVER EXPIRES |
| Hidden | Grey | N/A | ⚫ HIDDEN |

---

## 🚀 Quick Code Snippets

### Record Customer Activity

```dart
final service = ListingActivityService();

// Booking
await service.recordBooking(listingId, customerId);

// Review
await service.recordReview(listingId, customerId, 4.5);

// Message
await service.recordMessage(listingId, customerId);

// Save
await service.recordSave(listingId, customerId);

// Share
await service.recordShare(listingId, customerId, 'whatsapp');
```

### Check Activity Score

```dart
final score = await service.getActivityScore(listingId);
print('30-day score: ${score?.score30Days}');
print('Qualifies: ${score?.qualifiesForAutoRefresh}');
print('Activity level: ${score?.activityLevel}'); // LOW, MEDIUM, HIGH
```

### Show Freshness Badge

```dart
FreshnessStatusBadge(
  listing: listing,
  compact: true, // Small badge for cards
)
```

### Show Progress Bar

```dart
FreshnessProgressBar(
  listing: listing,
  showDays: true, // Show "X days left"
)
```

### Show Activity Badge

```dart
ActivityLevelBadge(
  activityLevel: 'HIGH',
  score: 45,
  compact: false,
)
```

### Show Freshness Info Card

```dart
FreshnessInfoCard(
  listing: listing,
  onRefresh: () => _refreshListing(),
)
```

### Open Refresh Dialog

```dart
final result = await showDialog<bool>(
  context: context,
  builder: (context) => ListingRefreshDialog(
    listing: listing,
    requireVerification: false, // Optional
  ),
);

if (result == true) {
  // Listing refreshed
}
```

### Quick Refresh (no verification)

```dart
final result = await showDialog<bool>(
  context: context,
  builder: (context) => QuickRefreshDialog(listing: listing),
);
```

### Bulk Refresh

```dart
final result = await showDialog<bool>(
  context: context,
  builder: (context) => BulkRefreshDialog(
    listings: selectedListings,
    showVerification: true,
  ),
);
```

### Open Dashboard

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ListingFreshnessDashboard(
      listings: myListings,
      onRefreshListing: _refreshSingle,
      onRefreshMultiple: _refreshBulk,
    ),
  ),
);
```

---

## 🔄 Cloud Function Integration

### Call Refresh Function

```dart
final functions = FirebaseFunctions.instance;

// Single refresh
await functions.httpsCallable('refreshListingFreshness').call({
  'listingId': listingId,
  'verified': true,
  'checklist': {
    'price': true,
    'availability': true,
    'contact': true,
    'photos': true,
    'details': true,
  },
});

// Bulk refresh
final result = await functions.httpsCallable('bulkRefreshListings').call({
  'listingIds': [listingId1, listingId2, listingId3],
});

print('Successful: ${result.data['successful']}');
print('Failed: ${result.data['failed']}');
```

### Manually Trigger Auto-Refresh (Testing)

```bash
# Using Firebase CLI
firebase functions:shell

# In shell
processActivityAutoRefresh()
```

---

## 📊 Database Paths

### Activity Record
```
listings/{listingId}/activities/{activityId}
```

### Activity Score (Cached)
```
listings/{listingId}/metadata/activity_score
```

### Auto-Refresh Records
```
listings/{listingId}/auto_refreshes/{refreshId}
```

### Listing Freshness Data
```
listings/{listingId}/freshness
```

---

## 📱 UI Integration Points

### Listing Card
```dart
// Add freshness badge
if (listing.freshness?.enabled == true)
  FreshnessStatusBadge(listing: listing, compact: true)
```

### Listing Detail Screen
```dart
// Add freshness info card
if (isOwner && listing.freshness?.enabled == true)
  FreshnessInfoCard(listing: listing, onRefresh: _refresh)
```

### Lister Menu
```dart
// Add dashboard link
ListTile(
  leading: Icon(Icons.schedule),
  title: Text('Listing Freshness'),
  onTap: _openDashboard,
)
```

### My Listings Screen
```dart
// Add bulk refresh button
if (urgentListings.isNotEmpty)
  FloatingActionButton(
    child: Icon(Icons.refresh),
    onPressed: () => _bulkRefresh(urgentListings),
  )
```

---

## ⚙️ Configuration Options

### Adjust Auto-Refresh Schedule

Edit `functions/src/listing_freshness.ts`:
```typescript
export const processActivityAutoRefresh = functions.pubsub
  .schedule("every 6 hours") // Change from 12 hours
  .onRun(async () => { ... });
```

### Adjust Activity Thresholds

```typescript
// In processActivityAutoRefresh function
if (
  activityScore.score30Days >= 15 ||  // Lower from 20
  activityScore.score7Days >= 10 ||   // Lower from 15
  activityScore.totalBookings >= 2    // Lower from 3
) {
  // Auto-refresh
}
```

### Change Activity Point Values

Edit `lib/listings/model/listing_activity.dart`:
```dart
static int getValueForType(String type) {
  const values = {
    'booking': 15,  // Increase from 10
    'review': 8,    // Increase from 5
    'message': 5,   // Increase from 3
    'share': 3,     // Increase from 2
    'save': 2,      // Increase from 1
  };
  return values[type] ?? 0;
}
```

### Make Verification Required

```dart
ListingRefreshDialog(
  listing: listing,
  requireVerification: true, // Change from false
)
```

### Add New Category Period

Edit `lib/listings/config/category_freshness_config.dart`:
```dart
static const Map<String, int> periods = {
  // ... existing categories
  'your_category': 45, // Add new category
};
```

---

## 🐛 Debugging Commands

### Check Activity Data

```bash
# View activities for a listing
firebase firestore:get listings/LISTING_ID/activities
```

### Check Activity Score

```bash
# View cached score
firebase firestore:get listings/LISTING_ID/metadata/activity_score
```

### View Auto-Refresh Records

```bash
# View refresh history
firebase firestore:get listings/LISTING_ID/auto_refreshes
```

### Check Cloud Function Logs

```bash
# All logs
firebase functions:log

# Specific function
firebase functions:log --only processActivityAutoRefresh

# Follow in real-time
firebase functions:log --tail
```

### Test Activity Recording

```dart
// In Flutter DevTools console
await ListingActivityService().recordBooking('listingId', 'userId');
```

---

## 📈 Analytics Events

Track these events:

```dart
// Listing refreshed
analytics.logEvent(name: 'listing_refreshed', parameters: {
  'method': 'manual|auto',
  'verified': true|false,
});

// Dashboard opened
analytics.logEvent(name: 'freshness_dashboard_opened', parameters: {
  'urgent_count': 5,
});

// Bulk refresh
analytics.logEvent(name: 'bulk_refresh', parameters: {
  'count': 3,
});

// Auto-refresh triggered
analytics.logEvent(name: 'auto_refresh_triggered', parameters: {
  'activity_score': 45,
  'listing_id': 'abc123',
});
```

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Activities appear in Firestore under `listings/{id}/activities`
2. ✅ Activity scores are calculated and cached
3. ✅ Auto-refresh function runs without errors
4. ✅ High-engagement listings are auto-refreshed
5. ✅ Notifications are sent to listers
6. ✅ Dashboard shows correct categorization
7. ✅ Bulk refresh updates multiple listings
8. ✅ Category-based periods are applied

---

## 🚨 Common Pitfalls

### ❌ Don't Do This

```dart
// Don't calculate score on every read
final score = await calculateActivityScore(listingId); // Slow!

// Don't record lister actions as customer activity
await recordMessage(listingId, listerOwnerId); // Wrong!

// Don't bypass verification tracking
await refreshListing(listingId); // Missing verification data
```

### ✅ Do This Instead

```dart
// Use cached score
final score = await getActivityScore(listingId); // Fast!

// Only record customer → lister messages
if (senderId != listingOwnerId) {
  await recordMessage(listingId, senderId); // Correct!
}

// Track verification
await functions.httpsCallable('refreshListingFreshness').call({
  'listingId': listingId,
  'verified': isVerified,
  'checklist': checklist,
});
```

---

## 📞 Support Checklist

When troubleshooting:

- [ ] Check cloud function logs
- [ ] Verify Firestore security rules
- [ ] Confirm activities are being recorded
- [ ] Check activity scores are calculating
- [ ] Verify category periods are correct
- [ ] Test in staging environment first
- [ ] Check notification delivery
- [ ] Verify user permissions

---

## 📚 Related Documentation

- [ENHANCED_FRESHNESS_IMPLEMENTATION.md](ENHANCED_FRESHNESS_IMPLEMENTATION.md) - Full feature docs
- [FRESHNESS_INTEGRATION_GUIDE.md](FRESHNESS_INTEGRATION_GUIDE.md) - Step-by-step integration
- [LISTING_FRESHNESS_ASSESSMENT.md](LISTING_FRESHNESS_ASSESSMENT.md) - Original analysis

---

**Status:** ✅ Production Ready  
**Version:** 1.0.0  
**Breaking Changes:** None
