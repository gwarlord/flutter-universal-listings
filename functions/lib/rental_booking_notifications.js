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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onRentalBookingEndTimeChanged = exports.sendOverdueRentalAlerts = exports.sendRentalReturnReminders = exports.onRentalBookingStatusChanged = exports.onRentalBookingCreated = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
const secrets_1 = require("./common/secrets");
const RETURN_REMINDER_WINDOW_MS = 10 * 60 * 1000; // +/- 10 min
const RENTAL_EVENT_DEDUP_COLLECTION = "_function_event_dedup";
const RENTAL_ALERTS_EMAIL_FROM = {
    email: "bookings@caribtap.com",
    name: "CaribTap Rentals",
};
function getUserPushTokens(userData) {
    if (!userData)
        return [];
    if (Array.isArray(userData.fcmTokens)) {
        return Array.from(new Set(userData.fcmTokens
            .filter((token) => typeof token === "string" && token.trim().length > 0)
            .map((token) => token.trim())));
    }
    if (typeof userData.pushToken === "string" && userData.pushToken.trim().length > 0) {
        return [userData.pushToken];
    }
    return [];
}
function hasRentalBeenReturned(booking, status) {
    return (status === "completed" ||
        status === "cancelled" ||
        status === "disputed" ||
        !!booking.returnedAt ||
        !!booking.checkinEvidence);
}
function normalizedCancellationReason(rawReason) {
    if (typeof rawReason !== "string") {
        return "";
    }
    const reason = rawReason.trim().replace(/\s+/g, " ");
    if (!reason) {
        return "";
    }
    return reason.length > 120 ? `${reason.substring(0, 117)}...` : reason;
}
/**
 * Firestore/PubSub triggers are at-least-once. Persist event ids to avoid duplicate sends.
 */
async function shouldProcessEvent(eventId) {
    if (!eventId)
        return true;
    const dedupRef = admin
        .firestore()
        .collection(RENTAL_EVENT_DEDUP_COLLECTION)
        .doc(`rental_${eventId}`);
    try {
        await dedupRef.create({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return true;
    }
    catch (error) {
        if (error?.code === 6 || error?.code === "already-exists") {
            return false;
        }
        throw error;
    }
}
/**
 * Send notification when a new rental booking is created
 */
exports.onRentalBookingCreated = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onCreate(async (snap, context) => {
    const shouldProcess = await shouldProcessEvent(context.eventId);
    if (!shouldProcess) {
        console.log("Skipping duplicate rental create event", {
            eventId: context.eventId,
        });
        return null;
    }
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
    const shouldProcess = await shouldProcessEvent(context.eventId);
    if (!shouldProcess) {
        console.log("Skipping duplicate rental status event", {
            eventId: context.eventId,
        });
        return null;
    }
    const before = change.before.data();
    const after = change.after.data();
    const bookingId = context.params.bookingId;
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
        const beforePayment = (before.payment || {});
        const afterPayment = (after.payment || {});
        const proofUrlBefore = String(beforePayment.proofOfPaymentUrl || "").trim();
        const proofUrlAfter = String(afterPayment.proofOfPaymentUrl || "").trim();
        const proofStatusBefore = String(beforePayment.proofOfPaymentStatus || "").toLowerCase();
        const proofStatusAfter = String(afterPayment.proofOfPaymentStatus || "").toLowerCase();
        const proofUploaded = !proofUrlBefore && !!proofUrlAfter;
        const proofReviewed = proofUrlAfter.length > 0 &&
            proofStatusBefore !== proofStatusAfter &&
            (proofStatusAfter === "approved" || proofStatusAfter === "rejected");
        if (proofUploaded) {
            recipientId = after.listerId;
            title = "Payment Proof Uploaded";
            body = `A customer uploaded proof of payment for ${listingTitle}.`;
            notificationType = "rental_proof_uploaded";
        }
        else if (proofReviewed) {
            recipientId = after.customerId;
            title = proofStatusAfter === "approved"
                ? "Payment Proof Approved"
                : "Payment Proof Rejected";
            body = proofStatusAfter === "approved"
                ? `Your proof of payment for ${listingTitle} was approved.`
                : `Your proof of payment for ${listingTitle} was rejected. Please upload a new one.`;
            notificationType = "rental_proof_reviewed";
        }
        if (!notificationType) {
            // Only process status-driven notifications when status changed.
            if (before.status === after.status) {
                return null;
            }
            switch (after.status) {
                case "confirmed":
                    // Notify customer that booking was confirmed
                    recipientId = after.customerId;
                    title = "✅ Rental Booking Confirmed";
                    body = `Your rental booking for ${listingTitle} has been confirmed!`;
                    notificationType = "rental_confirmed";
                    break;
                case "cancelled":
                    // Notify the customer with a distinct message for declined requests.
                    recipientId = after.customerId;
                    {
                        const cancelledByRole = (after.cancelledByRole || "").toString().toLowerCase();
                        const previousStatus = (before.status || "").toString().toLowerCase();
                        const wasDeclinedByLister = cancelledByRole === "lister" && previousStatus === "pending";
                        const wasCancelledByCustomer = cancelledByRole === "customer";
                        if (wasDeclinedByLister) {
                            title = "Rental Request Declined";
                            body = `Your booking request for ${listingTitle} was declined by the host. We're sorry this one didn't work out.`;
                        }
                        else if (wasCancelledByCustomer) {
                            title = "Rental Booking Cancelled";
                            body = `You cancelled your booking for ${listingTitle}.`;
                        }
                        else {
                            title = "Rental Booking Cancelled";
                            body = `Your booking for ${listingTitle} was cancelled by the host. We're sorry for the inconvenience.`;
                        }
                    }
                    {
                        const reason = normalizedCancellationReason(after.cancellationReason);
                        if (reason) {
                            body = `${body} Reason: ${reason}`;
                        }
                    }
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
        const recipientTokens = getUserPushTokens(recipient);
        if (recipientTokens.length === 0) {
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
            tokens: recipientTokens,
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
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Rental ${after.status} notification sent to:`, recipientId, {
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
        return null;
    }
    catch (error) {
        console.error("Error sending rental status notification:", error);
        return null;
    }
});
/**
 * Notify listers 1 hour before expected return time.
 * Skips bookings that are already returned/completed/disputed/cancelled.
 */
exports.sendRentalReturnReminders = functions.pubsub
    .schedule("every 10 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    const now = Date.now();
    const target = now + 60 * 60 * 1000; // 1 hour
    const lowerBound = new Date(target - RETURN_REMINDER_WINDOW_MS);
    const upperBound = new Date(target + RETURN_REMINDER_WINDOW_MS);
    try {
        const snapshot = await admin
            .firestore()
            .collection("rental_bookings")
            .where("endTime", ">=", lowerBound)
            .where("endTime", "<=", upperBound)
            .get();
        let sentCount = 0;
        for (const doc of snapshot.docs) {
            const booking = doc.data();
            const bookingId = doc.id;
            let claimed = false;
            let bookingForSend = null;
            // Atomically claim this reminder to prevent concurrent schedule runs from double sending.
            await admin.firestore().runTransaction(async (tx) => {
                const freshSnap = await tx.get(doc.ref);
                if (!freshSnap.exists) {
                    return;
                }
                const freshBooking = freshSnap.data();
                const status = (freshBooking.status || "").toString().toLowerCase();
                if (freshBooking.returnReminder1hSentAt) {
                    return;
                }
                if (hasRentalBeenReturned(freshBooking, status)) {
                    return;
                }
                if (status !== "confirmed" && status !== "active") {
                    return;
                }
                tx.update(doc.ref, {
                    returnReminder1hSentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                claimed = true;
                bookingForSend = freshBooking;
            });
            if (!claimed || !bookingForSend) {
                continue;
            }
            const claimedBooking = bookingForSend;
            const listerId = claimedBooking.listerId;
            if (!listerId) {
                continue;
            }
            const listerDoc = await admin.firestore().collection("users").doc(listerId).get();
            if (!listerDoc.exists) {
                continue;
            }
            const lister = listerDoc.data();
            if (lister?.settings?.allowPushNotifications === false) {
                continue;
            }
            const tokens = getUserPushTokens(lister);
            if (tokens.length === 0) {
                continue;
            }
            const listingDoc = await admin
                .firestore()
                .collection("listings")
                .doc(claimedBooking.listingId)
                .get();
            const listingTitle = listingDoc.exists
                ? listingDoc.data()?.title || "your rental item"
                : "your rental item";
            const endDate = claimedBooking.endTime?.toDate?.() || new Date(claimedBooking.endTime);
            const endTimeText = endDate.toLocaleTimeString("en-US", {
                hour: "numeric",
                minute: "2-digit",
            });
            const message = {
                tokens,
                notification: {
                    title: "Return Reminder: due in 1 hour",
                    body: `${listingTitle} is expected back at ${endTimeText}.`,
                },
                data: {
                    type: "rental_return_reminder",
                    bookingId,
                    listingId: claimedBooking.listingId || "",
                    reminderType: "1h_before_return",
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
                        },
                    },
                },
            };
            const response = await admin.messaging().sendEachForMulticast(message);
            if (response.successCount > 0) {
                sentCount++;
            }
            else {
                // Release the claim so the next scheduler run can retry.
                await doc.ref.update({
                    returnReminder1hSentAt: null,
                });
            }
        }
        console.log("Rental return reminders processed", {
            checked: snapshot.size,
            sent: sentCount,
        });
        return null;
    }
    catch (error) {
        console.error("Error sending rental return reminders", error);
        return null;
    }
});
/**
 * Notify listers when an active rental is overdue for return.
 * Sends one-time push + email per booking (tracked via overdueAlertSentAt).
 */
exports.sendOverdueRentalAlerts = functions.runWith({ secrets: [secrets_1.sendgridKeySecret] }).pubsub
    .schedule("every 10 minutes")
    .timeZone("UTC")
    .onRun(async () => {
    try {
        const now = Date.now();
        const sendgridKey = await secrets_1.sendgridKeySecret.value();
        if (sendgridKey) {
            mail_1.default.setApiKey(sendgridKey);
        }
        const snapshot = await admin
            .firestore()
            .collection("rental_bookings")
            .where("status", "==", "active")
            .get();
        let checked = 0;
        let alertsSent = 0;
        for (const doc of snapshot.docs) {
            const booking = doc.data();
            const bookingId = doc.id;
            const endMillis = booking.endTime?.toDate?.()?.getTime?.();
            if (!endMillis || endMillis > now) {
                continue;
            }
            checked++;
            let claimed = false;
            let claimedBooking = null;
            // Claim once to avoid duplicate sends on overlapping scheduler runs.
            await admin.firestore().runTransaction(async (tx) => {
                const freshSnap = await tx.get(doc.ref);
                if (!freshSnap.exists) {
                    return;
                }
                const fresh = freshSnap.data();
                const status = (fresh.status || "").toString().toLowerCase();
                const freshEndMillis = fresh.endTime?.toDate?.()?.getTime?.();
                if (!freshEndMillis || freshEndMillis > now) {
                    return;
                }
                if (status !== "active") {
                    return;
                }
                if (fresh.overdueAlertSentAt) {
                    return;
                }
                if (hasRentalBeenReturned(fresh, status)) {
                    return;
                }
                tx.update(doc.ref, {
                    overdueAlertSentAt: admin.firestore.FieldValue.serverTimestamp(),
                });
                claimed = true;
                claimedBooking = fresh;
            });
            if (!claimed || !claimedBooking) {
                continue;
            }
            const currentBooking = claimedBooking;
            const listerId = currentBooking.listerId || "";
            if (!listerId) {
                continue;
            }
            const [listerSnap, listingSnap, customerSnap] = await Promise.all([
                admin.firestore().collection("users").doc(listerId).get(),
                admin.firestore().collection("listings").doc(currentBooking.listingId || "").get(),
                admin.firestore().collection("users").doc(currentBooking.customerId || "").get(),
            ]);
            if (!listerSnap.exists) {
                continue;
            }
            const lister = listerSnap.data() || {};
            const listingTitle = listingSnap.exists
                ? listingSnap.data()?.title || "your rental item"
                : "your rental item";
            const customerName = customerSnap.exists
                ? `${customerSnap.data()?.firstName || ""} ${customerSnap.data()?.lastName || ""}`.trim() || "a customer"
                : "a customer";
            const overdueSince = currentBooking.endTime?.toDate?.() || new Date(now);
            const overdueTimeText = overdueSince.toLocaleTimeString("en-US", {
                hour: "numeric",
                minute: "2-digit",
            });
            const overdueDateText = overdueSince.toLocaleDateString("en-US", {
                month: "short",
                day: "numeric",
                year: "numeric",
            });
            let pushSent = false;
            let emailSent = false;
            if (lister.settings?.allowPushNotifications !== false) {
                const tokens = getUserPushTokens(lister);
                if (tokens.length > 0) {
                    const pushMessage = {
                        tokens,
                        notification: {
                            title: "Overdue Return Alert",
                            body: `${listingTitle} is overdue for return (due ${overdueDateText} at ${overdueTimeText}).`,
                        },
                        data: {
                            type: "rental_overdue",
                            bookingId,
                            listingId: currentBooking.listingId || "",
                            customerId: currentBooking.customerId || "",
                            overdueSince: overdueSince.toISOString(),
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
                    const pushResponse = await admin.messaging().sendEachForMulticast(pushMessage);
                    pushSent = pushResponse.successCount > 0;
                }
            }
            const listerEmail = lister.email?.trim();
            const emailEnabled = lister.settings?.bookingEmailReminders !== false;
            if (emailEnabled && listerEmail && sendgridKey) {
                const html = `
            <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #1f2937;">
              <h2 style="margin: 0 0 12px; color: #b91c1c;">Overdue Rental Return</h2>
              <p style="margin: 0 0 10px;">A rental booking is now overdue for return.</p>
              <p style="margin: 0 0 10px;"><strong>Listing:</strong> ${listingTitle}</p>
              <p style="margin: 0 0 10px;"><strong>Customer:</strong> ${customerName}</p>
              <p style="margin: 0 0 10px;"><strong>Due back:</strong> ${overdueDateText} at ${overdueTimeText}</p>
              <p style="margin: 0 0 10px;"><strong>Booking ID:</strong> ${bookingId}</p>
              <p style="margin: 0;">Open Manage Rentals in CaribTap to review and follow up.</p>
            </div>
          `;
                try {
                    await mail_1.default.send({
                        to: listerEmail,
                        from: RENTAL_ALERTS_EMAIL_FROM,
                        subject: `Overdue return alert: ${listingTitle}`,
                        html,
                    });
                    emailSent = true;
                }
                catch (emailError) {
                    console.error("Error sending overdue rental email", {
                        bookingId,
                        listerId,
                        emailError,
                    });
                }
            }
            if (!pushSent && !emailSent) {
                // Retry later if no channel succeeded.
                await doc.ref.update({ overdueAlertSentAt: null });
                continue;
            }
            alertsSent++;
        }
        console.log("Overdue rental alerts processed", {
            totalActive: snapshot.size,
            checked,
            alertsSent,
        });
        return null;
    }
    catch (error) {
        console.error("Error processing overdue rental alerts", error);
        return null;
    }
});
/**
 * If expected return time changes before return, allow reminder to be sent again.
 */
exports.onRentalBookingEndTimeChanged = functions.firestore
    .document("rental_bookings/{bookingId}")
    .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    const beforeMillis = before.endTime?.toDate?.()?.getTime?.();
    const afterMillis = after.endTime?.toDate?.()?.getTime?.();
    if (!beforeMillis || !afterMillis || beforeMillis === afterMillis) {
        return null;
    }
    const status = (after.status || "").toString().toLowerCase();
    if (hasRentalBeenReturned(after, status)) {
        return null;
    }
    try {
        await change.after.ref.update({
            returnReminder1hSentAt: null,
        });
        return null;
    }
    catch (error) {
        console.error("Error resetting rental return reminder marker", error);
        return null;
    }
});
