# Tap Feature - Quick Start Guide

## What Was Implemented

The **Tap (Community Vouching)** feature has been fully implemented. Users can now vouch for businesses they trust, creating a community-driven verification system independent of reviews and bookings.

## Files Created

### Models & Constants
- `lib/listings/model/tap_model.dart` - Tap data model and enums
- `lib/listings/constants/tap_constants.dart` - Constants and thresholds

### Repository & Service Layer
- `lib/listings/listings_module/api/tap_repository.dart` - Repository interface
- `lib/listings/listings_module/api/firebase/tap_firebase.dart` - Firebase implementation
- `lib/listings/services/tap_service.dart` - Business logic and validation

### Cloud Functions
- `functions/src/tap_functions.ts` - Automated tap count management
  - `onTapCreated` - Increment count on new tap
  - `onTapDeleted` - Decrement count on tap removal
  - `recomputeAllTapCounts` - Admin maintenance function

### UI Components
- `lib/listings/ui/widgets/tap_widgets.dart` - Reusable tap widgets
  - `TapButton` - Interactive tap/untap button
  - `TapBadgeWidget` - Community verification badge
  - `TapCountDisplay` - Compact tap count display
  - `TapReasonDialog` - Reason selection dialog

### Documentation & Tools
- `TAP_FEATURE_IMPLEMENTATION.md` - Comprehensive implementation guide
- `tools/migrate_tap_fields.js` - Database migration script

## Files Modified

### Data Models
- `lib/listings/model/listing_model.dart` - Added `tapCount` and `tapBadge` fields

### Security & Infrastructure
- `firestore.rules` - Added tap subcollection rules and protection
- `functions/src/index.ts` - Exported new tap functions

### UI Integration
- `lib/listings/listings_module/listing_details/listing_details_screen.dart` - Integrated tap UI

## Deployment Steps

### 1. Run Database Migration
```bash
cd tools
node migrate_tap_fields.js
```

### 2. Deploy Cloud Functions
```bash
cd functions
npm install
npm run build
firebase deploy --only functions:onTapCreated,functions:onTapDeleted,functions:recomputeAllTapCounts
```

### 3. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 4. Build & Test Flutter App
```bash
flutter clean
flutter pub get
flutter run  # Test locally first
```

### 5. Deploy to Production
```bash
flutter build appbundle  # Android
flutter build ios        # iOS
```

## Key Features

✅ **One tap per user per listing** - Toggle behavior (tap/untap)
✅ **Eligibility validation** - Cannot tap own listings, requires verified email or 10+ min account age
✅ **Community badges** - Automated badges at 10 and 50 taps
✅ **Optional tap reasons** - USED_SERVICE, KNOW_PERSONALLY, SEEN_THEIR_WORK
✅ **Spam prevention** - 5-second cooldown between actions
✅ **Cloud Functions** - Automatic count management, no client-side manipulation
✅ **Security rules** - Proper Firestore rules prevent abuse
✅ **Optimistic UI** - Instant feedback with rollback on errors
✅ **Animated buttons** - Smooth, engaging user experience

## Community Verification Levels

| Tap Count | Badge | Display |
|-----------|-------|---------|
| 0-9 | None | No badge shown |
| 10-49 | Community Vouched | Blue badge with check icon |
| 50+ | Community Verified | Green badge with verified icon |

## Testing Checklist

Before production deployment, verify:

- [ ] New listing shows tapCount: 0, tapBadge: 'none'
- [ ] User can tap a listing (not their own)
- [ ] Tap count increments correctly
- [ ] User can untap a listing
- [ ] Tap count decrements correctly
- [ ] Badge appears at 10 taps ("Community Vouched")
- [ ] Badge upgrades at 50 taps ("Community Verified")
- [ ] Cannot tap own listing (error message shown)
- [ ] Email verification check works
- [ ] Spam prevention works (5-sec cooldown)
- [ ] Reason dialog appears and works
- [ ] UI updates optimistically
- [ ] Network errors show proper messages

## Usage Examples

### For Users
1. Open any listing detail page
2. Look for "Tap to Vouch" button (only shown if not your own listing)
3. Click button → Optional reason dialog appears
4. Select reason (or skip) → Tap is created
5. Button changes to "Untap" → Click again to remove tap

### For Admins
To recompute all tap counts if data becomes inconsistent:
```bash
firebase functions:call recomputeAllTapCounts
```

## Architecture Highlights

### Data Flow
```
User Tap Action
    ↓
TapService (validation)
    ↓
TapRepository (create/delete tap document)
    ↓
Cloud Function Trigger (onTapCreated/onTapDeleted)
    ↓
Update listing.tapCount & listing.tapBadge
    ↓
UI reflects changes via Firestore stream
```

### Security Layers
1. **Client-side validation** - TapService checks eligibility
2. **Firestore rules** - Server-side enforcement
3. **Cloud Functions** - Manage counts (not client-editable)
4. **Rate limiting** - Prevent spam

## Cost Estimate

For 1000 active users, each tapping 5 listings per month:
- **Firestore**: ~$0.30/month (reads + writes)
- **Cloud Functions**: ~$0.10/month (invocations)
- **Total**: ~$0.40/month

Well within Firebase free tier for initial usage.

## Support

For detailed information, see:
- **Implementation Guide**: `TAP_FEATURE_IMPLEMENTATION.md`
- **Code Documentation**: Inline comments in source files
- **Firestore Rules**: `firestore.rules` (lines for taps subcollection)
- **Cloud Functions**: `functions/src/tap_functions.ts`

---

**Status**: ✅ Ready for production deployment

**Last Updated**: February 1, 2026
