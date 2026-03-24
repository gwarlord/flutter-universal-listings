import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";
import { sendgridKeySecret } from "./common/secrets";

const BOOKING_EMAIL_FROM = { email: "admin@caribtap.com", name: "CaribTap Bookings" };

type EmailOnceMarker =
  | "createRequest"
  | "statusConfirmed"
  | "statusRejected"
  | "statusCancelled";

function normalizeEmailForKey(value: string): string {
  const normalized = value.trim().toLowerCase();
  const atIndex = normalized.indexOf("@");
  if (atIndex <= 0 || atIndex === normalized.length - 1) {
    return normalized;
  }

  const local = normalized.substring(0, atIndex);
  const domain = normalized.substring(atIndex + 1);

  // Canonicalize common Gmail alias forms so role emails don't duplicate
  // into the same physical inbox (dots and plus-tags are ignored by Gmail).
  if (domain === "gmail.com" || domain === "googlemail.com") {
    const localWithoutPlus = local.split("+")[0];
    const localWithoutDots = localWithoutPlus.replace(/\./g, "");
    return `${localWithoutDots}@gmail.com`;
  }

  return normalized;
}

function sanitizeKeyPart(value: string): string {
  return value.replace(/[^a-z0-9._-]/gi, "_");
}

async function claimEmailSendMarker(
  bookingRef: FirebaseFirestore.DocumentReference,
  marker: EmailOnceMarker,
  bookingId: string
): Promise<boolean> {
  try {
    const db = admin.firestore();
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(bookingRef);
      if (!snap.exists) {
        return false;
      }

      const data = snap.data() || {};
      const existing = (data.emailDeliveryState || {}) as Record<string, unknown>;
      if (existing[marker]) {
        return false;
      }

      tx.set(
        bookingRef,
        {
          emailDeliveryState: {
            [marker]: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      return true;
    });
  } catch (error) {
    functions.logger.warn("Email send marker claim failed", {
      bookingId,
      marker,
      error: (error as any)?.message || String(error),
    });
    return false;
  }
}

async function claimEmailMessageKey(
  bookingRef: FirebaseFirestore.DocumentReference,
  messageKey: string,
  bookingId: string
): Promise<boolean> {
  try {
    const db = admin.firestore();
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(bookingRef);
      if (!snap.exists) {
        return false;
      }

      const data = snap.data() || {};
      const existing = (data.emailDeliveryState || {}) as Record<string, unknown>;
      if (existing[messageKey]) {
        return false;
      }

      tx.set(
        bookingRef,
        {
          emailDeliveryState: {
            [messageKey]: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      return true;
    });
  } catch (error) {
    functions.logger.warn("Email message key claim failed", {
      bookingId,
      messageKey,
      error: (error as any)?.message || String(error),
    });
    return false;
  }
}

async function resolveBookingListerId(
  db: FirebaseFirestore.Firestore,
  booking: FirebaseFirestore.DocumentData,
  listingIdFromPath?: string
): Promise<string> {
  const bookingListerId =
    typeof booking?.listersUserId === "string" && booking.listersUserId.trim().length > 0
      ? booking.listersUserId.trim()
      : "";

  if (bookingListerId) {
    return bookingListerId;
  }

  const listingId =
    typeof booking?.listingId === "string" && booking.listingId.trim().length > 0
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

function asNonEmptyString(value: unknown, fallback = ""): string {
  if (typeof value !== "string") {
    return fallback;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? fallback : trimmed;
}

async function sendToTokensIndividually(
  db: FirebaseFirestore.Firestore,
  messaging: admin.messaging.Messaging,
  userId: string,
  tokens: string[],
  payload: Omit<admin.messaging.TokenMessage, "token">
): Promise<{ successCount: number; failureCount: number }> {
  let successCount = 0;
  let failureCount = 0;

  for (const token of tokens) {
    try {
      await messaging.send({
        token,
        ...payload,
      });
      successCount += 1;
    } catch (error) {
      failureCount += 1;
      if (isStaleMessagingTokenError(error)) {
        await removeTokenFromUser(db, userId, token);
      }
      functions.logger.warn("Booking notification token failure", {
        userId,
        tokenSuffix: token.slice(-8),
        error: (error as any)?.message || String(error),
      });
    }
  }

  return { successCount, failureCount };
}

function isStaleMessagingTokenError(error: unknown): boolean {
  const code = ((error as any)?.code || "").toString().toLowerCase();
  const message = ((error as any)?.message || "").toString().toLowerCase();

    return code.includes("registration-token-not-registered") ||
      code.includes("invalid-registration-token") ||
      message.includes("requested entity was not found") ||
      message.includes("registration token is not a valid fcm registration token") ||
      message.includes("not a valid fcm registration token") ||
      message.includes("not registered");
}

async function removeTokenFromUser(
  db: FirebaseFirestore.Firestore,
  userId: string,
  token: string
): Promise<void> {
  if (!userId || !token) return;

  try {
    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    const updates: Record<string, unknown> = {
      fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
    };

    if (typeof userData.pushToken === "string" && userData.pushToken.trim() === token) {
      updates.pushToken = admin.firestore.FieldValue.delete();
    }

    await userRef.set(updates, { merge: true });

    functions.logger.info("Removed stale booking notification token", {
      userId,
      tokenSuffix: token.slice(-8),
    });
  } catch (cleanupError) {
    functions.logger.warn("Failed to remove stale booking notification token", {
      userId,
      tokenSuffix: token.slice(-8),
      error: (cleanupError as any)?.message || String(cleanupError),
    });
  }
}

/**
 * Send notification when a new booking is created
 * Watches: listings/{listingId}/bookings/{bookingId}
 */
export const onBookingCreated = functions.runWith({ secrets: [sendgridKeySecret] }).firestore
  .document("listings/{listingId}/bookings/{bookingId}")
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;

    try {
      const db = admin.firestore();
      const messaging = admin.messaging();
      const listerId = await resolveBookingListerId(
        db,
        booking,
        context.params.listingId
      );

      let successCount = 0;
      let failureCount = 0;
      let tokenCount = 0;

      if (!listerId) {
        functions.logger.warn("Booking created without a resolvable lister", {
          bookingId,
          listingId: context.params.listingId,
          bookingListerId: booking?.listersUserId,
        });
      } else {
        const listerDoc = await db.collection("users").doc(listerId).get();
        if (!listerDoc.exists) {
          functions.logger.warn("Lister document not found for booking notification", {
            bookingId,
            listingId: context.params.listingId,
            listerId,
          });
        } else {
          const listerData = listerDoc.data();
          if (listerData?.settings?.allowPushNotifications === false) {
            functions.logger.info("Lister has push notifications disabled", {
              bookingId,
              listingId: context.params.listingId,
              listerId,
            });
          } else {
            const listerTokens = getTokens(listerData);
            tokenCount = listerTokens.length;
            if (listerTokens.length === 0) {
              functions.logger.warn("Lister has no push tokens for booking notification", {
                bookingId,
                listingId: context.params.listingId,
                listerId,
                hasPushToken: !!listerData?.pushToken,
                hasFcmTokens: Array.isArray(listerData?.fcmTokens) && listerData.fcmTokens.length > 0,
              });
            } else {
              const listingTitle = booking.listingTitle || "Your listing";
              const customerName = booking.customerName || "Guest";
              const dataListingId = asNonEmptyString(booking?.listingId, context.params.listingId);

              const messagePayload: Omit<admin.messaging.TokenMessage, "token"> = {
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

              const response = await sendToTokensIndividually(
                db,
                messaging,
                listerId,
                listerTokens,
                messagePayload
              );
              successCount = response.successCount;
              failureCount = response.failureCount;
            }
          }
        }
      }

      try {
        await sendBookingEmailsOnCreate(snap.ref, booking, bookingId);
      } catch (emailError) {
        functions.logger.error("Booking create email send failed", {
          bookingId,
          listingId: context.params.listingId,
          error: (emailError as any)?.message || String(emailError),
        });
      }

      functions.logger.info("Standard booking notification sent to lister", {
        bookingId,
        listingId: context.params.listingId,
        listerId,
        tokenCount,
        successCount,
        failureCount,
      });
      return null;
    } catch (error) {
      console.error("Error in onBookingCreated:", error);
      return null;
    }
  });

/**
 * Send notification when booking status changes
 * Watches: listings/{listingId}/bookings/{bookingId}
 */
export const onBookingUpdated = functions.runWith({ secrets: [sendgridKeySecret] }).firestore
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
        } else {
          const customerDoc = await db.collection("users").doc(customerId).get();
          if (customerDoc.exists) {
            const tokens = getTokens(customerDoc.data());
            if (tokens.length > 0) {
              const customerResponse = await sendToTokensIndividually(
                db,
                messaging,
                customerId,
                tokens,
                {
                notification: { title: customerTitle, body: customerBody },
                data: { type: "booking_status", bookingId, status: nextStatus, click_action: "FLUTTER_NOTIFICATION_CLICK" },
                android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
                }
              );

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
        } else {
          const listerDoc = await db.collection("users").doc(listerId).get();
          if (listerDoc.exists) {
            const tokens = getTokens(listerDoc.data());
            if (tokens.length > 0) {
              const listerResponse = await sendToTokensIndividually(
                db,
                messaging,
                listerId,
                tokens,
                {
                notification: { title: listerTitle, body: listerBody },
                data: { type: "booking_status", bookingId, status: nextStatus, click_action: "FLUTTER_NOTIFICATION_CLICK" },
                android: { priority: "high", notification: { sound: "default", channelId: "bookings" } },
                apns: { payload: { aps: { sound: "default", badge: 1 } } },
                }
              );

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

      try {
        await sendBookingEmailsOnStatusChange(change.after.ref, after, bookingId, nextStatus);
      } catch (emailError) {
        functions.logger.error("Booking status email send failed", {
          bookingId,
          listingId: context.params.listingId,
          nextStatus,
          error: (emailError as any)?.message || String(emailError),
        });
      }

      return null;
    } catch (error) {
      console.error("Error in onBookingUpdated:", error);
      return null;
    }
  });

function getTokens(userData: any): string[] {
  let tokens: string[] = [];
  if (Array.isArray(userData?.fcmTokens)) {
    tokens = userData.fcmTokens
      .filter((t: any) => typeof t === "string" && t.trim().length > 0)
      .map((t: string) => t.trim());
  }
  if (userData?.pushToken && typeof userData.pushToken === "string") {
    const pushToken = userData.pushToken.trim();
    if (pushToken && !tokens.includes(pushToken)) {
      tokens.push(pushToken);
    }
  }
  return Array.from(new Set(tokens));
}

async function sendBookingEmailsOnCreate(
  bookingRef: FirebaseFirestore.DocumentReference,
  booking: FirebaseFirestore.DocumentData,
  bookingId: string
): Promise<void> {
  const sendgridKey = await sendgridKeySecret.value();
  if (!sendgridKey) {
    functions.logger.warn("Booking create email skipped because SENDGRID_KEY is not configured", {
      bookingId,
    });
    return;
  }

  const customerEmail = asNonEmptyString(booking?.customerEmail);
  const listerEmail = asNonEmptyString(booking?.listersEmail);
  if (!customerEmail && !listerEmail) {
    functions.logger.warn("Booking create email skipped because no recipient emails were found", {
      bookingId,
    });
    return;
  }

  const shouldSend = await claimEmailSendMarker(bookingRef, "createRequest", bookingId);
  if (!shouldSend) {
    functions.logger.info("Booking create email skipped because it was already sent", {
      bookingId,
    });
    return;
  }

  sgMail.setApiKey(sendgridKey);

  const listingTitle = asNonEmptyString(booking?.listingTitle, "Listing");
  const customerName = asNonEmptyString(booking?.customerName, "Guest");
  const listerName = asNonEmptyString(booking?.listersName, "Lister");
  const startDateStr = formatBookingDate(booking?.checkInDate);
  const endDateStr = formatBookingDate(booking?.checkOutDate);
  const qnaHtml = buildCustomAnswersHtml(booking?.customAnswers);

  const subject = `Booking Request: ${listingTitle}`;

  const sends: Promise<unknown>[] = [];

  const normalizedCustomerEmail = normalizeEmailForKey(customerEmail);
  const normalizedListerEmail = normalizeEmailForKey(listerEmail);

  if (customerEmail) {
    const customerKey = `createRequest_customer_${sanitizeKeyPart(normalizeEmailForKey(customerEmail))}`;
    const shouldSendCustomer = await claimEmailMessageKey(bookingRef, customerKey, bookingId);
    if (!shouldSendCustomer) {
      functions.logger.info("Booking create email to customer skipped because it was already sent", {
        bookingId,
        customerEmail,
        messageKey: customerKey,
      });
    } else {
    sends.push(
      sgMail.send({
        to: customerEmail,
        from: BOOKING_EMAIL_FROM,
        subject,
        html: `
          <h3>Hello ${escapeHtml(customerName)},</h3>
          <p>We've received your booking request for <b>${escapeHtml(listingTitle)}</b>.</p>
          <p><b>Start Date:</b> ${escapeHtml(startDateStr)}</p>
          <p><b>End Date:</b> ${escapeHtml(endDateStr)}</p>
          ${qnaHtml}
          <p>The lister will review your request and you will receive another email once it's confirmed or rejected.</p>
          <br><p>Best regards,<br>CaribTap Team</p>
        `,
      })
    );
    }
  }

  if (listerEmail && normalizedListerEmail !== normalizedCustomerEmail) {
    const listerKey = `createRequest_lister_${sanitizeKeyPart(normalizeEmailForKey(listerEmail))}`;
    const shouldSendLister = await claimEmailMessageKey(bookingRef, listerKey, bookingId);
    if (!shouldSendLister) {
      functions.logger.info("Booking create email to lister skipped because it was already sent", {
        bookingId,
        listerEmail,
        messageKey: listerKey,
      });
    } else {
    sends.push(
      sgMail.send({
        to: listerEmail,
        from: BOOKING_EMAIL_FROM,
        subject,
        html: `
          <h3>Hello ${escapeHtml(listerName)},</h3>
          <p>You have a new booking request for your listing: <b>${escapeHtml(listingTitle)}</b>.</p>
          <p><b>Customer:</b> ${escapeHtml(customerName)}</p>
          <p><b>Start Date:</b> ${escapeHtml(startDateStr)}</p>
          <p><b>End Date:</b> ${escapeHtml(endDateStr)}</p>
          ${qnaHtml}
          <p>Please log in to the app to confirm or reject this request.</p>
          <br><p>Best regards,<br>CaribTap Team</p>
        `,
      })
    );
    }
  }

  await Promise.all(sends);
}

async function sendBookingEmailsOnStatusChange(
  bookingRef: FirebaseFirestore.DocumentReference,
  booking: FirebaseFirestore.DocumentData,
  bookingId: string,
  nextStatus: string
): Promise<void> {
  const sendgridKey = await sendgridKeySecret.value();
  if (!sendgridKey) {
    functions.logger.warn("Booking status email skipped because SENDGRID_KEY is not configured", {
      bookingId,
      nextStatus,
    });
    return;
  }

  const customerEmail = asNonEmptyString(booking?.customerEmail);
  const listerEmail = asNonEmptyString(booking?.listersEmail);
  if (!customerEmail && !listerEmail) {
    functions.logger.warn("Booking status email skipped because no recipient emails were found", {
      bookingId,
      nextStatus,
    });
    return;
  }

  const statusMarkerMap: Record<string, EmailOnceMarker | undefined> = {
    confirmed: "statusConfirmed",
    approved: "statusConfirmed",
    rejected: "statusRejected",
    declined: "statusRejected",
    cancelled: "statusCancelled",
  };

  const marker = statusMarkerMap[nextStatus];
  if (marker) {
    const shouldSend = await claimEmailSendMarker(bookingRef, marker, bookingId);
    if (!shouldSend) {
      functions.logger.info("Booking status email skipped because it was already sent", {
        bookingId,
        nextStatus,
        marker,
      });
      return;
    }
  }

  sgMail.setApiKey(sendgridKey);

  const listingTitle = asNonEmptyString(booking?.listingTitle, "Listing");
  const customerName = asNonEmptyString(booking?.customerName, "Guest");
  const cancelledByRole = asNonEmptyString(booking?.cancelledBy).toLowerCase();
  const qnaHtml = buildCustomAnswersHtml(booking?.customAnswers);
  const sends: Promise<unknown>[] = [];
  const normalizedCustomerEmail = normalizeEmailForKey(customerEmail);
  const normalizedListerEmail = normalizeEmailForKey(listerEmail);

  const sendToCustomerWithKey = async (subject: string, html: string): Promise<void> => {
    if (!customerEmail) return;
    const key = `${nextStatus}_customer_${sanitizeKeyPart(normalizeEmailForKey(customerEmail))}`;
    const shouldSend = await claimEmailMessageKey(bookingRef, key, bookingId);
    if (!shouldSend) {
      functions.logger.info("Booking status email to customer skipped because it was already sent", {
        bookingId,
        nextStatus,
        customerEmail,
        messageKey: key,
      });
      return;
    }
    sends.push(
      sgMail.send({
        to: customerEmail,
        from: BOOKING_EMAIL_FROM,
        subject,
        html,
      })
    );
  };

  const sendToListerWithKey = async (subject: string, html: string): Promise<void> => {
    if (!listerEmail) return;
    const key = `${nextStatus}_lister_${sanitizeKeyPart(normalizeEmailForKey(listerEmail))}`;
    const shouldSend = await claimEmailMessageKey(bookingRef, key, bookingId);
    if (!shouldSend) {
      functions.logger.info("Booking status email to lister skipped because it was already sent", {
        bookingId,
        nextStatus,
        listerEmail,
        messageKey: key,
      });
      return;
    }
    sends.push(
      sgMail.send({
        to: listerEmail,
        from: BOOKING_EMAIL_FROM,
        subject,
        html,
      })
    );
  };

  if (nextStatus === "confirmed" && customerEmail) {
    await sendToCustomerWithKey(
      `Booking CONFIRMED: ${listingTitle}`,
      `
          <h3>Congratulations ${escapeHtml(customerName)}!</h3>
          <p>Your booking for <b>${escapeHtml(listingTitle)}</b> has been <b>CONFIRMED</b>.</p>
          ${qnaHtml}
          <p>Thank you for your business!</p>
          <br><p>Best regards,<br>CaribTap Team</p>
        `
    );
  }

  if ((nextStatus === "rejected" || nextStatus === "declined") && customerEmail) {
    await sendToCustomerWithKey(
      `Booking Update: ${listingTitle}`,
      `
          <h3>Hello ${escapeHtml(customerName)},</h3>
          <p>We're sorry, but your booking request for <b>${escapeHtml(listingTitle)}</b> was not accepted at this time.</p>
          ${qnaHtml}
          <p>Please feel free to browse other listings on CaribTap.</p>
          <br><p>Best regards,<br>CaribTap Team</p>
        `
    );
  }

  if (nextStatus === "cancelled") {
    if (cancelledByRole === "lister") {
      // Lister cancelled -> notify customer only.
      if (customerEmail) {
        await sendToCustomerWithKey(
          `Booking CANCELLED: ${listingTitle}`,
          `
            <h3>Hello ${escapeHtml(customerName)},</h3>
            <p>Your booking for <b>${escapeHtml(listingTitle)}</b> has been cancelled by the lister.</p>
            ${qnaHtml}
            <br><p>Best regards,<br>CaribTap Team</p>
          `
        );
      }
    } else if (cancelledByRole === "customer") {
      // Customer cancelled -> notify lister only.
      if (listerEmail && normalizedListerEmail !== normalizedCustomerEmail) {
        await sendToListerWithKey(
          `Booking CANCELLED: ${listingTitle}`,
          `
            <h3>Hello ${escapeHtml(asNonEmptyString(booking?.listersName, "Lister"))},</h3>
            <p>${escapeHtml(customerName)} cancelled their booking for <b>${escapeHtml(listingTitle)}</b>.</p>
            ${qnaHtml}
            <br><p>Best regards,<br>CaribTap Team</p>
          `
        );
      }
    } else {
      // Unknown role fallback: notify customer only to avoid role-crossed mails.
      functions.logger.warn("Booking cancellation role missing/unknown, using customer-only fallback", {
        bookingId,
        cancelledByRole,
      });
      if (customerEmail) {
        await sendToCustomerWithKey(
          `Booking CANCELLED: ${listingTitle}`,
          `
            <h3>Hello ${escapeHtml(customerName)},</h3>
            <p>Your booking for <b>${escapeHtml(listingTitle)}</b> has been cancelled.</p>
            ${qnaHtml}
            <br><p>Best regards,<br>CaribTap Team</p>
          `
        );
      }
    }
  }

  if (sends.length == 0) {
    return;
  }

  await Promise.all(sends);
}

function formatBookingDate(value: unknown): string {
  try {
    if (value instanceof admin.firestore.Timestamp) {
      return value.toDate().toISOString().split("T")[0];
    }
    if (typeof value === "string" && value.trim().length > 0) {
      const parsed = new Date(value);
      if (!Number.isNaN(parsed.getTime())) {
        return parsed.toISOString().split("T")[0];
      }
    }
  } catch (error) {
    functions.logger.warn("Unable to format booking date", { value, error });
  }
  return "";
}

function buildCustomAnswersHtml(value: unknown): string {
  if (!value || typeof value !== "object") {
    return "";
  }

  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length === 0) {
    return "";
  }

  return (
    "<h4>Custom Questions</h4>" +
    entries
      .map(([question, answer]) => {
        const answerText = typeof answer === "string" && answer.trim().length > 0 ? answer : "-";
        return `<p><b>${escapeHtml(question)}</b><br>${escapeHtml(answerText)}</p>`;
      })
      .join("")
  );
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
