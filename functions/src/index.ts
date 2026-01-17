import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Set your SendGrid API key in Functions config: firebase functions:config:set sendgrid.key="YOUR_KEY"
const SENDGRID_KEY = functions.config().sendgrid?.key;
if (SENDGRID_KEY) {
  sgMail.setApiKey(SENDGRID_KEY);
}

// Simple email sender
async function sendEmail(to: string, subject: string, html: string) {
  if (!SENDGRID_KEY) {
    functions.logger.warn("SendGrid key not set, skipping email", {to, subject});
    return;
  }
  await sgMail.send({
    to,
    from: {email: "no-reply@caribtap.com", name: "Caribbean Tap"},
    subject,
    html,
  });
}

// Send push notification to user
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    functions.logger.info("🔔 Attempting to send push notification", { userId, title, body });
    
    // Get user's FCM token
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      functions.logger.warn("❌ User not found for push notification", { userId });
      return;
    }

    const userData = userDoc.data();
    functions.logger.info("✅ User found", { userId, hasSettings: !!userData });

    const pushToken = userData?.pushToken;
    functions.logger.info("📱 Token check", { userId, hasToken: !!pushToken, tokenLength: pushToken?.length });
    
    if (!pushToken) {
      functions.logger.warn("❌ No push token for user", { userId, userData: userData });
      return;
    }

    // Send notification
    const message: admin.messaging.Message = {
      notification: {
        title,
        body,
      },
      data: data || {},
      token: pushToken,
    };

    functions.logger.info("📤 Sending message", { message });
    const messageId = await messaging.send(message);
    functions.logger.info("✅ Push notification sent successfully", { userId, title, messageId });
  } catch (error) {
    functions.logger.error("❌ Error sending push notification", { error, userId, title });
  }
}

// Build email bodies
function bookingRequestedEmail(data: any) {
  return {
    subject: `New booking request for ${data.listingTitle}`,
    html: `
      <p>You have a new booking request.</p>
      <p>Listing: ${data.listingTitle}</p>
      <p>Guest: ${data.customerName} (${data.customerEmail})</p>
      <p>Dates: ${data.checkInDate} → ${data.checkOutDate}</p>
      <p>Guests: ${data.numberOfGuests}</p>
      <p>Notes: ${data.guestNotes || "—"}</p>
    `,
  };
}

function bookingStatusEmail(data: any, status: string) {
  const titles: Record<string, string> = {
    confirmed: "Booking confirmed",
    rejected: "Booking rejected",
    cancelled: "Booking cancelled",
  };
  return {
    subject: `${titles[status] ?? "Booking update"}: ${data.listingTitle}`,
    html: `
      <p>Your booking has been ${status}.</p>
      <p>Listing: ${data.listingTitle}</p>
      <p>Dates: ${data.checkInDate} → ${data.checkOutDate}</p>
      <p>Status: ${status}</p>
    `,
  };
}

// Alias for backward compatibility
const buildStatusEmail = bookingStatusEmail;

// Trigger on new booking
export const onBookingCreated = functions.firestore
  .document("listings/{listingId}/bookings/{bookingId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return;

    // Send email to lister
    if (data.listersEmail) {
      const email = bookingRequestedEmail(data);
      await sendEmail(data.listersEmail, email.subject, email.html);
    }

    // Send push notification to lister
    await sendPushNotification(
      data.listersUserId,
      "New Booking Request",
      `${data.customerName} requested to book ${data.listingTitle}`,
      { bookingId: data.id, listingId: data.listingId, type: "booking_request" }
    );

    // Send confirmation email to customer
    if (data.customerEmail) {
      await sendEmail(
        data.customerEmail,
        `Booking request sent: ${data.listingTitle}`,
        `
          <p>Your booking request was sent.</p>
          <p>Listing: ${data.listingTitle}</p>
          <p>Dates: ${data.checkInDate} → ${data.checkOutDate}</p>
        `
      );
    }

    // Send confirmation push to customer
    await sendPushNotification(
      data.customerId,
      "Booking Sent",
      `Your booking request for ${data.listingTitle} has been sent`,
      { bookingId: data.id, listingId: data.listingId, type: "booking_sent" }
    );
  });

// Trigger on status change
export const onBookingUpdated = functions.firestore
  .document("listings/{listingId}/bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) return;

    const prevStatus = (before.status || "").toLowerCase();
    const nextStatus = (after.status || "").toLowerCase();
    if (prevStatus === nextStatus) return;

    // Send to customer
    if (after.customerEmail && ["confirmed", "rejected", "cancelled"].includes(nextStatus)) {
      const email = buildStatusEmail(after, nextStatus);
      await sendEmail(after.customerEmail, email.subject, email.html);

      // Send push to customer
      const notificationTitle = nextStatus === "confirmed" ? "Booking Confirmed!" : `Booking ${nextStatus}`;
      const notificationBody = `Your booking for ${after.listingTitle} has been ${nextStatus}`;
      
      await sendPushNotification(
        after.customerId,
        notificationTitle,
        notificationBody,
        { 
          bookingId: after.id, 
          listingId: after.listingId, 
          type: `booking_${nextStatus}`,
          status: nextStatus 
        }
      );
    }

    // Send to lister on cancellation
    if (after.listersEmail && nextStatus === "cancelled") {
      await sendEmail(
        after.listersEmail,
        `Booking cancelled: ${after.listingTitle}`,
        `
          <p>A booking was cancelled.</p>
          <p>Guest: ${after.customerName} (${after.customerEmail})</p>
          <p>Listing: ${after.listingTitle}</p>
          <p>Dates: ${after.checkInDate} → ${after.checkOutDate}</p>
        `
      );

      // Send push to lister
      await sendPushNotification(
        after.listersUserId,
        "Booking Cancelled",
        `${after.customerName} cancelled their booking for ${after.listingTitle}`,
        { bookingId: after.id, listingId: after.listingId, type: "booking_cancelled" }
      );
    }
  });
