# Chat Toggle Feature - Implementation Guide

**Date:** January 20, 2026  
**Status:** ✅ Complete

---

## Overview

The chat feature now supports **listing-level control**, allowing sellers to enable/disable chat on individual listings. This gives sellers granular control over customer communication.

---

## Changes Made

### 1. **ListingModel Updates** 
**File:** [lib/listings/model/listing_model.dart](lib/listings/model/listing_model.dart)

Added new property:
```dart
/// Chat
bool chatEnabled;  // Defaults to true for all listings
```

**Included in:**
- Constructor (default: `true`)
- `factory ListingModel.fromJson()` (default: `true`)
- `Map<String, dynamic> toJson()`
- `copyWith()` method

**Impact:** All existing listings will default to chat enabled (backward compatible).

---

### 2. **Booking Services Screen**
**File:** [lib/listings/listings_module/booking_services/booking_services_screen.dart](lib/listings/listings_module/booking_services/booking_services_screen.dart#L157-L167)

Added new toggle in the premium section:

```dart
// Enable Chat Toggle
_buildToggleTile(
  title: 'Enable Chat'.tr(),
  subtitle: 'Allow customers to message you directly'.tr(),
  value: listing.chatEnabled ?? true,
  onChanged: _isUpdating ? null : (value) {
    final updated = listing.copyWith(chatEnabled: value);
    _updateListing(updated);
    setState(() {
      _listings = _listings.map((l) => l.id == listing.id ? updated : l).toList();
    });
  },
  dark: dark,
),
```

**Location:** Right after "Require Booking" toggle  
**Position:** Premium → Booking Services

---

### 3. **Listing Details - Message Seller Button**
**File:** [lib/listings/listings_module/listing_details/listing_details_screen.dart](lib/listings/listings_module/listing_details/listing_details_screen.dart#L770-L807)

Updated button logic to check listing chat status:

**Before:**
```dart
// Checked if current user has Premium subscription
currentUser.hasDirectMessaging
```

**After:**
```dart
// Checks if listing has chat enabled AND user has Premium subscription
listing.chatEnabled  // Shows button if enabled
currentUser.hasDirectMessaging  // Requires Premium to actually send
```

**Button States:**
- ✅ **Enabled** (chat enabled on listing + user is Premium): Blue button, "Message Seller"
- 🔒 **Disabled** (chat disabled on listing): Gray button, "Chat Disabled", cannot click
- 🔒 **Locked** (chat enabled but user not Premium): Button works, shows upgrade prompt

---

### 4. **Advanced Analytics Dashboard**
**File:** [lib/listings/listings_module/analytics/advanced_analytics_screen.dart](lib/listings/listings_module/analytics/advanced_analytics_screen.dart)

#### Added Chat Statistics

**Metrics Calculation** (lines 105-152):
```dart
// Chat Enabled Count
int chatEnabledCount = listings.where((l) => l.chatEnabled).length;

// Added to metrics map:
'chatEnabledCount': chatEnabledCount,
```

**Display Card** (lines 306-320):
```dart
_buildMetricCard(
  'Chat Enabled',
  '${_advancedMetrics['chatEnabledCount'] ?? 0}/${_advancedMetrics['totalListings'] ?? 0}',
  Icons.chat_bubble,
  Colors.purple,
  dark,
),
```

**Shows:** How many of your listings have chat enabled vs. total

---

## User Experience Flow

### For Sellers

1. **Toggle Chat per Listing**
   - Navigate to Premium → Booking Services
   - Find listing in list
   - Toggle "Enable Chat" on/off
   - Changes saved immediately

2. **See in Analytics**
   - Navigate to Premium → Advanced Analytics
   - View "Chat Enabled" card showing X/Y listings with chat
   - Example: "3/5" means chat enabled on 3 of 5 listings

### For Buyers

1. **See Chat Button**
   - View any listing
   - If chat is enabled: See "Message Seller" button
   - If chat is disabled: See "Chat Disabled" button (grayed out)

2. **Send Message**
   - If Premium: Can message immediately
   - If Free/Professional: See upgrade prompt

---

## Database Schema

### Firestore - listings collection

```json
{
  "id": "listing_123",
  "chatEnabled": true,
  "bookingEnabled": true,
  "title": "Beach House",
  "authorID": "user_456",
  ...
}
```

**Field Type:** `boolean`  
**Default Value:** `true`  
**Nullable:** No

---

## Backward Compatibility

✅ **Fully Backward Compatible**

- All existing listings default to `chatEnabled: true`
- No migration needed
- Old listings without the field will default to `true`
- No UI breaks or errors

---

## Testing Checklist

- [ ] Toggle chat on/off in Booking Services
- [ ] Verify "Message Seller" button appears when chat enabled
- [ ] Verify button grays out when chat disabled
- [ ] Verify button is disabled (no tap) when chat disabled
- [ ] Verify unlock prompt shows when non-Premium user tries to message
- [ ] Verify Advanced Analytics shows correct chat count
- [ ] Verify analytics counts match actual enabled listings
- [ ] Verify changes persist after app restart

---

## API Impact

**None** - All changes are client-side and Firestore field updates.

---

## Security

**Firestore Rules:** No new rules needed
- Chat creation already requires user participation
- Chat access already validated at message level
- This is just a UI-level control

---

## Future Enhancements

1. **Chat Response Time Analytics**
   - Track average response time for sellers with chat enabled
   - Show in Advanced Analytics

2. **Chat Widget**
   - Show last message received notification
   - Unread message counter

3. **Bulk Chat Settings**
   - Enable/disable chat on all listings at once
   - Scheduled chat hours

4. **Chat Insights**
   - Track message volume per listing
   - Most popular listings by message count

---

## Commit Details

**Commit Hash:** `cf0d848`  
**Message:** "Feat: Add listing-level chat toggle control"

**Files Modified:**
1. `lib/listings/model/listing_model.dart`
2. `lib/listings/listings_module/booking_services/booking_services_screen.dart`
3. `lib/listings/listings_module/listing_details/listing_details_screen.dart`
4. `lib/listings/listings_module/analytics/advanced_analytics_screen.dart`

---

## Questions?

- **How do I enable chat on a listing?** Premium → Booking Services → Toggle "Enable Chat"
- **Can free users see the chat button?** Yes, but they'll see an upgrade prompt when clicking
- **Can I enable chat without Premium subscription?** Yes, any user can toggle it
- **Does disabling chat stop existing messages?** No, only prevents new messages
- **Is chat enabled by default?** Yes, all listings default to `chatEnabled: true`
