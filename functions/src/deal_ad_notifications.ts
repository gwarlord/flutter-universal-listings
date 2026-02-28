import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

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
      if (user.pushToken && user.settings?.allowPushNotifications !== false) {
        await admin.messaging().send({
          token: user.pushToken,
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
      // Send email if user has email
      if (user.email) {
        await admin.firestore().collection('mail').add({
          to: user.email,
          message: {
            subject: title,
            html: `<p>${body}</p><p><a href="${adUrl}">View Deal in App</a></p>`
          }
        });
      }
    }
  });
