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
exports.markAttentionModuleAsSeen = exports.onBookingCreatedUpdateAttention = exports.onBookingStatusChangedUpdateAttention = exports.onRentalBookingCreatedUpdateAttention = exports.onRentalBookingStatusChangedUpdateAttention = exports.onOrderCreatedUpdateAttention = exports.onOrderStatusChangedUpdateAttention = exports.onChatMessageCreatedUpdateAttention = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Increment unread count for conversations when a new message is created
 * Updated: Fixed collection path from chatChannels to channels
 * Updated: Switched to robust set({ merge: true }) logic for creating/updating documents
 */
exports.onChatMessageCreatedUpdateAttention = functions.firestore
    .document("channels/{channelId}/thread/{messageId}")
    .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message)
        return null;
    const channelId = context.params.channelId;
    const senderId = message.senderID || message.senderId;
    functions.logger.info("📨 Updating conversation attention for message", {
        channelId,
        senderId,
    });
    try {
        const channelDoc = await db.collection("channels").doc(channelId).get();
        if (!channelDoc.exists)
            return null;
        const channelData = channelDoc.data();
        if (!channelData)
            return null;
        const participantIds = channelData.participantIds || [];
        for (const userId of participantIds) {
            if (userId === senderId)
                continue;
            const attentionRef = db
                .collection("users")
                .doc(userId)
                .collection("attention")
                .doc("state");
            await attentionRef.set({
                counts: {
                    conversations: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        functions.logger.info("✅ Conversation attention updated", {
            channelId,
        });
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating conversation attention:", error);
        return null;
    }
});
/**
 * Increment my orders count when customer order status changes (for customer)
 */
exports.onOrderStatusChangedUpdateAttention = functions.firestore
    .document("order_requests/{orderId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return null;
    const orderId = context.params.orderId;
    const customerId = after.customerId || after.userId;
    functions.logger.info("🛒 Updating my orders attention", {
        orderId,
        customerId,
        newStatus: after.status,
    });
    try {
        if (customerId) {
            const attentionRef = db
                .collection("users")
                .doc(customerId)
                .collection("attention")
                .doc("state");
            await attentionRef.set({
                counts: {
                    myOrders: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        functions.logger.info("✅ My orders attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating my orders attention:", error);
        return null;
    }
});
/**
 * Increment order requests count when new order is created (for lister)
 */
exports.onOrderCreatedUpdateAttention = functions.firestore
    .document("order_requests/{orderId}")
    .onCreate(async (snap, context) => {
    const order = snap.data();
    if (!order)
        return null;
    const orderId = context.params.orderId;
    const listerId = order.listerId;
    functions.logger.info("🆕 Updating order requests attention", {
        orderId,
        listerId,
    });
    try {
        if (listerId) {
            const listerAttentionRef = db
                .collection("users")
                .doc(listerId)
                .collection("attention")
                .doc("state");
            await listerAttentionRef.set({
                counts: {
                    orderRequests: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            const listingDoc = await db
                .collection("listings")
                .doc(order.listingId)
                .get();
            if (listingDoc.exists) {
                const listingData = listingDoc.data();
                const collaborators = listingData?.collaborators || [];
                for (const collab of collaborators) {
                    if (collab.canManageOrders === true) {
                        const collabAttentionRef = db
                            .collection("users")
                            .doc(collab.userId)
                            .collection("attention")
                            .doc("state");
                        await collabAttentionRef.set({
                            counts: {
                                orderRequests: admin.firestore.FieldValue.increment(1),
                            },
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        }, { merge: true });
                    }
                }
            }
        }
        functions.logger.info("✅ Order requests attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating order requests attention:", error);
        return null;
    }
});
/**
 * Update attention for rentals (new rental or status change)
 */
exports.onRentalBookingStatusChangedUpdateAttention = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return null;
    const bookingId = context.params.bookingId;
    const customerId = after.customerId;
    const listerId = after.listerId;
    functions.logger.info("🚗 Updating rentals attention", {
        bookingId,
        newStatus: after.status,
    });
    try {
        if (customerId) {
            const customerAttentionRef = db
                .collection("users")
                .doc(customerId)
                .collection("attention")
                .doc("state");
            await customerAttentionRef.set({
                counts: {
                    rentals: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        if (listerId) {
            const listerAttentionRef = db
                .collection("users")
                .doc(listerId)
                .collection("attention")
                .doc("state");
            await listerAttentionRef.set({
                counts: {
                    rentals: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        functions.logger.info("✅ Rentals attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating rentals attention:", error);
        return null;
    }
});
/**
 * Update attention when new rental booking is created
 */
exports.onRentalBookingCreatedUpdateAttention = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const booking = snap.data();
    if (!booking)
        return null;
    const bookingId = context.params.bookingId;
    const listerId = booking.listerId;
    functions.logger.info("🆕 Updating rental booking requests attention", {
        bookingId,
        listerId,
    });
    try {
        if (listerId) {
            const attentionRef = db
                .collection("users")
                .doc(listerId)
                .collection("attention")
                .doc("state");
            await attentionRef.set({
                counts: {
                    rentals: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        functions.logger.info("✅ Rental booking requests attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating rental booking requests attention:", error);
        return null;
    }
});
/**
 * Update attention for bookings (new booking or status change)
 */
exports.onBookingStatusChangedUpdateAttention = functions.firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status)
        return null;
    const bookingId = context.params.bookingId;
    const customerId = after.customerId;
    functions.logger.info("📅 Updating bookings attention", {
        bookingId,
        newStatus: after.status,
    });
    try {
        if (customerId) {
            const attentionRef = db
                .collection("users")
                .doc(customerId)
                .collection("attention")
                .doc("state");
            await attentionRef.set({
                counts: {
                    myBookings: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        functions.logger.info("✅ Bookings attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating bookings attention:", error);
        return null;
    }
});
/**
 * Update attention when new booking is created
 */
exports.onBookingCreatedUpdateAttention = functions.firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const booking = snap.data();
    if (!booking)
        return null;
    const listingId = context.params.listingId;
    const bookingId = context.params.bookingId;
    let listerId = booking.listersUserId || booking.listerId || booking.authorID;
    // Fallback: resolve owner from listing doc when booking payload doesn't include lister id.
    if (!listerId && listingId) {
        try {
            const listingOwnerDoc = await db.collection("listings").doc(listingId).get();
            if (listingOwnerDoc.exists) {
                const listingData = listingOwnerDoc.data();
                listerId = listingData?.authorID || listingData?.authorId || listingData?.listerId;
            }
        }
        catch (error) {
            functions.logger.warn("⚠️ Unable to resolve listing owner for booking attention", {
                bookingId,
                listingId,
                error,
            });
        }
    }
    functions.logger.info("🆕 Updating booking requests attention", {
        bookingId,
        listingId,
        listerId,
    });
    try {
        if (listerId) {
            const listerAttentionRef = db
                .collection("users")
                .doc(listerId)
                .collection("attention")
                .doc("state");
            await listerAttentionRef.set({
                counts: {
                    bookingRequests: admin.firestore.FieldValue.increment(1),
                },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            const resolvedListingId = booking.listingId || listingId;
            const listingDoc = await db
                .collection("listings")
                .doc(resolvedListingId)
                .get();
            if (listingDoc.exists) {
                const listingData = listingDoc.data();
                const collaborators = listingData?.collaborators || [];
                for (const collab of collaborators) {
                    const canManageBookings = collab?.permissions?.manageBookings === true ||
                        collab?.canManageBookings === true;
                    if (canManageBookings) {
                        const collabAttentionRef = db
                            .collection("users")
                            .doc(collab.userId)
                            .collection("attention")
                            .doc("state");
                        await collabAttentionRef.set({
                            counts: {
                                bookingRequests: admin.firestore.FieldValue.increment(1),
                            },
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        }, { merge: true });
                    }
                }
            }
        }
        else {
            functions.logger.warn("⚠️ Skipping booking attention increment because listerId is missing", {
                bookingId,
                listingId,
                bookingListersUserId: booking.listersUserId,
                bookingListerId: booking.listerId,
                bookingAuthorId: booking.authorID,
            });
        }
        functions.logger.info("✅ Booking requests attention updated");
        return null;
    }
    catch (error) {
        functions.logger.error("Error updating booking requests attention:", error);
        return null;
    }
});
/**
 * Callable function: Mark a module as seen (clears the count for that module)
 */
exports.markAttentionModuleAsSeen = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const userId = context.auth.uid;
    const moduleKey = data.moduleKey;
    if (!moduleKey) {
        throw new functions.https.HttpsError("invalid-argument", "moduleKey is required");
    }
    functions.logger.info("👁️ Marking module as seen", { userId, moduleKey });
    try {
        const attentionRef = db
            .collection("users")
            .doc(userId)
            .collection("attention")
            .doc("state");
        // Use robust dot notation for updating nested fields
        await attentionRef.update({
            [`counts.${moduleKey}`]: 0,
            [`lastSeen.${moduleKey}`]: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        functions.logger.info("✅ Module marked as seen", { userId, moduleKey });
        return { success: true, message: `${moduleKey} marked as seen` };
    }
    catch (error) {
        // If the update fails (e.g., doc doesn't exist), create it.
        if (error.code === 'not-found') {
            functions.logger.warn("Document not found for markAsSeen, creating it.", { userId, moduleKey });
            const attentionRef = db
                .collection("users")
                .doc(userId)
                .collection("attention")
                .doc("state");
            await attentionRef.set({
                counts: { [moduleKey]: 0 },
                lastSeen: { [moduleKey]: admin.firestore.FieldValue.serverTimestamp() },
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            return { success: true, message: "Created document and marked as seen." };
        }
        functions.logger.error("Error marking module as seen:", error);
        throw new functions.https.HttpsError("internal", "Failed to mark module as seen");
    }
});
