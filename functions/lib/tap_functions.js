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
exports.recomputeAllTapCounts = exports.onTapDeleted = exports.onTapCreated = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Cloud Function: Increment tap count when a tap is created
 * Triggers on: listings/{listingId}/taps/{userId} onCreate
 */
exports.onTapCreated = functions.firestore
    .document("listings/{listingId}/taps/{userId}")
    .onCreate(async (snap, context) => {
    const listingId = context.params.listingId;
    const userId = context.params.userId;
    const tapData = snap.data();
    console.log(`🚀 [onTapCreated] TRIGGERED for listing=${listingId}, user=${userId}`);
    console.log(`📝 Tap data:`, tapData);
    try {
        const listingRef = db.collection("listings").doc(listingId);
        // Use transaction to safely increment count
        await db.runTransaction(async (transaction) => {
            const listingDoc = await transaction.get(listingRef);
            if (!listingDoc.exists) {
                console.error(`❌ [onTapCreated] Listing ${listingId} not found`);
                return;
            }
            const currentTapCount = listingDoc.data()?.tapCount || 0;
            const newTapCount = currentTapCount + 1;
            const newTapBadge = computeTapBadge(newTapCount);
            console.log(`📊 [onTapCreated] Incrementing ${listingId}: ${currentTapCount} → ${newTapCount}, badge=${newTapBadge}`);
            transaction.update(listingRef, {
                tapCount: newTapCount,
                tapBadge: newTapBadge,
            });
            console.log(`✅ [onTapCreated] Updated listing ${listingId}: tapCount=${newTapCount}, tapBadge=${newTapBadge}`);
        });
    }
    catch (error) {
        console.error(`❌ [onTapCreated] Error updating tap count for listing ${listingId}:`, error);
        throw error;
    }
});
/**
 * Cloud Function: Decrement tap count when a tap is deleted
 * Triggers on: listings/{listingId}/taps/{userId} onDelete
 */
exports.onTapDeleted = functions.firestore
    .document("listings/{listingId}/taps/{userId}")
    .onDelete(async (snap, context) => {
    const listingId = context.params.listingId;
    const userId = context.params.userId;
    const tapData = snap.data();
    console.log(`🚀 [onTapDeleted] TRIGGERED for listing=${listingId}, user=${userId}`);
    console.log(`📝 Tap data:`, tapData);
    try {
        const listingRef = db.collection("listings").doc(listingId);
        // Use transaction to safely decrement count
        await db.runTransaction(async (transaction) => {
            const listingDoc = await transaction.get(listingRef);
            if (!listingDoc.exists) {
                console.error(`❌ [onTapDeleted] Listing ${listingId} not found`);
                return;
            }
            const currentTapCount = listingDoc.data()?.tapCount || 0;
            const newTapCount = Math.max(0, currentTapCount - 1); // Ensure non-negative
            const newTapBadge = computeTapBadge(newTapCount);
            console.log(`📊 [onTapDeleted] Decrementing ${listingId}: ${currentTapCount} → ${newTapCount}, badge=${newTapBadge}`);
            transaction.update(listingRef, {
                tapCount: newTapCount,
                tapBadge: newTapBadge,
            });
            console.log(`✅ [onTapDeleted] Updated listing ${listingId}: tapCount=${newTapCount}, tapBadge=${newTapBadge}`);
        });
    }
    catch (error) {
        console.error(`❌ [onTapDeleted] Error updating tap count for listing ${listingId}:`, error);
        throw error;
    }
});
/**
 * Compute tap badge based on tap count
 */
function computeTapBadge(tapCount) {
    if (tapCount >= 50)
        return "community_verified";
    if (tapCount >= 10)
        return "community_vouched";
    return "none";
}
/**
 * Admin/Maintenance function: Recompute tap counts for all listings
 * Call this manually if tap counts become out of sync
 * Usage: firebase functions:call recomputeAllTapCounts
 */
exports.recomputeAllTapCounts = functions.https.onCall(async (data, context) => {
    // Require admin authentication
    if (!context.auth?.token?.isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Only admins can recompute tap counts");
    }
    console.log("🔄 Starting tap count recomputation for all listings...");
    try {
        const listingsSnapshot = await db.collection("listings").get();
        let updatedCount = 0;
        // Process in batches for efficiency
        const batchSize = 500;
        let batch = db.batch();
        let batchCount = 0;
        for (const listingDoc of listingsSnapshot.docs) {
            const listingId = listingDoc.id;
            // Count taps for this listing
            const tapsSnapshot = await db
                .collection("listings")
                .doc(listingId)
                .collection("taps")
                .count()
                .get();
            const tapCount = tapsSnapshot.data().count || 0;
            const tapBadge = computeTapBadge(tapCount);
            // Add to batch
            batch.update(listingDoc.ref, {
                tapCount: tapCount,
                tapBadge: tapBadge,
            });
            batchCount++;
            updatedCount++;
            // Commit batch if it reaches the limit
            if (batchCount >= batchSize) {
                await batch.commit();
                batch = db.batch();
                batchCount = 0;
            }
        }
        // Commit any remaining updates
        if (batchCount > 0) {
            await batch.commit();
        }
        console.log(`✅ Tap count recomputation complete. Updated ${updatedCount} listings.`);
        return { success: true, updatedCount };
    }
    catch (error) {
        console.error("❌ Error recomputing tap counts:", error);
        throw new functions.https.HttpsError("internal", "Failed to recompute tap counts");
    }
});
