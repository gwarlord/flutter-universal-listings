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
exports.onBookingUpdated = exports.onBookingCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
async function resolveBookingListerId(db, booking, listingIdFromPath) {
    const bookingListerId = typeof booking?.listersUserId === "string" && booking.listersUserId.trim().length > 0
        ? booking.listersUserId.trim()
        : "";
    if (bookingListerId) {
        return bookingListerId;
    }
    const listingId = typeof booking?.listingId === "string" && booking.listingId.trim().length > 0
        ? booking.listingId.trim()
        : (listingIdFromPath || "").trim();
    if (!listingId) {
        return "";
    }
    const listingDoc = await db.collection("listings").doc(listingId).get();
    if (!listingDoc.exists) {
        return "";
    }
    const listingData = listingDoc.data();
    if (typeof listingData?.authorID === "string" && listingData.authorID.trim().length > 0) {
        return listingData.authorID.trim();
    }
    return "";
}
function asNonEmptyString(value, fallback = "") {
    if (typeof value !== "string") {
        return fallback;
    }
    const trimmed = value.trim();
    return trimmed.length === 0 ? fallback : trimmed;
}
async function sendToTokensIndividually(messaging, tokens, payload) {
    let successCount = 0;
    let failureCount = 0;
    for (const token of tokens) {
        try {
            await messaging.send({
                token,
                ...payload,
            });
            successCount += 1;
        }
        catch (error) {
            failureCount += 1;
            functions.logger.warn("Booking notification token failure", {
                tokenSuffix: token.slice(-8),
                error: error?.message || String(error),
            });
        }
    }
    return { successCount, failureCount };
}
/**
 * Send notification when a new booking is created
 * Watches: listings/{listingId}/bookings/{bookingId}
 */
exports.onBookingCreated = functions.firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;
    try {
        const db = admin.firestore();
        const messaging = admin.messaging();
        const listerId = await resolveBookingListerId(db, booking, context.params.listingId);
        if (!listerId) {
            functions.logger.warn("Booking created without a resolvable lister", {
                bookingId,
                listingId: context.params.listingId,
                bookingListerId: booking?.listersUserId,
            });
            return null;
        }
        const listerDoc = await db.collection("users").doc(listerId).get();
        if (!listerDoc.exists) {
            functions.logger.warn("Lister document not found for booking notification", {
                bookingId,
                listingId: context.params.listingId,
                listerId,
            });
            return null;
        }
        const listerData = listerDoc.data();
        if (listerData?.settings?.allowPushNotifications === false) {
            functions.logger.info("Lister has push notifications disabled", {
                bookingId,
                listingId: context.params.listingId,
                listerId,
            });
            return null;
        }
        const listerTokens = getTokens(listerData);
        if (listerTokens.length === 0) {
            functions.logger.warn("Lister has no push tokens for booking notification", {
                bookingId,
                listingId: context.params.listingId,
                listerId,
                hasPushToken: !!listerData?.pushToken,
                hasFcmTokens: Array.isArray(listerData?.fcmTokens) && listerData.fcmTokens.length > 0,
            });
            return null;
        }
        const listingTitle = booking.listingTitle || "Your listing";
        const customerName = booking.customerName || "Guest";
        const dataListingId = asNonEmptyString(booking?.listingId, context.params.listingId);
        const messagePayload = {
            notification: {
                title: "📅 New Booking Request",
                body: `${customerName} requested to book "${listingTitle}"`,
            },
            data: {
                type: "new_booking",
                bookingId: bookingId,
                listingId: dataListingId,
                status: "pending",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
        };
        const response = await sendToTokensIndividually(messaging, listerTokens, messagePayload);
        functions.logger.info("Standard booking notification sent to lister", {
            bookingId,
            listingId: context.params.listingId,
            listerId,
            tokenCount: listerTokens.length,
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
        return null;
    }
    catch (error) {
        console.error("Error in onBookingCreated:", error);
        return null;
    }
});
/**
 * Send notification when booking status changes
 * Watches: listings/{listingId}/bookings/{bookingId}
 */
exports.onBookingUpdated = functions.firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;
    if (!before || !after || before.status === after.status) {
        return null;
    }
    try {
        const db = admin.firestore();
        const messaging = admin.messaging();
        const nextStatus = (after.status || "").toLowerCase();
        const listingTitle = after.listingTitle || "your booking";
        const customerId = asNonEmptyString(after.customerId);
        const listerId = asNonEmptyString(after.listersUserId);
        let customerTitle = "";
        let customerBody = "";
        let listerTitle = "";
        let listerBody = "";
        switch (nextStatus) {
            case "confirmed":
            case "approved":
                customerTitle = "✅ Booking Confirmed";
                customerBody = `Your booking for "${listingTitle}" has been confirmed!`;
                break;
            case "rejected":
            case "declined":
                customerTitle = "❌ Booking Rejected";
                customerBody = `Your booking request for "${listingTitle}" was not accepted.`;
                break;
            case "cancelled":
                // When cancelled, we notify BOTH so they are both aware.
                customerTitle = "🚫 Booking Cancelled";
                customerBody = `The booking for "${listingTitle}" has been cancelled.`;
                listerTitle = "🚫 Booking Cancelled";
                listerBody = `The booking for "${listingTitle}" by ${after.customerName} was cancelled.`;
                break;
            default:
                customerTitle = "Booking Update";
                customerBody = `Your booking for "${listingTitle}" was updated to ${nextStatus || "a new"} status.`;
                break;
        }
        // Notify Customer
        if (customerTitle) {
            if (!customerId) {
                functions.logger.warn("Missing customerId for booking status notification", {
                    bookingId,
                    listingId: context.params.listingId,
                    nextStatus,
                });
            }
            else {
                const customerDoc = await db.collection("users").doc(customerId).get();
                if (customerDoc.exists) {
                    const tokens = getTokens(customerDoc.data());
                    if (tokens.length > 0) {
                        const customerResponse = await sendToTokensIndividually(messaging, tokens, {
                            notification: { title: customerTitle, body: customerBody },
                            data: { type: "booking_status", bookingId, status: nextStatus, click_action: "FLUTTER_NOTIFICATION_CLICK" },
                            android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
                            apns: { payload: { aps: { sound: "default", badge: 1 } } },
                        });
                        functions.logger.info("Booking status notification sent to customer", {
                            bookingId,
                            customerId,
                            nextStatus,
                            tokenCount: tokens.length,
                            successCount: customerResponse.successCount,
                            failureCount: customerResponse.failureCount,
                        });
                    }
                }
            }
        }
        // Notify Lister (specifically for cancellations)
        if (listerTitle) {
            if (!listerId) {
                functions.logger.warn("Missing listersUserId for lister booking notification", {
                    bookingId,
                    listingId: context.params.listingId,
                    nextStatus,
                });
            }
            else {
                const listerDoc = await db.collection("users").doc(listerId).get();
                if (listerDoc.exists) {
                    const tokens = getTokens(listerDoc.data());
                    if (tokens.length > 0) {
                        const listerResponse = await sendToTokensIndividually(messaging, tokens, {
                            notification: { title: listerTitle, body: listerBody },
                            data: { type: "booking_status", bookingId, status: nextStatus, click_action: "FLUTTER_NOTIFICATION_CLICK" },
                            android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
                            apns: { payload: { aps: { sound: "default", badge: 1 } } },
                        });
                        functions.logger.info("Booking status notification sent to lister", {
                            bookingId,
                            listerId,
                            nextStatus,
                            tokenCount: tokens.length,
                            successCount: listerResponse.successCount,
                            failureCount: listerResponse.failureCount,
                        });
                    }
                }
            }
        }
        return null;
    }
    catch (error) {
        console.error("Error in onBookingUpdated:", error);
        return null;
    }
});
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
