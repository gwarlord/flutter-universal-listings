import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

function getTokens(userData: any): string[] {
  let tokens: string[] = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens = userData.fcmTokens
      .filter((t: any) => typeof t === "string" && t.trim().length > 0)
      .map((t: string) => t.trim());
  }
  if (userData?.pushToken && typeof userData.pushToken === "string") {
    const pushToken = userData.pushToken.trim();
    if (pushToken && !tokens.includes(pushToken)) {
      tokens.push(pushToken);
    }
  }
  return Array.from(new Set(tokens));
}

export const onReviewRemovalRequestCreated = functions.firestore
  .document("review_removal_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const request = snap.data();
    if (!request) return;

    const status = String(request.status || "").toUpperCase();
    if (status && status !== "PENDING") return;

    const listingId = String(request.listingId || "");
    let listingTitle = "a listing";

    if (listingId) {
      const listingDoc = await db.collection("listings").doc(listingId).get();
      if (listingDoc.exists) {
        const listingData = listingDoc.data();
        if (listingData?.title) {
          listingTitle = String(listingData.title);
        }
      }
    }

    const adminUsers = await db
      .collection("users")
      .where("isAdmin", "==", true)
      .get();

    if (adminUsers.empty) return;

    for (const adminDoc of adminUsers.docs) {
      const userData = adminDoc.data();
      const tokens = getTokens(userData);
      const allowPush = userData.settings?.allowPushNotifications !== false;

      if (tokens.length === 0 || !allowPush) continue;

      for (const token of tokens) {
        try {
          await admin.messaging().send({
            token,
            notification: {
              title: "Review Removal Request",
              body: `A lister requested removal of a review for \"${listingTitle}\"`
            },
            data: {
              type: "review_removal_request",
              requestId: context.params.requestId,
              listingId,
            },
          });
        } catch (error) {
          functions.logger.error("Failed to send review-removal admin notification", {
            adminUserId: adminDoc.id,
            requestId: context.params.requestId,
            error,
          });
        }
      }
    }
  });
