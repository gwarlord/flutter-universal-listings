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
exports.onChatMessageCreated = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
exports.onChatMessageCreated = functions.firestore
    .document("channels/{channelId}/thread/{messageId}")
    .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message)
        return;
    const channelId = context.params.channelId;
    const senderId = message.senderID || message.senderId;
    const content = message.content || "New message";
    functions.logger.info("🔔 Processing new message notification", { channelId, senderId });
    const channelDoc = await db.collection("channels").doc(channelId).get();
    if (!channelDoc.exists)
        return;
    const channelData = channelDoc.data();
    if (!channelData)
        return;
    const listingTitle = channelData.listingTitle || "Listing";
    const participantIds = channelData.participantIds || [];
    for (const userId of participantIds) {
        if (userId === senderId)
            continue;
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists)
            continue;
        const userData = userDoc.data();
        const pushToken = userData?.pushToken;
        if (!pushToken)
            continue;
        try {
            await admin.messaging().send({
                token: pushToken,
                notification: {
                    title: listingTitle,
                    body: content,
                },
                data: {
                    type: "chat",
                    channelID: channelId,
                    click_action: "FLUTTER_NOTIFICATION_CLICK", // Vital for background handling
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "chat_messages", // Ensure this exists in your Android code
                        clickAction: "FLUTTER_NOTIFICATION_CLICK",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            badge: 1,
                            sound: "default",
                        },
                    },
                },
            });
            functions.logger.info("✅ Notification sent", { userId });
        }
        catch (e) {
            functions.logger.error("❌ Error sending notification", { userId, error: e });
        }
    }
});
