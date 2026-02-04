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
exports.onOrderStatusChanged = exports.onOrderCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Send notification when a new order is placed
 */
exports.onOrderCreated = functions.firestore
    .document("order_requests/{orderId}")
    .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;
    try {
        // Get lister's user document to fetch FCM token
        const listerDoc = await admin
            .firestore()
            .collection("users")
            .doc(order.listerId)
            .get();
        if (!listerDoc.exists) {
            console.log("Lister not found:", order.listerId);
            return null;
        }
        const lister = listerDoc.data();
        const fcmToken = lister?.pushToken;
        if (!fcmToken) {
            console.log("Lister has no FCM token:", order.listerId);
            return null;
        }
        // Get listing details for notification
        const listingDoc = await admin
            .firestore()
            .collection("listings")
            .doc(order.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "Your listing";
        // Send notification
        const message = {
            token: fcmToken,
            notification: {
                title: "🛒 New Order Request",
                body: `You have a new order for ${listingTitle}`,
            },
            data: {
                type: "new_order",
                orderId: orderId,
                listingId: order.listingId,
                channelId: order.channelId || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "orders",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
        };
        await admin.messaging().send(message);
        console.log("Order notification sent to lister:", order.listerId);
        return null;
    }
    catch (error) {
        console.error("Error sending order notification:", error);
        return null;
    }
});
/**
 * Send notification when order status changes
 */
exports.onOrderStatusChanged = functions.firestore
    .document("order_requests/{orderId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;
    // Check if status changed
    if (before.status === after.status) {
        return null;
    }
    try {
        // Get listing details for notification
        const listingDoc = await admin
            .firestore()
            .collection("listings")
            .doc(after.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "your order";
        // Create notification based on status
        let title = "";
        let body = "";
        let emoji = "";
        let recipientId = after.customerId; // Default: notify customer
        switch (after.status) {
            case "confirmed":
                emoji = "✅";
                title = "Order Confirmed";
                body = `Your order for ${listingTitle} has been confirmed!`;
                recipientId = after.customerId;
                break;
            case "declined":
                emoji = "❌";
                title = "Order Declined";
                body = `Your order for ${listingTitle} was declined.`;
                recipientId = after.customerId;
                break;
            case "fulfilled":
                emoji = "📦";
                title = "Order Fulfilled";
                body = `Your order for ${listingTitle} is ready!`;
                recipientId = after.customerId;
                break;
            case "cancelled":
                emoji = "🚫";
                title = "Order Cancelled";
                // Determine who cancelled it and notify accordingly
                if (before.status === "requested") {
                    // Customer cancelling their pending order - notify lister
                    body = `An order for ${listingTitle} was cancelled.`;
                    recipientId = after.listerId;
                }
                else {
                    // Lister declining - notify customer
                    body = `Your order for ${listingTitle} was cancelled.`;
                    recipientId = after.customerId;
                }
                break;
            default:
                return null;
        }
        // Get the recipient's FCM token
        const recipientDoc = await admin
            .firestore()
            .collection("users")
            .doc(recipientId)
            .get();
        if (!recipientDoc.exists) {
            console.log("Recipient not found:", recipientId);
            return null;
        }
        const recipient = recipientDoc.data();
        const recipientFcmToken = recipient?.pushToken;
        if (!recipientFcmToken) {
            console.log("Recipient has no FCM token:", recipientId);
            return null;
        }
        // Send notification
        const message = {
            token: recipientFcmToken,
            notification: {
                title: `${emoji} ${title}`,
                body: body,
            },
            data: {
                type: "order_status_changed",
                orderId: orderId,
                status: after.status,
                listingId: after.listingId,
                channelId: after.channelId || "",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "orders",
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default",
                        badge: 1,
                    },
                },
            },
        };
        await admin.messaging().send(message);
        console.log(`Order status notification sent to ${recipientId}, status: ${after.status}`);
        return null;
    }
    catch (error) {
        console.error("Error sending order status notification:", error);
        return null;
    }
});
