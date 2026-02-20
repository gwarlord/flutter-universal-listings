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
exports.onBookingStatusChanged = exports.onBookingCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Send notification when a new booking is created
 * Notifies: Lister and collaborators with canManageBookings permission
 */
exports.onBookingCreated = functions.firestore
    .document("bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;
    const bookingNumber = bookingId.slice(0, 8).toUpperCase();
    try {
        const db = admin.firestore();
        const messaging = admin.messaging();
        // Get lister's user document to fetch FCM token
        const listerDoc = await db
            .collection("users")
            .doc(booking.listersUserId)
            .get();
        if (!listerDoc.exists) {
            console.log("Lister not found:", booking.listersUserId);
            return null;
        }
        const lister = listerDoc.data();
        const listerTokens = getListerTokens(lister);
        if (listerTokens.length === 0) {
            console.log("Lister has no FCM token:", booking.listersUserId);
            return null;
        }
        // Get listing details for notification
        const listingDoc = await db
            .collection("listings")
            .doc(booking.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "Your listing";
        // Get customer name if available
        const customerName = booking.customerName || "Guest";
        // Build notification
        const checkInDate = booking.checkInDate
            ? new Date(booking.checkInDate).toLocaleDateString()
            : "TBD";
        const checkOutDate = booking.checkOutDate
            ? new Date(booking.checkOutDate).toLocaleDateString()
            : "TBD";
        const notificationTitle = "📅 New Booking Request";
        const notificationBody = `${customerName} booked "${listingTitle}" (${checkInDate} - ${checkOutDate})`;
        // Send notification to lister
        for (const token of listerTokens) {
            try {
                await messaging.send({
                    token: token,
                    notification: {
                        title: notificationTitle,
                        body: notificationBody,
                    },
                    data: {
                        type: "new_booking",
                        bookingId: bookingId,
                        bookingNumber: bookingNumber,
                        listingId: booking.listingId,
                        status: booking.status || "pending",
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            sound: "default",
                            channelId: "bookings",
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
                });
                console.log("✅ Booking notification sent to lister:", booking.listersUserId);
            }
            catch (e) {
                console.error("❌ Error sending booking notification to lister:", e);
            }
        }
        // Send notification to collaborators with canManageBookings permission
        if (listingDoc.exists) {
            const listingData = listingDoc.data();
            const collaborators = listingData?.collaborators || [];
            for (const collab of collaborators) {
                if (collab.canManageBookings === true) {
                    const collabDoc = await db
                        .collection("users")
                        .doc(collab.userId)
                        .get();
                    if (!collabDoc.exists)
                        continue;
                    const collaborator = collabDoc.data();
                    const collabTokens = getTokens(collaborator);
                    for (const token of collabTokens) {
                        try {
                            await messaging.send({
                                token: token,
                                notification: {
                                    title: notificationTitle,
                                    body: notificationBody,
                                },
                                data: {
                                    type: "new_booking",
                                    bookingId: bookingId,
                                    bookingNumber: bookingNumber,
                                    listingId: booking.listingId,
                                    status: booking.status || "pending",
                                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                                },
                                android: {
                                    priority: "high",
                                    notification: {
                                        sound: "default",
                                        channelId: "bookings",
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
                            });
                            console.log("✅ Booking notification sent to collaborator:", collab.userId);
                        }
                        catch (e) {
                            console.error("❌ Error sending booking notification to collaborator:", e);
                        }
                    }
                }
            }
        }
        return null;
    }
    catch (error) {
        console.error("Error in onBookingCreated:", error);
        return null;
    }
});
/**
 * Send notification when booking status changes
 * Notifies: Customer for status changes
 */
exports.onBookingStatusChanged = functions.firestore
    .document("bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;
    const bookingNumber = bookingId.slice(0, 8).toUpperCase();
    // Check if status changed
    if (before.status === after.status) {
        return null;
    }
    try {
        const db = admin.firestore();
        const messaging = admin.messaging();
        // Get listing details for notification
        const listingDoc = await db
            .collection("listings")
            .doc(after.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "your booking";
        // Create notification based on status
        let title = "";
        let body = "";
        let emoji = "";
        let recipientId = after.customerId; // Default: notify customer
        switch (after.status) {
            case "confirmed":
            case "approved":
                emoji = "✅";
                title = "Booking Confirmed";
                body = `Your booking #${bookingNumber} for "${listingTitle}" has been confirmed!`;
                recipientId = after.customerId;
                break;
            case "rejected":
            case "declined":
                emoji = "❌";
                title = "Booking Rejected";
                body = `Your booking #${bookingNumber} for "${listingTitle}" was rejected.`;
                recipientId = after.customerId;
                break;
            case "cancelled":
                emoji = "🚫";
                title = "Booking Cancelled";
                body = `Your booking #${bookingNumber} for "${listingTitle}" has been cancelled.`;
                recipientId = after.customerId;
                break;
            case "completed":
                emoji = "🎉";
                title = "Booking Completed";
                body = `Your booking #${bookingNumber} for "${listingTitle}" is complete!`;
                recipientId = after.customerId;
                break;
            default:
                // For any other status changes, notify customer
                title = "Booking Update";
                body = `Your booking #${bookingNumber} status has changed.`;
                recipientId = after.customerId;
        }
        // Get the recipient's FCM token(s)
        const recipientDoc = await db
            .collection("users")
            .doc(recipientId)
            .get();
        if (!recipientDoc.exists) {
            console.log("Recipient not found:", recipientId);
            return null;
        }
        const recipient = recipientDoc.data();
        const recipientTokens = getTokens(recipient);
        if (recipientTokens.length === 0) {
            console.log("Recipient has no FCM token:", recipientId);
            return null;
        }
        // Send notification
        for (const token of recipientTokens) {
            try {
                await messaging.send({
                    token: token,
                    notification: {
                        title: `${emoji} ${title}`,
                        body: body,
                    },
                    data: {
                        type: "booking_status_changed",
                        bookingId: bookingId,
                        bookingNumber: bookingNumber,
                        status: after.status,
                        listingId: after.listingId,
                        click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                    android: {
                        priority: "high",
                        notification: {
                            sound: "default",
                            channelId: "bookings",
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
                });
                console.log("✅ Booking status notification sent to customer:", recipientId);
            }
            catch (e) {
                console.error("❌ Error sending booking status notification:", e);
            }
        }
        return null;
    }
    catch (error) {
        console.error("Error in onBookingStatusChanged:", error);
        return null;
    }
});
/**
 * Helper function to get FCM tokens from user document
 * Supports both new (fcmTokens array) and legacy (pushToken string) formats
 */
function getTokens(userData) {
    let tokens = [];
    // New format: array of FCM tokens
    if (Array.isArray(userData?.fcmTokens) && userData.fcmTokens.length > 0) {
        tokens = userData.fcmTokens;
    }
    // Legacy format: single pushToken string
    else if (userData?.pushToken && typeof userData.pushToken === "string" && userData.pushToken.trim().length > 0) {
        tokens = [userData.pushToken];
    }
    return tokens;
}
/**
 * Helper to get lister specific tokens (alias for getTokens)
 */
function getListerTokens(userData) {
    return getTokens(userData);
}
