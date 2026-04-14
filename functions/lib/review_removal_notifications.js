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
exports.onReviewRemovalRequestCreated = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
function getTokens(userData) {
    let tokens = [];
    if (Array.isArray(userData?.fcmTokens)) {
        tokens = userData.fcmTokens
            .filter((t) => typeof t === "string" && t.trim().length > 0)
            .map((t) => t.trim());
    }
    if (userData?.pushToken && typeof userData.pushToken === "string") {
        const pushToken = userData.pushToken.trim();
        if (pushToken && !tokens.includes(pushToken)) {
            tokens.push(pushToken);
        }
    }
    return Array.from(new Set(tokens));
}
exports.onReviewRemovalRequestCreated = functions.firestore
    .document("review_removal_requests/{requestId}")
    .onCreate(async (snap, context) => {
    const request = snap.data();
    if (!request)
        return;
    const status = String(request.status || "").toUpperCase();
    if (status && status !== "PENDING")
        return;
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
    if (adminUsers.empty)
        return;
    for (const adminDoc of adminUsers.docs) {
        const userData = adminDoc.data();
        const tokens = getTokens(userData);
        const allowPush = userData.settings?.allowPushNotifications !== false;
        if (tokens.length === 0 || !allowPush)
            continue;
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
            }
            catch (error) {
                functions.logger.error("Failed to send review-removal admin notification", {
                    adminUserId: adminDoc.id,
                    requestId: context.params.requestId,
                    error,
                });
            }
        }
    }
});
