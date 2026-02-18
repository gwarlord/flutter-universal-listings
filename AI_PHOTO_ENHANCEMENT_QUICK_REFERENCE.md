# AI Photo Enhancement - Quick Reference Guide
## CaribTap Implementation Checklist & FAQ

---

## QUICK START CHECKLIST

### Phase 1: Planning & Design (Week 1)
- [x] Review design document: `AI_PHOTO_ENHANCEMENT_DESIGN.md`
- [x] Review technical spec: `AI_PHOTO_ENHANCEMENT_TECHNICAL_SPEC.md`
- [x] Review backend guide: `AI_PHOTO_ENHANCEMENT_BACKEND.md`
- [ ] Get design approval from stakeholders
- [ ] Create feature flag: `ai_photo_enhancement_enabled` (false by default)

### Phase 2: Backend Setup (Week 2)
- [ ] Create Cloud Function `enhancePhoto`
- [ ] Create Cloud Function `saveEnhancementVariant`
- [ ] Update Firestore rules for image_variants collection
- [ ] Test functions locally with emulator
- [ ] Deploy to Firebase production
- [ ] Enable Google Vision API
- [ ] Set up monitoring & alerts

### Phase 3: Data Model Updates (Week 2)
- [ ] Update `listing_model.dart`:
  - Add `Enhancement Quota` class
  - Add `image_variants` field to `ListingModel`
  - Add `imageVariants` to toJson/fromJson
- [ ] Update Firestore schema
- [ ] Create data migration script (if needed)

### Phase 4: Frontend Implementation (Week 3)
- [ ] Create all model files (in `models/` folder)
- [ ] Create Cubit + State classes
- [ ] Create all service classes:
  - `PhotoEnhancementService`
  - `QuotaManager`
  - `OfflineQueueManager`
  - `EnhancementAnalytics`
- [ ] Create all widget components:
  - `EnhancementEntryButton`
  - `CategorySelectorModal`
  - `ProcessingIndicator`
  - `BeforeAfterComparison`
  - `TierUpsellModal`
  - `LimitReachedModal`
  - Others (see technical spec)

### Phase 5: Integration (Week 3–4)
- [ ] Integrate enhancement button into listing edit flow
- [ ] Wire cubit into existing BLoC/Provider structure
- [ ] Test with real images
- [ ] Test offline scenarios
- [ ] Test quota enforcement
- [ ] Test subscription tier access

### Phase 6: Testing & QA (Week 4)
- [ ] Unit tests for `QuotaManager`
- [ ] Unit tests for `PhotoEnhancementCubit`
- [ ] Widget tests for UI components
- [ ] End-to-end flow testing
- [ ] Load testing on backend
- [ ] Security testing (verify ownership, quota)

### Phase 7: Launch (Week 5)
- [ ] Enable feature flag for 5% of users
- [ ] Monitor error rates & performance
- [ ] Collect user feedback
- [ ] Rollout to 50% of users
- [ ] Full rollout to 100%

---

## FOLDER STRUCTURE (TO CREATE)

```
lib/listings/ui/photo_enhancement/
├── widgets/
│   ├── enhancement_entry_button.dart
│   ├── enhancement_modal.dart
│   ├── category_selector_modal.dart
│   ├── processing_indicator.dart
│   ├── before_after_comparison.dart          ← Most complex widget
│   ├── approval_actions.dart
│   ├── quota_indicator.dart
│   ├── tier_upsell_modal.dart
│   ├── limit_reached_modal.dart
│   ├── enhancement_error_modal.dart
│   └── disclosure_badge.dart
│
├── cubit/
│   ├── photo_enhancement_cubit.dart
│   └── photo_enhancement_state.dart
│
├── models/
│   ├── enhancement_request.dart
│   ├── enhancement_response.dart
│   ├── enhancement_quota.dart
│   ├── image_variant.dart
│   └── enhancement_specs.dart
│
└── services/
    ├── photo_enhancement_service.dart
    ├── quota_manager.dart
    ├── offline_queue_manager.dart
    └── enhancement_analytics.dart
```

---

## KEY DESIGN DECISIONS

### 1. Quota Enforcement
- **Per-listing, not per-user**: Abuse prevention (one seller can't spam all listings)
- **Monthly reset**: Automatic, based on calendar month
- **Count triggers on processing start**: Not on preview (prevents false counts)

### 2. Subscription Tiers
```
Tier 1 - Professional ($9.99/mo)
├─ Auto-crop & framing
├─ Lighting normalization
├─ Clarity enhancement
└─ Subtle background blur

Tier 2 - Professional Plus (Premium)
├─ (All of Tier 1)
├─ Background cleanup/neutralization
├─ Subject isolation
└─ Face cleanup (subtle only)

Tier 3 - Professional Pro (Enterprise)
├─ (All of Tier 1+2)
├─ Logo watermarking
├─ Position presets
├─ Opacity control
└─ Branded overlay
```

### 3. Image Storage Strategy
```
Cloud Storage:
listings/{listingId}/
├─ images/              (original images only)
│  ├─ imageId.jpg
│  └─ imageId2.jpg
├─ variants/            (enhanced variants only)
│  ├─ imageId-enhanced-1708099200000.png
│  └─ imageId2-enhanced-1708099320000.png

Firestore:
listings/{listingId}/
├─ images: [...]        (unchanged array of original URLs)
├─ image_variants: [    (NEW: stores enhanced variants)
│  {
│    original_image_id,
│    variant_url,
│    category,
│    tier,
│    enhancements: string[],
│    enhanced_at: timestamp
│  }
│]
└─ enhancement_quota:   (NEW: tracks monthly usage)
   {
     year: number,
     month: number (0-indexed),
     used_count: number (0-10),
     month_reset_date: timestamp
   }
```

### 4. Error Handling Priority
1. **Offline**: Can't process; offer to queue
2. **Not subscribed**: Show upsell modal
3. **Quota exceeded**: Show limit reached modal
4. **Processing failed**: Show retry option
5. **Other errors**: Generic error with retry

---

## CRITICAL IMPLEMENTATION NOTES

### ⚠️ DO NOT FORGET

1. **Preserve original images always**
   - Never overwrite original
   - Always store variants separately
   - Provide restore option if user deletes

2. **Add disclosure badge**
   - "ENHANCED FOR CLARITY" watermark
   - Applied by backend before returning
   - Non-negotiable for trust

3. **Require explicit approval**
   - Before/after must be reviewed
   - "Approve & Save" button required
   - No auto-saving enhancements

4. **Enforce quota strictly**
   - 10 per listing per calendar month
   - Count resets on 1st of next month
   - Disable button when limit reached

5. **Check subscription tier**
   - Before showing enhancement button
   - Before allowing processing
   - Sync with subscription service

6. **Handle offline gracefully**
   - Queue enhancements locally
   - Retry when online
   - Don't lose user work

### 🚀 OPTIMIZATION TIPS

1. **Use feature flag for rollout**
   ```dart
   bool isEnhancementEnabled = RemoteConfig.instance
     .getBool('ai_photo_enhancement_enabled');
   
   if (!isEnhancementEnabled) return SizedBox.shrink();
   ```

2. **Cache Vision API results**
   - Store labels/objects in Firestore
   - Reuse for category inference
   - Reduces API costs

3. **Compress images before processing**
   - Resize to max 1024x1024
   - Reduce file size
   - Faster processing

4. **Monitor costs**
   - Vision API: ~$0.003 per call
   - Set budget alerts in Google Cloud Console
   - Target: <$500/month for first 100k users

5. **Async processing**
   - Don't block UI during Cloud Function
   - Show progress indicator
   - Allow user to navigate away

---

## COMMON QUESTIONS (FAQ)

### Q: What if the enhancement image doesn't exist after approval?
**A**: Implement retry logic. If save fails:
1. Keep enhanced image in temp cache
2. Show "Save failed. Retry?" prompt
3. Don't discard the enhancement
4. Allow user to try again later

### Q: Can users enhance the same image multiple times?
**A**: Yes, but counts against quota. Each attempt = 1 of 10.
- User can compare multiple variants
- Only keeps approved ones
- Quota resets monthly

### Q: What happens at month boundary (Feb 28 → Mar 1)?
**A**: Automatic quota reset at midnight UTC.
```dart
// Backend automatically handles:
if (quota.month != currentMonth || quota.year != currentYear) {
  resetQuota(); // Sets used_count = 0
}
```

### Q: Can users downgrade from Professional to Free?
**A**: Yes. When downgrading:
1. Can still view enhanced images (existing)
2. Cannot create new enhancements
3. Show: "Feature unavailable on your current plan"

### Q: What if image is copyright/non-compliant?
**A**: Content moderation needed post-launch.
```
Future plans:
- Flag for manual review if detected
- Remove variant if reported
- Warn user about compliance
```

### Q: How long does enhancement take?
**A**: 5–15 seconds typically.
- Upload image: 1–2s
- Vision API: 1–3s
- Processing: 1–5s
- Save variant: 1–2s
- Return: 1s

### Q: What image formats are supported?
**A**: JPEG, PNG, WebP (most common).
```dart
// Validate in Flutter:
final ext = Path.extension(imageFile.path).toLowerCase();
if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
  showError('Format not supported');
}
```

### Q: Can we enhance already-enhanced images?
**A**: Yes, but not recommended.
- Each enhancement counts against quota
- Watermark stacking could confuse buyers
- Consider UI hint: "Image already enhanced"

### Q: What about GDPR/data privacy?
**A**: Images processed for enhancement:
- Stored temporarily during processing
- Deleted after enhancement (except final variant)
- Never used for training
- Add privacy notice to upsell modal

### Q: Can we charge per enhancement?
**A**: Not in v1. Included in Professional subscription.
Future: Could add "Premium enhancements" ($0.99/each) for Pro tier.

---

## TESTING SCENARIOS

### Scenario 1: Happy Path
```
1. Seller (Professional tier) uploads product photo
2. Taps "Enhance photo"
3. Selects "Product Photo" category
4. Sees before/after comparison
5. Taps "Approve & Save"
6. Enhanced image saved, quota updated (9 of 10)
```

### Scenario 2: Quota Limit
```
1. Seller has used 10/10 enhancements this month
2. Taps "Enhance photo"
3. Sees "Monthly limit reached" modal
4. Show: "Limit resets March 1, 2026"
5. Options: OK, or "See Pro+ features"
```

### Scenario 3: Not Subscribed
```
1. Free tier seller uploads photo
2. Taps "Enhance photo"
3. Sees tier upsell modal: "⭐ Unlock AI Photo Enhancement"
4. Options: "Subscribe", "Already subscribed? Refresh", "Maybe Later"
```

### Scenario 4: Processing Fails
```
1. Seller taps "Enhance photo"
2. Processing starts... 45%...
3. Network error occurs
4. Shows: "⚠️ Enhancement failed. Check internet & try again"
5. Options: "Retry", "Use Original"
```

### Scenario 5: Offline
```
1. User is offline
2. Taps "Enhance photo"
3. Shows: "🔌 You need internet to use AI enhancement"
4. Options: "OK", or "Reconnect"
5. (Optional) Queue for later processing when online
```

---

## ROLLOUT STRATEGY

### Alpha (Week 5)
- Internal team testing
- All features enabled
- Bug fixes & iterations

### Beta (Weeks 5–6)
- 5% of Professional sellers
- Feature flag: 5% rollout
- Monitor errors & performance
- Gather feedback

### Gradual Rollout (Weeks 6–7)
- 25% → 50% → 100%
- Monitor quota abuse patterns
- Adjust limits if needed
- Performance optimizations

### Post-Launch
- Upsell campaign to Professional subscribers
- Feature highlight in app
- Email: "New Pro Feature: AI Photo Enhancement"
- Monitor conversion impact

---

## SUCCESS METRICS (30-Day Target)

| Metric | Target | How to Measure |
|--------|--------|---|
| Adoption | 15% of Professional tiers | `ai_enhance_attempt` count |
| Approval Rate | 60%+ | approved / attempts |
| Views Uplift | +12% avg | Compare views before/after enhancement |
| Error Rate | <1% | Failed enhancements / total |
| Avg Processing Time | <15s | Firebase function logs |
| Quota Abuse | <5% hit limit | `ai_enhance_quota_limit` events |

---

## DEPENDENCIES TO ADD

Update `pubspec.yaml`:
```yaml
dependencies:
  connectivity_plus: ^5.0.0
  cloud_functions: ^4.5.0
  # ... existing dependencies ...

dev_dependencies:
  # ... existing ...
```

Update `functions/package.json`:
```json
{
  "dependencies": {
    "firebase-functions": "^4.5.0",
    "firebase-admin": "^12.0.0",
    "@google-cloud/vision": "^3.5.0",
    "@google-cloud/storage": "^7.0.0",
    "sharp": "^0.32.0"
  }
}
```

---

## SUPPORT & DOCUMENTATION

### Internal Docs
- Design: `AI_PHOTO_ENHANCEMENT_DESIGN.md`
- Technical: `AI_PHOTO_ENHANCEMENT_TECHNICAL_SPEC.md`
- Backend: `AI_PHOTO_ENHANCEMENT_BACKEND.md`
- This guide: `AI_PHOTO_ENHANCEMENT_QUICK_REFERENCE.md`

### External Resources
- Google Vision API: https://cloud.google.com/vision/docs
- Sharp (image processing): https://sharp.pixelplumbing.com/
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- Flutter BLoC: https://bloclibrary.dev/

---

## ESCALATION CONTACTS

| Issue | Contact | Channel |
|-------|---------|---------|
| Product / Design | Product Manager | Slack #product |
| Backend / Cloud | DevOps Lead | Slack #backend |
| Flutter / Mobile | Mobile Tech Lead | Slack #mobile |
| Data / Analytics | Analytics Engineer | Slack #data |
| Costs / Billing | Finance | Email |

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-16 | Initial design document created |

---

## END OF QUICK REFERENCE GUIDE

Questions? Refer back to the main design documents or escalate to the team leads.
