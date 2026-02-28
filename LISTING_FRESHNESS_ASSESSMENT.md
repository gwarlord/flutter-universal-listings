# Listing Freshness Mechanism Assessment

**Date:** February 27, 2026  
**Assessment Type:** Listing Visibility Management System Review

## Executive Summary

Your CaribTap app has a **robust automatic listing freshness system** that requires listers to actively maintain their listings to keep them visible. The system is well-designed with multiple notification stages, but there are opportunities to enhance lister engagement and prevent listings from becoming stale.

---

## Current Mechanism Overview

### How It Works

**Automatic Expiration System:**
1. **Default Lifespan:** Listings automatically hide after **90 days** (1 day in dev mode)
2. **Countdown Tracking:** Each listing has a `hideAt` timestamp calculated from creation/last refresh
3. **Warning System:** Listers receive notifications at:
   - **10 days** before expiration
   - **1 day** before expiration
   - **Upon expiration** (when listing is hidden)
4. **Automated Process:** Cloud Function runs **every 6 hours** to:
   - Send warning notifications
   - Hide expired listings
   - Backfill missing freshness data

### Key Components

#### 1. **Cloud Function** (`functions/src/listing_freshness.ts`)
```typescript
// Runs every 6 hours
export const processListingFreshness = functions.pubsub
  .schedule("every 6 hours")
  .onRun(async () => {
    await backfillMissingFreshness(now);
    await sendFreshnessWarnings(now, "10d");  // 10-day warnings
    await sendFreshnessWarnings(now, "1d");   // 1-day warnings
    await hideExpiredListings(now);           // Hide expired
  });
```

#### 2. **Listing Data Model** (`lib/listings/model/listing_model.dart`)
```dart
class ListingFreshness {
  final bool enabled;              // Can be disabled per listing
  final int days;                  // Days until expiration (default 90)
  final Timestamp lastRefreshedAt; // Last refresh time
  final Timestamp hideAt;          // When it will be hidden
  final String status;             // ACTIVE, HIDDEN_EXPIRED
  final bool exempt;               // Exemption from auto-hide
  final Timestamp? warn10SentAt;   // 10-day warning sent
  final Timestamp? warn1SentAt;    // 1-day warning sent
  final Timestamp? hiddenNotifiedAt; // Hidden notification sent
}
```

#### 3. **Manual Refresh Function**
```typescript
// Listers can manually reset their listing freshness
export const refreshListingFreshness = functions.https.onCall(
  async (data, context) => {
    // Resets lastRefreshedAt to now
    // Recalculates hideAt (now + 90 days)
    // Clears all warning timestamps
    // Sets listing to visible
  }
);
```

---

## Exemption System (3 Levels)

The system supports three types of exemptions from auto-hide:

### 1. **Listing-Level Exemption**
```dart
listing.freshness.exempt = true  // Individual listing exempt
```

### 2. **Lister-Level Exemption**
```dart
user.listingFreshnessExempt = true  // All user's listings exempt
```

### 3. **Brand-Level Exemption** (For Multi-Location Brands)
```dart
brand.freshnessExempt = true  // All brand locations exempt
```

**Priority:** Listing → Lister → Brand → Age Check

---

## Strengths of Current System

### ✅ **1. Multi-Channel Communication**
- **Email notifications** via SendGrid
- **Push notifications** via Firebase Cloud Messaging
- **In-app notifications** (status field updates)

### ✅ **2. Progressive Warning System**
- Two advance warnings (10 days, 1 day)
- Clear notification about actual hiding
- Prevents sudden surprises for listers

### ✅ **3. Automated & Reliable**
- Scheduled cloud function (every 6 hours)
- Transaction-based updates (prevents race conditions)
- Error logging and retry mechanisms

### ✅ **4. Flexible Exemption System**
- Multiple exemption levels
- Admin can exempt specific listers or brands
- Individual listings can be marked exempt

### ✅ **5. Self-Service Refresh**
- Listers can manually refresh anytime
- Simple one-click action
- Immediate reactivation of hidden listings

### ✅ **6. Proper Data Tracking**
```typescript
{
  warn10SentAt: timestamp,      // Track notification delivery
  warn1SentAt: timestamp,
  hiddenNotifiedAt: timestamp,
  lastNotifyError: string,      // Error tracking
  lastNotifyErrorAt: timestamp
}
```

---

## Weaknesses & Opportunities for Improvement

### ⚠️ **1. Passive Engagement Model**

**Current:** Listers only need to click "Refresh" to keep listings active
**Issue:** No verification that listing info is still current/accurate

**Impact:**
- Listers can keep outdated info visible
- No incentive to update prices, availability, or details
- Gaming the system by just clicking refresh

**Recommendation:**
Require listers to actively verify listing accuracy during refresh.

---

### ⚠️ **2. No Content Update Requirement**

**Current:** Refresh just resets the timer
**Issue:** Listings can remain visible without any changes

**Recommendation:**
Implement a "verification checklist" or minor update requirement.

---

### ⚠️ **3. Limited Lister Accountability**

**Current:** System assumes listers will respond to notifications
**Issue:** No penalties for repeatedly ignoring warnings

**Recommendation:**
Track lister responsiveness and adjust behavior accordingly.

---

### ⚠️ **4. Single Freshness Period**

**Current:** All listings use same 90-day period
**Issue:** Different listing types may need different lifespans

Examples:
- **Rentals/Real Estate:** Longer freshness (120 days)
- **Limited-Time Deals:** Shorter freshness (30 days)
- **Seasonal Businesses:** Variable freshness

**Recommendation:**
Category-based freshness periods.

---

### ⚠️ **5. No Activity-Based Freshness**

**Current:** Only time-based expiration
**Issue:** Popular, active listings still expire

**Recommendation:**
Auto-refresh listings with recent customer engagement:
- Recent bookings
- Recent reviews
- Recent messages/inquiries

---

## Recommended Enhancements

### 🎯 **Priority 1: Active Verification Requirement**

Instead of just "Refresh," require listers to verify listing accuracy:

```dart
// New refresh flow
class ListingRefreshDialog extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Keep Listing Active'),
      content: Column(
        children: [
          Text('To keep this listing visible, please confirm:'),
          CheckboxListTile(
            title: Text('Price is still accurate'),
            value: priceVerified,
            onChanged: (val) => setState(() => priceVerified = val ?? false),
          ),
          CheckboxListTile(
            title: Text('Availability is current'),
            value: availabilityVerified,
            onChanged: (val) => setState(() => availabilityVerified = val ?? false),
          ),
          CheckboxListTile(
            title: Text('Contact info is correct'),
            value: contactVerified,
            onChanged: (val) => setState(() => contactVerified = val ?? false),
          ),
          CheckboxListTile(
            title: Text('Photos are up to date'),
            value: photosVerified,
            onChanged: (val) => setState(() => photosVerified = val ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: Text('Confirm & Refresh'),
          onPressed: allChecked ? () => _refreshListing() : null,
        ),
      ],
    );
  }
}
```

**Benefits:**
- Forces listers to review listing content
- Creates psychological commitment to accuracy
- Documents verification in listing history
- Reduces outdated information

---

### 🎯 **Priority 2: Minor Update Requirement**

Require at least one small update to refresh:

**Options:**
1. **Add a new photo**
2. **Update description (min 10 chars changed)**
3. **Update price/availability**
4. **Respond to pending messages**
5. **Add/update business hours**

**Implementation:**
```typescript
// Cloud Function
export const refreshListingWithUpdate = functions.https.onCall(
  async (data, context) => {
    const { listingId, updateType, updateData } = data;
    
    // Validate that actual content changed
    const changes = await validateUpdateQuality(listingId, updateData);
    
    if (!changes.isSignificant) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Please make a meaningful update to refresh your listing'
      );
    }
    
    // Log the update type
    await logRefreshActivity({
      listingId,
      updateType,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Refresh listing
    await refreshListingFreshness(listingId);
    
    return { success: true };
  }
);
```

---

### 🎯 **Priority 3: Activity-Based Auto-Refresh**

Auto-refresh listings with recent customer engagement:

```typescript
// Trigger on customer activity
export const onCustomerEngagement = functions.firestore
  .document('interactions/{interactionId}')
  .onCreate(async (snapshot) => {
    const interaction = snapshot.data();
    const listingId = interaction.listingId;
    
    // Types: 'booking', 'review', 'message', 'save', 'share'
    const activityValue = getActivityValue(interaction.type);
    
    // Auto-refresh if enough recent activity
    const recentActivity = await getRecentActivityScore(listingId, 30); // 30 days
    
    if (recentActivity >= ACTIVITY_THRESHOLD) {
      await autoRefreshListing(listingId, 'customer_engagement');
      await notifyLister({
        listingId,
        message: 'Your listing was auto-refreshed due to customer activity!'
      });
    }
  });

function getActivityValue(type: string): number {
  const values = {
    booking: 10,
    review: 5,
    message: 3,
    save: 1,
    share: 2
  };
  return values[type] || 0;
}
```

**Benefits:**
- Rewards active, engaging listings
- Keeps popular content visible
- Reduces manual work for successful listers
- Natural quality signal

---

### 🎯 **Priority 4: Category-Based Freshness Periods**

Different listing types need different lifespans:

```dart
class CategoryFreshnessConfig {
  static const Map<String, int> periods = {
    // Short-term
    'deals': 30,
    'events': 14,
    'flash_sales': 7,
    
    // Standard
    'services': 90,
    'products': 90,
    'restaurants': 90,
    
    // Long-term
    'real_estate': 120,
    'rentals': 120,
    'professionals': 180,
  };
  
  static int getDaysForCategory(String category) {
    return periods[category] ?? 90; // Default to 90
  }
}

// In onCreate listing trigger
final freshnessDays = CategoryFreshnessConfig.getDaysForCategory(
  listing.category
);
```

---

### 🎯 **Priority 5: Graduated Warning System**

Escalate communication based on lister behavior:

```typescript
interface ListerRefreshBehavior {
  totalRefreshes: number;
  missedWarnings: number;
  autoHiddenCount: number;
  lastRefreshDate: Date;
  averageRefreshInterval: number; // days
}

async function sendWarningWithEscalation(
  listing: any,
  type: '10d' | '1d',
  behavior: ListerRefreshBehavior
) {
  let urgency = 'normal';
  
  if (behavior.missedWarnings >= 2) {
    urgency = 'critical';
  } else if (behavior.autoHiddenCount >= 1) {
    urgency = 'high';
  }
  
  const message = buildEscalatedMessage(type, urgency, behavior);
  
  await sendNotification({
    urgency,
    message,
    includeWhatsApp: urgency === 'critical', // Extra channel
    includeSMS: urgency === 'critical'
  });
}
```

---

### 🎯 **Priority 6: Lister Dashboard with Freshness Status**

Visual dashboard showing all listings and their freshness:

```dart
class ListerDashboard extends StatelessWidget {
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Urgent: Expiring soon
        _buildSection(
          'Urgent Attention',
          listings.where((l) => l.freshness.daysRemaining! <= 10),
          Colors.red,
          'These listings will hide soon. Take action now!',
        ),
        
        // Warning: Expiring this month
        _buildSection(
          'Needs Refresh Soon',
          listings.where((l) => 
            l.freshness.daysRemaining! > 10 && 
            l.freshness.daysRemaining! <= 30
          ),
          Colors.orange,
          'Plan to refresh these listings soon.',
        ),
        
        // Good: Fresh listings
        _buildSection(
          'Active & Fresh',
          listings.where((l) => l.freshness.daysRemaining! > 30),
          Colors.green,
          'These listings are in good standing.',
        ),
        
        // Hidden: Need reactivation
        _buildSection(
          'Hidden Listings',
          listings.where((l) => l.hidden),
          Colors.grey,
          'Refresh to make these visible again.',
        ),
      ],
    );
  }
  
  Widget _buildSection(
    String title,
    Iterable<ListingModel> listings,
    Color color,
    String description,
  ) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.circle, color: color),
            title: Text(title),
            subtitle: Text(description),
            trailing: Chip(label: Text('${listings.length}')),
          ),
          ...listings.map((listing) => ListingFreshnessCard(
            listing: listing,
            onRefresh: () => _refreshListing(listing),
          )),
        ],
      ),
    );
  }
}
```

---

## Implementation Priority

### Phase 1 (Quick Wins - 1-2 Days)
1. ✅ Add visual freshness indicators to lister dashboard
2. ✅ Show days remaining on listing cards
3. ✅ Add bulk refresh action for multiple listings

### Phase 2 (Medium Effort - 1 Week)
4. ✅ Implement verification checklist for refresh
5. ✅ Add category-based freshness periods
6. ✅ Create lister freshness dashboard

### Phase 3 (Advanced Features - 2 Weeks)
7. ✅ Activity-based auto-refresh system
8. ✅ Minor update requirement for refresh
9. ✅ Graduated warning escalation
10. ✅ Analytics dashboard for admin monitoring

---

## Conclusion

### Current State: **GOOD** ✅
Your existing freshness system is well-architected with:
- Reliable automation
- Multi-channel notifications
- Flexible exemption system
- Self-service lister controls

### Opportunity: **SIGNIFICANT** 🎯
By adding verification requirements and activity-based logic, you can:
- **Increase data quality** - Force listers to review content
- **Reward engagement** - Auto-refresh popular listings
- **Reduce gaming** - Prevent mindless "refresh clicking"
- **Improve user trust** - Ensure visible listings are current

### Verdict
**The mechanism works, but it's too easy to game.** Listers currently just click "refresh" without verifying accuracy. Implementing verification checklists and activity-based auto-refresh will significantly improve listing quality while maintaining a fair system for active, engaged listers.

---

## Next Steps

1. **Review this assessment** with your team
2. **Prioritize enhancements** based on your goals
3. **Implement Phase 1** (quick wins) first
4. **Test with real listers** and gather feedback
5. **Iterate** based on lister behavior patterns

Would you like me to implement any of these recommendations?
