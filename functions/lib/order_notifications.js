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
async function getUserTokens(uid) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists)
        return [];
    const user = userDoc.data() || {};
    const tokens = [];
    if (Array.isArray(user.fcmTokens)) {
        tokens.push(...user.fcmTokens.map((t) => String(t || "").trim()));
    }
    if (typeof user.pushToken === "string") {
        tokens.push(user.pushToken.trim());
    }
    if (typeof user.fcmToken === "string") {
        tokens.push(user.fcmToken.trim());
    }
    return [...new Set(tokens.filter((t) => t.length > 0))];
}
async function getManageOrderCollaboratorIds(listingId, listerId) {
    const listingDoc = await admin.firestore().collection("listings").doc(listingId).get();
    if (!listingDoc.exists)
        return [];
    const listing = listingDoc.data() || {};
    const collaborators = Array.isArray(listing.collaborators) ? listing.collaborators : [];
    const collaboratorIds = collaborators
        .filter((collab) => {
        const canManageOrders = collab?.canManageOrders === true ||
            collab?.permissions?.changeOrderStatus === true;
        return canManageOrders;
    })
        .map((collab) => String(collab?.userId || collab?.uid || collab?.collaboratorUid || "").trim())
        .filter((uid) => uid.length > 0 && uid !== listerId);
    return [...new Set(collaboratorIds)];
}
async function getTokensForUsers(userIds) {
    const tokenGroups = await Promise.all(userIds.map((uid) => getUserTokens(uid)));
    const merged = tokenGroups.flat();
    return [...new Set(merged.filter((t) => t.length > 0))];
}
async function sendToUserTokens(tokens, message) {
    if (tokens.length === 0)
        return;
    await Promise.allSettled(tokens.map((token) => admin.messaging().send({
        ...message,
        token,
    })));
}
/**
 * Send notification when a new order is placed
 */
exports.onOrderCreated = functions.firestore
    .document("order_requests/{orderId}")
    .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;
    const orderNumber = orderId.slice(0, 8).toUpperCase();
    try {
        const collaboratorIds = await getManageOrderCollaboratorIds(order.listingId, order.listerId);
        const recipientIds = [...new Set([order.listerId, ...collaboratorIds])];
        const listerAndCollaboratorTokens = await getTokensForUsers(recipientIds);
        if (listerAndCollaboratorTokens.length === 0) {
            console.log("Order recipients have no FCM tokens:", recipientIds);
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
            notification: {
                title: "🛒 New Order Request",
                body: `Order #${orderNumber}: ${listingTitle}`,
            },
            data: {
                type: "new_order",
                orderId: orderId,
                orderNumber: orderNumber,
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
        await sendToUserTokens(listerAndCollaboratorTokens, message);
        console.log("Order notification sent to lister/collaborators:", recipientIds);
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
    const orderNumber = orderId.slice(0, 8).toUpperCase();
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
        const collaboratorIds = await getManageOrderCollaboratorIds(after.listingId, after.listerId);
        const listerAndCollaboratorIds = [...new Set([after.listerId, ...collaboratorIds])];
        // Proof of payment upload notification (customer -> lister/collaborators)
        const beforePayment = before.payment || {};
        const afterPayment = after.payment || {};
        const proofUrlBefore = String(beforePayment.proofOfPaymentUrl || "").trim();
        const proofUrlAfter = String(afterPayment.proofOfPaymentUrl || "").trim();
        const proofStatusBefore = String(beforePayment.proofOfPaymentStatus || "").toLowerCase();
        const proofStatusAfter = String(afterPayment.proofOfPaymentStatus || "").toLowerCase();
        const proofJustUploaded = proofUrlBefore.length === 0 && proofUrlAfter.length > 0;
        if (proofJustUploaded) {
            const recipientTokens = await getTokensForUsers(listerAndCollaboratorIds);
            if (recipientTokens.length > 0) {
                const popMessage = {
                    notification: {
                        title: "🧾 Proof of Payment Uploaded",
                        body: `Order #${orderNumber}: customer uploaded proof of payment for ${listingTitle}.`,
                    },
                    data: {
                        type: "proof_of_payment_uploaded",
                        orderId: orderId,
                        orderNumber: orderNumber,
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
                await sendToUserTokens(recipientTokens, popMessage);
                console.log("Proof upload notification sent to lister/collaborators:", listerAndCollaboratorIds);
            }
        }
        // Proof review notification (lister/collaborator -> customer)
        const proofReviewed = proofStatusAfter !== proofStatusBefore &&
            (proofStatusAfter === "approved" || proofStatusAfter === "rejected");
        if (proofReviewed) {
            const customerTokens = await getUserTokens(after.customerId);
            if (customerTokens.length > 0) {
                const isApproved = proofStatusAfter === "approved";
                const reviewMessage = {
                    notification: {
                        title: isApproved ? "✅ Proof Approved" : "❌ Proof Rejected",
                        body: `Order #${orderNumber}: your proof of payment was ${isApproved ? "approved" : "rejected"}.`,
                    },
                    data: {
                        type: "proof_of_payment_reviewed",
                        orderId: orderId,
                        orderNumber: orderNumber,
                        status: proofStatusAfter,
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
                await sendToUserTokens(customerTokens, reviewMessage);
                console.log("Proof review notification sent to customer:", after.customerId);
            }
        }
        // Check if order status changed
        if (before.status === after.status) {
            return null;
        }
        // Create notification based on status
        let title = "";
        let body = "";
        let emoji = "";
        let recipientId = after.customerId; // Default: notify customer
        let recipientIds = [];
        let notifyCollaborators = false;
        switch (after.status) {
            case "confirmed":
                emoji = "✅";
                title = "Order Active";
                body = `Order #${orderNumber} for ${listingTitle} is now active.`;
                recipientId = after.customerId;
                break;
            case "preparing":
                emoji = "👨‍🍳";
                title = "Order Preparing";
                body = `Order #${orderNumber} for ${listingTitle} is being prepared.`;
                recipientId = after.customerId;
                break;
            case "ready":
                emoji = "🔔";
                title = "Order Ready";
                body = `Order #${orderNumber} for ${listingTitle} is ready.`;
                recipientId = after.customerId;
                break;
            case "served":
                emoji = "🍽️";
                title = "Order Served";
                body = `Order #${orderNumber} for ${listingTitle} has been served.`;
                recipientId = after.customerId;
                break;
            case "declined":
                emoji = "❌";
                title = "Order Declined";
                body = `Order #${orderNumber} for ${listingTitle} was declined.`;
                recipientId = after.customerId;
                break;
            case "fulfilled":
                emoji = "📦";
                title = "Order Fulfilled";
                body = `Order #${orderNumber} for ${listingTitle} is ready!`;
                recipientId = after.customerId;
                break;
            case "cancelled":
                emoji = "🚫";
                title = "Order Cancelled";
                // Determine who cancelled it and notify accordingly
                if (before.status === "requested") {
                    // Customer cancelling their pending order - notify lister
                    body = `Order #${orderNumber} for ${listingTitle} was cancelled.`;
                    recipientId = after.listerId;
                    notifyCollaborators = true;
                }
                else {
                    // Lister declining - notify customer
                    body = `Order #${orderNumber} for ${listingTitle} was cancelled.`;
                    recipientId = after.customerId;
                }
                break;
            default:
                return null;
        }
        recipientIds = notifyCollaborators
            ? [...new Set([after.listerId, ...collaboratorIds])]
            : [recipientId];
        const recipientTokens = await getTokensForUsers(recipientIds);
        if (recipientTokens.length === 0) {
            console.log("Recipients have no FCM tokens:", recipientIds);
            return null;
        }
        // Send notification
        const message = {
            notification: {
                title: `${emoji} ${title}`,
                body: body,
            },
            data: {
                type: "order_status_changed",
                orderId: orderId,
                orderNumber: orderNumber,
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
        await sendToUserTokens(recipientTokens, message);
        console.log(`Order status notification sent to ${recipientIds.join(",")}, status: ${after.status}`);
        return null;
    }
    catch (error) {
        console.error("Error sending order status notification:", error);
        return null;
    }
});
