import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

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

/**
 * Sends a notification to a user when they are suspended
 */
export const onUserSuspended = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change) => {
    const firestore = admin.firestore();
    const before = change.before.data();
    const after = change.after.data();
    const userId = change.after.id;

    // Check if suspension status changed from false to true
    const wasSuspended = before?.suspended === true;
    const isSuspendedNow = after?.suspended === true;

    if (wasSuspended || !isSuspendedNow) {
      return null; // Not a new suspension
    }

    const user = after;
    if (user.settings?.allowPushNotifications === false) {
      console.log("Push notifications disabled for suspended user:", userId);
      return null;
    }

    const tokens = getTokens(user);
    if (tokens.length === 0) {
      console.log("No push tokens for suspended user:", userId);
      return null;
    }

    const suspensionInfo = user.suspensionInfo || {};
    const reasonText = suspensionInfo.reasonText
      ? `Reason: ${suspensionInfo.reasonText}`
      : "Your account has been suspended due to a policy violation.";

    const messagePayload = {
      notification: {
        title: "🚫 Account Suspended",
        body: reasonText,
      },
      data: {
        type: "account_suspended",
        userId: userId,
        reason: suspensionInfo.reason || "unknown",
        timestamp: new Date().toISOString(),
      },
    };

    try {
      for (const token of tokens) {
        await admin.messaging().send({ ...messagePayload, token });
      }
      console.log("Suspension notification sent to user:", userId);
      return null;
    } catch (error) {
      console.error("Error sending suspension notification:", error);
      return null;
    }
  });

/**
 * Sends a notification to a user when they are unsuspended
 */
export const onUserUnsuspended = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change) => {
    const firestore = admin.firestore();
    const before = change.before.data();
    const after = change.after.data();
    const userId = change.after.id;

    // Check if suspension status changed from true to false
    const wasSuspended = before?.suspended === true;
    const isSuspendedNow = after?.suspended === true;

    if (!wasSuspended || isSuspendedNow) {
      return null; // Not an unsuspension
    }

    const user = after;
    if (user.settings?.allowPushNotifications === false) {
      console.log("Push notifications disabled for unsuspended user:", userId);
      return null;
    }

    const tokens = getTokens(user);
    if (tokens.length === 0) {
      console.log("No push tokens for unsuspended user:", userId);
      return null;
    }

    const messagePayload = {
      notification: {
        title: "✅ Account Restored",
        body: "Your account suspension has been lifted. You can now log in again.",
      },
      data: {
        type: "account_unsuspended",
        userId: userId,
        timestamp: new Date().toISOString(),
      },
    };

    try {
      for (const token of tokens) {
        await admin.messaging().send({ ...messagePayload, token });
      }
      console.log("Unsuspension notification sent to user:", userId);
      return null;
    } catch (error) {
      console.error("Error sending unsuspension notification:", error);
      return null;
    }
  });
