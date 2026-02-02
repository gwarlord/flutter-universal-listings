# Tap (Community Vouching) Feature - Implementation Guide

## Overview
The "Tap" feature allows users to vouch for the credibility of businesses/listings without needing to book or leave a review. A Tap means "I know this business / they are legit" and contributes to community-driven trust indicators.

## Core Concepts

### What is a Tap?
- **Purpose**: Community verification/vouching for listings
- **Meaning**: "I know this business / they are legit"
- **Not a Review**: Taps don't require completed transactions
- **Public**: All taps are visible on listing cards and details

### Community Verification Levels
Taps contribute to automated trust badges:
- **≥10 taps** → "Community Vouched" (blue badge)
- **≥50 taps** → "Community Verified" (green badge)
- Admin/platform verification remains separate and independent

## Implementation Details

### 1. Data Schema

#### Firestore Structure
```
listings/{listingId}
  ├── tapCount: int (managed by Cloud Functions)
  ├── tapBadge: string ('none' | 'community_vouched' | 'community_verified')
  └── taps/{userId}
      ├── userId: string
      ├── listingId: string
      ├── createdAt: timestamp
      └── reason: string (optional: 'USED_SERVICE' | 'KNOW_PERSONALLY' | 'SEEN_THEIR_WORK')
```

#### ListingModel Fields (Added)
```dart
int tapCount;        // Number of taps (default: 0)
String tapBadge;     // Badge level (default: 'none')
```

### 2. Business Rules

#### Eligibility
✅ **Can Tap:**
- Authenticated users
- Email verified OR account age > 10 minutes
- NOT the listing author

❌ **Cannot Tap:**
- Unauthenticated users
- Own listings
- New unverified accounts (< 10 min old)

#### Rate Limiting
- Minimum 5 seconds between tap/untap actions (spam prevention)
- One tap per user per listing (toggle behavior)

#### Optional Tap Reasons
Users can optionally select a reason when tapping:
- `USED_SERVICE` - "Used their service"
- `KNOW_PERSONALLY` - "Know them personally"
- `SEEN_THEIR_WORK` - "Seen their work"

### 3. Security Rules

**Firestore Rules** (already implemented in `firestore.rules`):
```javascript
match /listings/{listingId}/taps/{userId} {
  // Anyone can read taps (public)
  allow read: if true;
  
  // Users can create their own tap
  allow create: if isSignedIn() && 
                  request.auth.uid == userId && 
                  request.auth.uid != get(/databases/$(database)/documents/listings/$(listingId)).data.authorID;
  
  // Users can delete only their own tap
  allow delete: if isSignedIn() && request.auth.uid == userId;
  
  // No updates allowed
  allow update: if false;
}
```

**Important**: `tapCount` and `tapBadge` fields are protected from client-side modification:
```javascript
// In listings update rule
(!request.resource.data.diff(resource.data).affectedKeys().hasAny(['tapCount', 'tapBadge']) || isAdmin())
```

### 4. Cloud Functions

Three Cloud Functions manage tap counts automatically:

#### `onTapCreated`
- **Trigger**: `listings/{listingId}/taps/{userId}` onCreate
- **Action**: Increments `tapCount`, recomputes `tapBadge`
- **Transaction**: Ensures atomic updates

#### `onTapDeleted`
- **Trigger**: `listings/{listingId}/taps/{userId}` onDelete
- **Action**: Decrements `tapCount`, recomputes `tapBadge`
- **Safety**: Prevents negative counts

#### `recomputeAllTapCounts` (Admin/Maintenance)
- **Type**: Callable HTTPS function
- **Purpose**: Recompute all tap counts if data becomes out of sync
- **Auth**: Requires admin token
- **Usage**: 
  ```bash
  firebase functions:call recomputeAllTapCounts
  ```

**Deploy Functions:**
```bash
cd functions
npm install
npm run build
firebase deploy --only functions:onTapCreated,functions:onTapDeleted,functions:recomputeAllTapCounts
```

### 5. Flutter Implementation

#### Service Layer
- **`TapService`**: Business logic, validation, eligibility checks
- **`TapRepository`**: Abstract interface
- **`TapFirebase`**: Firebase implementation

#### UI Components
- **`TapButton`**: Interactive tap/untap button with animation
- **`TapBadgeWidget`**: Display community verification badge
- **`TapCountDisplay`**: Compact tap count (for listing cards)
- **`TapReasonDialog`**: Optional reason selection dialog

#### Integration Points
1. **Listing Details Screen**: Main tap button and badge display
2. **Listing Cards** (Future): Add `TapCountDisplay` widget
3. **Search/Filters** (Future): Filter by tap thresholds

### 6. User Experience

#### Tap Flow
1. User clicks "Tap to Vouch" button
2. Optional dialog: Select reason (or skip)
3. Optimistic UI update
4. Cloud Function increments count in background
5. Success/error feedback via SnackBar

#### Untap Flow
1. User clicks "Untap" button
2. Immediate optimistic UI update
3. Cloud Function decrements count
4. Confirmation message

#### Error Handling
- Network errors: Show user-friendly message, rollback UI
- Validation errors: Clear explanation (e.g., "You cannot tap your own listing")
- Rate limiting: "Please wait a moment before tapping again"

## Migration & Deployment

### Step 1: Database Migration
Add tap fields to existing listings:

**Option A: Firebase Console**
1. Go to Firestore → `listings` collection
2. Bulk update all documents:
   - Add field: `tapCount` = 0
   - Add field: `tapBadge` = "none"

**Option B: Migration Script** (Recommended)
```javascript
// Run in Firebase Functions or Admin SDK
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function migrateTapFields() {
  const listings = await db.collection('listings').get();
  const batch = db.batch();
  
  listings.docs.forEach(doc => {
    batch.update(doc.ref, {
      tapCount: 0,
      tapBadge: 'none'
    });
  });
  
  await batch.commit();
  console.log(`Migrated ${listings.size} listings`);
}

migrateTapFields().catch(console.error);
```

### Step 2: Deploy Cloud Functions
```bash
cd functions
npm run build
firebase deploy --only functions:onTapCreated,functions:onTapDeleted,functions:recomputeAllTapCounts
```

### Step 3: Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### Step 4: Flutter App Build & Release
```bash
flutter clean
flutter pub get
flutter build appbundle  # Android
flutter build ios        # iOS
```

### Step 5: Testing Checklist
- [ ] User can tap a listing (not their own)
- [ ] User can untap a listing
- [ ] Tap count increments/decrements correctly
- [ ] Badge updates at 10 and 50 taps
- [ ] Cannot tap own listing (error message shown)
- [ ] New users (<10 min) without verified email cannot tap
- [ ] Spam prevention works (5 sec delay)
- [ ] Reason selection dialog works
- [ ] UI updates optimistically
- [ ] Network errors handled gracefully

## Future Enhancements

### Phase 2 (Optional)
1. **Weighted Taps**: Premium users' taps count more
2. **Tap Insights**: Show who tapped (for listing owners)
3. **Tap Notifications**: Notify listing owners of new taps
4. **Tap Leaderboard**: Showcase most-tapped listings
5. **Abuse Detection**: ML-based spam/fake tap detection
6. **Tap Reasons Analytics**: Aggregated statistics on tap reasons

### Phase 3 (Advanced)
1. **Reverse Taps**: Allow users to "flag" suspicious listings
2. **Tap Quality Score**: Weight taps by user reputation
3. **Geo-filtering**: Only allow taps from same region
4. **Tap Decay**: Older taps count less over time

## Troubleshooting

### Issue: Tap counts out of sync
**Solution**: Run maintenance function
```bash
firebase functions:call recomputeAllTapCounts
```

### Issue: Cloud Functions not triggering
**Check**:
1. Functions deployed: `firebase functions:list`
2. Function logs: `firebase functions:log`
3. Firestore permissions for service account

### Issue: Users can't tap
**Common causes**:
1. Email not verified (if account < 10 min old)
2. Trying to tap own listing
3. Rate limit (< 5 sec since last action)
4. Network error

## Cost Implications

### Firestore
- **Reads**: ~1 read per tap (check existing tap)
- **Writes**: 2 writes per tap (tap doc + listing update via function)
- **Deletes**: 2 writes per untap

### Cloud Functions
- **Invocations**: 2 per tap/untap event
- **Compute time**: <100ms per function
- **Cost**: Minimal (within free tier for most usage)

### Estimated Monthly Costs (1000 active users, avg 5 taps/month)
- Firestore: ~$0.10-0.50
- Functions: ~$0.05-0.20
- **Total**: <$1/month

## Support & Maintenance

### Regular Maintenance
- Weekly: Monitor tap counts and badge distribution
- Monthly: Check for spam patterns
- Quarterly: Review and adjust thresholds if needed

### Monitoring
```bash
# View function logs
firebase functions:log --only onTapCreated,onTapDeleted

# Check Firestore usage
# Go to Firebase Console → Usage & Billing
```

---

## Summary

The Tap feature is now fully implemented with:
✅ Data models and constants
✅ Repository and service layer
✅ Cloud Functions for count management
✅ Firestore security rules
✅ Updated Listing model
✅ Complete UI components
✅ Integration in listing details screen

**Ready for production deployment!**

For questions or issues, refer to the codebase documentation or contact the development team.
