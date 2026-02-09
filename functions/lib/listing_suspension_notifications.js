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
exports.onListingUnsuspended = exports.onListingSuspended = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Sends a notification to a lister when their listing is suspended
 */
exports.onListingSuspended = functions.firestore
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
    const reasonKey = suspensionInfo.reason;
    const reasonText = suspensionInfo.reasonText;
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
        const message = {
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
    }
    catch (error) {
        console.error("Error sending listing suspension notification:", error);
        return null;
    }
});
/**
 * Sends a notification to a lister when their listing is unsuspended
 */
exports.onListingUnsuspended = functions.firestore
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
        const message = {
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
    }
    catch (error) {
        console.error("Error sending listing unsuspension notification:", error);
        return null;
    }
});
const formatSuspensionReason = (reasonKey) => {
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
