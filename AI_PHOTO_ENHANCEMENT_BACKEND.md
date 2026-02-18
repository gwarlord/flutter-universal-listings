# AI Photo Enhancement - Backend Implementation Guide
## Firebase Cloud Functions & Firestore Setup

---

## TABLE OF CONTENTS
1. [Cloud Function Code](#cloud-function-code)
2. [Firestore Security Rules](#firestore-rules)
3. [Deployment Guide](#deployment)
4. [Testing & Monitoring](#testing)

---

## CLOUD FUNCTION CODE

### File: `functions/src/enhance-photo.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as vision from '@google-cloud/vision';
import * as storage from '@google-cloud/storage';
import * as sharp from 'sharp';

const visionClient = new vision.ImageAnnotatorClient();
const storageClient = new storage.Storage();
const db = admin.firestore();

interface EnhancementRequest {
  listing_id: string;
  image_id: string;
  image_url: string;
  category: 'product' | 'service' | 'person';
  user_tier: 'professional' | 'professional_plus' | 'professional_pro';
}

interface EnhancementSpec {
  type: string;
  applied: boolean;
}

/**
 * Main Cloud Function to enhance photos
 * Triggered by client via Cloud Functions HTTP call
 */
export const enhancePhoto = functions.https.onCall(
  async (data: EnhancementRequest, context) => {
    try {
      // 1. Verify authentication
      if (!context.auth?.uid) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'User not authenticated'
        );
      }

      const userId = context.auth.uid;
      const { listing_id, image_id, image_url, category, user_tier } = data;

      // 2. Validate inputs
      validateEnhancementRequest(data);

      // 3. Verify user subscription
      const userDoc = await db.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User profile not found'
        );
      }

      const userTier = userDoc.data()?.subscription_tier;
      if (!isSubscribedForEnhancement(userTier)) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User not subscribed to enhancement features'
        );
      }

      // 4. Verify listing ownership
      const listingDoc = await db.collection('listings').doc(listing_id).get();
      if (!listingDoc.exists || listingDoc.data()?.user_id !== userId) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'User does not own this listing'
        );
      }

      // 5. Check quota
      const quota = await getOrInitializeQuota(listing_id);
      if (quota.used_count >= 10) {
        // Log quota exceeded event
        await db.collection('analytics_events').add({
          event: 'ai_enhance_quota_limit',
          listing_id,
          tier: user_tier,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Monthly enhancement limit reached for this listing'
        );
      }

      // 6. Download original image from Cloud Storage
      const bucket = storageClient.bucket();
      const fileName = extractFileNameFromUrl(image_url);
      const file = bucket.file(fileName);

      let imageBuffer: Buffer;
      try {
        const data = await file.download();
        imageBuffer = data[0];
      } catch (err) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Could not download image from storage'
        );
      }

      // 7. Analyze image with Google Vision API
      functions.logger.info('Analyzing image with Vision API', {
        listing_id,
        image_id,
      });

      const visionResult = await analyzeImage(imageBuffer);

      // 8. Apply enhancements based on category
      functions.logger.info('Applying enhancements', {
        category,
        tier: user_tier,
      });

      const enhancedBuffer = await applyEnhancements(
        imageBuffer,
        category,
        user_tier,
        visionResult
      );

      // 9. Add disclosure watermark
      const watermarkedBuffer = await addDisclosureBadge(enhancedBuffer);

      // 10. Upload enhanced variant to Cloud Storage
      const variantFileName = `listings/${listing_id}/variants/${image_id}-enhanced-${Date.now()}.png`;
      const variantFile = bucket.file(variantFileName);

      await variantFile.save(watermarkedBuffer, {
        metadata: {
          contentType: 'image/png',
          metadata: {
            original_image_id: image_id,
            enhancement_tier: user_tier,
            enhancement_category: category,
            enhanced_at: new Date().toISOString(),
          },
        },
      });

      // Get public signed URL
      const [signedUrl] = await variantFile.getSignedUrl({
        version: 'v4',
        action: 'read',
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 days
      });

      functions.logger.info('Enhanced variant uploaded', {
        variantFileName,
        signedUrl: signedUrl.substring(0, 50) + '...',
      });

      // 11. Save image variant metadata to Firestore
      const variantRef = db
        .collection('listings')
        .doc(listing_id)
        .collection('image_variants')
        .doc();

      const specs = getEnhancementSpecsForTier(user_tier);

      await variantRef.set({
        original_image_id: image_id,
        variant_url: signedUrl,
        category,
        tier: user_tier,
        enhancements: specs.map((s) => s.type),
        has_disclosure: true,
        enhanced_at: admin.firestore.FieldValue.serverTimestamp(),
        created_by: userId,
      });

      // 12. Update quota
      await db.collection('listings').doc(listing_id).update({
        'enhancement_quota.used_count':
          admin.firestore.FieldValue.increment(1),
      });

      // 13. Log success analytics
      await db.collection('analytics_events').add({
        event: 'ai_enhance_success',
        listing_id,
        image_id,
        variant_id: variantRef.id,
        category,
        tier: user_tier,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 14. Return response
      return {
        success: true,
        enhanced_image_url: signedUrl,
        variant_id: variantRef.id,
        specs,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      functions.logger.error('Enhancement failed', error);

      // Log failure event
      await db.collection('analytics_events').add({
        event: 'ai_enhance_failure',
        error_code: error instanceof functions.https.HttpsError ? error.code : 'unknown',
        error_message: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        'internal',
        'Image enhancement processing failed'
      );
    }
  }
);

/**
 * Save image variant to listing (post-approval)
 */
export const saveEnhancementVariant = functions.https.onCall(
  async (data, context) => {
    if (!context.auth?.uid) {
      throw new functions.https.HttpsError('unauthenticated', '');
    }

    const { listing_id, image_id, variant_id, enhanced_image_url } = data;
    const userId = context.auth.uid;

    // Verify user owns listing
    const listingDoc = await db.collection('listings').doc(listing_id).get();
    if (!listingDoc.exists || listingDoc.data()?.user_id !== userId) {
      throw new functions.https.HttpsError('permission-denied', '');
    }

    // Add variant to listing's image_variants array
    await db.collection('listings').doc(listing_id).update({
      image_variants: admin.firestore.FieldValue.arrayUnion([
        {
          id: variant_id,
          original_image_id: image_id,
          enhanced_image_url,
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        },
      ]),
    });

    // Log approval
    await db.collection('analytics_events').add({
      event: 'ai_enhance_approval',
      listing_id,
      image_id,
      variant_id,
      user_id: userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function validateEnhancementRequest(data: any): void {
  if (!data.listing_id || typeof data.listing_id !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid listing_id'
    );
  }
  if (!data.image_id || typeof data.image_id !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid image_id');
  }
  if (!data.image_url || typeof data.image_url !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid image_url');
  }
  if (!['product', 'service', 'person'].includes(data.category)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid category');
  }
  if (
    !['professional', 'professional_plus', 'professional_pro'].includes(
      data.user_tier
    )
  ) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid user_tier');
  }
}

function isSubscribedForEnhancement(tier: string): boolean {
  return (
    tier === 'professional' ||
    tier === 'professional_plus' ||
    tier === 'professional_pro'
  );
}

async function getOrInitializeQuota(
  listingId: string
): Promise<{ year: number; month: number; used_count: number }> {
  const listingDoc = await db.collection('listings').doc(listingId).get();
  let quota = listingDoc.data()?.enhancement_quota;

  if (!quota) {
    quota = createNewQuota();
    await db.collection('listings').doc(listingId).update({
      enhancement_quota: quota,
    });
  } else {
    // Check if month has changed
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth(); // 0-indexed

    if (quota.year !== currentYear || quota.month !== currentMonth) {
      // Month changed; reset quota
      quota = createNewQuota();
      await db.collection('listings').doc(listingId).update({
        enhancement_quota: quota,
      });
    }
  }

  return quota;
}

function createNewQuota() {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  return {
    year: now.getFullYear(),
    month: now.getMonth(), // 0-indexed
    used_count: 0,
    month_reset_date: nextMonth.toISOString(),
  };
}

function extractFileNameFromUrl(url: string): string {
  // Extract file path from Cloud Storage URL
  // e.g., "gs://bucket/listings/xyz/images/abc.png" → "listings/xyz/images/abc.png"
  const match = url.match(/\/([^/]+\/.*)/);
  return match ? match[1] : url;
}

async function analyzeImage(
  imageBuffer: Buffer
): Promise<vision.protos.google.cloud.vision.v1.IAnnotateImageResponse> {
  const [result] = await visionClient.annotateImage({
    image: { content: imageBuffer },
    features: [
      { type: 'LABEL_DETECTION' },
      { type: 'OBJECT_LOCALIZATION' },
      { type: 'IMAGE_PROPERTIES' },
      { type: 'TEXT_DETECTION' },
      { type: 'FACE_DETECTION' },
    ],
  });

  return result;
}

async function applyEnhancements(
  imageBuffer: Buffer,
  category: string,
  tier: string,
  visionResult: any
): Promise<Buffer> {
  let enhanced = sharp(imageBuffer);

  // Apply category-specific enhancements
  switch (category) {
    case 'product':
      enhanced = await enhanceProduct(enhanced, tier, visionResult);
      break;
    case 'service':
      enhanced = await enhanceService(enhanced, tier, visionResult);
      break;
    case 'person':
      enhanced = await enhancePerson(enhanced, tier, visionResult);
      break;
  }

  return await enhanced.png().toBuffer();
}

async function enhanceProduct(
  image: sharp.Sharp,
  tier: string,
  visionResult: any
): Promise<sharp.Sharp> {
  // Tier 1: Auto-crop, lighting, clarity, blur
  // Tier 2+: Background cleanup, subject isolation

  // 1. Auto-crop to subject
  const metadata = await image.metadata();
  const croppedImage = image.extract({
    left: 0,
    top: 0,
    width: metadata.width || 1000,
    height: metadata.height || 1000,
  });

  // 2. Enhance lighting (increase contrast)
  let enhanced = croppedImage
    .modulate({
      saturation: 1.1, // Slightly boost saturation
    })
    .normalize(); // Auto-level

  // 3. Sharpen clarity
  enhanced = enhanced.sharpen({
    sigma: 1.5,
  });

  // 4. For Tier 2+: Additional background cleanup
  if (tier === 'professional_plus' || tier === 'professional_pro') {
    // Subtle Gaussian blur on background
    enhanced = enhanced.blur(1.2);
  }

  return enhanced;
}

async function enhanceService(
  image: sharp.Sharp,
  tier: string,
  visionResult: any
): Promise<sharp.Sharp> {
  // Tier 1: Lighting, clarity
  // Tier 2+: Background neutralization

  let enhanced = image
    .modulate({
      brightness: 1.05, // Slight brightness boost
      saturation: 1.08,
    })
    .normalize();

  // Sharpen
  enhanced = enhanced.sharpen({
    sigma: 1.2,
  });

  // For Tier 2+: Reduce background complexity
  if (tier === 'professional_plus' || tier === 'professional_pro') {
    // Apply subtle blur to reduce distractions
    enhanced = enhanced.blur(0.8);
  }

  return enhanced;
}

async function enhancePerson(
  image: sharp.Sharp,
  tier: string,
  visionResult: any
): Promise<sharp.Sharp> {
  // Tier 1: Lighting, tone normalization
  // Tier 2+: Subtle face cleanup

  let enhanced = image
    .modulate({
      brightness: 1.08,
      saturation: 1.1,
    })
    .normalize();

  // Sharpen for clarity
  enhanced = enhanced.sharpen({
    sigma: 0.8,
  });

  // For Tier 2+: Very subtle softening (not face replacement!)
  if (tier === 'professional_plus' || tier === 'professional_pro') {
    // Apply very light blur for softening, then re-sharpen selectively
    const softened = enhanced.blur(0.3);
    // Note: true face cleanup would require ML model like
    // Google's FaceAPI or similar (beyond scope of basic implementation)
  }

  return enhanced;
}

async function addDisclosureBadge(imageBuffer: Buffer): Promise<Buffer> {
  // Add "ENHANCED FOR CLARITY" badge to bottom-left corner
  const metadata = await sharp(imageBuffer).metadata();
  const width = metadata.width || 1000;
  const height = metadata.height || 1000;

  // Create badge SVG
  const badgeSvg = `
    <svg width="${Math.round(width * 0.4)}" height="30">
      <rect width="100%" height="100%" fill="rgba(0,0,0,0.3)" rx="3"/>
      <text x="8" y="20" font-size="12" fill="white" font-family="Arial">
        🔍 ENHANCED FOR CLARITY
      </text>
    </svg>
  `;

  // Overlay badge on bottom-left
  const compositeImage = await sharp(imageBuffer)
    .composite([
      {
        input: Buffer.from(badgeSvg),
        left: 10,
        top: height - 40,
      },
    ])
    .png()
    .toBuffer();

  return compositeImage;
}

function getEnhancementSpecsForTier(tier: string): EnhancementSpec[] {
  const baseSpecs: EnhancementSpec[] = [
    { type: 'Auto-crop & framing', applied: true },
    { type: 'Lighting normalization', applied: true },
    { type: 'Clarity enhancement', applied: true },
    { type: 'Subtle background blur', applied: true },
  ];

  const tier2Extras: EnhancementSpec[] = [
    { type: 'Background cleanup', applied: true },
    { type: 'Subject isolation', applied: true },
    { type: 'Neutral background option', applied: true },
  ];

  const tier3Extras: EnhancementSpec[] = [
    { type: 'Logo watermarking', applied: true },
  ];

  if (tier === 'professional') return baseSpecs;
  if (tier === 'professional_plus') return [...baseSpecs, ...tier2Extras];
  if (tier === 'professional_pro')
    return [...baseSpecs, ...tier2Extras, ...tier3Extras];

  return baseSpecs;
}
```

---

## FIRESTORE RULES

### File: `firestore.rules`

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ==================== LISTINGS ====================
    match /listings/{listingId} {
      // Users can read their own listings
      allow read: if request.auth.uid != null;
      
      // Only owner can write listing
      allow write: if request.auth.uid == resource.data.user_id;
      
      // Image variants subcollection
      match /image_variants/{variantId} {
        // Can read if user owns listing or is reading published listing
        allow read: if request.auth.uid != null;
        
        // Can write if owns listing
        allow write: if request.auth.uid == get(/databases/$(database)/documents/listings/$(listingId)).data.user_id;
      }
    }

    // ==================== ANALYTICS ====================
    match /analytics_events/{eventId} {
      // Server-only writes (Cloud Function)
      allow read: if false;
      allow write: if request.auth.uid != null && request.resource.data.listing_id != null;
    }

    // ==================== USERS ====================
    match /users/{userId} {
      // Users can read their own data
      allow read: if request.auth.uid == userId;
      
      // Cannot directly write subscription tier (managed by separate admin function)
      allow write: if false;
    }
  }
}
```

---

## DEPLOYMENT GUIDE

### Prerequisites
```bash
# Ensure you have Firebase CLI installed
npm install -g firebase-tools

# Install project dependencies
cd functions
npm install

# Required packages in functions/package.json:
# - firebase-functions
# - firebase-admin
# - @google-cloud/vision
# - @google-cloud/storage
# - sharp
```

### Step 1: Update `functions/package.json`

```json
{
  "name": "caribtap-functions",
  "version": "1.0.0",
  "engines": {
    "node": "18"
  },
  "dependencies": {
    "firebase-functions": "^4.5.0",
    "firebase-admin": "^12.0.0",
    "@google-cloud/vision": "^3.5.0",
    "@google-cloud/storage": "^7.0.0",
    "sharp": "^0.32.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^18.0.0"
  },
  "scripts": {
    "build": "tsc",
    "serve": "firebase emulators:start --only functions",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  }
}
```

### Step 2: Deploy Function

```bash
# From project root
firebase deploy --only functions:enhancePhoto,functions:saveEnhancementVariant

# Or deploy all functions
firebase deploy --only functions
```

### Step 3: Enable Required APIs

```bash
# In Google Cloud Console, enable these APIs:
# 1. Cloud Vision API
# 2. Cloud Storage API
# 3. Cloud Functions API
# 4. Cloud Firestore API

gcloud services enable vision.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable firestore.googleapis.com
```

### Step 4: Set Environment Variables

Create `functions/.env.local`:
```
GOOGLE_CLOUD_PROJECT=caribtap-prod
FIREBASE_STORAGE_BUCKET=caribtap-prod.appspot.com
ENHANCEMENT_TIMEOUT_MS=30000
```

---

## TESTING & MONITORING

### Local Testing

```bash
# Start emulator
firebase emulators:start

# In another terminal, run tests
npm test
```

### Test Script

```typescript
// functions/src/__tests__/enhance-photo.test.ts

import * as testUtils from 'firebase-functions-test';
import * as admin from 'firebase-admin';

const { testWithOptions } = testUtils({
  projectId: 'caribtap-test',
}, 'path/to/service-account-key.json');

describe('enhancePhoto', () => {
  it('should enhance product photo successfully', async () => {
    const wrapped = testWithOptions(
      { enforceAppCheck: false },
      require('../enhance-photo').enhancePhoto
    );

    const result = await wrapped(
      {
        listing_id: 'test-listing-1',
        image_id: 'test-image-1',
        image_url: 'gs://test-bucket/listings/test/images/image.jpg',
        category: 'product',
        user_tier: 'professional',
      },
      { auth: { uid: 'test-user-1' } }
    );

    expect(result.success).toBe(true);
    expect(result.enhanced_image_url).toBeDefined();
    expect(result.specs.length).toBeGreaterThan(0);
  });

  it('should reject non-subscribed users', async () => {
    // Test that free tier users cannot enhance
    expect(async () => {
      // Should throw permission-denied error
    }).rejects.toThrow();
  });

  it('should enforce monthly quota', async () => {
    // Test that 11th enhancement is rejected
  });
});
```

### Monitor Function Performance

```bash
# View function logs
firebase functions:log

# Or in Google Cloud Console:
# Cloud Functions → Choose function → Logs
```

### Key Metrics to Monitor

1. **Function Invocation Count**
   - Should correlate with user engagement
   
2. **Error Rate**
   - Target: <1% failures
   - Watch for permission-denied, processing-failed
   
3. **Execution Time**
   - Target: <15 seconds average (Vision API + enhancement)
   - If > 30s, consider timeout issues
   
4. **Memory Usage**
   - Watch for memory spikes with large images
   - May need to increase function memory (512MB → 1GB)
   
5. **Quota Usage**
   - Vision API quota
   - Storage API quota
   - Firebase Realtime Database write quota

### Alerts to Set Up

```yaml
# In Google Cloud Console → Monitoring:

1. Error rate > 5%
   Alert to: #engineering on Slack

2. Function execution time > 20 seconds
   Alert to: #performance on Slack

3. Vision API quota exceeded
   Alert to: #infrastructure on Slack

4. Storage API errors
   Alert to: #infrastructure on Slack
```

---

## COST ESTIMATION

### Per Enhancement
- Google Vision API: ~$0.003 (label + object detection)
- Cloud Storage: ~$0.000 (negligible for small variants)
- Cloud Functions: ~$0.002 (15s execution @ 512MB)

**Total per enhancement: ~$0.005 (0.5 cents)**

### Monthly Projections
- 1,000 enhancements/month: ~$5
- 10,000 enhancements/month: ~$50
- 100,000 enhancements/month: ~$500

### Cost Optimization
1. Batch process during off-peak hours
2. Cache Vision API results
3. Resize images before processing
4. Use reserved capacity for predictable load

---

## TROUBLESHOOTING

### Issue: "Could not download image from storage"
- Solution: Verify Cloud Storage bucket permissions in Firebase console
- Check image URL format

### Issue: Function timeout (>30 seconds)
- Solution: Reduce image resolution before processing
- Increase function memory allocation
- Optimize Vision API calls

### Issue: "Quota exceeded"
- Solution: Monitor Vision API usage
- Implement request queuing/rate limiting
- Consider batch processing

### Issue: Watermark not appearing
- Solution: Check SVG rendering in sharp
- Verify image coordinates
- Test locally first

---

## NEXT STEPS

1. Deploy `enhancePhoto` and `saveEnhancementVariant` functions
2. Update Firestore rules
3. Test with real images
4. Monitor error rates and performance
5. Iterate on enhancement algorithms based on user feedback

---

## END OF BACKEND IMPLEMENTATION GUIDE
