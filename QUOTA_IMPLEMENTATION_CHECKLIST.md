# Photo Enhancement Quota Implementation Checklist

## ✅ Backend Setup (COMPLETED)

- [x] Created `UserEnhancementQuota` model with monthly limits (10 each)
- [x] Created `UserQuotaManager` service for Firestore operations
- [x] Integrated into `PhotoEnhancementCubit`:
  - [x] Check preview quota before generating preview
  - [x] Track preview usage automatically
  - [x] Track enhancement usage on approval
  - [x] Pass quota data to UI states
- [x] Updated all cubit instantiations with `UserQuotaManager()`

## 🎨 Frontend Widgets (COMPLETED)

- [x] `UsageCounterWidget` - Full display with cards
- [x] `CompactUsageCounterWidget` - Inline format "{used}/{limit}"
- [x] Color coding (green > orange > red)
- [x] Reset date display using `getScheduleInfo()`
- [x] Updated state to include `userQuota`

## 🔧 Integration Tasks (TO BE DONE)

### Step 1: Add to Edit Listing Screen
**File**: Find your edit listing screen where photos are managed

Add this at the top of the photo section:
```dart
// Get user quota
final userQuota = context.read<PhotoEnhancementCubit>().getLastUserQuota();

// Display compact counter
if (userQuota != null) {
  CompactUsageCounterWidget(quota: userQuota)
}
```

### Step 2: Add to Photo Enhancement Bottom Sheet
**File**: `lib/listings/ui/photo_enhancement/widgets/photo_enhancement_bottom_sheet.dart`

Add this in the build method:
```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<PhotoEnhancementCubit, PhotoEnhancementState>(
    builder: (context, state) {
      return Column(
        children: [
          // Add quota display at top
          if (state is ComparisonView && state.userQuota != null)
            Padding(
              padding: EdgeInsets.all(16),
              child: CompactUsageCounterWidget(quota: state.userQuota!),
            ),
          
          // Rest of existing content...
        ],
      );
    },
  );
}
```

### Step 3: Add to Comparison View
**File**: `lib/listings/ui/photo_enhancement/widgets/comparison_view_widget.dart`

Add this above the approve/reject buttons:
```dart
// Show quota status
if (widget.userQuota != null)
  Padding(
    padding: EdgeInsets.only(bottom: 16),
    child: UsageCounterWidget(
      quota: widget.userQuota!,
      compact: true, // Or false for full card view
    ),
  ),
```

### Step 4: Add Quota Listener for Alerts
Add to any screen that calls `startEnhancement()`:

```dart
BlocListener<PhotoEnhancementCubit, PhotoEnhancementState>(
  listenWhen: (prev, curr) => curr is QuotaExhausted,
  listener: (context, state) {
    if (state is QuotaExhausted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.message ?? 
            'Monthly quota exhausted. Try again ${state.resetDate.month}/${state.resetDate.day}'
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  },
  child: // your widget tree
),
```

## 📊 Display Locations

### Option 1: Compact (Inline)
Best for: List headers, sidebars, action bars
```
Enhancements: 1/10 | Previews: 3/10
```

### Option 2: Full (Cards)
Best for: Detail screens, before enhancement
Shows side-by-side cards with icons and progress bars

### Option 3: Minimal (Text Only)
Best for: Buttons, badges
```
(1/10)
```

## 🧪 Testing

### Scenario 1: Normal Usage
1. Open edit listing
2. See: "Enhancements: 0/10 | Previews: 0/10"
3. Select product image
4. Preview generated → "Previews: 1/10"
5. Approve enhancement → "Enhancements: 1/10"

### Scenario 2: Quota Low
1. Use 8 previews
2. UI shows: "Previews: 8/10" (orange warning color)
3. Try to use 9th preview
4. Dialog appears: "Only 1 preview left"
5. Use 10th preview
6. Next attempt shows: "Quota exhausted"

### Scenario 3: Month Reset
1. Simulate with `resetQuota()` in testing
2. Verify counters reset to 0/10
3. Check reset date shows next month

## 🔍 Debugging

### Check Firestore Data
```
Collection: user_enhancement_quotas
Doc ID: {userId}
Expected fields:
- enhancementsUsed: 0-10
- previewsUsed: 0-10
- monthResetDate: ISO date string
```

### Get User Quota Programmatically
```dart
final userQuotaManager = UserQuotaManager();
final quota = await userQuotaManager.getQuota(userId);
print('Enhancements: ${quota.enhancementsUsed}/10');
print('Previews: ${quota.previewsUsed}/10');
print('Resets: ${quota.monthResetDate}');
```

### Listen to Quota Changes
```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
    .collection('user_enhancement_quotas')
    .doc(userId)
    .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final quota = UserEnhancementQuota.fromJson(
        snapshot.data!.data() as Map<String, dynamic>
      );
      return CompactUsageCounterWidget(quota: quota);
    }
    return SizedBox.shrink();
  },
)
```

## 📝 Code Locations

| Component | Location |
|-----------|----------|
| Model | `lib/listings/ui/photo_enhancement/models/user_enhancement_quota.dart` |
| Service | `lib/listings/ui/photo_enhancement/services/user_quota_manager.dart` |
| Full Widget | `lib/listings/ui/photo_enhancement/widgets/usage_counter_widget.dart` (UsageCounterWidget) |
| Compact Widget | `lib/listings/ui/photo_enhancement/widgets/usage_counter_widget.dart` (CompactUsageCounterWidget) |
| Cubit | `lib/listings/ui/photo_enhancement/cubit/photo_enhancement_cubit.dart` |
| State | `lib/listings/ui/photo_enhancement/cubit/photo_enhancement_state.dart` |

## 🚀 Next Steps

1. [ ] Identify edit listing screen location
2. [ ] Add CompactUsageCounterWidget to photo section header
3. [ ] Add to photo enhancement bottom sheet
4. [ ] Add to comparison view widget
5. [ ] Test with real images
6. [ ] Verify Firestore tracking
7. [ ] Test monthly reset (March 1st)
8. [ ] Add styling to match app theme

## 💭 Notes

- Quotas are **per-user**, not per-listing
- Monthly reset happens at **00:00 UTC on the 1st**
- Each preview counts as 1 preview quota
- Each full enhancement counts as 1 enhancement quota
- Previews are **free** (no API cost), enhancements are **paid tier**
- Over quota behavior: Show error, don't process
- Color changes based on remaining: green → orange → red

## 🆘 Troubleshooting

**Issue**: Quota not updating
**Solution**: Check `UserQuotaManager.incrementPreviewUsage()` is called

**Issue**: Widget not showing quota
**Solution**: Pass `userQuota` from cubit state to widget

**Issue**: Reset date wrong
**Solution**: Verify `monthResetDate` calculation in model

**Issue**: Wrong user quota appears
**Solution**: Ensure `userId` parameter is correct and matches Firebase auth
