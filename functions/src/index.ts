import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";
import { sendgridKeySecret } from "./common/secrets";

// Initialize Firebase Admin before any imports that use it
admin.initializeApp();

// Export email verification functions
export * from "./email_verification";

// Export order notification functions
export * from "./order_notifications";

// Export order tracking functions
export * from "./order_tracking";

// Export rental booking notification functions
export * from "./rental_booking_notifications";

// Export booking notification functions
export * from "./booking_notifications";

// Export user suspension notification functions
export * from "./user_suspension_notifications";

// Export listing suspension notification functions
export * from "./listing_suspension_notifications";

// Export booking reminder functions
export * from "./booking_reminders";

// Export listing freshness functions
export * from "./listing_freshness";

// Export collaboration functions
export * from "./collaboration";

// Export tap functions
export * from "./tap_functions";

// Export deal ad notification functions
export * from "./deal_ad_notifications";

// Export chat notification functions
export * from "./chat_notifications";

// Export attention tracking functions (badges/dots)
export * from "./attention_tracking";

// Export table mode functions
export * from "./tableMode";

// Export brand functions
export * from "./brand_functions";

// Export proof of payment functions
export * from "./proof_of_payment_functions";

// Export AI photo enhancement functions
export * from "./photo_enhancement";

// Export AI search functions
export * from "./ai_search/index";

// Export pro docs functions
export * from "./pro_docs/quote_acceptance";

// Export subscription verification functions
export * from "./subscriptions";

// Export featured listing functions
export * from "./featured_functions";

const db = admin.firestore();
const messaging = admin.messaging();

// Remove old sendEmail helper - use the one from common/secrets.ts if needed
// For functions that need to send emails, import sendgridKeySecret and use it within the function

// Send push notification to user
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
) {
  try {
    functions.logger.info("🔔 Attempting to send push notification", { userId, title, body });
    
    // Get user's FCM token(s)
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      functions.logger.warn("❌ User not found for push notification", { userId });
      return;
    }

    const userData = userDoc.data();
    functions.logger.info("✅ User found", { userId, hasSettings: !!userData });

    // Support both new (fcmTokens array) and legacy (pushToken string) field names
    let tokens: string[] = [];
    
    // New format: array of FCM tokens
    if (Array.isArray(userData?.fcmTokens) && userData.fcmTokens.length > 0) {
      tokens = userData.fcmTokens;
    }
    // Legacy format: single pushToken string
    else if (userData?.pushToken && typeof userData.pushToken === "string" && userData.pushToken.trim().length > 0) {
      tokens = [userData.pushToken];
    }

    functions.logger.info("📱 Token check", { userId, tokenCount: tokens.length, hasLegacyToken: !!userData?.pushToken, hasNewTokens: !!userData?.fcmTokens });
    
    if (tokens.length === 0) {
      functions.logger.warn("❌ No push tokens for user", { userId });
      return;
    }

    // Send notification using multicast (supports multiple tokens and provides better error handling)
    const message: admin.messaging.MulticastMessage = {
      notification: {
        title,
        body,
      },
      data: data || {},
      tokens: tokens,
    };

    functions.logger.info("📤 Sending message to", { userId, tokenCount: tokens.length });
    const response = await messaging.sendMulticast(message);
    functions.logger.info("✅ Push notification sent", { 
      userId, 
      title, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      tokenCount: tokens.length
    });
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
      <p><b>Start Date:</b> ${data.checkInDate}</p>
      <p><b>End Date:</b> ${data.checkOutDate}</p>
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
  let extra = '';
  if (status === 'confirmed') {
    extra = '<p>Thank you for your business!</p>';
  }
  return {
    subject: `${titles[status] ?? "Booking update"}: ${data.listingTitle}`,
    html: `
      <p>Your booking has been ${status}.</p>
      <p>Listing: ${data.listingTitle}</p>
      <p><b>Start Date:</b> ${data.checkInDate}</p>
      <p><b>End Date:</b> ${data.checkOutDate}</p>
      <p>Status: ${status}</p>
      ${extra}
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
      try {
        const sendgridKey = await sendgridKeySecret.value();
        if (sendgridKey) {
          sgMail.setApiKey(sendgridKey);
          await sgMail.send({
            to: data.listersEmail,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject: email.subject,
            html: email.html,
          });
        }
      } catch (error) {
        functions.logger.error("Error sending email", { error, to: data.listersEmail });
      }
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
      try {
        const sendgridKey = await sendgridKeySecret.value();
        if (sendgridKey) {
          sgMail.setApiKey(sendgridKey);
          await sgMail.send({
            to: data.customerEmail,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject: `Booking request sent: ${data.listingTitle}`,
            html: `
              <p>Your booking request was sent.</p>
              <p>Listing: ${data.listingTitle}</p>
              <p>Dates: ${data.checkInDate} → ${data.checkOutDate}</p>
            `,
          });
        }
      } catch (error) {
        functions.logger.error("Error sending email", { error, to: data.customerEmail });
      }
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
      try {
        const sendgridKey = await sendgridKeySecret.value();
        if (sendgridKey) {
          sgMail.setApiKey(sendgridKey);
          await sgMail.send({
            to: after.customerEmail,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject: email.subject,
            html: email.html,
          });
        }
      } catch (error) {
        functions.logger.error("Error sending email", { error, to: after.customerEmail });
      }

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
      try {
        const sendgridKey = await sendgridKeySecret.value();
        if (sendgridKey) {
          sgMail.setApiKey(sendgridKey);
          await sgMail.send({
            to: after.listersEmail,
            from: { email: "admin@caribtap.com", name: "CaribTap" },
            subject: `Booking cancelled: ${after.listingTitle}`,
            html: `
              <p>A booking was cancelled.</p>
              <p>Guest: ${after.customerName} (${after.customerEmail})</p>
              <p>Listing: ${after.listingTitle}</p>
              <p>Dates: ${after.checkInDate} → ${after.checkOutDate}</p>
            `,
          });
        }
      } catch (error) {
        functions.logger.error("Error sending email", { error, to: after.listersEmail });
      }

      // Send push to lister
      await sendPushNotification(
        after.listersUserId,
        "Booking Cancelled",
        `${after.customerName} cancelled their booking for ${after.listingTitle}`,
        { bookingId: after.id, listingId: after.listingId, type: "booking_cancelled" }
      );
    }
  });

function buildReminderEmail(user: admin.firestore.DocumentData, expiresAt: Date) {
  const friendlyDate = expiresAt.toISOString().split("T")[0];
  return {
    subject: `Your CaribTap subscription expires on ${friendlyDate}`,
    html: `
      <p>Hi ${user.firstName || "there"},</p>
      <p>Your subscription will expire on <strong>${friendlyDate}</strong>.</p>
      <p>Open the app to renew and avoid losing booking and premium features.</p>
      <p><a href="https://caribtap.com">Open CaribTap</a></p>
    `,
  };
}

export const sendSubscriptionReminders = functions.pubsub
  .schedule("every 1 hours")
  .onRun(async () => {
    const now = new Date();

    const snap = await db
      .collection("users")
      .where("subscriptionExpiresAt", "!=", null)
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const settings = (data.settings || {}) as { subscriptionReminderDays?: number | string; allowPushNotifications?: boolean };
      const tier = (data.subscriptionTier || "").toString().trim().toLowerCase();
      const expiresAt = data.subscriptionExpiresAt?.toDate?.() as Date | undefined;

      if (!expiresAt) continue;
      if (!["professional", "premium", "business"].includes(tier)) continue;

      let reminderDays = 3;
      if (typeof settings.subscriptionReminderDays === "number") {
        reminderDays = settings.subscriptionReminderDays;
      } else if (typeof settings.subscriptionReminderDays === "string") {
        const parsed = parseInt(settings.subscriptionReminderDays, 10);
        if (!isNaN(parsed)) reminderDays = parsed;
      }
      if (reminderDays <= 0) continue;

      const reminderAt = new Date(expiresAt.getTime() - reminderDays * 24 * 60 * 60 * 1000);
      if (now < reminderAt) continue;
      if (now > expiresAt) continue; // already expired; skip

      const lastSent: admin.firestore.Timestamp | undefined = data.subscriptionReminderLastSentAt;
      if (lastSent && lastSent.toDate() >= reminderAt) continue; // already sent for this window

      const email = buildReminderEmail(data, expiresAt);
      if (data.email) {
        try {
          const sendgridKey = await sendgridKeySecret.value();
          if (sendgridKey) {
            sgMail.setApiKey(sendgridKey);
            await sgMail.send({
              to: data.email,
              from: { email: "admin@caribtap.com", name: "CaribTap" },
              subject: email.subject,
              html: email.html,
            });
          }
        } catch (error) {
          functions.logger.error("Error sending email", { error, to: data.email });
        }
      }

      if (settings.allowPushNotifications !== false) {
        await sendPushNotification(
          doc.id,
          "Subscription expiring soon",
          `Renews by ${expiresAt.toDateString()}`,
          { type: "subscription_reminder" }
        );
      }

      await doc.ref.update({ subscriptionReminderLastSentAt: admin.firestore.FieldValue.serverTimestamp() });
    }


    return null;
  });

// Migrate listings to set listerTierSnapshot from author's current subscription
export const migrateListingTierSnapshots = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }

  // Require admin to run this
  const adminUser = await db.collection("users").doc(context.auth.uid).get();
  if (!adminUser.exists || !adminUser.data()?.isAdmin) {
    throw new functions.https.HttpsError("permission-denied", "Only admins can run this migration");
  }

  let processedCount = 0;
  let skippedCount = 0;

  try {
    const listingsRef = db.collection("listings");
    const snapshot = await listingsRef.get();

    const batch = db.batch();
    let batchSize = 0;
    const MAX_BATCH_SIZE = 500;

    for (const listingDoc of snapshot.docs) {
      const listingData = listingDoc.data();
      
      // Skip if already has listerTierSnapshot set to a valid value
      if (listingData.listerTierSnapshot && listingData.listerTierSnapshot !== "free") {
        skippedCount++;
        continue;
      }

      // Get author's current tier
      const authorId = listingData.authorID;
      if (!authorId) {
        functions.logger.warn("Listing missing authorID", { listingId: listingDoc.id });
        skippedCount++;
        continue;
      }

      try {
        const authorDoc = await db.collection("users").doc(authorId).get();
        const authorTier = authorDoc.exists ? (authorDoc.data()?.subscriptionTier || "free") : "free";

        // Update the listing with author's tier
        batch.update(listingDoc.ref, { listerTierSnapshot: authorTier.toLowerCase() });
        processedCount++;
        batchSize++;

        // Commit batch if it gets too large
        if (batchSize >= MAX_BATCH_SIZE) {
          await batch.commit();
          batchSize = 0;
        }
      } catch (err) {
        functions.logger.error("Error processing listing", { listingId: listingDoc.id, error: err });
        skippedCount++;
      }
    }

    // Commit remaining batch
    if (batchSize > 0) {
      await batch.commit();
    }

    functions.logger.info("✅ Migration complete", { processedCount, skippedCount });
    return { success: true, processedCount, skippedCount };
  } catch (error) {
    functions.logger.error("Migration failed", { error });
    throw new functions.https.HttpsError("internal", String(error));
  }
});

// Export deal ad and chat notification triggers
export { onDealAdApproved } from './deal_ad_notifications';
export { onChatMessageCreated } from './chat_notifications';

// Export tap (vouch) feature functions
export { onTapCreated, onTapDeleted, recomputeAllTapCounts } from './tap_functions';
