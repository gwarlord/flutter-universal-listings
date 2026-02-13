# Multi-Location Brands - Cloud Functions Setup

This document provides the Cloud Functions (callables) needed for the multi-location brands feature.

## Required Cloud Functions

All of these should be placed in your `functions/` directory alongside existing functions.

### 1. createBrand

Creates a new brand owned by the calling user.

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const createBrand = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to create a brand.',
    );
  }

  const uid = context.auth.uid;
  const { name, logoUrl, description } = data;

  // Validate required fields
  if (!name || typeof name !== 'string' || name.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Brand name is required.',
    );
  }

  try {
    const db = admin.firestore();
    
    // Optional: Check if user is Premium (RevenueCat integration)
    // const user = await admin.auth().getUser(uid);
    // const isAdmin = await checkIfAdmin(uid);
    // if (!isAdmin && !isPremium) {
    //   throw new functions.https.HttpsError(
    //     'permission-denied',
    //     'Brands are a Premium feature.',
    //   );
    // }

    const brandRef = db.collection('brands').doc();
    await brandRef.set({
      name: name.trim(),
      logoUrl: logoUrl || null,
      description: description || null,
      ownerUid: uid,
      isVerified: false,
      freshnessExempt: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { brandId: brandRef.id, success: true };
  } catch (error) {
    console.error('Error creating brand:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create brand',
    );
  }
});
```

### 2. updateBrand

Updates a brand's details. Admin-only for isVerified and freshnessExempt.

```typescript
export const updateBrand = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.',
    );
  }

  const uid = context.auth.uid;
  const { brandId, patch } = data;

  if (!brandId || typeof brandId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Brand ID is required.',
    );
  }

  try {
    const db = admin.firestore();
    const brandRef = db.collection('brands').doc(brandId);
    const brandSnap = await brandRef.get();

    if (!brandSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Brand not found.',
      );
    }

    const brand = brandSnap.data() as any;
    const isAdmin = await checkIfAdmin(uid);

    // Owner and admin can update; only admin can set isVerified/freshnessExempt
    if (brand.ownerUid !== uid && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not have permission to update this brand.',
      );
    }

    // Check for admin-only fields
    if ((patch.isVerified !== undefined || patch.freshnessExempt !== undefined) && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only admins can modify isVerified or freshnessExempt.',
      );
    }

    const updateData = {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await brandRef.update(updateData);
    return { success: true };
  } catch (error) {
    console.error('Error updating brand:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update brand',
    );
  }
});
```

### 3. linkListingToBrand

Links a listing to a brand.

```typescript
export const linkListingToBrand = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.',
    );
  }

  const uid = context.auth.uid;
  const { listingId, brandId, locationLabel } = data;

  if (!listingId || !brandId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Listing ID and Brand ID are required.',
    );
  }

  try {
    const db = admin.firestore();
    const isAdmin = await checkIfAdmin(uid);

    // Verify listing exists and user owns it
    const listingRef = db.collection('listings').doc(listingId);
    const listingSnap = await listingRef.get();

    if (!listingSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Listing not found.',
      );
    }

    const listing = listingSnap.data() as any;
    if (listing.authorID !== uid && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not own this listing.',
      );
    }

    // Verify brand exists
    const brandRef = db.collection('brands').doc(brandId);
    const brandSnap = await brandRef.get();

    if (!brandSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Brand not found.',
      );
    }

    const brand = brandSnap.data() as any;

    // User must own the brand or be admin
    if (brand.ownerUid !== uid && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not own this brand.',
      );
    }

    // Link listing to brand
    await listingRef.update({
      brandId: brandId,
      locationLabel: locationLabel || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error('Error linking listing to brand:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to link listing to brand',
    );
  }
});
```

### 4. unlinkListingFromBrand

Removes a listing from its brand.

```typescript
export const unlinkListingFromBrand = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.',
    );
  }

  const uid = context.auth.uid;
  const { listingId } = data;

  if (!listingId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Listing ID is required.',
    );
  }

  try {
    const db = admin.firestore();
    const isAdmin = await checkIfAdmin(uid);

    // Verify listing exists and user owns it
    const listingRef = db.collection('listings').doc(listingId);
    const listingSnap = await listingRef.get();

    if (!listingSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Listing not found.',
      );
    }

    const listing = listingSnap.data() as any;
    if (listing.authorID !== uid && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not own this listing.',
      );
    }

    // Unlink from brand
    await listingRef.update({
      brandId: admin.firestore.FieldValue.delete(),
      locationLabel: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error('Error unlinking listing from brand:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to unlink listing from brand',
    );
  }
});
```

### 5. deleteBrand

Deletes a brand (owner or admin only). Optionally unlinks all listings.

```typescript
export const deleteBrand = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.',
    );
  }

  const uid = context.auth.uid;
  const { brandId, unlinkListings = true } = data;

  if (!brandId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Brand ID is required.',
    );
  }

  try {
    const db = admin.firestore();
    const isAdmin = await checkIfAdmin(uid);

    const brandRef = db.collection('brands').doc(brandId);
    const brandSnap = await brandRef.get();

    if (!brandSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Brand not found.',
      );
    }

    const brand = brandSnap.data() as any;
    if (brand.ownerUid !== uid && !isAdmin) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'You do not own this brand.',
      );
    }

    // Optionally unlink all listings
    if (unlinkListings) {
      const listingsRef = db.collection('listings');
      const listingsSnap = await listingsRef.where('brandId', '==', brandId).get();
      const batch = db.batch();

      listingsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          brandId: admin.firestore.FieldValue.delete(),
          locationLabel: admin.firestore.FieldValue.delete(),
        });
      });

      await batch.commit();
    }

    // Delete brand
    await brandRef.delete();

    return { success: true };
  } catch (error) {
    console.error('Error deleting brand:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to delete brand',
    );
  }
});
```

### Helper: checkIfAdmin

Add this helper function to your functions codebase:

```typescript
async function checkIfAdmin(uid: string): Promise<boolean> {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(uid).get();
    return userDoc.data()?.isAdmin === true;
  } catch (error) {
    return false;
  }
}
```

## Firestore Security Rules

Add these rules to your `firestore.rules`:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Brands collection
    match /brands/{brandId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth.uid == resource.data.ownerUid || isAdmin();
      allow delete: if request.auth.uid == resource.data.ownerUid || isAdmin();
    }
    
    // Listings - allow updating brandId if user owns listing and brand
    match /listings/{listingId} {
      allow read: if true;
      allow write: if request.auth.uid == resource.data.authorID || isAdmin();
    }
    
    // Helper function
    function isAdmin() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
    }
  }
}
```

## Firestore Indexes

You'll need the following composite index for efficient querying:

**Collection:** `listings`
**Fields:**
- `brandId` (Ascending)
- `createdAt` (Descending)

This can be created from the Firestore Console or added to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "listings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "brandId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

## Testing Steps

1. **Create Brand**
   - Call `createBrand({ name: "KFC", logoUrl: "https://...", description: "..." })`
   - Verify brand created with ownerUid = current user

2. **Link Multiple Listings**
   - Call `linkListingToBrand({ listingId: "listing1", brandId, locationLabel: "KFC – Maraval" })`
   - Call `linkListingToBrand({ listingId: "listing2", brandId, locationLabel: "KFC – Port of Spain" })`

3. **Verify Brand Locations**
   - Query `listings` where `brandId == brandId`
   - Should return both listings

4. **Test Admin Features**
   - Call `updateBrand({ brandId, patch: { isVerified: true, freshnessExempt: true } })` as admin
   - Should succeed
   - Try as non-admin user
   - Should fail with permission-denied

5. **Test Location Discovery**
   - Open listing 1 detail
   - Should show "KFC – Port of Spain" as another location
   - Tap to navigate to listing 2
