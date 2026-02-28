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
exports.onDealAdApproved = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// Trigger: When a deal ad is approved, notify all users who favorited the lister's listing
exports.onDealAdApproved = functions.firestore
    .document("deal_ads/{adId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after)
        return;
    if (before.status === after.status)
        return;
    if (after.status !== "approved")
        return;
    // Get the listingId and listerId from the ad
    const { listingId, listerId, mediaUrl, mediaType, caption } = after;
    if (!listingId)
        return;
    // Get the listing details to retrieve the title
    const listingDoc = await db.collection("listings").doc(listingId).get();
    if (!listingDoc.exists)
        return;
    const listingData = listingDoc.data();
    const listingTitle = listingData?.title || "a listing";
    // Find all users who have this listing in their likedListingsIDs
    const usersSnap = await db.collection("users")
        .where("likedListingsIDs", "array-contains", listingId)
        .get();
    if (usersSnap.empty)
        return;
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
