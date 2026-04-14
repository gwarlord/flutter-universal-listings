import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";
import { sendgridKeySecret, appUrlSecret } from "./common/secrets";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Configuration
const EMAIL_FROM = {email: "bookings@caribtap.com", name: "CaribTap Bookings"};

// Reminder windows (in milliseconds)
const REMINDER_24H = 24 * 60 * 60 * 1000; // 24 hours
const REMINDER_1H = 1 * 60 * 60 * 1000; // 1 hour
const REMINDER_WINDOW = 10 * 60 * 1000; // ±10 minutes window

/**
 * Scheduled function that runs every 10 minutes to check for bookings
 * that need reminder notifications
 */
export const sendBookingReminders = functions.runWith({ secrets: [sendgridKeySecret, appUrlSecret] }).pubsub
  .schedule("every 10 minutes")
  .onRun(async (context) => {
    functions.logger.info("🔔 Starting booking reminders check...");
    
    const now = new Date();
    const nowTimestamp = now.getTime();
    
    // Check for 24-hour reminders
    await processReminders(nowTimestamp, REMINDER_24H, "24h");
    
    // Check for 1-hour reminders
    await processReminders(nowTimestamp, REMINDER_1H, "1h");
    
    functions.logger.info("✅ Booking reminders check completed");
    return null;
  });

/**
 * Process reminders for a specific time window
 */
async function processReminders(
  nowTimestamp: number,
  reminderOffset: number,
  reminderType: "24h" | "1h"
) {
  const reminderField = reminderType === "24h" ? "reminder24hSentAt" : "reminder1hSentAt";
  
  // Calculate time window
  const targetTime = nowTimestamp + reminderOffset;
  const lowerBound = new Date(targetTime - REMINDER_WINDOW);
  const upperBound = new Date(targetTime + REMINDER_WINDOW);
  
  functions.logger.info(`🔍 Checking ${reminderType} reminders`, {
    lowerBound: lowerBound.toISOString(),
    upperBound: upperBound.toISOString(),
  });
  
  try {
    // Query all listings to find bookings in the time window
    const listingsSnapshot = await db.collection("listings").get();
    
    let bookingsProcessed = 0;
    let remindersSent = 0;
    
    for (const listingDoc of listingsSnapshot.docs) {
      const listingId = listingDoc.id;
      
      // Query bookings for this listing
      const bookingsQuery = await db
        .collection("listings")
        .doc(listingId)
        .collection("bookings")
        .where("status", "==", "confirmed")
        .get();
      
      for (const bookingDoc of bookingsQuery.docs) {
        const booking = bookingDoc.data();
        const bookingId = bookingDoc.id;
        
        bookingsProcessed++;
        
        // Parse check-in date
        let checkInDate: Date;
        try {
          checkInDate = new Date(booking.checkInDate);
        } catch (error) {
          functions.logger.warn(`Invalid checkInDate for booking ${bookingId}`, {error});
          continue;
        }
        
        // Check if booking is in the time window
        if (checkInDate >= lowerBound && checkInDate <= upperBound) {
          // Check if reminder already sent
          if (booking[reminderField]) {
            functions.logger.debug(`Reminder already sent for ${bookingId} (${reminderType})`);
            continue;
          }
          
          // Check if booking has already started
          if (checkInDate.getTime() <= nowTimestamp) {
            functions.logger.debug(`Booking ${bookingId} already started, skipping reminder`);
            continue;
          }
          
          functions.logger.info(`📧 Sending ${reminderType} reminder for booking ${bookingId}`);
          
          // Send reminder
          await sendBookingReminder(booking, bookingId, listingId, reminderType);
          
          // Mark reminder as sent
          await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(bookingId)
            .update({
              [reminderField]: admin.firestore.FieldValue.serverTimestamp(),
            });
          
          // Also update in user's myBookings
          try {
            await db
              .collection("users")
              .doc(booking.customerId)
              .collection("myBookings")
              .doc(bookingId)
              .update({
                [reminderField]: admin.firestore.FieldValue.serverTimestamp(),
              });
          } catch (updateError) {
            functions.logger.warn("Failed to update myBookings", {bookingId, updateError});
          }
          
          // Also update in lister's receivedBookings
          try {
            await db
              .collection("users")
              .doc(booking.listersUserId)
              .collection("receivedBookings")
              .doc(bookingId)
              .update({
                [reminderField]: admin.firestore.FieldValue.serverTimestamp(),
              });
          } catch (updateError) {
            functions.logger.warn("Failed to update receivedBookings", {bookingId, updateError});
          }
          
          remindersSent++;
        }
      }
    }
    
    functions.logger.info(`✅ ${reminderType} reminders processed`, {
      bookingsProcessed,
      remindersSent,
    });
  } catch (error) {
    functions.logger.error(`❌ Error processing ${reminderType} reminders`, {error});
  }
}

/**
 * Send booking reminder email and push notification
 */
async function sendBookingReminder(
  booking: any,
  bookingId: string,
  listingId: string,
  reminderType: "24h" | "1h"
) {
  const customerId = booking.customerId;

  // Get customer details and preferences
  const customerDoc = await db.collection("users").doc(customerId).get();
  if (!customerDoc.exists) {
    functions.logger.warn("Customer not found", {customerId, bookingId});
    return;
  }
  
  const customer = customerDoc.data();
  const settings = customer?.settings || {};
  
  // Check notification preferences
  const emailEnabled = settings.bookingEmailReminders !== false; // Default true
  const pushEnabled = settings.bookingPushReminders !== false; // Default true
  
  if (!emailEnabled && !pushEnabled) {
    functions.logger.info("Reminders disabled for customer", {customerId});
    return;
  }
  
  // Format dates
  const checkInDate = new Date(booking.checkInDate);
  const checkOutDate = new Date(booking.checkOutDate);
  const timezone = booking.timezone || "America/Port_of_Spain";
  
  const checkInFormatted = formatDateForTimezone(checkInDate, timezone);
  const checkOutFormatted = formatDateForTimezone(checkOutDate, timezone);
  
  // Prepare reminder content
  const timeLabel = reminderType === "24h" ? "24 hours" : "1 hour";
  const title = "Booking Reminder";
  const emailSubject = `Reminder: Your booking is in ${timeLabel}`;

  // Get secrets asynchronously
  const appUrl = await appUrlSecret.value() || "https://caribtap.com";
  const sendgridKey = await sendgridKeySecret.value();
  
  const webLink = `${appUrl}/booking/${bookingId}`;
  
  // Send email reminder
  if (emailEnabled && customer?.email && sendgridKey) {
    try {
      const emailHtml = buildReminderEmailTemplate({
        customerName: booking.customerName || customer?.firstName || "Guest",
        listingTitle: booking.listingTitle,
        listingPhoto: booking.listingPhoto,
        checkInDate: checkInFormatted,
        checkOutDate: checkOutFormatted,
        timeLabel,
        numberOfGuests: booking.numberOfGuests,
        timeBlock: booking.timeBlock,
        totalPrice: booking.totalPrice,
        currency: booking.currency || "USD",
        bookingReference: bookingId.substring(0, 8).toUpperCase(),
        deepLink: webLink,
        appUrl,
      });
      
      sgMail.setApiKey(sendgridKey);
      await sgMail.send({
        to: customer.email,
        from: EMAIL_FROM,
        subject: emailSubject,
        html: emailHtml,
      });
      
      functions.logger.info("✅ Email reminder sent", {customerId, bookingId, reminderType});
    } catch (emailError) {
      functions.logger.error("❌ Error sending email reminder", {
        emailError,
        customerId,
        bookingId,
      });
    }
  }
  
  // Send push notification reminder
  const tokens = getTokens(customer);
  if (pushEnabled && tokens.length > 0) {
    try {
      const pushBody = `Your booking for ${booking.listingTitle} is in ${timeLabel}. Check-in: ${checkInFormatted}`;
      
      await messaging.sendMulticast({
        tokens: tokens,
        notification: {
          title: title,
          body: pushBody,
        },
        data: {
          type: "booking_reminder",
          bookingId: bookingId,
          listingId: listingId,
          reminderType: reminderType,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "booking_reminders",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
            },
          },
        },
      });
      
      functions.logger.info("✅ Push reminder sent", {customerId, bookingId, reminderType});
    } catch (pushError) {
      functions.logger.error("❌ Error sending push reminder", {
        pushError,
        customerId,
        bookingId,
      });
    }
  }
}

/**
 * Format date for specific timezone
 */
function formatDateForTimezone(date: Date, timezone: string): string {
  try {
    return date.toLocaleString("en-US", {
      timeZone: timezone,
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  } catch (error) {
    return date.toLocaleString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  }
}

/**
 * Helper to get FCM tokens from user document
 */
function getTokens(userData: any): string[] {
  let tokens: string[] = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens = userData.fcmTokens.filter((t: any) => typeof t === "string" && t.length > 0);
  }
  if (userData?.pushToken && typeof userData.pushToken === "string" && !tokens.includes(userData.pushToken)) {
    tokens.push(userData.pushToken);
  }
  return tokens;
}

/**
 * Build HTML email template for booking reminder
 */
function buildReminderEmailTemplate(data: {
  customerName: string;
  listingTitle: string;
  listingPhoto?: string;
  checkInDate: string;
  checkOutDate: string;
  timeLabel: string;
  numberOfGuests?: number;
  timeBlock?: string;
  totalPrice?: number;
  currency?: string;
  bookingReference: string;
  deepLink: string;
  appUrl: string;
}): string {
  return `
    <!DOCTYPE html>
    <html>
    <body style="font-family: Arial, sans-serif;">
      <p>Hi ${data.customerName},</p>
      <p>This is a reminder that your booking for <b>${data.listingTitle}</b> is in ${data.timeLabel}.</p>
      <p>Check-in: ${data.checkInDate}</p>
      <p>Reference: ${data.bookingReference}</p>
    </body>
    </html>
  `;
}

/**
 * Handle booking creation - initialize reminder fields
 */
export const onBookingCreatedForReminders = functions.firestore
  .document("listings/{listingId}/bookings/{bookingId}")
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;

    if (!booking.reminder24hSentAt && !booking.reminder1hSentAt) {
      try {
        await snap.ref.update({
          reminder24hSentAt: null,
          reminder1hSentAt: null,
          timezone: booking.timezone || null,
        });
      } catch (error) {
        functions.logger.error("❌ Error initializing reminder fields", {error, bookingId});
      }
    }
    
    return null;
  });

/**
 * Handle booking updates - reset reminders if check-in date changes
 */
export const onBookingUpdatedForReminders = functions.firestore
  .document("listings/{listingId}/bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const bookingId = context.params.bookingId;

    if (beforeData.checkInDate !== afterData.checkInDate) {
      try {
        await change.after.ref.update({
          reminder24hSentAt: null,
          reminder1hSentAt: null,
        });

        await db.collection("users").doc(afterData.customerId).collection("myBookings").doc(bookingId).update({
          reminder24hSentAt: null,
          reminder1hSentAt: null,
        });
        
        await db.collection("users").doc(afterData.listersUserId).collection("receivedBookings").doc(bookingId).update({
          reminder24hSentAt: null,
          reminder1hSentAt: null,
        });
      } catch (error) {
        functions.logger.error("❌ Error resetting reminders", {error, bookingId});
      }
    }
    
    return null;
  });
