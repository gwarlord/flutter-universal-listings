"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteBrand = exports.unlinkListingFromBrand = exports.linkListingToBrand = exports.updateBrand = exports.createBrand = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
// Get Firestore FieldValue for easier use
const fieldValue = admin.firestore.FieldValue;
// Helper function to check if user is admin
async function checkIfAdmin(uid) {
    try {
        const db = admin.firestore();
        const userDoc = await db.collection("users").doc(uid).get();
        return userDoc.data()?.isAdmin === true;
    }
    catch (error) {
        return false;
    }
}
// 1. Create Brand
exports.createBrand = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to create a brand.");
    }
    const uid = context.auth.uid;
    const { name, logoUrl, description } = data;
    // Validate required fields
    if (!name || typeof name !== "string" || name.trim().length === 0) {
        throw new functions.https.HttpsError("invalid-argument", "Brand name is required.");
    }
    try {
        const db = admin.firestore();
        const brandRef = db.collection("brands").doc();
        await brandRef.set({
            name: name.trim(),
            logoUrl: logoUrl || null,
            description: description || null,
            ownerUid: uid,
            isVerified: false,
            freshnessExempt: false,
            createdAt: fieldValue.serverTimestamp(),
            updatedAt: fieldValue.serverTimestamp(),
        });
        return { brandId: brandRef.id, success: true };
    }
    catch (error) {
        console.error("Error creating brand:", error);
        throw new functions.https.HttpsError("internal", "Failed to create brand");
    }
});
// 2. Update Brand
exports.updateBrand = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    const { brandId, patch } = data;
    if (!brandId || typeof brandId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "Brand ID is required.");
    }
    try {
        const db = admin.firestore();
        const brandRef = db.collection("brands").doc(brandId);
        const brandSnap = await brandRef.get();
        if (!brandSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Brand not found.");
        }
        const brand = brandSnap.data();
        const isAdmin = await checkIfAdmin(uid);
        // Owner and admin can update; only admin can set isVerified/freshnessExempt
        if (brand.ownerUid !== uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "You do not have permission to update this brand.");
        }
        // Check for admin-only fields
        if ((patch.isVerified !== undefined || patch.freshnessExempt !== undefined) &&
            !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "Only admins can modify isVerified or freshnessExempt.");
        }
        const updateData = {
            ...patch,
            updatedAt: fieldValue.serverTimestamp(),
        };
        await brandRef.update(updateData);
        return { success: true };
    }
    catch (error) {
        console.error("Error updating brand:", error);
        throw new functions.https.HttpsError("internal", "Failed to update brand");
    }
});
// 3. Link Listing to Brand
exports.linkListingToBrand = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    const { listingId, brandId, locationLabel } = data;
    if (!listingId || !brandId) {
        throw new functions.https.HttpsError("invalid-argument", "Listing ID and Brand ID are required.");
    }
    try {
        const db = admin.firestore();
        const isAdmin = await checkIfAdmin(uid);
        // Verify listing exists and user owns it
        const listingRef = db.collection("listings").doc(listingId);
        const listingSnap = await listingRef.get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found.");
        }
        const listing = listingSnap.data();
        if (listing.authorID !== uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "You do not own this listing.");
        }
        // Verify brand exists
        const brandRef = db.collection("brands").doc(brandId);
        const brandSnap = await brandRef.get();
        if (!brandSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Brand not found.");
        }
        const brand = brandSnap.data();
        // User must own the brand or be admin
        if (brand.ownerUid !== uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "You do not own this brand.");
        }
        // Link listing to brand
        await listingRef.update({
            brandId: brandId,
            locationLabel: locationLabel || null,
            updatedAt: fieldValue.serverTimestamp(),
        });
        return { success: true };
    }
    catch (error) {
        console.error("Error linking listing to brand:", error);
        throw new functions.https.HttpsError("internal", "Failed to link listing to brand");
    }
});
// 4. Unlink Listing from Brand
exports.unlinkListingFromBrand = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    const { listingId } = data;
    if (!listingId) {
        throw new functions.https.HttpsError("invalid-argument", "Listing ID is required.");
    }
    try {
        const db = admin.firestore();
        const isAdmin = await checkIfAdmin(uid);
        // Verify listing exists and user owns it
        const listingRef = db.collection("listings").doc(listingId);
        const listingSnap = await listingRef.get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found.");
        }
        const listing = listingSnap.data();
        if (listing.authorID !== uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "You do not own this listing.");
        }
        // Unlink from brand
        await listingRef.update({
            brandId: fieldValue.delete(),
            locationLabel: fieldValue.delete(),
            updatedAt: fieldValue.serverTimestamp(),
        });
        return { success: true };
    }
    catch (error) {
        console.error("Error unlinking listing from brand:", error);
        throw new functions.https.HttpsError("internal", "Failed to unlink listing from brand");
    }
});
// 5. Delete Brand
exports.deleteBrand = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated.");
    }
    const uid = context.auth.uid;
    const { brandId, unlinkListings = true } = data;
    if (!brandId) {
        throw new functions.https.HttpsError("invalid-argument", "Brand ID is required.");
    }
    try {
        const db = admin.firestore();
        const isAdmin = await checkIfAdmin(uid);
        const brandRef = db.collection("brands").doc(brandId);
        const brandSnap = await brandRef.get();
        if (!brandSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Brand not found.");
        }
        const brand = brandSnap.data();
        if (brand.ownerUid !== uid && !isAdmin) {
            throw new functions.https.HttpsError("permission-denied", "You do not own this brand.");
        }
        // Optionally unlink all listings
        if (unlinkListings) {
            const listingsRef = db.collection("listings");
            const listingsSnap = await listingsRef
                .where("brandId", "==", brandId)
                .get();
            // Process in batches of 100 (Firestore limit)
            const batchSize = 100;
            for (let i = 0; i < listingsSnap.docs.length; i += batchSize) {
                const batch = db.batch();
                const docs = listingsSnap.docs.slice(i, i + batchSize);
                docs.forEach((doc) => {
                    batch.update(doc.ref, {
                        brandId: fieldValue.delete(),
                        locationLabel: fieldValue.delete(),
                    });
                });
                await batch.commit();
                console.log(`Unlinked batch ${Math.floor(i / batchSize) + 1}: ${docs.length} listings`);
            }
        }
        // Delete brand
        await brandRef.delete();
        console.log(`Successfully deleted brand: ${brandId}`);
        return { success: true };
    }
    catch (error) {
        console.error("Error deleting brand:", error);
        throw new functions.https.HttpsError("internal", `Failed to delete brand: ${error}`);
    }
});
