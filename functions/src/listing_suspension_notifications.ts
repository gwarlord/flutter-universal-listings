import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Sends a notification to a lister when their listing is suspended
 */
export const onListingSuspended = functions.firestore
  .document("listings/{listingId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    const listingId = change.after.id;

    // Check if suspension status changed from false to true
    const wasSuspended = before?.suspended === true;
    const isSuspendedNow = after?.suspended === true;

    if (wasSuspended || !isSuspendedNow) {
      return null; // Not a new suspension
    }

    const listing = after;
    const listingTitle = listing.title || "Your listing";
    const suspensionInfo = listing.suspensionInfo || {};
    const reasonKey = suspensionInfo.reason as string | undefined;
    const reasonText = suspensionInfo.reasonText as string | undefined;
    const reasonLabel = reasonKey ? formatSuspensionReason(reasonKey) : "";
    const reasonDetail = reasonText || reasonLabel;

    // Get lister/author details
    try {
      const listerDoc = await admin
        .firestore()
        .collection("users")
        .doc(listing.authorID)
        .get();

      if (!listerDoc.exists) {
        console.log("Lister not found for listing:", listingId);
        return null;
      }

      const lister = listerDoc.data();
      if (!lister?.pushToken) {
        console.log("No push token for lister of listing:", listingId);
        return null;
      }

      // Check if push notifications are enabled
      if (lister.settings?.allowPushNotifications === false) {
        console.log("Push notifications disabled for lister:", listing.authorID);
        return null;
      }

      const message: admin.messaging.Message = {
        notification: {
          title: "🚫 Listing Suspended",
          body: `"${listingTitle}" has been suspended and is no longer visible to customers.${reasonDetail ? ` Reason: ${reasonDetail}.` : ""}`,
        },
        data: {
          type: "listing_suspended",
          listingId: listingId,
          listingTitle: listingTitle,
          reason: reasonKey || "",
          reasonText: reasonText || "",
          timestamp: new Date().toISOString(),
        },
        token: lister.pushToken,
      };

      await admin.messaging().send(message);
      console.log("Listing suspension notification sent to lister:", listing.authorID);
      return null;
    } catch (error) {
      console.error("Error sending listing suspension notification:", error);
      return null;
    }
  });

/**
 * Sends a notification to a lister when their listing is unsuspended
 */
export const onListingUnsuspended = functions.firestore
  .document("listings/{listingId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    const listingId = change.after.id;

    // Check if suspension status changed from true to false
    const wasSuspended = before?.suspended === true;
    const isSuspendedNow = after?.suspended === true;

    if (!wasSuspended || isSuspendedNow) {
      return null; // Not an unsuspension
    }

    const listing = after;
    const listingTitle = listing.title || "Your listing";

    // Get lister/author details
    try {
      const listerDoc = await admin
        .firestore()
        .collection("users")
        .doc(listing.authorID)
        .get();

      if (!listerDoc.exists) {
        console.log("Lister not found for listing:", listingId);
        return null;
      }

      const lister = listerDoc.data();
      if (!lister?.pushToken) {
        console.log("No push token for lister of listing:", listingId);
        return null;
      }

      // Check if push notifications are enabled
      if (lister.settings?.allowPushNotifications === false) {
        console.log("Push notifications disabled for lister:", listing.authorID);
        return null;
      }

      const message: admin.messaging.Message = {
        notification: {
          title: "✅ Listing Restored",
          body: `"${listingTitle}" is now visible to customers again.`,
        },
        data: {
          type: "listing_unsuspended",
          listingId: listingId,
          listingTitle: listingTitle,
          timestamp: new Date().toISOString(),
        },
        token: lister.pushToken,
      };

      await admin.messaging().send(message);
      console.log("Listing unsuspension notification sent to lister:", listing.authorID);
      return null;
    } catch (error) {
      console.error("Error sending listing unsuspension notification:", error);
      return null;
    }
  });

const formatSuspensionReason = (reasonKey: string): string => {
  switch (reasonKey) {
    case "breachOfPolicy":
      return "Breach of Policy";
    case "suspiciousActivity":
      return "Suspicious Activity";
    case "violentOrHarassiveBehavior":
      return "Violent or Harassing Behavior";
    case "fraudulent":
      return "Fraudulent Activity";
    case "spamOrMislabeling":
      return "Spam or Mislabeling";
    case "paymentIssues":
      return "Payment Issues";
    case "otherViolation":
      return "Other Violation";
    default:
      return "Other Violation";
  }
};
