# Per-User Photo Enhancement Quotas

## Overview

Every user gets monthly quotas for the photo enhancement feature:
- **10 Enhancements per month** - Full quality enhanced images
- **10 Previews per month** - Free preview generation before approving

## Usage Display

### Compact Format (For lists/headers)
```
Enhancements: 1/10 | Previews: 3/10
Reset: 3/1 (March 1st)
```

### Full Format (For detail screens)
Shows two cards side-by-side:
- **Enhancements**: Icon + count + progress bar
- **Previews**: Icon + count + progress bar

## Color Indicators

- **Green**: > 5 remaining
- **Orange**: 2-5 remaining  
- **Red**: 0-1 remaining (quota nearly exhausted)

## Where to Display

### 1. Edit Listing Screen
Add near the top of the photo section:
```dart
UsageCounterWidget(
  quota: userQuota,
  compact: true, // Shows: "Enhancements: 1/10 | Previews: 3/10"
)
```

### 2. Photo Enhancement Bottom Sheet
Add header before the image selector:
```dart
BlocBuilder<PhotoEnhancementCubit, PhotoEnhancementState>(
  builder: (context, state) {
    if (state is ComparisonView && state.userQuota != null) {
      return CompactUsageCounterWidget(quota: state.userQuota!);
    }
    return SizedBox.shrink();
  },
)
```

### 3. Enhancement Comparison View
Add above the approve/reject buttons:
```dart
UsageCounterWidget(
  quota: comparison State.userQuota ?? defaultQuota,
  compact: false, // Shows detailed cards
)
```

## Quota Reset Logic

- Resets monthly on the **1st of each month at 00:00 UTC**
- Display: `getScheduleInfo()` returns "{month}/{day}" format
- If quota exhausted: Show "Quota exhausted. Try again {month}/{day}"

## Usage Tracking

### Preview Usage (Free)
Tracked when:
- User selects product image
- Cloud Function returns preview result
- `incrementPreviewUsage(userId)` called automatically

### Enhancement Usage (Paid)
Tracked when:
- User approves preview and requests full quality
- Full quality image processed
- `incrementEnhancementUsage(userId)` called automatically

## Implementation in Screens

### Add to Photo Selection Screen
```dart
BlocListener<PhotoEnhancementCubit, PhotoEnhancementState>(
  listener: (context, state) {
    if (state is QuotaExhausted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.message ?? 'Monthly quota exhausted'),
        backgroundColor: Colors.red,
      ));
    }
  },
),
```

### Add Warnings Before Enhancement
```dart
if (userQuota.getRemainingPreviewQuota() < 2) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Limited Previews'),
      content: Text('You have ${userQuota.getRemainingPreviewQuota()} previews left'),
      actions: [
        TextButton(
          onPressed: Navigator.pop,
          child: Text('OK'),
        ),
      ],
    ),
  );
}
```

## Firestore Rules

Add to your Firestore security rules to protect quota updates:

```javascript
match /user_enhancement_quotas/{userId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId && 
    is_valid_quota_update(request.data);
}

function is_valid_quota_update(data) {
  return data.enhancementsUsed <= 10 &&
         data.previewsUsed <= 10 &&
         data.enhancementsUsed >= 0 &&
         data.previewsUsed >= 0;
}
```

## Testing

### Reset User Quota (Testing Only)
```dart
final userQuotaManager = UserQuotaManager();
await userQuotaManager.resetQuota('userId123');
```

### Check Current Quotas
```dart
final userQuota = await userQuotaManager.getQuota(userId);
print(userQuota.getQuotaStatusString());
// Output: "Enhancements: 1/10 | Previews: 3/10"
```

### Simulate Quota Exhaustion (Testing)
```dart
for (int i = 0; i < 10; i++) {
  await userQuotaManager.incrementPreviewUsage(userId);
}
// Now preview quota is exhausted
```

## User Messaging

### When Quota Available
"You have **3 previews** left this month"

### When Quota Low (2 or less)
"⚠️ Limited previews! Only **1** preview left"

### When Quota Exhausted
"❌ Monthly quota exhausted. Try again on **March 1st**"

### After Enhancement
"✅ Enhancement saved! ({used}/{limit} previews used)"

## Database

Collection: `user_enhancement_quotas`
Document ID: `{userId}`

Fields:
```json
{
  "userId": "user123",
  "year": 2026,
  "month": 1,  // 0-indexed (0 = January)
  "enhancementsUsed": 1,
  "previewsUsed": 3,
  "monthResetDate": "2026-03-01T00:00:00Z",
  "lastEnhancementAt": "2026-02-18T10:30:00Z",
  "lastPreviewAt": "2026-02-18T10:15:00Z"
}
```

## Future Enhancements

1. **Upgrade Path**: Link to premium plan when quota exhausted
2. **Quota Rollover**: Add unlimited enhancements for paid tiers
3. **Usage Analytics**: Track which products get enhanced most
4. **Smart Scheduling**: Suggest best times to use previews
