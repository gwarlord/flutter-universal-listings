# CaribTap AI Photo Enhancement Feature
## Comprehensive Design Document

---

## TABLE OF CONTENTS
1. [Feature Overview](#overview)
2. [UX Design & Screens](#ux-design)
3. [Feature Architecture](#architecture)
4. [Data Models](#data-models)
5. [Implementation Roadmap](#roadmap)
6. [Abuse Prevention & Limits](#abuse-prevention)
7. [Copy & Messaging](#copy-messaging)

---

## OVERVIEW

### What This Feature Does
- **Enhancement, not generation**: AI improves real photos without adding fake elements
- **Preserves original**: Original image always accessible, never overwritten
- **Transparent**: Disclosure badge ("Enhanced for clarity") applied automatically
- **Subscription-gated**: Professional tier and above only
- **User approval required**: No auto-saves; user explicitly approves each enhancement

### Core Principle
Trust is paramount. Buyers should never question whether a photo is real or artificially created.

---

## UX DESIGN

### SCREEN 1: Listing Image Upload (Entry Point)

**Location**: Listing creation → Photo upload section / Edit Listing → Images section

```
┌─────────────────────────────────┐
│  Upload Photos                  │
├─────────────────────────────────┤
│                                 │
│  [📷 Add Photo]  [📁 Gallery]   │
│                                 │
│  Uploaded Images:               │
│  ┌─────────┬─────────┬─────────┐│
│  │ Image 1 │ Image 2 │ Image 3 ││
│  │ [✓]     │ [✓]     │ [✓]     ││
│  │ [Edit]  │ [Edit]  │ [Edit]  ││
│  └─────────┴─────────┴─────────┘│
│                                 │
│  [Category: Product ▼]          │
│                                 │
│  Next Step: Add Title           │
└─────────────────────────────────┘
```

### SCREEN 2: Image Edit Modal (Triggered from Image 1 above)

**When user taps [Edit] on an uploaded image:**

```
┌──────────────────────────────────────┐
│  Edit Photo                       [✕] │
├──────────────────────────────────────┤
│                                      │
│  [Original Photo Preview]            │
│  ┌──────────────────────────────────┐│
│  │                                  ││
│  │         [Photo Thumbnail]        ││
│  │                                  ││
│  └──────────────────────────────────┘│
│                                      │
│  ┌──────────────────────────────────┐│
│  │ ✨ Enhance photo (Professional)  ││
│  │ AI-assisted improvements for     ││
│  │ better clarity & framing         ││
│  │                                  ││
│  │ Remaining: 7 of 10 this month ✓ ││
│  │                                  ││
│  │    [Enhance] [Dismiss]           ││
│  └──────────────────────────────────┘│
│                                      │
│  [Crop]  [Rotate]  [Filter]  [More] │
│                                      │
│  [Cancel]         [Save Changes]     │
└──────────────────────────────────────┘
```

**Key elements:**
- **Quota indicator**: "7 of 10 AI enhancements remaining this month"
- **Tier messaging**: "(Professional)" upsell if user not subscribed
- **Non-intrusive**: Not front-and-center; secondary enhancement options

### SCREEN 3: Category Selection (Conditional, First Enhancement)

**When user taps [Enhance] without category context:**

```
┌──────────────────────────────────────┐
│  What are you enhancing?          [✕] │
├──────────────────────────────────────┤
│                                      │
│  Select category for best results:   │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 📷 Product Photo               │ │
│  │ (Objects, items, merchandise)  │ │
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 🏢 Service Environment         │ │
│  │ (Business space, setup)        │ │
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │ 👤 Person / Service Provider   │ │
│  │ (Headshots, professional photo)│ │
│  └────────────────────────────────┘ │
│                                      │
│  [Cancel]                  [Continue] │
└──────────────────────────────────────┘
```

### SCREEN 4: Processing State

**Shown after user confirms category (5–10 seconds):**

```
┌──────────────────────────────────────┐
│  Enhancing your photo...          [✕] │
├──────────────────────────────────────┤
│                                      │
│  ┌──────────────────────────────────┐│
│  │                                  ││
│  │          [Spinning Loader]       ││
│  │                                  ││
│  │     AI is optimizing lighting,   ││
│  │     clarity, and framing...      ││
│  │                                  ││
│  │            45%                   ││
│  │       ████████░░░░░░░░          ││
│  │       (~5 seconds remaining)     ││
│  │                                  ││
│  └──────────────────────────────────┘│
│                                      │
│  Note: Original image always kept    │
└──────────────────────────────────────┘
```

**Edge case – Processing failure:**
```
┌──────────────────────────────────────┐
│  Enhancement failed                [✕] │
├──────────────────────────────────────┤
│                                      │
│  ⚠️  We couldn't process this image  │
│     Check your internet & try again  │
│                                      │
│  [Retry]              [Use Original] │
└──────────────────────────────────────┘
```

**Edge case – Offline:**
```
┌──────────────────────────────────────┐
│  Cannot enhance (offline)          [✕] │
├──────────────────────────────────────┤
│                                      │
│  🔌 You need internet to use AI      │
│     enhancement features             │
│                                      │
│  Please reconnect and try again.     │
│                                      │
│  [OK]                                │
└──────────────────────────────────────┘
```

### SCREEN 5: Before / After Comparison

**Core UX for approval:**

```
┌──────────────────────────────────────────┐
│  AI Enhancement Preview                [✕] │
├──────────────────────────────────────────┤
│                                          │
│  ┌──────────────────────────────────────┐│
│  │                                      ││
│  │    [BEFORE] ▮▮▮▮▮▮  [AFTER]        ││
│  │                                      ││
│  │         [Enhanced Photo]              ││
│  │    (Drag slider to compare)          ││
│  │                                      ││
│  │  ┌────────────┬─────────────────┐   ││
│  │  │ Lighting   │ ✓ Optimized    │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Clarity    │ ✓ Sharpened    │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Framing    │ ✓ Auto-cropped │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Category   │ Product Photo   │   ││
│  │  └────────────┴─────────────────┘   ││
│  │                                      ││
│  │  [ENHANCED FOR CLARITY] badge        ││
│  │  (Will appear on listing)            ││
│  │                                      ││
│  └──────────────────────────────────────┘│
│                                          │
│  [Discard]              [Approve & Save] │
└──────────────────────────────────────────┘
```

**Interactive elements:**
- **Slider comparison**: Drag left-right to reveal before/after
- **Spec checklist**: Shows what was enhanced
- **Disclosure badge preview**: "ENHANCED FOR CLARITY" watermark shown
- **Storage note**: "New variant saved. Original always available."

### SCREEN 6: Tier Upsell (Non-Subscriber)

**When user without Professional subscription taps Enhance:**

```
┌──────────────────────────────────────┐
│  Unlock AI Photo Enhancement       [✕] │
├──────────────────────────────────────┤
│                                      │
│  ⭐ Professional Subscription         │
│                                      │
│  Get AI-powered tools to make your   │
│  listings stand out:                 │
│                                      │
│  ✓ Smart lighting optimization      │
│  ✓ Auto-crop & framing              │
│  ✓ Clarity enhancement              │
│  ✓ Background blur (Pro+)           │
│  ✓ Up to 10 per listing / month     │
│                                      │
│  ┌──────────────────────────────────┐│
│  │ Professional   $9.99 / month      ││
│  │ (Includes all premium seller tools)
│  │                    [Subscribe]   ││
│  └──────────────────────────────────┘│
│                                      │
│  Already subscribed?                 │
│  [Refresh Subscription Status]       │
│                                      │
│  [Maybe Later]                       │
└──────────────────────────────────────┘
```

### SCREEN 7: Limit Reached

**When user hits 10/10 enhancements for the month:**

```
┌──────────────────────────────────────────┐
│  Monthly limit reached              [✕]   │
├──────────────────────────────────────────┤
│                                          │
│  📊 You've used all 10 AI enhancements   │
│     for this listing this month          │
│                                          │
│  Limit resets:  March 1, 2026            │
│  (23 days remaining)                     │
│                                          │
│  💡 What you can do:                     │
│  • Continue using this enhanced version  │
│  • Edit or delete existing enhancements  │
│  • Enhance a different listing           │
│  • Wait for reset next month             │
│                                          │
│  ℹ️  Limits apply per listing per month  │
│     to prevent abuse.                    │
│                                          │
│  [OK]             [See Pro+ Tiers ➜]     │
└──────────────────────────────────────────┘
```

### SCREEN 8: Pro+ Background Cleanup Preview

**Tier 2 exclusive – Advanced enhancement before/after:**

```
┌──────────────────────────────────────────┐
│  Advanced Enhancement (Pro+)           [✕] │
├──────────────────────────────────────────┤
│                                          │
│  ┌──────────────────────────────────────┐│
│  │                                      ││
│  │    [BEFORE] ▮▮▮▮▮▮  [AFTER]        ││
│  │                                      ││
│  │         [Product on Clean BG]       ││
│  │                                      ││
│  │  ┌────────────┬─────────────────┐   ││
│  │  │ Lighting   │ ✓ Optimized    │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Clarity    │ ✓ Enhanced      │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Background │ ✓ Neutralized   │   ││
│  │  ├────────────┼─────────────────┤   ││
│  │  │ Subject    │ ✓ Isolated      │   ││
│  │  └────────────┴─────────────────┘   ││
│  │                                      ││
│  │  Background Options:                 ││
│  │  ☐ White (Studio)                    ││
│  │  ☑ Soft Gray (Professional)         ││
│  │  ☐ Transparent (e-commerce)          ││
│  │                                      ││
│  │  [ENHANCED FOR CLARITY] badge        ││
│  │                                      ││
│  └──────────────────────────────────────┘│
│                                          │
│  [Discard]              [Approve & Save] │
└──────────────────────────────────────────┘
```

### SCREEN 9: Pro Branding Tools

**Tier 3 exclusive:**

```
┌──────────────────────────────────────────┐
│  Add Logo Watermark (Pro)              [✕] │
├──────────────────────────────────────────┤
│                                          │
│  Your Brand Logo:                        │
│  ┌──────────────────────────────────────┐│
│  │  [Upload Logo or Use Saved Logo ▼]  ││
│  └──────────────────────────────────────┘│
│                                          │
│  Position Preset:                        │
│  ☐ Bottom Right (Default)                │
│  ☐ Bottom Left                           │
│  ☐ Center Subtle                         │
│                                          │
│  Opacity:                                │
│  ░░░░░░░░░░░░░░░░░░ 30%                 │
│  (Slide to adjust)                       │
│                                          │
│  Preview:                                │
│  ┌──────────────────────────────────────┐│
│  │  [Enhanced Photo with Logo]          ││
│  │                                      ││
│  │       Logo here (30% opacity)        ││
│  │                                      ││
│  └──────────────────────────────────────┘│
│                                          │
│  [Cancel]              [Apply & Save]    │
└──────────────────────────────────────────┘
```

---

## FEATURE ARCHITECTURE

### Where This Fits in Listing Flow

```
User Opens Listing Creation
    ↓
[BASIC FLOW] User uploads photo
    ↓
◆ --- ENTRY POINT: Enhancement CTA Appears ---
    ↓
❌ User skips        OR        ✅ User taps Enhance
    ↓                               ↓
[Continue]            [Category Selection Modal]
    ↓                               ↓
[Next Step]                 [AI Processing]
                                ↓
                        [Before/After Compare]
                                ↓
                     ✅ Approve    OR    ❌ Discard
                                ↓
                        [Enhanced variant saved]
                        [Original preserved]
                                ↓
                        [Continue listing creation]
```

### Integration Points

```
1. LISTING CREATION FLOW
   ├─ Photo upload section (lib/listings/listings_module/add_listing/)
   ├─ NEW: Enhancement modal triggered on image tap
   └─ Enhanced images stored as variants in listing model

2. LISTING EDIT FLOW
   ├─ Image management (Edit → Images tab)
   ├─ Enhancement available on existing images
   └─ Can view/delete enhanced variants

3. SUBSCRIPTION CHECK
   ├─ Query user's subscription tier from FireStore
   ├─ Professional (Tier 1), Professional+ (Tier 2), Professional Pro (Tier 3)
   └─ Disable UI if not Professional and above

4. QUOTA ENFORCEMENT
   ├─ Track monthly enhancements per listing in FireStore
   ├─ Reset on 1st of each month
   └─ Disable button at 10/month threshold
```

### Component Architecture

```
lib/listings/ui/photo_enhancement/
├─ widgets/
│  ├─ enhancement_entry_button.dart
│  │  └─ "Enhance photo" CTA on image tile
│  ├─ enhancement_modal.dart
│  │  └─ Main enhancement flow container
│  ├─ category_selector.dart
│  │  └─ Product/Service/Person selection
│  ├─ before_after_comparison.dart
│  │  └─ Slider-based visual comparison
│  ├─ approval_actions.dart
│  │  └─ Approve & Save / Discard buttons
│  ├─ quota_indicator.dart
│  │  └─ "7 of 10 remaining" display
│  ├─ tier_upsell_modal.dart
│  │  └─ Subscribe CTA for non-subscribers
│  └─ limit_reached_modal.dart
│     └─ "Monthly limit reached" message
│
├─ cubit/
│  └─ photo_enhancement_cubit.dart
│     ├─ emit(EnhancementLoading)
│     ├─ emit(EnhancementReady)
│     └─ emit(EnhancementError)
│
├─ models/
│  ├─ enhancement_request.dart
│  │  └─ {listingId, imageId, category, tier}
│  ├─ enhancement_response.dart
│  │  └─ {enhancedImageUrl, specs[], timestamp}
│  └─ enhancement_quota.dart
│     └─ {listingId, month, usedCount, remainingCount}
│
├─ services/
│  ├─ photo_enhancement_service.dart
│  │  └─ API calls to backend
│  ├─ quota_manager.dart
│  │  └─ Track & enforce monthly limits
│  └─ offline_handler.dart
│     └─ Queue enhancements if offline
│
└─ screens/
   └─ (No new screens; all modals attach to existing edit flow)
```

### Data Model Changes

**Listing Model Extension** (existing `listing_model.dart`)

```dart
class ListingModel {
  // ... existing fields ...
  
  List<ImageVariant>? imageVariants;
  EnhancementQuota? quota; // NEW
}

class ImageVariant {
  String originalImageId;
  String variantId;
  String variantUrl;
  String category; // 'product' | 'service' | 'person'
  List<String> enhancements; // ['lighting', 'clarity', 'framing', etc]
  bool hasDisclosure; // Always true for enhanced images
  DateTime enhancedAt;
  String tier; // 'professional' | 'professional_plus' | 'professional_pro'
}

class EnhancementQuota {
  String listingId;
  int year;
  int month;
  int usedCount; // 0–10
  DateTime monthResetDate;
  
  bool get isAtLimit => usedCount >= 10;
  int get remaining => 10 - usedCount;
}
```

**Backend Endpoint** (Firebase Cloud Function)

```typescript
POST /api/v1/listings/{listingId}/enhance_photo

Request:
{
  imageId: string,
  category: "product" | "service" | "person",
  userTier: "professional" | "professional_plus" | "professional_pro",
  imageUrl: string
}

Response (5–10 second processing):
{
  enhancedImageUrl: string,
  variantId: string,
  specs: [
    { type: "lighting", applied: true },
    { type: "clarity", applied: true },
    { type: "framing", applied: true },
    # Tier 2 adds:
    # { type: "background", applied: true }
    # { type: "subject_isolation", applied: true }
  ],
  timestamp: ISO8601
}

Error:
{
  error: "PROCESSING_FAILED" | "INVALID_CATEGORY" | "TIER_NOT_ELIGIBLE",
  message: string
}
```

---

## DATA MODELS

### Firebase Structure

```
firestore:
└─ listings/{listingId}
   ├─ id: string
   ├─ title: string
   ├─ images: string[] // Original image URLs
   ├─ imageVariants: {
   │  └─ [{
   │     originalImageId: string,
   │     variantId: string,
   │     variantUrl: string,
   │     category: string,
   │     enhancedAt: timestamp,
   │     tier: string
   │  }]
   ├─ enhancementQuota: {
   │  ├─ year: number,
   │  ├─ month: number,
   │  ├─ usedCount: number,
   │  └─ monthResetDate: timestamp
   └─ ... other listing fields ...

analytics_events:
└─ {
   event: "ai_enhance_attempt",
   listingId: string,
   category: string,
   status: "STARTED" | "SUCCESS" | "FAILED",
   tier: string,
   timestamp: timestamp
}
```

---

## IMPLEMENTATION ROADMAP

### Phase 1: Core Infrastructure (Week 1–2)
- [ ] Create `photo_enhancement_cubit` with state management
- [ ] Build `quota_manager` service with Firestore integration
- [ ] Implement `enhancement_entry_button` widget (non-intrusive CTA)
- [ ] Set up category selection modal
- [ ] Test offline detection & graceful degradation

### Phase 2: UI & Flows (Week 2–3)
- [ ] Build `before_after_comparison` widget with slider
- [ ] Implement tier upsell modal
- [ ] Build limit-reached modal
- [ ] Integrate into existing listing edit flow
- [ ] Add disclosure badge to listing images

### Phase 3: Backend Integration (Week 3–4)
- [ ] Wire up `photo_enhancement_service` to Firebase Cloud Function
- [ ] Implement processing state (spinner + progress)
- [ ] Add error handling (offline, timeout, invalid image)
- [ ] Test tier-based feature restrictions

### Phase 4: Testing & Analytics (Week 4)
- [ ] Unit test quota enforcement logic
- [ ] End-to-end test: upload → enhance → approve → save
- [ ] Analytics logging for attempts / approvals / conversions
- [ ] Load test backend processing

### Phase 5: Launch (Week 5)
- [ ] Feature flag for gradual rollout
- [ ] Monitor error rates & processing latency
- [ ] Gather user feedback

---

## ABUSE PREVENTION & LIMITS

### Monthly Quota Enforcement

**Rule**: 10 AI enhancements per listing per calendar month

**Implementation**:
```dart
// In quota_manager.dart

Future<int> getRemainingQuota(String listingId) async {
  final listing = await firestore
    .collection('listings')
    .doc(listingId)
    .get();
  
  final quota = listing.data()?['enhancementQuota'];
  if (quota == null) {
    // First time: create quota record
    await initializeQuota(listingId);
    return 10;
  }
  
  final quotaMonth = quota['month']; // 0–11
  final quotaYear = quota['year'];
  final today = DateTime.now();
  
  if (quotaYear != today.year || quotaMonth != today.month - 1) {
    // Month has changed; reset
    await resetQuota(listingId);
    return 10;
  }
  
  // Month still current
  final usedCount = quota['usedCount'] ?? 0;
  return 10 - usedCount;
}

Future<bool> canEnhance(String listingId) async {
  final remaining = await getRemainingQuota(listingId);
  return remaining > 0;
}

Future<void> recordEnhancementAttempt(String listingId) async {
  // Called ONLY after AI processing starts (not on preview)
  final docRef = firestore.collection('listings').doc(listingId);
  await docRef.update({
    'enhancementQuota.usedCount': FieldValue.increment(1),
  });
}
```

**Reset Logic**:
```dart
Future<void> resetQuota(String listingId) async {
  final today = DateTime.now();
  await firestore
    .collection('listings')
    .doc(listingId)
    .update({
      'enhancementQuota': {
        'year': today.year,
        'month': today.month - 1, // 0-indexed
        'usedCount': 0,
        'monthResetDate': Timestamp.fromDate(
          DateTime(today.year, today.month + 1, 1) // First day of next month
        ),
      }
    });
}
```

### Tier-Based Access Control

```dart
// In photo_enhancement_cubit.dart

bool canAccessEnhancement(User user) {
  final tier = user.subscriptionTier;
  // 'free' | 'professional' | 'professional_plus' | 'professional_pro'
  return tier != 'free' && tier != null;
}

List<String> getAvailableFeatures(String userTier) {
  switch (userTier) {
    case 'professional':
      return [
        'auto_crop',
        'lighting_normalization',
        'clarity_enhancement',
        'subtle_background_blur',
      ];
    case 'professional_plus':
      return [
        ...professional,
        'background_cleanup',
        'subject_isolation',
        'studio_background_options',
        'face_cleanup_subtle',
        'multiple_aspect_ratios',
      ];
    case 'professional_pro':
      return [
        ...professional_plus,
        'logo_watermarking',
        'position_presets',
        'opacity_control',
        'branded_overlay',
      ];
    default:
      return [];
  }
}
```

### Processing Count Logic

**Rule**: Count increments ONLY when AI processing is triggered, not on previews

```dart
Future<void> startEnhancement(String listingId, String imageId) async {
  emit(EnhancementLoading());
  
  try {
    // IMPORTANT: Record attempt BEFORE calling API
    // This handles the case where API fails after counting
    await quotaManager.recordEnhancementAttempt(listingId);
    
    final response = await photoEnhancementService.enhance(
      listingId: listingId,
      imageId: imageId,
      category: selectedCategory, // user-selected
    );
    
    emit(EnhancementReady(
      originalImageUrl: response.originalUrl,
      enhancedImageUrl: response.enhancedUrl,
      specs: response.specs,
    ));
  } on QuotaExceededException {
    emit(QuotaExceeded(remaining: 0));
  } on OfflineException {
    emit(OfflineError());
  } catch (e) {
    emit(EnhancementError(message: e.toString()));
  }
}
```

### Edge Cases & Handling

| Edge Case | Behavior | UX |
|-----------|----------|-----|
| **User enhances, then deletes original** | Enhanced variant orphaned; can still view/delete | "Original image deleted. Variant still available." |
| **User re-uploads same image** | Treated as new image; quota resets for this new ID | No special handling needed |
| **Enhancement succeeds, but save fails** | Variant stored in temp cache; retry prompt | "Save failed. Retry?" |
| **Offline during processing** | Queue stored locally; retry when online | "Queued. Will process when online." |
| **Subscription downgraded mid-month** | Can still view enhanced images; cannot create new ones | "Feature unavailable on your current plan." |
| **Month boundary (e.g., Feb 28 → Mar 1)** | Quota auto-resets at midnight UTC | No action needed; automatic |
| **User hits quota on last image** | Button disabled; "Limit reached next month" msg | Clear messaging |
| **Enhance button + offline + no cache** | Disabled state | "Internet required. Offline mode active." |

---

## COPY & MESSAGING

### Entry Point Copy

```
[Button Text]
"✨ Enhance photo (Professional)"

[Subtitle if on hover]
"AI optimization for lighting, clarity, framing"

[Tier indicator if non-subscriber]
"✨ Enhance photo (Professional)"
```

### Category Selection

```
Title:
"What are you enhancing?"

Subtitle:
"Select category for best results"

Product:
"📷 Product Photo"
Subtext: "Objects, items, merchandise"

Service:
"🏢 Service Environment"
Subtext: "Business space, setup"

Person:
"👤 Person / Service Provider"
Subtext: "Headshots, professional photo"
```

### Processing State

```
Title:
"Enhancing your photo..."

Message:
"AI is optimizing lighting, clarity, and framing..."

Progress indicator:
"45% (approx. X seconds remaining)"
```

### Before/After Title

```
"AI Enhancement Preview"

Subtitle:
"Drag slider to compare improvements"
```

### Spec Checklist

```
Lighting       ✓ Optimized
Clarity        ✓ Sharpened
Framing        ✓ Auto-cropped
Background     ✓ Neutralized (Pro+ only)
Subject        ✓ Isolated (Pro+ only)
```

### Approval Actions

```
[Secondary Button (Left)]
"Discard"

[Primary Button (Right)]
"Approve & Save"

Post-save message:
"✓ Enhanced image saved. Original always available."
```

### Quota Indicator

```
Default:
"Remaining: 7 of 10 this month"

At 9/10:
"Remaining: 1 of 10 this month"

At 10/10:
"Monthly limit reached"
```

### Limit Reached Modal

```
Title:
"Monthly limit reached"

Icon:
"📊"

Message:
"You've used all 10 AI enhancements for this listing this month"

Countdown:
"Limit resets: March 1, 2026 (23 days remaining)"

Suggestions:
"💡 What you can do:
• Continue using this enhanced version
• Edit or delete existing enhancements
• Enhance a different listing
• Wait for reset next month"

Footer:
"ℹ️ Limits apply per listing per month to prevent abuse."

CTA:
[See upgrade options ➜]  (links to Pro+ pricing)
```

### Upsell: Non-Subscriber

```
Headline:
"⭐ Unlock AI Photo Enhancement"

Subheading:
"Professional Subscription"

Body:
"Get AI-powered tools to make your listings stand out:"

Features:
✓ Smart lighting optimization
✓ Auto-crop & framing
✓ Clarity enhancement
✓ Background blur (Pro+ feature)
✓ Up to 10 per listing / month

Pricing box:
"Professional   $9.99 / month
(Includes all premium seller tools)

[Subscribe]"

Secondary:
"Already subscribed?
[Refresh Subscription Status]"

Dismiss:
"[Maybe Later]"
```

### Error: Offline

```
Icon: 🔌

Title:
"Cannot enhance (offline)"

Message:
"You need internet to use AI enhancement features.
Please reconnect and try again."

Action:
"[OK]" or "[Retry]"
```

### Error: Processing Failed

```
Icon: ⚠️

Title:
"Enhancement failed"

Message:
"We couldn't process this image.
Check your internet & try again."

Actions:
"[Retry] [Use Original]"
```

### Success Message (After Save)

```
Icon: ✓

Message:
"Enhanced image saved! 
Original always accessible.
7 of 10 refinements remaining."
```

### Disclosure Badge (On Listing)

```
Small label on enhanced image thumbnail:

"🔍 ENHANCED FOR CLARITY"

Font: Small, subtle
Position: Bottom-left corner of image
Background: Semi-transparent black (20%)
Text: White
```

---

## TECHNICAL CONSIDERATIONS

### Firebase Cloud Function (Pseudo-code)

```typescript
// Backend: enhance-photo.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as vision from '@google-cloud/vision'; // Google Vision API

const visionClient = new vision.ImageAnnotatorClient();

export const enhancePhoto = functions.https.onCall(async (data, context) => {
  const { listingId, imageId, category, imageUrl } = data;
  const uid = context.auth?.uid;

  // 1. Verify user authentication
  if (!uid) throw new functions.https.HttpsError('unauthenticated', '');

  // 2. Verify user subscription
  const userDoc = await admin.firestore()
    .collection('users').doc(uid).get();
  const tier = userDoc.data()?.subscriptionTier;
  
  if (!['professional', 'professional_plus', 'professional_pro'].includes(tier)) {
    throw new functions.https.HttpsError('permission-denied', 'Not subscribed');
  }

  // 3. Verify quota
  const listingDoc = await admin.firestore()
    .collection('listings').doc(listingId).get();
  const quota = listingDoc.data()?.enhancementQuota;
  
  const today = new Date();
  if (quota?.usedCount >= 10 && quota?.month === today.getMonth()) {
    throw new functions.https.HttpsError('resource-exhausted', 'Quota exceeded');
  }

  // 4. Download original image
  const storage = admin.storage().bucket();
  const imageBuffer = await storage.file(imageUrl).download();

  // 5. Run Google Vision API for analysis
  const [result] = await visionClient.labelDetection(imageBuffer[0]);
  const labels = result.labelAnnotations || [];

  // 6. AI Enhancement Processing
  // (This is where your actual enhancement logic goes)
  const enhancedBuffer = await performEnhancement(
    imageBuffer[0],
    category,
    tier,
    labels
  );

  // 7. Upload enhanced variant to Firebase Storage
  const variantPath = `listings/${listingId}/variants/${imageId}-enhanced-${Date.now()}.png`;
  await storage.file(variantPath).save(enhancedBuffer);
  const enhancedUrl = await storage.file(variantPath).getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
  });

  // 8. Save variant metadata to Firestore
  await admin.firestore()
    .collection('listings').doc(listingId)
    .collection('imageVariants').add({
      originalImageId: imageId,
      variantUrl: enhancedUrl[0],
      category,
      tier,
      enhancements: getEnhancementsList(tier),
      hasDisclosure: true,
      enhancedAt: admin.firestore.Timestamp.now(),
    });

  // 9. Update enhancement quota
  await admin.firestore()
    .collection('listings').doc(listingId)
    .update({
      'enhancementQuota.usedCount': admin.firestore.FieldValue.increment(1),
    });

  // 10. Log analytics event
  await admin.firestore()
    .collection('analytics_events').add({
      event: 'ai_enhance_success',
      listingId,
      category,
      tier,
      timestamp: admin.firestore.Timestamp.now(),
    });

  return {
    success: true,
    enhancedImageUrl: enhancedUrl[0],
    specs: getEnhancementsList(tier),
  };
});

function performEnhancement(
  imageBuffer: Buffer,
  category: string,
  tier: string,
  labels: any[]
): Promise<Buffer> {
  // Placeholder: implement actual enhancement
  // You'd use a library like sharp, PIL, or a specialized ML model
  
  switch (category) {
    case 'product':
      return enhanceProduct(imageBuffer, tier);
    case 'service':
      return enhanceService(imageBuffer, tier);
    case 'person':
      return enhancePerson(imageBuffer, tier);
    default:
      return Promise.resolve(imageBuffer);
  }
}

function getEnhancementsList(tier: string): string[] {
  const base = ['lighting', 'clarity', 'framing'];
  if (tier === 'professional') return base;
  if (tier === 'professional_plus')
    return [...base, 'background_cleanup', 'subject_isolation'];
  if (tier === 'professional_pro')
    return [...base, 'background_cleanup', 'subject_isolation', 'logo_watermark'];
  return [];
}
```

### Image Storage & Variants

```
Firebase Storage Structure:

gs://caribtap-storage/
└─ listings/
   └─ {listingId}/
      ├─ images/
      │  ├─ {imageId}.png (Original)
      │  ├─ {imageId}.png (Original)
      │  └─ ...
      └─ variants/
         ├─ {imageId}-enhanced-1708099200000.png
         ├─ {imageId}-enhanced-1708099320000.png
         └─ ...

Retention:
- Original images: Keep indefinitely (always restorable)
- Enhanced variants: Keep for listing lifetime
- Deleted listings: Delete variants after 30-day grace period
```

---

## ANALYTICS & METRICS

### Events to Track

```
1. ai_enhance_attempt
   ├─ listingId
   ├─ category (product|service|person)
   ├─ tier (professional|professional_plus|professional_pro)
   ├─ status (started|success|failure)
   └─ timestamp

2. ai_enhance_approval
   ├─ listingId
   ├─ imageId
   ├─ variantId
   ├─ category
   ├─ tier
   └─ timestamp

3. ai_enhance_discard
   ├─ listingId
   ├─ imageId
   ├─ reason (user_choice|offline|timeout)
   └─ timestamp

4. listing_conversion_after_enhancement
   ├─ listingId
   ├─ views (count)
   ├─ saves (count)
   ├─ chats (count)
   ├─ daysAfterEnhancement
   └─ timestamp

5. ai_enhance_quota_limit
   ├─ listingId
   ├─ tier
   └─ timestamp

6. ai_enhance_upsell_click
   ├─ userId
   ├─ fromUpsellModal (true|false)
   └─ timestamp
```

### KPIs

- % of Professional subscribers using enhancement feature
- Avg. enhancement attempts per listing per month
- Enhancement approval rate
- Listing views/saves/chats uplift (30 days post-enhancement)
- Tier distribution among enhancement users
- Quota limit hit rate

---

## CONSTRAINTS & NON-NEGOTIABLES

✅ **DO:**
- Preserve original image always
- Show disclosure badge on enhanced images
- Require explicit user approval before saving
- Enforce 10/month per listing limit
- Block non-Professional subscribers
- Handle offline gracefully
- Show clear quota remaining

❌ **DON'T:**
- Add fake objects/props to images
- Change shapes, sizes, or distort subjects
- Replace faces or alter age/identity
- Enlarge spaces or exaggerate dimensions
- Auto-save enhancements without approval
- Allow cross-listing quota sharing
- Display misleading enhancement descriptions

---

## ROLLOUT STRATEGY

### Phase 1: Beta (5% of Professional sellers)
- Feature flag: `ai_photo_enhancement_beta`
- Monitor error rates, processing latency
- Collect user feedback via in-app survey
- Iteration on UX based on feedback

### Phase 2: Gradual Rollout (50% → 100%)
- Feature flag: `ai_photo_enhancement_enabled`
- Monitor quota abuse patterns
- Adjust limits if needed
- Performance optimizations

### Phase 3: Upsell Campaign
- Email: "New Pro Feature: AI Photo Enhancement"
- In-app banner: Feature preview for free/basic tiers
- Marketplace highlight: "Enhanced listings get more attention"

---

## SUCCESS METRICS (30-Day Target)

- 15% of Professional tiers using at least 1 enhancement
- 60% approval rate (approved / attempts)
- +12% avg. views on enhanced listings (vs. baseline)
- <5% error rate on enhancement processing
- <10% quota abuse incidents

---

## APPENDIX: Example User Journey

**Seller "Jane" (Professional tier, product photos)**

```
1. Jane creates new listing for handmade jewelry
2. Uploads 4 product photos
3. On image 1, sees CTA: "✨ Enhance photo (Professional)"
4. Taps [Enhance]
5. Selects "Product Photo" category
6. Sees loading spinner (Processing...) → 45%
7. Before/After comparison appears
   - Lighting: ✓ Optimized
   - Clarity: ✓ Sharpened  
   - Framing: ✓ Auto-cropped
8. Jane drags slider left/right to compare
9. Taps [Approve & Save]
10. ✓ Enhanced image saved. 9 of 10 remaining.
11. Repeats for images 2 & 3
12. On image 4, sees: "Monthly limit reached. Limit resets March 1."
13. Jane publishes listing with 3 enhanced images
14. 7 days later: Listing gets 24% more views than baseline
15. Jane considers upgrading to Professional+ for background cleanup

✓ End result: Professional images, happy buyer, repeat seller
```

---

## END OF DESIGN DOCUMENT
