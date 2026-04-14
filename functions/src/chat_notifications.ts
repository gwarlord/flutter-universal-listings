import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

const db = admin.firestore();

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

export const onChatMessageCreated = functions.firestore
  .document("channels/{channelId}/thread/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    if (!message) return;

    const channelId = context.params.channelId;
    const senderId = message.senderID || message.senderId;
    const content = message.content || "New message";
    
    functions.logger.info("🔔 Processing new message notification", { channelId, senderId });

    const channelDoc = await db.collection("channels").doc(channelId).get();
    if (!channelDoc.exists) return;
    
    const channelData = channelDoc.data();
    if (!channelData) return;

    const listingTitle = channelData.listingTitle || "Listing";
    const participantIds = channelData.participantIds || [];

    for (const userId of participantIds) {
      if (userId === senderId) continue;
      
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) continue;
      
      const userData = userDoc.data();
      const tokens = getTokens(userData);

      if (tokens.length === 0) continue;

      for (const token of tokens) {
        try {
          await admin.messaging().send({
              token,
              notification: {
                  title: listingTitle,
                  body: content,
              },
              data: {
                  type: "chat",
                  channelID: channelId,
                  click_action: "FLUTTER_NOTIFICATION_CLICK", // Vital for background handling
              },
              android: {
                  priority: "high",
                  notification: {
                      channelId: "chat_messages", // Ensure this exists in your Android code
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
          functions.logger.info("✅ Notification sent", { userId });
        } catch (e) {
          functions.logger.error("❌ Error sending notification", { userId, error: e });
        }
      }
    }
  });
