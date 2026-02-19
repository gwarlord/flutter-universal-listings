import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";
import { sendgridKeySecret, revenuecatKeySecret } from "./common/secrets";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Verify RevenueCat entitlement server-side using REST API
 * @param appUserId - The Firebase UID (used as appUserId in RevenueCat)
 * @param entitlementId - The entitlement to check (e.g., "CaribTap Pro")
 * @returns true if user has active entitlement, false otherwise
 */
async function hasRevenueCatEntitlement(appUserId: string, entitlementId: string): Promise<boolean> {
  const revenuecatKey = await revenuecatKeySecret.value();
  if (!revenuecatKey) {
    functions.logger.warn("RevenueCat API key not configured, skipping entitlement check");
    // In development, allow without RevenueCat verification
    return true; // TODO: Change to false in production
  }

  try {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${appUserId}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${revenuecatKey}`,
        "Accept": "application/json",
      },
    });

    if (!response.ok) {
      functions.logger.error("RevenueCat API error", { status: response.status });
      return false;
    }

    const data = await response.json() as any;
    const subscriber = data.subscriber;

    // Check if user has active entitlement
    if (subscriber?.entitlements && subscriber.entitlements[entitlementId]) {
      const entitlement = subscriber.entitlements[entitlementId];
      return entitlement.expires_date ? new Date(entitlement.expires_date) > new Date() : false;
    }

    return false;
  } catch (error) {
    functions.logger.error("Error checking RevenueCat entitlement", { error, appUserId });
    return false;
  }
}

/**
 * Callable function to set/update order tracking information
 * 
 * Requires:
 * - User must be authenticated
 * - User must be the lister (owner) of the order
 * - User must have active "CaribTap Pro" entitlement
 * 
 * Input data:
 * {
 *   orderId: string
 *   carrierName?: string
 *   trackingNumber: string (required to save)
 *   trackingUrl: string (required to save)
 *   status?: "UNKNOWN" | "LABEL_CREATED" | "IN_TRANSIT" | "OUT_FOR_DELIVERY" | "DELIVERED"
 * }
 */
export const setOrderTracking = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  const uid = context.auth.uid;
  const { orderId, carrierName, trackingNumber, trackingUrl, status } = data;

  // Validate required fields
  if (!orderId || typeof orderId !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "orderId is required");
  }

  // Tracking number and URL are required to save
  if (!trackingNumber || !trackingUrl) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "trackingNumber and trackingUrl are required"
    );
  }

  try {
    // Get the order
    const orderDoc = await admin.firestore().collection("order_requests").doc(orderId).get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found");
    }

    const order = orderDoc.data();

    // Verify user is the lister
    if (order?.listerId !== uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You do not have permission to update this order"
      );
    }

    // Verify order is using SHIPPING fulfillment method
    if (order?.fulfillment?.method !== "shipping") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "This order does not use shipping fulfillment"
      );
    }

    // CRITICAL: Verify user has active RevenueCat entitlement for "CaribTap Pro"
    const hasProEntitlement = await hasRevenueCatEntitlement(uid, "CaribTap Pro");

    if (!hasProEntitlement) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Tracking is only available for CaribTap Pro subscribers"
      );
    }

    // Get previous shipping data to detect changes for email notifications
    const previousShipping = order?.shipping || {};
    const wasTracked = previousShipping?.trackingNumber && previousShipping?.trackingUrl;

    // Prepare new shipping data
    const updatedShipping = {
      carrierName: carrierName || previousShipping.carrierName || null,
      trackingNumber,
      trackingUrl,
      status: status || previousShipping.status || "UNKNOWN",
      updatedAt: new Date().toISOString(),
      updatedBy: uid,
    };

    // Update order in Firestore
    await admin.firestore().collection("order_requests").doc(orderId).update({
      shipping: updatedShipping,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // Send email notification to customer
    const customerDoc = await admin.firestore().collection("users").doc(order?.customerId).get();
    const customer = customerDoc.data();

    if (customer?.email) {
      const isFirstTracking = !wasTracked; // First time adding tracking
      const trackingLink = trackingUrl ? `<a href="${trackingUrl}">View Tracking</a>` : trackingNumber;

      const subject = isFirstTracking
        ? "📦 Your order has been shipped!"
        : "📦 Tracking updated";

      const html = isFirstTracking
        ? `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #333;">Your order has been shipped! 🎉</h2>
            <p>Great news! Your order is on its way.</p>
            <div style="background-color: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 8px;">
              <p><strong>Carrier:</strong> ${carrierName || "TBD"}</p>
              <p><strong>Tracking Number:</strong> ${trackingNumber}</p>
              <p><strong>Status:</strong> ${status || "UNKNOWN"}</p>
              <p style="margin-top: 20px;">${trackingLink}</p>
            </div>
            <p>Thank you for your order!</p>
          </div>
        `
        : `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #333;">Tracking updated ✉️</h2>
            <p>Your order tracking has been updated.</p>
            <div style="background-color: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 8px;">
              <p><strong>Carrier:</strong> ${carrierName || "TBD"}</p>
              <p><strong>Tracking Number:</strong> ${trackingNumber}</p>
              <p><strong>Status:</strong> ${status || "UNKNOWN"}</p>
              <p style="margin-top: 20px;">${trackingLink}</p>
            </div>
          </div>
        `;

      try {
        const sendgridKey = await sendgridKeySecret.value();
        if (sendgridKey) {
          sgMail.setApiKey(sendgridKey);
          await sgMail.send({
            to: customer.email,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject,
            html,
          });
        } else {
          functions.logger.warn("SendGrid not configured, skipping email");
        }
      } catch (emailError) {
        functions.logger.error("Error sending tracking email", emailError);
        // Don't fail the whole operation if email fails
      }
    }

    return {
      success: true,
      message: "Tracking information updated successfully",
      orderId,
      tracking: updatedShipping,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error("Error updating order tracking", error);
    throw new functions.https.HttpsError("internal", "Failed to update tracking");
  }
});

/**
 * Send tracking email to customer
 * Called internally or manually to resend tracking info
 */
export const sendTrackingEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  const { orderId } = data;

  if (!orderId) {
    throw new functions.https.HttpsError("invalid-argument", "orderId is required");
  }

  try {
    const orderDoc = await admin.firestore().collection("order_requests").doc(orderId).get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Order not found");
    }

    const order = orderDoc.data();

    // Verify user is the lister
    if (order?.listerId !== context.auth.uid) {
      throw new functions.https.HttpsError("permission-denied", "Not authorized");
    }

    if (!order?.shipping || !order.shipping.trackingNumber) {
      throw new functions.https.HttpsError("invalid-argument", "No tracking info available");
    }

    const customer = (await admin.firestore().collection("users").doc(order.customerId).get()).data();

    if (!customer?.email) {
      throw new functions.https.HttpsError("invalid-argument", "Customer email not found");
    }

    const { carrierName, trackingNumber, trackingUrl, status } = order.shipping;
    const trackingLink = trackingUrl ? `<a href="${trackingUrl}">View Tracking</a>` : trackingNumber;

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
        <h2 style="color: #333;">Order Tracking Info</h2>
        <div style="background-color: #f5f5f5; padding: 20px; margin: 20px 0; border-radius: 8px;">
          <p><strong>Carrier:</strong> ${carrierName || "TBD"}</p>
          <p><strong>Tracking Number:</strong> ${trackingNumber}</p>
          <p><strong>Status:</strong> ${status || "UNKNOWN"}</p>
          <p style="margin-top: 20px;">${trackingLink}</p>
        </div>
      </div>
    `;

    const sendgridKey = await sendgridKeySecret.value();
    if (sendgridKey) {
      sgMail.setApiKey(sendgridKey);
      await sgMail.send({
        to: customer.email,
        from: { email: "admin@caribtap.com", name: "CaribTap" },
        subject: "📦 Your order tracking information",
        html,
      });
    }

    return { success: true, message: "Tracking email sent" };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    functions.logger.error("Error sending tracking email", error);
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});
