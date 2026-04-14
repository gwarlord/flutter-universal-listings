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
exports.onProofOfPaymentReviewed = exports.onProofOfPaymentUploaded = exports.reviewProofOfPayment = exports.submitProofOfPayment = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
const secrets_1 = require("./common/secrets");
const db = admin.firestore();
const messaging = admin.messaging();
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
async function sendPushNotification(userId, title, body, data) {
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists)
            return;
        const tokens = getTokens(userDoc.data());
        if (tokens.length === 0) {
            functions.logger.warn("POP: no FCM tokens found for user", { userId });
            return;
        }
        for (const token of tokens) {
            try {
                await messaging.send({
                    token,
                    notification: { title, body },
                    data: data || {},
                    android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
                    apns: { payload: { aps: { sound: "default", badge: 1 } } },
                });
            }
            catch (tokenError) {
                functions.logger.warn("POP: push token send failed", {
                    userId,
                    tokenSuffix: token.slice(-8),
                    error: tokenError?.message || String(tokenError),
                });
            }
        }
    }
    catch (error) {
        functions.logger.error("POP: error sending push notification", { userId, error });
    }
}
async function sendEmail(to, subject, html) {
    try {
        const apiKey = secrets_1.sendgridKeySecret.value();
        if (!apiKey) {
            functions.logger.warn("POP: SendGrid key not set, skipping email", { to, subject });
            return;
        }
        mail_1.default.setApiKey(apiKey);
        await mail_1.default.send({
            to,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject,
            html,
        });
    }
    catch (error) {
        functions.logger.error("POP: error sending email", { to, error });
    }
}
/**
 * Callable Cloud Function: submitProofOfPayment
 * Customer submits POP after uploading to Storage
 * Validates ownership and updates Firestore
 */
exports.submitProofOfPayment = functions.runWith({ secrets: [secrets_1.sendgridKeySecret] }).https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const customerId = context.auth.uid;
    const { listingId, orderId, fileUrl, filePath, fileType, fileName } = data;
    try {
        // Verify that the customer owns this order
        const orderSnap = await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(orderId)
            .get();
        if (!orderSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Order not found");
        }
        const orderData = orderSnap.data();
        // Only the customer who placed the order can submit POP
        if (orderData.customerId !== customerId) {
            throw new functions.https.HttpsError("permission-denied", "You are not the owner of this order");
        }
        // Verify listing payment settings are enabled
        const listingSnap = await db.collection("listings").doc(listingId).get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listingData = listingSnap.data();
        const popSettings = listingData.payments || {};
        if (!popSettings.acceptProofOfPayment) {
            throw new functions.https.HttpsError("failed-precondition", "This listing does not accept proof of payment");
        }
        // Update the order with the new POP upload
        const newUpload = {
            fileUrl,
            filePath,
            fileType,
            fileName,
            uploadedAt: admin.firestore.Timestamp.now(),
            uploadedByUid: customerId,
            status: "SUBMITTED",
        };
        const popData = orderData.proofOfPayment || {
            enabledAtOrderTime: popSettings.acceptProofOfPayment,
            uploads: [],
            overallStatus: "NONE",
        };
        // Add upload to array
        popData.uploads = popData.uploads || [];
        popData.uploads.push(newUpload);
        popData.overallStatus = "SUBMITTED";
        // Update order document
        await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(orderId)
            .update({
            proofOfPayment: popData,
            updatedAt: new Date().toISOString(),
        });
        // Also update customer's booking copy
        await db
            .collection("users")
            .doc(customerId)
            .collection("myBookings")
            .doc(orderId)
            .update({
            proofOfPayment: popData,
            updatedAt: new Date().toISOString(),
        });
        // Send notifications to lister and staff
        const listerEmail = orderData.listersEmail;
        const listerUserId = orderData.listersUserId;
        // Email to lister
        if (listerEmail) {
            await sendEmail(listerEmail, `New Proof of Payment - Order #${orderId.slice(0, 8)}`, `
            <h3>New Proof of Payment Submitted</h3>
            <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
            <p><strong>Customer:</strong> ${orderData.customerName}</p>
            <p><strong>Listing:</strong> ${orderData.listingTitle}</p>
            <p><strong>File Type:</strong> ${fileType}</p>
            <p>Please log in to review this proof of payment.</p>
            <br/>
            <p>Best regards,<br/>CaribTap Team</p>
          `);
        }
        // Push notification to lister
        await sendPushNotification(listerUserId, "New Proof of Payment", `${orderData.customerName} submitted proof of payment for Order #${orderId.slice(0, 8)}`, {
            orderId,
            listingId,
            type: "proof_of_payment_submitted",
        });
        // Write activity log event
        await db
            .collection("listings")
            .doc(listingId)
            .collection("activity_log")
            .add({
            type: "PAYMENT_PROOF_SUBMITTED",
            orderId,
            customerId,
            customerName: orderData.customerName,
            fileType,
            createdAt: admin.firestore.Timestamp.now(),
        });
        return {
            success: true,
            message: "Proof of payment submitted successfully",
        };
    }
    catch (error) {
        console.error("Error submitting proof of payment:", error);
        if (error.code && error.message) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "Internal server error");
    }
});
/**
 * Callable Cloud Function: reviewProofOfPayment
 * Lister/staff reviews and verifies or rejects POP
 */
exports.reviewProofOfPayment = functions.runWith({ secrets: [secrets_1.sendgridKeySecret] }).https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const reviewerId = context.auth.uid;
    const { listingId, orderId, decision, reviewNote } = data;
    try {
        // Verify decision is valid
        if (!["VERIFIED", "REJECTED"].includes(decision)) {
            throw new functions.https.HttpsError("invalid-argument", "Decision must be VERIFIED or REJECTED");
        }
        // Get order
        const orderSnap = await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(orderId)
            .get();
        if (!orderSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Order not found");
        }
        const orderData = orderSnap.data();
        // Verify that reviewer is the listing owner or a collaborator with permission
        const listingSnap = await db.collection("listings").doc(listingId).get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listingData = listingSnap.data();
        // Check if reviewer is listing owner
        const isLister = listingData.authorID === reviewerId;
        // If not lister, check if collaborator with manageOrders permission
        if (!isLister) {
            const collabSnap = await db
                .collection("collaborations")
                .where("listingId", "==", listingId)
                .where("collaboratorUid", "==", reviewerId)
                .where("canManageOrders", "==", true)
                .limit(1)
                .get();
            if (collabSnap.empty) {
                throw new functions.https.HttpsError("permission-denied", "You do not have permission to review proofs of payment");
            }
        }
        // Update POP with review data
        const popData = orderData.proofOfPayment || {};
        const uploads = popData.uploads || [];
        if (uploads.length > 0) {
            // Update latest upload
            const latestUpload = uploads[uploads.length - 1];
            latestUpload.status = decision;
            latestUpload.reviewerUid = reviewerId;
            latestUpload.reviewedAt = admin.firestore.Timestamp.now();
            latestUpload.reviewerNote = reviewNote || null;
        }
        popData.overallStatus = decision;
        // Update order
        await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(orderId)
            .update({
            proofOfPayment: popData,
            updatedAt: new Date().toISOString(),
        });
        // Send notification to customer
        const customerEmail = orderData.customerEmail;
        const customerId = orderData.customerId;
        const decisionText = decision === "VERIFIED" ? "verified" : "rejected";
        const decisionColor = decision === "VERIFIED" ? "green" : "red";
        if (customerEmail) {
            await sendEmail(customerEmail, `Proof of Payment ${decisionText.toUpperCase()} - Order #${orderId.slice(0, 8)}`, `
            <h3>Your Proof of Payment Has Been ${decision.toUpperCase()}</h3>
            <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
            <p><strong>Listing:</strong> ${orderData.listingTitle}</p>
            <p><strong>Status:</strong> <span style="color: ${decisionColor}; font-weight: bold;">${decision}</span></p>
            ${reviewNote ? `<p><strong>Message:</strong> ${reviewNote}</p>` : ""}
            <p>Thank you for submitting your proof of payment.</p>
            <br/>
            <p>Best regards,<br/>CaribTap Team</p>
          `);
        }
        // Push notification to customer
        await sendPushNotification(customerId, `Proof of Payment ${decision}`, `Your proof of payment for Order #${orderId.slice(0, 8)} has been ${decisionText}`, {
            orderId,
            listingId,
            decision,
            type: "proof_of_payment_reviewed",
        });
        // Write activity log
        await db
            .collection("listings")
            .doc(listingId)
            .collection("activity_log")
            .add({
            type: `PAYMENT_PROOF_${decision}`,
            orderId,
            reviewerId,
            reviewerName: listingData.authorName,
            note: reviewNote,
            createdAt: admin.firestore.Timestamp.now(),
        });
        return {
            success: true,
            message: `Proof of payment ${decisionText} successfully`,
        };
    }
    catch (error) {
        console.error("Error reviewing proof of payment:", error);
        if (error.code && error.message) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "Internal server error");
    }
});
/**
 * Firestore trigger: fires when a booking document is updated.
 * Detects new proof-of-payment uploads and notifies the lister.
 */
exports.onProofOfPaymentUploaded = functions.runWith({ secrets: [secrets_1.sendgridKeySecret] }).firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after)
        return;
    const beforeUploads = (before.proofOfPayment?.uploads) || [];
    const afterUploads = (after.proofOfPayment?.uploads) || [];
    // Only proceed if a new upload was added
    if (afterUploads.length <= beforeUploads.length)
        return;
    const listerUserId = after.listersUserId || "";
    const listerEmail = after.listersEmail || "";
    const customerName = after.customerName || "A customer";
    const listingTitle = after.listingTitle || "your listing";
    const orderId = after.id || context.params.bookingId;
    const listingId = context.params.listingId;
    // Push notification to lister
    if (listerUserId) {
        await sendPushNotification(listerUserId, "New Proof of Payment", `${customerName} submitted proof of payment for Order #${orderId.slice(0, 8)}`, {
            orderId,
            listingId,
            type: "proof_of_payment_submitted",
        });
    }
    // Email to lister
    if (listerEmail) {
        await sendEmail(listerEmail, `New Proof of Payment – Order #${orderId.slice(0, 8)}`, `
          <h3>New Proof of Payment Submitted</h3>
          <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
          <p><strong>Customer:</strong> ${customerName}</p>
          <p><strong>Listing:</strong> ${listingTitle}</p>
          <p>Please log in to review this proof of payment.</p>
          <br/>
          <p>Best regards,<br/>CaribTap Team</p>
        `);
    }
});
/**
 * Firestore trigger: fires when a booking document is updated.
 * Detects when a lister verifies or rejects proof of payment and notifies the customer.
 */
exports.onProofOfPaymentReviewed = functions.runWith({ secrets: [secrets_1.sendgridKeySecret] }).firestore
    .document("listings/{listingId}/bookings/{bookingId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after)
        return;
    const prevStatus = (before.proofOfPayment?.overallStatus || "").toUpperCase();
    const nextStatus = (after.proofOfPayment?.overallStatus || "").toUpperCase();
    // Only proceed when the review decision was just set (VERIFIED or REJECTED)
    if (prevStatus === nextStatus)
        return;
    if (!["VERIFIED", "REJECTED"].includes(nextStatus))
        return;
    // Don't fire on a fresh upload flipping from NONE → SUBMITTED (handled by onProofOfPaymentUploaded)
    if (nextStatus === "SUBMITTED")
        return;
    const customerId = after.customerId || "";
    const customerEmail = after.customerEmail || "";
    const listingTitle = after.listingTitle || "your listing";
    const orderId = after.id || context.params.bookingId;
    const listingId = context.params.listingId;
    const latestUpload = (after.proofOfPayment?.uploads || []).slice(-1)[0] || {};
    const reviewNote = latestUpload.reviewerNote || "";
    const decisionLabel = nextStatus === "VERIFIED" ? "Verified ✓" : "Rejected ✗";
    const decisionColor = nextStatus === "VERIFIED" ? "#4CAF50" : "#F44336";
    const decisionLower = nextStatus === "VERIFIED" ? "verified" : "rejected";
    // Push notification to customer
    if (customerId) {
        await sendPushNotification(customerId, `Proof of Payment ${decisionLabel}`, `Your proof of payment for Order #${orderId.slice(0, 8)} has been ${decisionLower}`, {
            orderId,
            listingId,
            type: "proof_of_payment_reviewed",
            decision: nextStatus,
        });
    }
    // Email to customer
    if (customerEmail) {
        await sendEmail(customerEmail, `Proof of Payment ${nextStatus} – Order #${orderId.slice(0, 8)}`, `
          <h3>Your Proof of Payment Has Been ${nextStatus}</h3>
          <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
          <p><strong>Listing:</strong> ${listingTitle}</p>
          <p><strong>Status:</strong> <span style="color: ${decisionColor}; font-weight: bold;">${decisionLabel}</span></p>
          ${reviewNote ? `<p><strong>Message from host:</strong> ${reviewNote}</p>` : ""}
          <br/>
          <p>Best regards,<br/>CaribTap Team</p>
        `);
    }
});
