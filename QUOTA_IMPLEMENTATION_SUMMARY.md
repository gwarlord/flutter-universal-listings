# Photo Enhancement Per-User Quotas - Implementation Summary

## ✅ What's Been Completed

### 1. **User Quota Model** (`user_enhancement_quota.dart`)
- Tracks monthly enhancements and previews per user
- 10 enhancements per month limit
- 10 previews per month limit
- Automatic monthly reset on the 1st of each month
- Color-coded remaining quota tracking
- Firestore serialization/deserialization

### 2. **User Quota Manager Service** (`user_quota_manager.dart`)
- Manages Firestore operations for user quotas
- Auto-creates quotas on first use
- Tracks usage with `incrementEnhancementUsage()` and `incrementPreviewUsage()`
- Provides quota checking methods without incrementing
- Monthly reset logic
- Gets usage counts as tuple for easy display

### 3. **Usage Counter Widgets** (`usage_counter_widget.dart`)
Two widget options:

**A) Full View** - `UsageCounterWidget`
- Side-by-side cards with icons
- Progress bars for each quota type
- Color-coded indicators
- Shows reset date
- Best for: Detail screens, comparison views

**B) Compact View** - `CompactUsageCounterWidget`
- Inline format: "Enhancements: 1/10 | Previews: 3/10"
- Minimal space, full information
- Icons for quick identification
- Best for: List headers, action bars

### 4. **PhotoEnhancementCubit Integration**
Updated with:
- `UserQuotaManager` dependency
- Preview quota check before enhancement
- Automatic preview usage tracking
- Automatic enhancement usage tracking on approval
- Passes `userQuota` to ComparisonView state
- Helper methods: `getLastUserQuota()` and `fetchUserQuota()`

### 5. **State Updates**
Updated states to include quota information:
- `QuotaExhausted`: Now supports message and userQuota fields
- `ComparisonView`: Now includes userQuota for display

### 6. **Instantiation Updates**
Updated all cubit instantiation points:
- `add_listing_screen.dart` (both AddListing and EditListing)
- `setup_dependencies.dart`
- `integration_guide.dart`

### 7. **Documentation**
Created comprehensive guides:
- `USER_QUOTAS_GUIDE.md` - User-facing quota documentation
- `QUOTA_IMPLEMENTATION_CHECKLIST.md` - Step-by-step implementation guide

## 🎯 Feature Specs

### Monthly Limits
```
Previews: 10/month (FREE - no API cost)
Enhancements: 10/month (PAID - uses remove.bg API)
```

### Usage Tracking
```
Preview Used: When Cloud Function returns preview
Enhancement Used: When user approves and processes full quality
```

### Display Format
```
Compact: "Enhancements: 1/10 | Previews: 3/10"
Full: Two cards with progress bars and reset date
Color: Green (plenty) → Orange (low) → Red (critical)
```

### Quota Reset
```
Schedule: 1st of each month at 00:00 UTC
Display: "Quota resets on 3/1"
Auto-reset: Handled by manager on getQuota() call
```

## 📦 Deliverables

### New Files Created
1. `lib/listings/ui/photo_enhancement/models/user_enhancement_quota.dart` - Data model
2. `lib/listings/ui/photo_enhancement/services/user_quota_manager.dart` - Service layer
3. `lib/listings/ui/photo_enhancement/widgets/usage_counter_widget.dart` - UI widgets
4. `USER_QUOTAS_GUIDE.md` - Feature guide
5. `QUOTA_IMPLEMENTATION_CHECKLIST.md` - Implementation guide

### Modified Files
1. `photo_enhancement_cubit.dart` - Added UserQuotaManager, tracking logic
2. `photo_enhancement_state.dart` - Updated states with quota fields
3. `add_listing_screen.dart` - Added UserQuotaManager to instantiation
4. `setup_dependencies.dart` - Updated cubit example code
5. `integration_guide.dart` - Updated cubit example code
6. `models/models.dart` - Exported new user_enhancement_quota model
7. `services/services.dart` - Exported UserQuotaManager
8. `widgets/widgets.dart` - Exported usage counter widgets

## 🔧 How to Use in Your Screens

### Option 1: Edit Listing Screen (Display Quota)
```dart
// At top of photo section
FutureBuilder<UserEnhancementQuota?>(
  future: context.read<PhotoEnhancementCubit>().fetchUserQuota(userId),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: CompactUsageCounterWidget(quota: snapshot.data!),
      );
    }
    return SizedBox.shrink();
  },
)
```

### Option 2: Enhancement Screen (Automatic Display)
```dart
BlocBuilder<PhotoEnhancementCubit, PhotoEnhancementState>(
  builder: (context, state) {
    if (state is ComparisonView && state.userQuota != null) {
      return UsageCounterWidget(quota: state.userQuota!, compact: true);
    }
    return SizedBox.shrink();
  },
)
```

### Option 3: Quota Alert on Exhaustion
```dart
BlocListener<PhotoEnhancementCubit, PhotoEnhancementState>(
  listenWhen: (prev, curr) => curr is QuotaExhausted,
  listener: (context, state) {
    if (state is QuotaExhausted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Monthly Quota Exhausted'),
          content: Text('Your enhancement quota resets on ${state.resetDate.month}/${state.resetDate.day}'),
          actions: [
            TextButton(onPressed: Navigator.pop, child: Text('OK')),
          ],
        ),
      );
    }
  },
  child: YourWidget(),
)
```

## 📊 Database Structure

### Firestore Collection: `user_enhancement_quotas`
```
Document ID: {userId}
{
  "userId": "user123",
  "year": 2026,
  "month": 1,  // 0-indexed
  "enhancementsUsed": 1,
  "previewsUsed": 3,
  "monthResetDate": "2026-03-01T00:00:00Z",
  "lastEnhancementAt": "2026-02-18T14:30:00Z",
  "lastPreviewAt": "2026-02-18T14:15:00Z"
}
```

## 🚀 Deployment Checklist

- [x] Code implementation completed
- [x] Models and services created
- [x] UI widgets created
- [x] Cubit integration completed
- [x] All instantiation points updated
- [x] Documentation created
- [ ] Add to your edit listing screen
- [ ] Add to your enhancement comparison screen
- [ ] Test with real images
- [ ] Verify Firestore quota tracking
- [ ] Test monthly reset
- [ ] Deploy to production

## 🧪 Testing

### Test Preview Quota
```dart
// In testing
final manager = UserQuotaManager();
for (int i = 0; i < 10; i++) {
  await manager.incrementPreviewUsage('testUser');
}
// Now preview quota is exhausted
```

### Test Enhancement Quota
```dart
// In testing
for (int i = 0; i < 10; i++) {
  await manager.incrementEnhancementUsage('testUser');
}
```

### Check Quota Status
```dart
final quota = await manager.getQuota('userId');
print(quota.getQuotaStatusString());
// Output: "Enhancements: 1/10 | Previews: 3/10"
```

## 💡 Key Features

✅ **Per-User Tracking** - Each user has own quotas
✅ **Monthly Limits** - 10 enhancements + 10 previews
✅ **Auto Reset** - Monthly on 1st of month
✅ **Usage Display** - (1/10) format with colors
✅ **Two Widget Styles** - Full cards or compact inline
✅ **Real-time Tracking** - Updates as enhancements happen
✅ **Firestore Persistence** - Survives app restarts
✅ **Easy Integration** - Simple UI widget placement

## 🎯 What Happens When Quota Exhausted

1. **Preview Quota**: Enhancement can't start, shows message
2. **Enhancement Quota**: Full quality can't be processed, shows message
3. **Either**: User sees "Try again on {date}"
4. **UI Response**: Shows red indicator, disables button if needed

## 📝 Next Steps for You

1. Locate your edit listing screen (photo management section)
2. Add `CompactUsageCounterWidget` to header
3. Locate your enhancement/comparison view
4. Add `UsageCounterWidget` above buttons
5. Test with product images
6. Verify Firestore has `user_enhancement_quotas` collection
7. Check that quotas increment properly

## 🔗 Related Documentation

- `USER_QUOTAS_GUIDE.md` - Detailed feature guide
- `QUOTA_IMPLEMENTATION_CHECKLIST.md` - Step-by-step integration
- `AI_PHOTO_ENHANCEMENT_DESIGN.md` - Overall design
- `PHOTO_ENHANCEMENT_DEPLOYMENT.md` - Deployment guide

## ❓ Questions?

Review the implementation checklists and guides for:
- Where to place widgets
- How to listen to quota changes
- Testing procedures
- Troubleshooting common issues
