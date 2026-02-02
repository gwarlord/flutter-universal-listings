import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Cloud Function: Increment tap count when a tap is created
 * Triggers on: listings/{listingId}/taps/{userId} onCreate
 */
export const onTapCreated = functions.firestore
  .document("listings/{listingId}/taps/{userId}")
  .onCreate(async (snap, context) => {
    const listingId = context.params.listingId;
    const tapData = snap.data();

    console.log(`📍 Tap created for listing ${listingId} by user ${tapData.userId}`);

    try {
      const listingRef = db.collection("listings").doc(listingId);
      
      // Use transaction to safely increment count
      await db.runTransaction(async (transaction) => {
        const listingDoc = await transaction.get(listingRef);
        
        if (!listingDoc.exists) {
          console.error(`❌ Listing ${listingId} not found`);
          return;
        }

        const currentTapCount = listingDoc.data()?.tapCount || 0;
        const newTapCount = currentTapCount + 1;
        const newTapBadge = computeTapBadge(newTapCount);

        transaction.update(listingRef, {
          tapCount: newTapCount,
          tapBadge: newTapBadge,
        });

        console.log(`✅ Updated listing ${listingId}: tapCount=${newTapCount}, tapBadge=${newTapBadge}`);
      });
    } catch (error) {
      console.error(`❌ Error updating tap count for listing ${listingId}:`, error);
    }
  });

/**
 * Cloud Function: Decrement tap count when a tap is deleted
 * Triggers on: listings/{listingId}/taps/{userId} onDelete
 */
export const onTapDeleted = functions.firestore
  .document("listings/{listingId}/taps/{userId}")
  .onDelete(async (snap, context) => {
    const listingId = context.params.listingId;
    const tapData = snap.data();

    console.log(`📍 Tap deleted for listing ${listingId} by user ${tapData.userId}`);

    try {
      const listingRef = db.collection("listings").doc(listingId);
      
      // Use transaction to safely decrement count
      await db.runTransaction(async (transaction) => {
        const listingDoc = await transaction.get(listingRef);
        
        if (!listingDoc.exists) {
          console.error(`❌ Listing ${listingId} not found`);
          return;
        }

        const currentTapCount = listingDoc.data()?.tapCount || 0;
        const newTapCount = Math.max(0, currentTapCount - 1); // Ensure non-negative
        const newTapBadge = computeTapBadge(newTapCount);

        transaction.update(listingRef, {
          tapCount: newTapCount,
          tapBadge: newTapBadge,
        });

        console.log(`✅ Updated listing ${listingId}: tapCount=${newTapCount}, tapBadge=${newTapBadge}`);
      });
    } catch (error) {
      console.error(`❌ Error updating tap count for listing ${listingId}:`, error);
    }
  });

/**
 * Compute tap badge based on tap count
 */
function computeTapBadge(tapCount: number): string {
  if (tapCount >= 50) return "community_verified";
  if (tapCount >= 10) return "community_vouched";
  return "none";
}

/**
 * Admin/Maintenance function: Recompute tap counts for all listings
 * Call this manually if tap counts become out of sync
 * Usage: firebase functions:call recomputeAllTapCounts
 */
export const recomputeAllTapCounts = functions.https.onCall(async (data, context) => {
  // Require admin authentication
  if (!context.auth?.token?.isAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can recompute tap counts"
    );
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
  } catch (error) {
    console.error("❌ Error recomputing tap counts:", error);
    throw new functions.https.HttpsError("internal", "Failed to recompute tap counts");
  }
});
