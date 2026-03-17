import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// =============================================================================
// HELPERS
// =============================================================================

/**
 * Check if user is an admin (mirrors isAdminUser from collaboration.ts)
 */
async function isAdminUser(uid: string): Promise<boolean> {
  const userSnap = await db.collection("users").doc(uid).get();
  if (userSnap.exists && userSnap.data()?.isAdmin === true) {
    return true;
  }

  const adminDoc = await db.collection("admins").doc("admins").get();
  if (!adminDoc.exists) return false;

  const adminUserIds = adminDoc.data()?.adminUserIds || [];
  return adminUserIds.includes(uid);
}

// =============================================================================
// CALLABLE FUNCTIONS
// =============================================================================

/**
 * Send a global push notification to all users.
 *
 * data.title       {string}  Required. Notification title.
 * data.body        {string}  Required. Notification body.
 * data.targetMode  {string}  'topic' (default) | 'all'.
 *   - 'topic'  : sends to FCM topic 'all_users' (devices must be subscribed).
 *   - 'all'    : queries every user doc and sends via multicast batches of 499.
 * data.extraData   {object}  Optional key-value pairs added to the FCM data payload.
 */
export const sendGlobalNotification = functions.https.onCall(
  async (data, context) => {
    // ---- auth guard ----
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "You must be signed in to send notifications."
      );
    }

    const callerUid = context.auth.uid;
    const isAdmin = await isAdminUser(callerUid);
    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can send global notifications."
      );
    }

    // ---- input validation ----
    const title = typeof data.title === "string" ? data.title.trim() : "";
    const body = typeof data.body === "string" ? data.body.trim() : "";
    const targetMode: string = data.targetMode || "topic";
    const extraData: Record<string, string> = data.extraData || {};

    if (!title) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "title is required."
      );
    }
    if (!body) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "body is required."
      );
    }
    if (!["topic", "all", "self"].includes(targetMode)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetMode must be 'topic', 'all', or 'self'."
      );
    }

    // Sanitise extraData values — all must be strings for FCM data payload
    const safeExtra: Record<string, string> = {};
    for (const key of Object.keys(extraData)) {
      const v = extraData[key];
      safeExtra[key] = typeof v === "string" ? v : String(v);
    }

    const fcmData: Record<string, string> = {
      ...safeExtra,
      type: "global_notification",
      title,
      body,
    };

    let recipientCount = 0;

    if (targetMode === "self") {
      // ---- test send: caller only ----
      const callerSnap = await db.collection("users").doc(callerUid).get();
      const callerData = callerSnap.data();
      const selfTokens: string[] = Array.isArray(callerData?.fcmTokens)
        ? callerData.fcmTokens
        : callerData?.pushToken
        ? [callerData.pushToken as string]
        : [];

      if (selfTokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens: selfTokens,
          notification: { title, body },
          data: fcmData,
        });
        recipientCount = selfTokens.length;
      }
      functions.logger.info("Test notification sent to caller only", {
        callerUid,
        recipientCount,
      });

      // No audit log for test sends — return early
      return { success: true, recipientCount };
    } else if (targetMode === "topic") {
      // ---- topic send ----
      await messaging.send({
        topic: "all_users",
        notification: { title, body },
        data: fcmData,
      });
      // topic delivery reaches every subscribed device; exact count unknown
      recipientCount = -1;
      functions.logger.info("Global notification sent via topic", { title });
    } else {
      // ---- multicast to all users ----
      const usersSnap = await db.collection("users").get();

      // Deduplicate tokens across all user docs
      const tokenSet = new Set<string>();
      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const tokens: string[] = Array.isArray(userData?.fcmTokens)
          ? userData.fcmTokens
          : [];
        if (tokens.length === 0 && userData?.pushToken) {
          tokens.push(userData.pushToken as string);
        }
        for (const t of tokens) {
          if (t && typeof t === "string") tokenSet.add(t);
        }
      }

      const allTokens = Array.from(tokenSet);
      const BATCH = 499; // FCM multicast cap is 500

      for (let i = 0; i < allTokens.length; i += BATCH) {
        const batch = allTokens.slice(i, i + BATCH);
        try {
          await messaging.sendEachForMulticast({
            tokens: batch,
            notification: { title, body },
            data: fcmData,
          });
          recipientCount += batch.length;
        } catch (batchErr) {
          functions.logger.error("sendEachForMulticast batch failed", {
            batchStart: i,
            error: batchErr,
          });
        }
      }

      functions.logger.info("Global notification sent via multicast", {
        title,
        recipientCount,
      });
    }

    // ---- audit log ----
    await db.collection("adminNotifications").add({
      sentBy: callerUid,
      title,
      body,
      targetMode,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      recipientCount,
      extraData: safeExtra,
    });

    return { success: true, recipientCount };
  }
);
