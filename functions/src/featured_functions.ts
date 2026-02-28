import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Normalize subscription tier values to numeric representation
 * professional/pro/business -> 1
 * premium -> 3
 */
function normalizeTierValue(value: any): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const lower = value.toLowerCase().trim();
    if (lower === "professional" || lower === "pro" || lower === "business") {
      return 1;
    }
    if (lower === "premium") {
      return 3;
    }
  }
  return 0;
}

/**
 * Fetch user's subscription tier from multiple sources
 * Checks both entitlements/subscription doc and user.subscriptionTier field
 */
async function fetchEntitlement(uid: string): Promise<number> {
  try {
    // Check entitlements/subscription document
    const entitlementDoc = await db
      .collection("users")
      .doc(uid)
      .collection("entitlements")
      .doc("subscription")
      .get();

    if (entitlementDoc.exists) {
      const tier = entitlementDoc.data()?.tier;
      if (tier) {
        const normalized = normalizeTierValue(tier);
        if (normalized > 0) {
          return normalized;
        }
      }
    }

    // Fallback: Check user.subscriptionTier field
    const userDoc = await db.collection("users").doc(uid).get();
    if (userDoc.exists) {
      const subscriptionTier = userDoc.data()?.subscriptionTier;
      if (subscriptionTier) {
        const normalized = normalizeTierValue(subscriptionTier);
        if (normalized > 0) {
          return normalized;
        }
      }
    }

    return 0;
  } catch (error) {
    console.error(`Error fetching entitlement for user ${uid}:`, error);
    return 0;
  }
}

/**
 * Check if a listing is eligible for featured placement
 * Requirements:
 * - Not suspended
 * - Not hidden
 * - At least 3 photos
 * - Description >= 80 characters
 * - Has categoryID
 * - Has country (countryCode OR country field)
 * - Has more than 5 vouches
 * - Has phone number, email address, or WhatsApp number populated
 */
async function checkListingEligibility(listing: any): Promise<{
  eligible: boolean;
  reason?: string;
}> {
  // Check if suspended
  if (listing.isSuspended === true) {
    return { eligible: false, reason: "Listing is suspended" };
  }

  // Check if hidden
  if (listing.isHidden === true) {
    return { eligible: false, reason: "Listing is hidden" };
  }

  // Check photos
  const photoCount = listing.photos?.length || 0;
  if (photoCount < 3) {
    return {
      eligible: false,
      reason: "Listing must have at least 3 photos",
    };
  }

  // Check description length
  const descriptionLength = (listing.description || "").length;
  if (descriptionLength < 80) {
    return {
      eligible: false,
      reason: "Listing description must be at least 80 characters",
    };
  }

  // Check categoryID
  if (!listing.categoryID) {
    return { eligible: false, reason: "Listing must have a category" };
  }

  // Check country (accept countryCode OR country)
  const hasCountry = listing.countryCode || listing.country;
  if (!hasCountry) {
    return { eligible: false, reason: "Listing must have a country selected" };
  }

  // Check vouches (must have more than 5)
  const vouchCount = listing.vouches?.length || 0;
  if (vouchCount <= 5) {
    return {
      eligible: false,
      reason: "Listing must have more than 5 vouches",
    };
  }

  // Check contact information (phone, email, or WhatsApp)
  const hasPhoneNumber = !!listing.phoneNumber;
  const hasEmailAddress = !!listing.emailAddress;
  const hasWhatsAppNumber = !!listing.whatsappNumber;

  if (!hasPhoneNumber && !hasEmailAddress && !hasWhatsAppNumber) {
    return {
      eligible: false,
      reason: "Listing must have a phone number, email address, or WhatsApp number",
    };
  }

  return { eligible: true };
}

/**
 * Request featured listing placement (Callable Function)
 * Auto-approves if listing is eligible and user has subscription >= 1
 */
export const requestFeaturedListing = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const uid = context.auth.uid;
    const listingId = data.listingId as string;

    if (!listingId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "listingId is required"
      );
    }

    try {
      // Get listing
      const listingDoc = await db.collection("listings").doc(listingId).get();
      if (!listingDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Listing not found"
        );
      }

      const listing = listingDoc.data()!;

      // Verify user owns the listing
      if (listing.authorID !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You can only request featured status for your own listings"
        );
      }

      // Check eligibility
      const eligibili = await checkListingEligibility(listing);
      if (!eligibili.eligible) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Listing Not Eligible: ${eligibili.reason}`
        );
      }

      // Check subscription tier
      const tier = await fetchEntitlement(uid);
      if (tier < 1) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You must have a Professional or Premium subscription to request featured placement"
        );
      }

      // Check if already featured
      const featuredRequest = await db
        .collection("featured_requests")
        .where("listingId", "==", listingId)
        .where("status", "==", "active")
        .limit(1)
        .get();

      if (!featuredRequest.empty) {
        throw new functions.https.HttpsError(
          "already-exists",
          "This listing already has an active featured request"
        );
      }

      // Create featured request (auto-approve for eligible listings)
      const now = admin.firestore.Timestamp.now();
      const expiresAt = new admin.firestore.Timestamp(
        now.seconds + 30 * 24 * 60 * 60, // 30 days
        now.nanoseconds
      );

      const requestId = db.collection("featured_requests").doc().id;
      await db.collection("featured_requests").doc(requestId).set({
        listingId,
        userId: uid,
        status: "active", // Auto-approved for eligible listings
        tier,
        createdAt: now,
        expiresAt,
        approvedAt: now,
        approvedBy: "system",
      });

      // Update listing with featured flag
      await db.collection("listings").doc(listingId).update({
        isFeatured: true,
        featuredRequestId: requestId,
        featuredAt: now,
      });

      // Record usage
      await db.collection("featured_usage").doc(uid).set(
        {
          currentMonth: new Date().toISOString().split("T")[0].slice(0, 7),
          count: admin.firestore.FieldValue.increment(1),
          lastUsedAt: now,
        },
        { merge: true }
      );

      return {
        success: true,
        requestId,
        message: "Your listing has been featured!",
      };
    } catch (error: any) {
      console.error("Error in requestFeaturedListing:", error);
      if (error.code) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to process featured request"
      );
    }
  });

/**
 * Admin function to manually approve/reject featured requests
 */
export const adminApproveFeaturedRequest = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // Verify admin
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const uid = context.auth.uid;
    const isAdmin =
      context.auth.token.isAdmin === true ||
      (await db.collection("admins").doc("admins").get()).data()?.adminUserIds?.includes(uid) ||
      false;

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can approve featured requests"
      );
    }

    const requestId = data.requestId as string;
    const approve = data.approve as boolean;

    if (!requestId || approve === undefined) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId and approve are required"
      );
    }

    try {
      const requestDoc = await db
        .collection("featured_requests")
        .doc(requestId)
        .get();

      if (!requestDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Featured request not found"
        );
      }

      const request = requestDoc.data()!;
      const listingId = request.listingId;
      const now = admin.firestore.Timestamp.now();

      if (approve) {
        // Approve
        const expiresAt = new admin.firestore.Timestamp(
          now.seconds + 30 * 24 * 60 * 60, // 30 days
          now.nanoseconds
        );

        await db.collection("featured_requests").doc(requestId).update({
          status: "active",
          approvedAt: now,
          approvedBy: uid,
        });

        await db.collection("listings").doc(listingId).update({
          isFeatured: true,
          featuredRequestId: requestId,
          featuredAt: now,
        });
      } else {
        // Reject
        await db.collection("featured_requests").doc(requestId).update({
          status: "rejected",
          rejectedAt: now,
          rejectedBy: uid,
        });

        await db.collection("listings").doc(listingId).update({
          isFeatured: false,
        });
      }

      return {
        success: true,
        message: approve ? "Request approved" : "Request rejected",
      };
    } catch (error: any) {
      console.error("Error in adminApproveFeaturedRequest:", error);
      if (error.code) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to process approval"
      );
    }
  });

/**
 * Scheduled function to expire featured listings after 30 days
 * Runs daily at 2:00 AM UTC
 */
export const expireFeaturedListings = functions.pubsub
  .schedule("0 2 * * *") // 2:00 AM UTC daily
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("Expiring featured listings...");
    const now = admin.firestore.Timestamp.now();

    try {
      // Find all active featured requests that have expired
      const expiredRequests = await db
        .collection("featured_requests")
        .where("status", "==", "active")
        .where("expiresAt", "<=", now)
        .get();

      console.log(`Found ${expiredRequests.docs.length} expired featured listings`);

      // Batch update to mark as expired
      const batch = db.batch();

      for (const doc of expiredRequests.docs) {
        const request = doc.data();
        const listingId = request.listingId;

        // Mark request as expired
        batch.update(doc.ref, {
          status: "expired",
          expiredAt: now,
        });

        // Remove featured flag from listing
        batch.update(db.collection("listings").doc(listingId), {
          isFeatured: false,
        });
      }

      if (expiredRequests.docs.length > 0) {
        await batch.commit();
        console.log(`Expired ${expiredRequests.docs.length} featured listings`);
      }

      return null;
    } catch (error) {
      console.error("Error expiring featured listings:", error);
      throw error;
    }
  });
