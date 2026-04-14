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

// Trigger: When a deal ad is approved, notify all users who favorited the lister's listing
export const onDealAdApproved = functions.firestore
  .document("deal_ads/{adId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;
    if (before.status === after.status) return;
    if (after.status !== "approved") return;

    // Get the listingId and listerId from the ad
    const { listingId, listerId, mediaUrl, mediaType, caption } = after;
    if (!listingId) return;

    // Get the listing details to retrieve the title
    const listingDoc = await db.collection("listings").doc(listingId).get();
    if (!listingDoc.exists) return;
    const listingData = listingDoc.data();
    const listingTitle = listingData?.title || "a listing";

    // Find all users who have this listing in their likedListingsIDs
    const usersSnap = await db.collection("users")
      .where("likedListingsIDs", "array-contains", listingId)
      .get();

    if (usersSnap.empty) return;

    // Prepare notification
    const title = "New Deal from one of your Favourite Listing!";
    const body = listingTitle;
    const adUrl = `caribtap://deals/${context.params.adId}`;

    for (const userDoc of usersSnap.docs) {
      const user = userDoc.data();
      // Send push notification if allowed
      const tokens = getTokens(user);
      if (tokens.length > 0 && user.settings?.allowPushNotifications !== false) {
        for (const token of tokens) {
          await admin.messaging().send({
            token,
            notification: {
              title,
              body,
            },
            data: {
              type: "deal_ad",
              adId: context.params.adId,
              listingId,
              listerId,
              adUrl,
            },
          });
        }
      }
    }
  });
