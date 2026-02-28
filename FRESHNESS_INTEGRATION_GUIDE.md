# Quick Integration Guide - Enhanced Freshness System

**Purpose:** Step-by-step guide to integrate the new freshness features into your existing app

---

## ✅ Integration Checklist

### Phase 1: Backend Setup (30 minutes)
- [ ] Deploy cloud functions
- [ ] Test auto-refresh function manually
- [ ] Verify activity tracking writes work
- [ ] Update Firestore security rules

### Phase 2: Activity Tracking Integration (2 hours)
- [ ] Import `ListingActivityService` in booking flow
- [ ] Record bookings
- [ ] Record reviews
- [ ] Record messages
- [ ] Record saves/shares
- [ ] Test activity recording

### Phase 3: UI Integration (3 hours)
- [ ] Add freshness indicators to listing cards
- [ ] Add dashboard to lister menu
- [ ] Update listing detail screens
- [ ] Add bulk refresh option
- [ ] Test all UI components

### Phase 4: Testing (2 hours)
- [ ] Test auto-refresh workflow
- [ ] Test verification dialog
- [ ] Test bulk refresh
- [ ] Test dashboard filtering
- [ ] Test category-based periods

### Phase 5: Analytics & Monitoring (1 hour)
- [ ] Set up cloud function monitoring
- [ ] Add analytics events
- [ ] Create admin dashboard view
- [ ] Test notification delivery

---

## 📝 Step-by-Step Integration

### Step 1: Deploy Cloud Functions

```bash
# Navigate to functions directory
cd functions

# Install dependencies (if needed)
npm install

# Deploy specific functions
firebase deploy --only functions:processActivityAutoRefresh
firebase deploy --only functions:bulkRefreshListings

# Or deploy all functions
firebase deploy --only functions
```

**Verify deployment:**
- Go to Firebase Console → Functions
- Look for `processActivityAutoRefresh` and `bulkRefreshListings`
- Check that they're deployed and enabled

---

### Step 2: Update Firestore Security Rules

Add rules for activity tracking:

```javascript
// In firestore.rules
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Existing listing rules...
    match /listings/{listingId} {
      // ... existing rules
      
      // Activity tracking - customers can write, owners can read
      match /activities/{activityId} {
        allow read: if request.auth != null && 
          (resource.data.customerId == request.auth.uid || 
           get(/databases/$(database)/documents/listings/$(listingId)).data.authorID == request.auth.uid);
        
        allow write: if request.auth != null && 
          request.resource.data.customerId == request.auth.uid;
      }
      
      // Activity score - computed, read-only for users
      match /metadata/activity_score {
        allow read: if request.auth != null && 
          get(/databases/$(database)/documents/listings/$(listingId)).data.authorID == request.auth.uid;
        
        allow write: if false; // Only cloud functions can write
      }
      
      // Auto-refresh records - read-only for owners
      match /auto_refreshes/{refreshId} {
        allow read: if request.auth != null && 
          get(/databases/$(database)/documents/listings/$(listingId)).data.authorID == request.auth.uid;
        
        allow write: if false; // Only cloud functions can write
      }
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

### Step 3: Integrate Activity Tracking

#### A. Booking Flow

Find your booking confirmation code and add:

```dart
import 'package:caribtap/listings/services/listing_activity_service.dart';

// After successful booking
Future<void> _confirmBooking(Booking booking) async {
  // ... existing booking logic
  
  // Record activity
  final activityService = ListingActivityService();
  await activityService.recordBooking(
    booking.listingId,
    booking.customerId,
  );
  
  // ... rest of code
}
```

#### B. Review Submission

Find your review submission code and add:

```dart
import 'package:caribtap/listings/services/listing_activity_service.dart';

// After review is submitted
Future<void> _submitReview(Review review) async {
  // ... existing review logic
  
  // Record activity
  final activityService = ListingActivityService();
  await activityService.recordReview(
    review.listingId,
    review.customerId,
    review.rating,
  );
  
  // ... rest of code
}
```

#### C. Messaging

Find your message sending code and add:

```dart
import 'package:caribtap/listings/services/listing_activity_service.dart';

// After message is sent
Future<void> _sendMessage(Message message) async {
  // ... existing messaging logic
  
  // Record activity (only for customer → lister messages)
  if (message.senderId != listingOwnerId) {
    final activityService = ListingActivityService();
    await activityService.recordMessage(
      message.listingId,
      message.senderId,
    );
  }
  
  // ... rest of code
}
```

#### D. Save/Favorite

Find your favorite/save functionality and add:

```dart
import 'package:caribtap/listings/services/listing_activity_service.dart';

// When user saves a listing
Future<void> _saveListing(String listingId) async {
  // ... existing save logic
  
  // Record activity
  final activityService = ListingActivityService();
  await activityService.recordSave(
    listingId,
    currentUserId,
  );
  
  // ... rest of code
}
```

#### E. Share

Find your share functionality and add:

```dart
import 'package:caribtap/listings/services/listing_activity_service.dart';

// When user shares a listing
Future<void> _shareListing(String listingId, String platform) async {
  // ... existing share logic
  
  // Record activity
  final activityService = ListingActivityService();
  await activityService.recordShare(
    listingId,
    currentUserId,
    platform, // 'whatsapp', 'facebook', 'twitter', etc.
  );
  
  // ... rest of code
}
```

---

### Step 4: Add Freshness Indicators to Listing Cards

Update your listing card widget:

```dart
import 'package:caribtap/listings/widgets/freshness_indicators.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // ... existing card content
          
          // Add freshness indicator
          if (listing.freshness?.enabled == true)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  FreshnessStatusBadge(listing: listing, compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FreshnessProgressBar(listing: listing),
                  ),
                ],
              ),
            ),
          
          // ... rest of card
        ],
      ),
    );
  }
}
```

---

### Step 5: Add Dashboard to Navigation

Add to your lister's main menu:

```dart
import 'package:caribtap/listings/screens/listing_freshness_dashboard.dart';

// In your drawer or navigation menu
ListTile(
  leading: Icon(Icons.schedule_outlined),
  title: Text('Listing Freshness'),
  subtitle: Text('Manage your active listings'),
  trailing: _hasUrgentListings 
    ? Badge(
        label: Text('${_urgentCount}'),
        backgroundColor: Colors.red,
      )
    : null,
  onTap: () => _openFreshnessDashboard(),
)

// Handler method
void _openFreshnessDashboard() async {
  // Load lister's listings
  final listings = await _loadMyListings();
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ListingFreshnessDashboard(
        listings: listings,
        onRefreshListing: (listing) => _refreshSingleListing(listing),
        onRefreshMultiple: (listings) => _refreshMultipleListings(listings),
      ),
    ),
  );
}

// Refresh handlers
Future<void> _refreshSingleListing(ListingModel listing) async {
  final functions = FirebaseFunctions.instance;
  await functions.httpsCallable('refreshListingFreshness').call({
    'listingId': listing.id,
  });
  
  // Reload listing
  setState(() {
    // Update listing in state
  });
}

Future<void> _refreshMultipleListings(List<ListingModel> listings) async {
  final functions = FirebaseFunctions.instance;
  await functions.httpsCallable('bulkRefreshListings').call({
    'listingIds': listings.map((l) => l.id).toList(),
  });
  
  // Reload listings
  setState(() {
    // Update listings in state
  });
}
```

---

### Step 6: Update Listing Detail Screen

Add more detailed freshness info:

```dart
import 'package:caribtap/listings/widgets/freshness_indicators.dart';
import 'package:caribtap/listings/widgets/listing_refresh_dialogs.dart';

class ListingDetailScreen extends StatelessWidget {
  final ListingModel listing;
  final bool isOwner;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing scaffold
      body: Column(
        children: [
          // ... existing content
          
          // Add freshness info card for owner
          if (isOwner && listing.freshness?.enabled == true)
            FreshnessInfoCard(
              listing: listing,
              onRefresh: () => _showRefreshDialog(context),
            ),
          
          // ... rest of content
        ],
      ),
    );
  }
  
  Future<void> _showRefreshDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ListingRefreshDialog(
        listing: listing,
        requireVerification: false, // Optional verification
      ),
    );
    
    if (result == true) {
      // Listing was refreshed, reload it
      setState(() {
        // Update listing
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listing refreshed successfully!')),
      );
    }
  }
}
```

---

### Step 7: Add Bulk Refresh to "My Listings" Screen

```dart
import 'package:caribtap/listings/widgets/listing_refresh_dialogs.dart';

class MyListingsScreen extends StatefulWidget {
  // ... existing code
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<ListingModel> _selectedListings = [];
  bool _selectionMode = false;
  
  @override
  Widget build(BuildContext context) {
    final urgentListings = _listings.where((l) => 
      l.freshness?.enabled == true && 
      l.daysUntilExpiration != null && 
      l.daysUntilExpiration! <= 10
    ).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode 
          ? '${_selectedListings.length} selected' 
          : 'My Listings'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedListings.clear();
              }),
            ),
          if (!_selectionMode && urgentListings.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${urgentListings.length}'),
                child: Icon(Icons.refresh),
              ),
              tooltip: 'Refresh urgent listings',
              onPressed: () => _bulkRefreshUrgent(urgentListings),
            ),
        ],
      ),
      body: ListView.builder(
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          final listing = _listings[index];
          final isSelected = _selectedListings.contains(listing);
          
          return ListTile(
            leading: _selectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (value) => _toggleSelection(listing),
                )
              : null,
            title: Text(listing.title),
            subtitle: listing.freshness?.enabled == true
              ? FreshnessStatusBadge(listing: listing)
              : null,
            onLongPress: () => _toggleSelectionMode(listing),
            onTap: _selectionMode 
              ? () => _toggleSelection(listing)
              : () => _viewListing(listing),
          );
        },
      ),
      floatingActionButton: _selectionMode && _selectedListings.isNotEmpty
        ? FloatingActionButton.extended(
            icon: Icon(Icons.refresh),
            label: Text('Refresh ${_selectedListings.length}'),
            onPressed: () => _bulkRefreshSelected(),
          )
        : null,
    );
  }
  
  void _toggleSelectionMode(ListingModel listing) {
    setState(() {
      _selectionMode = true;
      _selectedListings = [listing];
    });
  }
  
  void _toggleSelection(ListingModel listing) {
    setState(() {
      if (_selectedListings.contains(listing)) {
        _selectedListings.remove(listing);
        if (_selectedListings.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedListings.add(listing);
      }
    });
  }
  
  Future<void> _bulkRefreshSelected() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BulkRefreshDialog(
        listings: _selectedListings,
        showVerification: true,
      ),
    );
    
    if (result == true) {
      setState(() {
        _selectionMode = false;
        _selectedListings.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listings refreshed successfully!')),
      );
    }
  }
  
  Future<void> _bulkRefreshUrgent(List<ListingModel> urgentListings) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BulkRefreshDialog(
        listings: urgentListings,
        showVerification: false,
      ),
    );
    
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${urgentListings.length} urgent listings refreshed!'),
        ),
      );
    }
  }
}
```

---

### Step 8: Test Activity Recording

Create a test script:

```dart
// test/activity_tracking_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:caribtap/listings/services/listing_activity_service.dart';

void main() {
  final service = ListingActivityService();
  const testListingId = 'test_listing_123';
  const testCustomerId = 'test_customer_456';
  
  test('Record booking activity', () async {
    await service.recordBooking(testListingId, testCustomerId);
    
    // Verify activity was recorded
    final score = await service.getActivityScore(testListingId);
    expect(score, isNotNull);
    expect(score!.totalBookings, greaterThan(0));
  });
  
  test('Calculate activity score', () async {
    // Record multiple activities
    await service.recordBooking(testListingId, testCustomerId);
    await service.recordReview(testListingId, testCustomerId, 4.5);
    await service.recordMessage(testListingId, testCustomerId);
    
    // Calculate score
    final score = await service.calculateActivityScore(testListingId);
    
    expect(score.score30Days, greaterThanOrEqualTo(18)); // 10 + 5 + 3
    expect(score.totalBookings, equals(1));
    expect(score.totalReviews, equals(1));
    expect(score.totalMessages, equals(1));
  });
  
  test('Check auto-refresh eligibility', () async {
    // Record enough activity to qualify
    for (int i = 0; i < 3; i++) {
      await service.recordBooking(testListingId, 'customer_$i');
    }
    
    final qualifies = await service.qualifiesForAutoRefresh(testListingId);
    expect(qualifies, isTrue);
  });
}
```

Run tests:
```bash
flutter test test/activity_tracking_test.dart
```

---

### Step 9: Monitor Auto-Refresh Function

Check cloud function logs:

```bash
# View all functions logs
firebase functions:log

# View specific function
firebase functions:log --only processActivityAutoRefresh

# Follow logs in real-time
firebase functions:log --only processActivityAutoRefresh --tail
```

Look for:
- `Processing listing for auto-refresh: {listingId}`
- `Auto-refreshed {count} listings`
- Any error messages

---

### Step 10: Add Analytics Events

Track freshness-related actions:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// When listing is manually refreshed
await analytics.logEvent(
  name: 'listing_refreshed',
  parameters: {
    'listing_id': listing.id,
    'method': 'manual',
    'verified': isVerified,
    'days_remaining': listing.daysUntilExpiration,
  },
);

// When listing is auto-refreshed (in cloud function)
await analytics.logEvent(
  name: 'listing_refreshed',
  parameters: {
    'listing_id': listing.id,
    'method': 'auto',
    'activity_score': activityScore,
    'reason': 'customer_engagement',
  },
);

// When opening freshness dashboard
await analytics.logEvent(
  name: 'freshness_dashboard_opened',
  parameters: {
    'urgent_count': urgentListings.length,
    'total_count': allListings.length,
  },
);

// When bulk refresh performed
await analytics.logEvent(
  name: 'bulk_refresh',
  parameters: {
    'listing_count': listings.length,
    'verified': wasVerified,
  },
);
```

---

## 🧪 Testing Checklist

### Manual Testing

#### Test 1: Record Activities
- [ ] Book a listing → Check activity recorded in Firestore
- [ ] Review a listing → Check activity recorded
- [ ] Message a lister → Check activity recorded
- [ ] Save a listing → Check activity recorded
- [ ] Share a listing → Check activity recorded

#### Test 2: Activity Scores
- [ ] Record 3+ activities → Check score is calculated
- [ ] Verify 30-day score is correct
- [ ] Verify activity breakdown is accurate
- [ ] Check `qualifiesForAutoRefresh` flag

#### Test 3: Auto-Refresh
- [ ] Create test listing with high activity
- [ ] Manually trigger cloud function (or wait for schedule)
- [ ] Verify listing was auto-refreshed
- [ ] Check notification was sent
- [ ] Verify auto-refresh record created

#### Test 4: Dashboard
- [ ] Open dashboard → See all listings categorized
- [ ] Check urgent listings appear in red
- [ ] Verify activity badges show correctly
- [ ] Test filtering by status
- [ ] Check bulk select mode

#### Test 5: Refresh Dialogs
- [ ] Test verification dialog → All checkboxes work
- [ ] Test quick refresh → No verification required
- [ ] Test bulk refresh → Multiple listings updated
- [ ] Verify success messages appear

#### Test 6: Category Periods
- [ ] Create listings in different categories
- [ ] Verify each has correct freshness period
- [ ] Check warnings appear at correct times

---

## 🚨 Common Issues & Solutions

### Issue: Activities not recording
**Solution:**
1. Check Firestore rules allow writes
2. Verify user is authenticated
3. Check network connectivity
4. Look for errors in console

### Issue: Auto-refresh not working
**Solution:**
1. Verify cloud function is deployed
2. Check function logs for errors
3. Confirm activity score meets thresholds
4. Ensure listing isn't exempt

### Issue: Dashboard shows wrong counts
**Solution:**
1. Refresh listings data
2. Clear cached data
3. Check freshness calculation logic
4. Verify timestamp parsing

### Issue: Notifications not sending
**Solution:**
1. Check SendGrid API key is set
2. Verify FCM tokens are valid
3. Check notification preferences
4. Look for errors in function logs

---

## 📊 Expected Timeline

**Total Integration Time:** ~8 hours

| Phase | Duration | Critical Path |
|-------|----------|---------------|
| Backend Setup | 30 min | Yes |
| Activity Tracking | 2 hours | Yes |
| UI Integration | 3 hours | No |
| Testing | 2 hours | Yes |
| Monitoring Setup | 30 min | No |

**Parallel Work Opportunities:**
- UI integration can happen while testing activity tracking
- Monitoring setup can happen anytime after deployment

---

## ✅ Success Criteria

You'll know integration is complete when:

1. ✅ Activities are being recorded for all customer actions
2. ✅ Activity scores are calculated and cached
3. ✅ Auto-refresh function runs every 12 hours without errors
4. ✅ Dashboard shows correct listing categorization
5. ✅ Bulk refresh works for multiple listings
6. ✅ Notifications are sent when listings are auto-refreshed
7. ✅ Verification dialogs appear and save data
8. ✅ Category-based periods are applied correctly

---

## 📚 Additional Resources

- [ENHANCED_FRESHNESS_IMPLEMENTATION.md](ENHANCED_FRESHNESS_IMPLEMENTATION.md) - Complete feature documentation
- [LISTING_FRESHNESS_ASSESSMENT.md](LISTING_FRESHNESS_ASSESSMENT.md) - Original analysis
- Firebase Console - Monitor functions and database
- Analytics Dashboard - Track usage metrics

---

**Last Updated:** February 27, 2026  
**Status:** Ready for Integration  
**Breaking Changes:** None
