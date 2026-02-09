# Quick Integration Guide - Ad Upload Screen

## How to Add Deal Settings to AdUploadScreen

The new `DealSettingsForm` has been created and is ready to integrate. This guide shows you where and how to add it to the existing upload flow.

---

## Option 1: Add as a Separate Step (Recommended)

### 1. Add Import
```dart
import 'package:instaflutter/listings/ui/deals/deal_settings_form.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
```

### 2. Add State Variables to _AdUploadScreenState
```dart
// Add these variables to store deal settings
DateTime? _dealExpireAt;
DateTime? _dealScheduleAt;
String _redemptionType = 'IN_APP_CLAIM';
String? _promoCode;
int? _redemptionLimitTotal;
int? _redemptionLimitPerUser;
```

### 3. Add Button in Form

Find where your form buttons are (typically in build method around the upload/submit area):

```dart
// Add this after media selection, before or after targeting section
OutlinedButton.icon(
  icon: const Icon(Icons.settings),
  label: const Text('Deal Settings'),
  onPressed: () async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DealSettingsForm(
          initialRedemptionType: _redemptionType,
          initialPromoCode: _promoCode,
          initialRedemptionLimitTotal: _redemptionLimitTotal,
          initialRedemptionLimitPerUser: _redemptionLimitPerUser,
          initialExpireAt: _dealExpireAt,
          initialScheduleAt: _dealScheduleAt,
          onSaved: (settings) {
            setState(() {
              _dealExpireAt = settings.expireAt;
              _dealScheduleAt = settings.scheduleAt;
              _redemptionType = settings.redemptionType;
              _promoCode = settings.promoCode;
              _redemptionLimitTotal = settings.redemptionLimitTotal;
              _redemptionLimitPerUser = settings.redemptionLimitPerUser;
            });
          },
        ),
      ),
    );
  },
),
```

### 4. Update DealAdModel Creation

Find where you create the DealAdModel for submission, typically in your save/submit method:

```dart
// When creating the DealAdModel, add these fields:
ad = DealAdModel(
  // ... existing fields ...
  expireAt: _dealExpireAt ?? DateTime.now().add(Duration(days: 30)),
  scheduleAt: _dealScheduleAt,
  redemptionType: _redemptionType,
  promoCode: _promoCode,
  redemptionLimitTotal: _redemptionLimitTotal,
  redemptionLimitPerUser: _redemptionLimitPerUser,
  // ... rest of fields ...
);
```

### 5. (Optional) Show Settings Summary

Add a card to display current settings:

```dart
if (_dealExpireAt != null) ...[
  Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deal Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Expires: ${DateFormat('MMM dd, yyyy').format(_dealExpireAt!)}'),
          Text('Type: $_redemptionType'),
          if (_redemptionLimitTotal != null)
            Text('Limit: $_redemptionLimitTotal'),
        ],
      ),
    ),
  ),
  SizedBox(height: 16),
],
```

---

## Option 2: Add Fields Inline (Less Recommended)

If you prefer to add fields directly to the existing form without creating a separate step:

### 1. Add State Variables (same as Option 1)

### 2. Add Form Fields

Add these TextFields/Dropdowns/DatePickers in the form:

```dart
// Redemption Type Dropdown
DropdownButtonFormField<String>(
  value: _redemptionType,
  items: [
    DropdownMenuItem(value: 'IN_APP_CLAIM', child: Text('In-App Claim')),
    DropdownMenuItem(value: 'PROMO_CODE', child: Text('Promo Code')),
  ],
  onChanged: (value) => setState(() => _redemptionType = value ?? 'IN_APP_CLAIM'),
  decoration: InputDecoration(labelText: 'Redemption Type'),
),

// Promo Code (only show if PROMO_CODE selected)
if (_redemptionType == 'PROMO_CODE')
  TextField(
    decoration: InputDecoration(labelText: 'Promo Code'),
    onChanged: (value) => setState(() => _promoCode = value),
  ),

// Expiry Date Picker
GestureDetector(
  onTap: () async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dealExpireAt = picked);
    }
  },
  child: InputDecorator(
    decoration: InputDecoration(labelText: 'Expires'),
    child: Text(_dealExpireAt != null 
      ? DateFormat('MMM dd, yyyy').format(_dealExpireAt!)
      : 'Select Date'),
  ),
),

// Redemption Limits (with toggles)
CheckboxListTile(
  title: Text('Limit Total Redemptions'),
  value: _redemptionLimitTotal != null,
  onChanged: (value) {
    setState(() {
      _redemptionLimitTotal = value == true ? 100 : null;
    });
  },
),
```

---

## Option 3: Minimal Integration (For Quick Adoption)

If you just want the basic functionality working quickly:

### Add to Upload Method Only:
```dart
// Just before submission, use default values if not set:
ad = DealAdModel(
  // ... existing fields ...
  expireAt: DateTime.now().add(Duration(days: 30)),  // Default 30 days
  redemptionType: 'IN_APP_CLAIM',  // Default claim type
  // ... rest ...
);
```

This requires NO UI changes - all deals will have same expiry. Users can edit via separate management screen later.

---

## Upcoming Features to Link To

Once integrated, also add these in the deals management section:

```dart
// For deal owners - access analytics
IconButton(
  icon: Icon(Icons.analytics),
  onPressed: () => push(context, 
    DealAnalyticsScreen(
      dealId: deal.id,
      currentUser: currentUser,
    )
  ),
),

// For users - quick access to saved
IconButton(
  icon: Icon(Icons.favorite),
  onPressed: () => push(context,
    SavedDealsScreen(currentUser: currentUser)
  ),
),
```

---

## Testing the Integration

### Quick Test Flow:
1. Open Ad Upload
2. Click "Deal Settings" button (or fill fields inline)
3. Set expiry date to tomorrow
4. Select "PROMO_CODE" and enter "TESTCODE123"
5. Submit ad
6. Approve in Admin Panel
7. View on Deal Feed - should see "Ending today" badge
8. Click hearticon to save
9. Go to Profile > Saved Deals - should appear

---

## Common Issues & Solutions

**Issue:** "DealAdModel requires expireAt"
**Solution:** Make sure you're passing `expireAt` when creating DealAdModel

**Issue:** "SavedDealsScreen not found"
**Solution:** Check import path: `lib/listings/ui/deals/saved_deals_screen.dart`

**Issue:** "Need to update existing ads"
**Solution:** No need! Missing fields default to safe values in fromDoc() factory

**Issue:** "Tasks completed but not visible"
**Solution:** Ensure admin approval completes - expired deals are filtered from feeds

---

## Database Schema Changes Needed

### In your ad_upload_screen or admin panel add migration:

```dart
// One-time data migration (optional, for old deals)
Future<void> migrateExistingDeals() async {
  final snapshot = await FirebaseFirestore.instance.collection('deal_ads').get();
  final batch = FirebaseFirestore.instance.batch();
  
  for (var doc in snapshot.docs) {
    if (!doc.data().containsKey('expireAt')) {
      // Add missing fields to old deals
      batch.update(doc.reference, {
        'expireAt': DateTime.now().add(Duration(days: 365)),
        'redemptionType': 'IN_APP_CLAIM',
        'viewCount': 0,
        'saveCount': 0,
        'claimCount': 0,
      });
    }
  }
  
  await batch.commit();
  print('Migration complete');
}
```

---

Done! Your Deal Settings are now integrated. 🎉

