# AI Photo Enhancement - Visual Flows & Diagrams
## CaribTap User Experience & System Architecture

---

## TABLE OF CONTENTS
1. [User Flows](#user-flows)
2. [System Architecture](#system-architecture)
3. [State Diagrams](#state-diagrams)
4. [Data Flow](#data-flow)

---

## USER FLOWS

### Flow 1: Happy Path (Subscribed Seller, First Enhancement)

```
START: Listing Edit Screen
│
├─ User taps [Edit] on uploaded image
│
├─ Image Edit Modal opens
│  ├─ Shows original photo
│  ├─ Shows enhancement CTA with quota
│  │  "✨ Enhance photo (Professional)"
│  │  "Remaining: 7 of 10 this month"
│  └─ CTA is ENABLED
│
├─ User taps [Enhance]
│
├─ → Check subscription tier
│  └─ ✓ User is Professional subscriber
│
├─ → Check internet connection
│  └─ ✓ Online
│
├─ → Check quota
│  └─ ✓ Has 7 remaining
│
├─ Category Selector Modal appears
│  ├─ "📷 Product Photo"
│  ├─ "🏢 Service Environment"
│  └─ "👤 Person / Service Provider"
│
├─ User selects "Product Photo"
│
├─ Processing Indicator appears
│  ├─ Spinner with progress (45%)
│  ├─ Message: "AI is optimizing lighting, clarity, framing..."
│  └─ Duration: ~5-10 seconds
│
├─ → Cloud Function processes image
│  ├─ Downloads image from Storage
│  ├─ Analyzes with Vision API
│  ├─ Applies enhancements
│  ├─ Adds disclosure watermark
│  └─ Uploads variant to Storage
│
├─ Before/After Comparison Modal appears
│  ├─ Shows before image
│  ├─ Slider drag to compare
│  ├─ After image (enhanced)
│  ├─ Checklist of applied enhancements:
│  │  ✓ Lighting: Optimized
│  │  ✓ Clarity: Sharpened
│  │  ✓ Framing: Auto-cropped
│  └─ Disclosure badge preview
│
├─ User drags slider to compare
│
├─ User taps [Approve & Save]
│
├─ Variant saved to
│  ├─ Cloud Firestore (metadata)
│  ├─ Cloud Storage (image)
│  └─ Local model (imageVariants)
│
├─ Success feedback
│  ├─ ✓ message: "Enhanced image saved!"
│  ├─ "Remaining: 6 of 10 this month"
│  └─ Quota decremented: 7 → 6
│
├─ Modal closes
│
├─ Back to Image Edit Modal
│  └─ Shows original image with variant available
│
END: User continues editing listing
```

---

### Flow 2: Not Subscribed (Free/Basic Tier)

```
START: Listing Edit Screen
│
├─ User taps [Enhance]
│
├─ → Check subscription tier
│  └─ ✗ User is Free tier
│
├─ Tier Upsell Modal appears
│  ├─ Headline: "⭐ Unlock AI Photo Enhancement"
│  ├─ Features list:
│  │  ✓ Smart lighting optimization
│  │  ✓ Auto-crop & framing
│  │  ✓ Clarity enhancement
│  │  ... (more features)
│  ├─ Pricing box:
│  │  "Professional $9.99/month"
│  │  [Subscribe]
│  ├─ Secondary:
│  │  "Already subscribed?"
│  │  [Refresh Subscription Status]
│  └─ Dismiss: [Maybe Later]
│
├─ User taps [Subscribe]
│  └─ → Opens subscription page (separate module)
│
END: Flow continues after subscription
```

---

### Flow 3: Quota Limit Reached (10/10 Used)

```
START: Listing Edit Screen
│
├─ User taps [Enhance]
│
├─ → Check quota
│  └─ ✗ Used 10 of 10 this month
│
├─ Enhance button disabled
│  (Grayed out, non-clickable)
│
├─ Quota Indicator shows
│  "Remaining: 0 of 10 this month"
│
├─ User attempts to tap anyway
│  └─ Shows info modal
│
├─ Limit Reached Modal appears
│  ├─ Icon: 📊
│  ├─ Title: "Monthly limit reached"
│  ├─ Message: "You've used all 10 AI enhancements for this listing this month"
│  ├─ Countdown: "Limit resets: March 1, 2026 (23 days remaining)"
│  ├─ Suggestions:
│  │  • Continue using this enhanced version
│  │  • Edit or delete existing enhancements
│  │  • Enhance a different listing
│  │  • Wait for reset next month
│  ├─ Info: "ℹ️ Limits apply per listing per month"
│  └─ CTA: [See upgrade options ➜] or [OK]
│
END: User dismisses modal
```

---

### Flow 4: Processing Fails (Offline/Error)

```
START: Enhancement Processing
│
├─ User selected category
│
├─ Processing starts...
│
├─ → Check internet connection
│  └─ ✗ OFFLINE or NETWORK ERROR
│
├─ Processing Indicator stops
│
├─ Error Modal appears
│  ├─ If OFFLINE:
│  │  ├─ Icon: 🔌
│  │  ├─ Title: "Cannot enhance (offline)"
│  │  ├─ Message: "You need internet to use AI enhancement"
│  │  └─ [OK]
│  │
│  ├─ If PROCESSING FAILED:
│  │  ├─ Icon: ⚠️
│  │  ├─ Title: "Enhancement failed"
│  │  ├─ Message: "We couldn't process this image. Check your internet & try again."
│  │  ├─ [Retry] ← User can retry
│  │  └─ [Use Original] ← Fall back to original
│  │
│  └─ If OTHER ERROR:
│     ├─ Generic error message
│     ├─ [Retry] [Cancel]
│     └─ Logs error for debugging
│
├─ If [Retry]:
│  └─ → Restart processing from beginning
│
├─ If [Use Original] or [Cancel]:
│  └─ Close modal, return to image edit
│
END: User can try different image or continue
```

---

### Flow 5: Variant Management (Edit Listing)

```
START: Listing Edit → Images Tab
│
├─ Shows grid of images
│  ├─ Original image 1
│  │  └─ [Edit] [Delete] options
│  │
│  ├─ Original image 2
│  │  ├─ [Edit] shows:
│  │  │  ├─ Enhanced variant (if exists)
│  │  │  │  ├─ "ENHANCED FOR CLARITY" badge
│  │  │  │  ├─ [View] [Delete variant] [Restore]
│  │  │  ├─ Enhancement CTA
│  │  │  └─ Other edit options
│  │  └─ [Delete]
│  │
│  └─ Image 3 (no enhancement)
│     └─ [Edit] [Delete]
│
├─ User taps [View] on enhanced variant
│
├─ Before/After preview appears
│  ├─ Shows what was enhanced
│  ├─ Can see specs applied
│  └─ [Close]
│
├─ User taps [Delete variant]
│  ├─ Confirmation: "Delete enhanced version? Original kept."
│  ├─ [Delete] [Cancel]
│  └─ → Removes variant, original remains
│
├─ User taps [Restore]
│  ├─ "Restore to original?" (if they want to use original instead)
│  ├─ [Restore] [Cancel]
│  └─ → Updates listing to use original image again
│
END: Listing saved with updated images
```

---

## SYSTEM ARCHITECTURE

### High-Level System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      CARIBTAP FLUTTER APP                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          Listing Edit Screen                             │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │ Image 1    Image 2    Image 3   [Add More]          │ │   │
│  │  │  [✓✓]      [✓✓]      [✓✓]                           │ │   │
│  │  │ [Edit]    [Edit]    [Edit]                          │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  │       ↓ taps [Edit] on Image 1                             │   │
│  │  ┌─────────────────────────────────────────────────────┐ │   │
│  │  │ Image Edit Modal (Modal#1)                          │ │   │
│  │  │ - Shows original image                              │ │   │
│  │  │ - Enhance button: ✨ (with quota indicator)         │ │   │
│  │  │ - Standard edit options (crop, rotate, etc)         │ │   │
│  │  └─────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                      ↓ taps [Enhance]                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          Category Selector Modal (Modal#2)              │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │ 📷 Product Photo                                   │ │   │
│  │  │ 🏢 Service Environment                             │ │   │
│  │  │ 👤 Person / Service Provider                       │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                      ↓ selects "Product"                  │   │
│  │          Processing Indicator (Modal#3)                 │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │ [Spinner] 45% (AI is optimizing...)                │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                      ↓ (5-10 seconds)                            │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │     Before/After Comparison Modal (Modal#4)             │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │ [BEFORE] ▮▮▮▮▮▮ [AFTER]                           │ │   │
│  │  │ (Slider drag to compare)                           │ │   │
│  │  │                                                     │ │   │
│  │  │ ✓ Lighting normalization                           │ │   │
│  │  │ ✓ Clarity enhancement                              │ │   │
│  │  │ ✓ Framing optimization                             │ │   │
│  │  │                                                     │ │   │
│  │  │ [ENHANCED FOR CLARITY] badge                       │ │   │
│  │  │                                                     │ │   │
│  │  │ [Discard]           [Approve & Save]               │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────┘   │
│                 ↓ taps [Approve & Save]                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Back to Image Edit Modal                               │   │
│  │ - Original image still shown                            │   │
│  │ - ✓ Success: Enhanced image saved!                      │   │
│  │ - Quota updated: 6 of 10 remaining                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓↓↓
┌─────────────────────────────────────────────────────────────────┐
│              FIREBASE BACKEND & CLOUD STORAGE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Cloud Functions                                                 │
│  ┌──────────────────────────────────────────────────────┐       │
│  │ enhancePhoto(request)                                │       │
│  │  1. Verify authentication & subscription             │       │
│  │  2. Check quota                                      │       │
│  │  3. Download image from Cloud Storage               │       │
│  │  4. Analyze with Google Vision API                  │       │
│  │  5. Apply enhancements (sharp.js)                   │       │
│  │  6. Add disclosure watermark                         │       │
│  │  7. Upload variant to Cloud Storage                 │       │
│  │  8. Save metadata to Firestore                       │       │
│  │  9. Update quota counter                             │       │
│  │  10. Log analytics event                             │       │
│  │  11. Return signed URL to client                     │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                   │
│  Cloud Storage (gs://caribtap-storage/)                          │
│  ┌──────────────────────────────────────────────────────┐       │
│  │ listings/                                             │       │
│  │ ├─ {listingId}/                                      │       │
│  │ │  ├─ images/                  (originals)           │       │
│  │ │  │  ├─ image1.jpg                                 │       │
│  │ │  │  └─ image2.jpg                                 │       │
│  │ │  └─ variants/                (enhanced)            │       │
│  │ │     ├─ image1-enhanced-1708099200000.png          │       │
│  │ │     └─ image2-enhanced-1708099320000.png          │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                   │
│  Firestore Database                                              │
│  ┌──────────────────────────────────────────────────────┐       │
│  │ listings/                                             │       │
│  │ ├─ {listingId}/                                      │       │
│  │ │  ├─ images: [...]            (original URLs)       │       │
│  │ │  ├─ image_variants: [        (enhanced metadata)   │       │
│  │ │  │  {                                               │       │
│  │ │  │    original_image_id,                            │       │
│  │ │  │    variant_url,                                  │       │
│  │ │  │    category,                                     │       │
│  │ │  │    tier,                                         │       │
│  │ │  │    enhanced_at                                   │       │
│  │ │  │  }                                               │       │
│  │ │  │]                                                 │       │
│  │ │  └─ enhancement_quota: {                            │       │
│  │ │     used_count: 6,                                  │       │
│  │ │     month_reset_date                                │       │
│  │ │  }                                                  │       │
│  │ └─ image_variants/            (variant details)       │       │
│  │    ├─ {variantId}/                                   │       │
│  │    └─ {variantId}/                                   │       │
│  │                                                        │       │
│  │ analytics_events/             (for tracking)          │       │
│  │ ├─ ai_enhance_attempt                                │       │
│  │ ├─ ai_enhance_success                                │       │
│  │ ├─ ai_enhance_approval                               │       │
│  │ └─ ai_enhance_quota_limit                            │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                   │
│  Google Cloud Services                                           │
│  ┌──────────────────────────────────────────────────────┐       │
│  │ Vision API - Image analysis (labels, objects)        │       │
│  │ Storage API - File upload/download                   │       │
│  │ Cloud Functions API - Function execution             │       │
│  └──────────────────────────────────────────────────────┘       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

### Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    LISTING_EDIT_SCREEN                      │
│                  (uses PhotoEnhancementCubit)               │
│                                                              │
│  Lifecycle:                                                  │
│  1. initState: Load listing data, fetch quota               │
│  2. build: Render images with enhancement button           │
│  3. onTap: Trigger PhotoEnhancementCubit.startEnhancement  │
│  4. listen: Update UI based on cubit state changes         │
│  5. dispose: Clean up resources                             │
└─────────────────────────────────────────────────────────────┘
           ↑                              ↑
           │ providers/BLoC               │ state changes
           │                              │
┌──────────────────────────────────────────────────────────────┐
│           PHOTO_ENHANCEMENT_CUBIT (State Management)         │
│                                                               │
│  States:                                                      │
│  • PhotoEnhancementInitial                                   │
│  • EnhancementLoading (progress: 0-100)                      │
│  • EnhancementReady (before/after ready)                     │
│  • EnhancementApproved (saved)                               │
│  • EnhancementDiscarded                                      │
│  • EnhancementError (with error code)                        │
│  • QuotaExceeded                                             │
│  • NotSubscribed                                             │
│  • OfflineError                                              │
│                                                               │
│  Methods:                                                    │
│  • startEnhancement(...) → calls QuotaManager + Service     │
│  • approveEnhancement(...) → saves variant                  │
│  • discardEnhancement() → cancel enhancement                │
│  • reset() → back to initial state                           │
└──────────────────────────────────────────────────────────────┘
        ↑              ↑              ↑              ↑
        │              │              │              │
    Photo          Quota         Enhancement      Analytics
    Enhancement    Manager       Service          Service
    Service                       
        │              │              │              │
        └──────────────┴──────────────┴──────────────┘
                    ↓ (calls)
┌──────────────────────────────────────────────────────────────┐
│                  FIREBASE BACKEND (Cloud Functions)          │
│                                                               │
│  enhancePhoto() HTTP Callable Function                       │
│  ├─ Receives: EnhancementRequest                             │
│  ├─ Returns: EnhancementResponse                             │
│  └─ Triggers: Vision API, Storage API, writes Firestore     │
│                                                               │
│  saveEnhancementVariant() HTTP Callable Function             │
│  ├─ Receives: listingId, imageId, variantId, variantUrl    │
│  └─ Returns: { success: true }                              │
└──────────────────────────────────────────────────────────────┘

SERVICES (Flutter Client)
┌────────────────────────────────────────────────────────────────┐
│ PhotoEnhancementService                                         │
│ • enhance(request) → calls Cloud Function                       │
│ • saveVariant(...) → calls Cloud Function                       │
│ • cancels ongoing operations                                    │
│                                                                  │
│ QuotaManager                                                    │
│ • getRemainingQuota(listingId) → queries Firestore             │
│ • canEnhance(listingId) → checks 10/month limit               │
│ • recordEnhancementAttempt(listingId) → increments quota       │
│                                                                  │
│ OfflineQueueManager                                             │
│ • queueEnhancement(request) → saves to SharedPreferences       │
│ • getQueuedEnhancements() → returns queued list                │
│ • removeFromQueue(...) → deletes queue entry                   │
│                                                                  │
│ EnhancementAnalytics                                            │
│ • logEnhancementAttempt(...) → Firestore event                 │
│ • logEnhancementApproval(...) → Firestore event                │
│ • logEnhancementDiscard(...) → Firestore event                 │
│ • logQuotaLimitReached(...) → Firestore event                  │
└────────────────────────────────────────────────────────────────┘
```

---

## STATE DIAGRAMS

### Photo Enhancement Cubit State Machine

```
                          ┌─────────────────────────┐
                          │ PhotoEnhancementInitial │
                          └────────────┬────────────┘
                                       │
                    ┌──────────┬───────┴────────┬──────────┐
                    │          │                │          │
            (offline?)  (not_subscribed?)  (quota_limit?)  (internet ok?)
                    │          │                │          │
                    ↓          ↓                ↓          ↓
            ┌──────────────┐  ┌──────────────┐ ┌──────────────┐
            │ OfflineError │  │NotSubscribed │ │QuotaExceeded │
            └──────────────┘  └──────────────┘ └──────────────┘
            
            [User reconnects]  [User subscribes]  [Month resets]
            │                  │                  │
            └──────────────────┴──────────────────┘
                    │
                    ↓
            ┌──────────────────────┐
            │ EnhancementLoading   │
            │ (progress: 0% → 100%)│
            └──────────┬───────────┘
                       │
            ┌──────────┴──────────┐
            │                     │
        (success)           (error)
            │                     │
            ↓                     ↓
    ┌──────────────────┐  ┌──────────────────┐
    │ EnhancementReady │  │ EnhancementError │
    │ (before/after)   │  │ (with error msg) │
    └────────┬─────────┘  └──────────────────┘
             │
        ┌────┴────┐
        │          │
    (approve)  (discard)
        │          │
        ↓          ↓
    ┌──────────────────────┐  ┌──────────────────────┐
    │ EnhancementApproved  │  │ EnhancementDiscarded │
    │ (variant id & url)   │  │ (clean up resources) │
    └──────────┬───────────┘  └──────────┬───────────┘
               │                         │
               └────────┬────────────────┘
                        │
                    [user dismisses]
                        │
                        ↓
            ┌──────────────────────┐
            │ PhotoEnhancementInit │ ← Back to initial
            └──────────────────────┘
```

---

## DATA FLOW

### Send Enhancement Request

```
User UI (Flutter)
    │
    ├─ PhotoEnhancementCubit.startEnhancement()
    │    │
    │    ├─ emit(EnhancementLoading(0))
    │    │
    │    ├─ QuotaManager.recordEnhancementAttempt() ← COUNT RECORDED HERE
    │    │    └─ Firestore: used_count++
    │    │
    │    └─ PhotoEnhancementService.enhance()
    │         └─ Cloud Functions HTTP Callable
    │              │
    │              ├─ Functions receives JSON:
    │              │  {
    │              │    "listing_id": "abc123",
    │              │    "image_id": "img456",
    │              │    "image_url": "gs://...",
    │              │    "category": "product",
    │              │    "user_tier": "professional"
    │              │  }
    │              │
    │              ├─ Verify user auth & subscription
    │              │
    │              ├─ Download image from Cloud Storage
    │              │
    │              ├─ Google Vision API
    │              │  └─ Analyze (labels, objects, etc)
    │              │
    │              ├─ Apply enhancements (sharp.js)
    │              │
    │              ├─ Add "ENHANCED FOR CLARITY" badge
    │              │
    │              ├─ Upload variant to Cloud Storage
    │              │    └─ gs://bucket/listings/{id}/variants/{id}-enhanced.png
    │              │
    │              ├─ Save metadata to Firestore
    │              │    └─ /listings/{id}/image_variants/{variantId}
    │              │
    │              └─ Return JSON:
    │                 {
    │                   "enhanced_image_url": "signed_url",
    │                   "variant_id": "var789",
    │                   "specs": [
    │                     {"type": "lighting", "applied": true},
    │                     {"type": "clarity", "applied": true}
    │                   ],
    │                   "timestamp": "2026-02-16T..."
    │                 }
    │
    ├─ emit(EnhancementReady(
    │   originalImageUrl: "...",
    │   enhancedImageUrl: "signed_url_returned",
    │   specs: [...]
    │ ))
    │
    └─ UI displays Before/After comparison
       (ready for user approval)
```

### Save Enhancement (Approval)

```
User taps [Approve & Save]
    │
    ├─ PhotoEnhancementCubit.approveEnhancement()
    │    │
    │    ├─ emit(EnhancementLoading(50%))
    │    │
    │    └─ PhotoEnhancementService.saveVariant()
    │         └─ Cloud Functions HTTP Callable
    │              │
    │              ├─ Functions receives:
    │              │  {
    │              │    "listing_id": "abc123",
    │              │    "image_id": "img456",
    │              │    "variant_id": "var789",
    │              │    "enhanced_image_url": "signed_url",
    │              │    "category": "product",
    │              │    "user_tier": "professional"
    │              │  }
    │              │
    │              ├─ Update listing document:
    │              │    /listings/{id}.image_variants += [variantId]
    │              │
    │              └─ Return: { success: true }
    │
    ├─ EnhancementAnalytics.logEnhancementApproval()
    │    └─ Write to Firestore: analytics_events collection
    │
    ├─ emit(EnhancementApproved(
    │   variantId: "var789",
    │   enhancedImageUrl: "signed_url"
    │ ))
    │
    └─ UI shows success message
       "✓ Enhanced image saved! 6 of 10 remaining."
       (quota automatically updated by backend)
```

### Quota Check & Reset

```
User taps [Enhance]
    │
    ├─ QuotaManager.getQuota(listingId)
    │    │
    │    ├─ Query Firestore: /listings/{id}.enhancement_quota
    │    │
    │    ├─ Check current date
    │    │    │
    │    │    ├─ IF month hasn't changed:
    │    │    │  └─ Return current quota (e.g., used_count: 7)
    │    │    │
    │    │    └─ IF month HAS changed (e.g., Feb 28 → Mar 1):
    │    │       ├─ Reset quota to:
    │    │       │  {
    │    │       │    year: 2026,
    │    │       │    month: 2,  // 0-indexed (March = 2)
    │    │       │    used_count: 0,
    │    │       │    month_reset_date: April 1, 2026
    │    │       │  }
    │    │       └─ Return fresh quota (remaining: 10)
    │    │
    │    └─ Return EnhancementQuota object
    │
    ├─ Check quota.isAtLimit
    │    │
    │    ├─ IF remaining > 0:
    │    │  └─ Enable [Enhance] button, show: "7 of 10 remaining"
    │    │
    │    └─ IF remaining == 0:
    │       └─ Disable [Enhance] button, show: "Limit reached"
    │
    └─ User can proceed or see "limit reached" modal
```

---

## ERROR HANDLING FLOW

```
Enhancement Processing
    │
    ├─ Connectivity check
    │    │
    │    └─ FAIL → OfflineError
    │         │
    │         └─ Show: "🔌 Internet required"
    │            Options: [OK], [Reconnect]
    │
    ├─ Authentication check
    │    │
    │    └─ FAIL → AuthenticationError
    │         │
    │         └─ Show: "Sign in required"
    │
    ├─ Subscription check
    │    │
    │    └─ FAIL → NotSubscribed
    │         │
    │         └─ Show: Upsell modal
    │
    ├─ Quota check
    │    │
    │    └─ FAIL → QuotaExceeded
    │         │
    │         └─ Show: "Limit reached. Resets March 1."
    │
    ├─ Cloud Function call
    │    │
    │    └─ Network error → ProcessingFailedException
    │         │
    │         └─ Show: "⚠️ Enhancement failed"
    │            Options: [Retry], [Use Original]
    │
    │    └─ Invalid input → InvalidCategoryException
    │         │
    │         └─ Show: "Invalid selection"
    │            Options: [Try again]
    │
    │    └─ Function error → Generic HttpsException
    │         │
    │         └─ Show: Generic error message
    │            Options: [Retry], [Cancel]
    │
    ├─ Vision API error
    │    │
    │    └─ FAIL → ProcessingFailedException
    │         │
    │         └─ Show: "Image analysis failed"
    │            Options: [Retry], [Use Original]
    │
    ├─ Image processing error
    │    │
    │    └─ FAIL → ProcessingFailedException
    │         │
    │         └─ Show: "Enhancement couldn't be applied"
    │            Options: [Retry], [Use Original]
    │
    ├─ Storage upload error
    │    │
    │    └─ FAIL → ProcessingFailedException
    │         │
    │         └─ Show: "Couldn't save enhanced image"
    │            Options: [Retry], [Use Original]
    │
    └─ Firestore write error
         │
         └─ FAIL → ProcessingFailedException
              │
              └─ Show: "Couldn't update listing"
                 Options: [Retry], [Use Original]
```

---

## QUOTA MANAGEMENT TIMELINE

```
January 2026
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  Listing A                                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Jan 1:  enhancement_quota = {                    │   │
│  │           year: 2026,                            │   │
│  │           month: 0,    // January                │   │
│  │           used_count: 0,                         │   │
│  │           month_reset_date: Feb 1, 2026          │   │
│  │         }                                         │   │
│  │                                                  │   │
│  │ Jan 5:  [Enhance] → used_count: 0 → 1           │   │
│  │         (1 of 10 remaining)                      │   │
│  │                                                  │   │
│  │ Jan 12: [Enhance] → used_count: 1 → 2           │   │
│  │         (2 of 10 remaining)                      │   │
│  │                                                  │   │
│  │ ...                                              │   │
│  │                                                  │   │
│  │ Jan 31: [Enhance] → used_count: 9 → 10          │   │
│  │         (10 of 10 - at limit)                    │   │
│  │         [Enhance] button now DISABLED            │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
                        ↓ (midnight UTC)
│
February 2026 (Month Boundary)
┌─────────────────────────────────────────────────────────┐
│                                                          │
│  Listing A                                               │
│  ┌──────────────────────────────────────────────────┐   │
│  │ Feb 1:  [Auto-reset triggered]                   │   │
│  │                                                  │   │
│  │ enhancement_quota = {                           │   │
│  │   year: 2026,                                   │   │
│  │   month: 1,    // February                       │   │
│  │   used_count: 0,    ← RESET                      │   │
│  │   month_reset_date: Mar 1, 2026                  │   │
│  │ }                                                │   │
│  │                                                  │   │
│  │ Feb 1:  [Enhance] now ENABLED again              │   │
│  │         (10 of 10 remaining)                     │   │
│  │                                                  │   │
│  │ Feb 3:  [Enhance] → used_count: 0 → 1           │   │
│  │         (1 of 10 remaining)                      │   │
│  │                                                  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## END OF VISUAL FLOWS & DIAGRAMS

All diagrams are representative and simplified for clarity.
For complete technical details, refer to the other design documents.
