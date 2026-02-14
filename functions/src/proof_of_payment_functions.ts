import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const messaging = admin.messaging();

// Send push notification to user
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    const pushToken = userDoc.get("pushToken");

    if (!pushToken) return;

    await messaging.sendToDevice(pushToken, {
      notification: { title, body },
      data: data || {},
    });
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
}

// Send email notification
async function sendEmail(to: string, subject: string, html: string) {
  try {
    const sgMail = require("@sendgrid/mail");
    sgMail.setApiKey(process.env.SENDGRID_API_KEY || "");

    await sgMail.send({
      to,
      from: "noreply@caribtap.com",
      subject,
      html,
    });
  } catch (error) {
    console.error("Error sending email:", error);
  }
}

/**
 * Callable Cloud Function: submitProofOfPayment
 * Customer submits POP after uploading to Storage
 * Validates ownership and updates Firestore
 */
export const submitProofOfPayment = functions.https.onCall(
  async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
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

      const orderData = orderSnap.data() as any;

      // Only the customer who placed the order can submit POP
      if (orderData.customerId !== customerId) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You are not the owner of this order"
        );
      }

      // Verify listing payment settings are enabled
      const listingSnap = await db.collection("listings").doc(listingId).get();
      if (!listingSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Listing not found"
        );
      }

      const listingData = listingSnap.data() as any;
      const popSettings = listingData.payments || {};

      if (!popSettings.acceptProofOfPayment) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "This listing does not accept proof of payment"
        );
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
        await sendEmail(
          listerEmail,
          `New Proof of Payment - Order #${orderId.slice(0, 8)}`,
          `
            <h3>New Proof of Payment Submitted</h3>
            <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
            <p><strong>Customer:</strong> ${orderData.customerName}</p>
            <p><strong>Listing:</strong> ${orderData.listingTitle}</p>
            <p><strong>File Type:</strong> ${fileType}</p>
            <p>Please log in to review this proof of payment.</p>
            <br/>
            <p>Best regards,<br/>CaribTap Team</p>
          `
        );
      }

      // Push notification to lister
      await sendPushNotification(
        listerUserId,
        "New Proof of Payment",
        `${orderData.customerName} submitted proof of payment for Order #${orderId.slice(0, 8)}`,
        {
          orderId,
          listingId,
          type: "proof_of_payment_submitted",
        }
      );

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
    } catch (error: any) {
      console.error("Error submitting proof of payment:", error);
      if (error.code && error.message) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Internal server error"
      );
    }
  }
);

/**
 * Callable Cloud Function: reviewProofOfPayment
 * Lister/staff reviews and verifies or rejects POP
 */
export const reviewProofOfPayment = functions.https.onCall(
  async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const reviewerId = context.auth.uid;
    const { listingId, orderId, decision, reviewNote } = data;

    try {
      // Verify decision is valid
      if (!["VERIFIED", "REJECTED"].includes(decision)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Decision must be VERIFIED or REJECTED"
        );
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

      const orderData = orderSnap.data() as any;

      // Verify that reviewer is the listing owner or a collaborator with permission
      const listingSnap = await db.collection("listings").doc(listingId).get();
      if (!listingSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Listing not found"
        );
      }

      const listingData = listingSnap.data() as any;

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
          throw new functions.https.HttpsError(
            "permission-denied",
            "You do not have permission to review proofs of payment"
          );
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
      const decisionColor =
        decision === "VERIFIED" ? "green" : "red";

      if (customerEmail) {
        await sendEmail(
          customerEmail,
          `Proof of Payment ${decisionText.toUpperCase()} - Order #${orderId.slice(0, 8)}`,
          `
            <h3>Your Proof of Payment Has Been ${decision.toUpperCase()}</h3>
            <p><strong>Order:</strong> #${orderId.slice(0, 8)}</p>
            <p><strong>Listing:</strong> ${orderData.listingTitle}</p>
            <p><strong>Status:</strong> <span style="color: ${decisionColor}; font-weight: bold;">${decision}</span></p>
            ${reviewNote ? `<p><strong>Message:</strong> ${reviewNote}</p>` : ""}
            <p>Thank you for submitting your proof of payment.</p>
            <br/>
            <p>Best regards,<br/>CaribTap Team</p>
          `
        );
      }

      // Push notification to customer
      await sendPushNotification(
        customerId,
        `Proof of Payment ${decision}`,
        `Your proof of payment for Order #${orderId.slice(0, 8)} has been ${decisionText}`,
        {
          orderId,
          listingId,
          decision,
          type: "proof_of_payment_reviewed",
        }
      );

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
    } catch (error: any) {
      console.error("Error reviewing proof of payment:", error);
      if (error.code && error.message) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Internal server error"
      );
    }
  }
);
