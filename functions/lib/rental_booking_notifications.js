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
exports.onRentalBookingStatusChanged = exports.onRentalBookingCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Send notification when a new rental booking is created
 */
exports.onRentalBookingCreated = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;
    try {
        // Get lister's user document to fetch FCM token
        const listerDoc = await admin
            .firestore()
            .collection("users")
            .doc(booking.listerId)
            .get();
        if (!listerDoc.exists) {
            console.log("Lister not found:", booking.listerId);
            return null;
        }
        const lister = listerDoc.data();
        const fcmToken = lister?.pushToken;
        if (!fcmToken) {
            console.log("Lister has no FCM token:", booking.listerId);
            return null;
        }
        // Check if push notifications are enabled
        if (lister?.settings?.allowPushNotifications === false) {
            console.log("Push notifications disabled for lister:", booking.listerId);
            return null;
        }
        // Get listing details for notification
        const listingDoc = await admin
            .firestore()
            .collection("listings")
            .doc(booking.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "Your listing";
        // Get rental type to determine emoji
        const listingData = listingDoc.data();
        const rentalConfig = listingData?.rentalConfig || {};
        const isVehicleRental = rentalConfig.rentalType === "vehicle";
        const notificationEmoji = isVehicleRental ? "🚗" : "📦";
        // Get customer name
        const customerDoc = await admin
            .firestore()
            .collection("users")
            .doc(booking.customerId)
            .get();
        const customerName = customerDoc.exists
            ? `${customerDoc.data()?.firstName || ""} ${customerDoc.data()?.lastName || ""}`.trim() || "A customer"
            : "A customer";
        // Format dates
        const startDate = booking.startTime?.toDate?.() || new Date(booking.startTime);
        const endDate = booking.endTime?.toDate?.() || new Date(booking.endTime);
        const dateRange = `${startDate.toLocaleDateString()} - ${endDate.toLocaleDateString()}`;
        // Send notification
        const message = {
            token: fcmToken,
            notification: {
                title: `${notificationEmoji} New Rental Booking`,
                body: `${customerName} requested a rental from ${listingTitle} (${dateRange})`,
            },
            data: {
                type: "new_rental_booking",
                bookingId: bookingId,
                listingId: booking.listingId,
                customerId: booking.customerId,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "rental_bookings",
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
        console.log("Rental booking notification sent to lister:", booking.listerId);
        return null;
    }
    catch (error) {
        console.error("Error sending rental booking notification:", error);
        return null;
    }
});
/**
 * Send notification when rental booking status changes
 */
exports.onRentalBookingStatusChanged = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;
    // Check if status changed
    if (before.status === after.status) {
        return null;
    }
    try {
        // Determine who to notify based on status change
        let recipientId = "";
        let title = "";
        let body = "";
        let notificationType = "";
        // Get listing details
        const listingDoc = await admin
            .firestore()
            .collection("listings")
            .doc(after.listingId)
            .get();
        const listingTitle = listingDoc.exists
            ? listingDoc.data()?.title
            : "A rental";
        // Get rental type to determine emoji
        const listingData = listingDoc.data();
        const rentalConfig = listingData?.rentalConfig || {};
        const isVehicleRental = rentalConfig.rentalType === "vehicle";
        const vehicleEmoji = isVehicleRental ? "🚘" : "📦";
        const startEmoji = isVehicleRental ? "🚘" : "📤";
        switch (after.status) {
            case "confirmed":
                // Notify customer that booking was confirmed
                recipientId = after.customerId;
                title = "✅ Rental Booking Confirmed";
                body = `Your rental booking for ${listingTitle} has been confirmed!`;
                notificationType = "rental_confirmed";
                break;
            case "cancelled":
                // Notify the customer that booking was cancelled
                recipientId = after.customerId;
                title = "❌ Rental Booking Cancelled";
                body = `Your rental booking for ${listingTitle} has been cancelled`;
                notificationType = "rental_cancelled";
                break;
            case "active":
                // Notify customer that rental period has started
                recipientId = after.customerId;
                title = `${startEmoji} Rental Started`;
                body = `Your rental period for ${listingTitle} has started. Enjoy!`;
                notificationType = "rental_started";
                break;
            case "completed":
                // Notify customer that rental is complete
                recipientId = after.customerId;
                title = "✨ Rental Complete";
                body = `Your rental of ${listingTitle} is complete. Thank you!`;
                notificationType = "rental_completed";
                break;
            default:
                return null;
        }
        if (!recipientId) {
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
        // Check if push notifications are enabled
        if (recipient?.settings?.allowPushNotifications === false) {
            console.log("Push notifications disabled for recipient:", recipientId);
            return null;
        }
        // Send notification
        const message = {
            token: recipientFcmToken,
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: notificationType,
                bookingId: bookingId,
                listingId: after.listingId,
                status: after.status,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
                priority: "high",
                notification: {
                    sound: "default",
                    channelId: "rental_bookings",
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
        console.log(`Rental ${after.status} notification sent to:`, recipientId);
        return null;
    }
    catch (error) {
        console.error("Error sending rental status notification:", error);
        return null;
    }
});
