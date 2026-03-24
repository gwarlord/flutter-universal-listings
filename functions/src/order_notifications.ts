import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

async function getUserTokens(uid: string): Promise<string[]> {
  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  if (!userDoc.exists) return [];

  const user = userDoc.data() || {};
  const tokens: string[] = [];

  if (Array.isArray(user.fcmTokens)) {
    tokens.push(...user.fcmTokens.map((t: any) => String(t || "").trim()));
  }
  if (typeof user.pushToken === "string") {
    tokens.push(user.pushToken.trim());
  }
  if (typeof user.fcmToken === "string") {
    tokens.push(user.fcmToken.trim());
  }

  return [...new Set(tokens.filter((t) => t.length > 0))];
}

async function sendToUserTokens(tokens: string[], message: Omit<admin.messaging.Message, "token">): Promise<void> {
  if (tokens.length === 0) return;
  await Promise.allSettled(
    tokens.map((token) =>
      admin.messaging().send({
        ...message,
        token,
      })
    )
  );
}

/**
 * Send notification when a new order is placed
 */
export const onOrderCreated = functions.firestore
  .document("order_requests/{orderId}")
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const orderId = context.params.orderId;
    const orderNumber = orderId.slice(0, 8).toUpperCase();

    try {
      const listerTokens = await getUserTokens(order.listerId);
      if (listerTokens.length === 0) {
        console.log("Lister has no FCM tokens:", order.listerId);
        return null;
      }

      // Get listing details for notification
      const listingDoc = await admin
        .firestore()
        .collection("listings")
        .doc(order.listingId)
        .get();

      const listingTitle = listingDoc.exists
        ? listingDoc.data()?.title
        : "Your listing";

      // Send notification
      const message: Omit<admin.messaging.Message, "token"> = {
        notification: {
          title: "🛒 New Order Request",
          body: `Order #${orderNumber}: ${listingTitle}`,
        },
        data: {
          type: "new_order",
          orderId: orderId,
          orderNumber: orderNumber,
          listingId: order.listingId,
          channelId: order.channelId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high" as const,
          notification: {
            sound: "default",
            channelId: "orders",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      await sendToUserTokens(listerTokens, message);
      console.log("Order notification sent to lister:", order.listerId);

      return null;
    } catch (error) {
      console.error("Error sending order notification:", error);
      return null;
    }
  });

/**
 * Send notification when order status changes
 */
export const onOrderStatusChanged = functions.firestore
  .document("order_requests/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const orderId = context.params.orderId;
    const orderNumber = orderId.slice(0, 8).toUpperCase();

    // Check if status changed
    if (before.status === after.status) {
      return null;
    }

    try {
      // Get listing details for notification
      const listingDoc = await admin
        .firestore()
        .collection("listings")
        .doc(after.listingId)
        .get();

      const listingTitle = listingDoc.exists
        ? listingDoc.data()?.title
        : "your order";

      // Create notification based on status
      let title = "";
      let body = "";
      let emoji = "";
      let recipientId = after.customerId; // Default: notify customer

      switch (after.status) {
        case "confirmed":
          emoji = "✅";
          title = "Order Active";
          body = `Order #${orderNumber} for ${listingTitle} is now active.`;
          recipientId = after.customerId;
          break;
        case "preparing":
          emoji = "👨‍🍳";
          title = "Order Preparing";
          body = `Order #${orderNumber} for ${listingTitle} is being prepared.`;
          recipientId = after.customerId;
          break;
        case "ready":
          emoji = "🔔";
          title = "Order Ready";
          body = `Order #${orderNumber} for ${listingTitle} is ready.`;
          recipientId = after.customerId;
          break;
        case "served":
          emoji = "🍽️";
          title = "Order Served";
          body = `Order #${orderNumber} for ${listingTitle} has been served.`;
          recipientId = after.customerId;
          break;
        case "declined":
          emoji = "❌";
          title = "Order Declined";
          body = `Order #${orderNumber} for ${listingTitle} was declined.`;
          recipientId = after.customerId;
          break;
        case "fulfilled":
          emoji = "📦";
          title = "Order Fulfilled";
          body = `Order #${orderNumber} for ${listingTitle} is ready!`;
          recipientId = after.customerId;
          break;
        case "cancelled":
          emoji = "🚫";
          title = "Order Cancelled";
          // Determine who cancelled it and notify accordingly
          if (before.status === "requested") {
            // Customer cancelling their pending order - notify lister
            body = `Order #${orderNumber} for ${listingTitle} was cancelled.`;
            recipientId = after.listerId;
          } else {
            // Lister declining - notify customer
            body = `Order #${orderNumber} for ${listingTitle} was cancelled.`;
            recipientId = after.customerId;
          }
          break;
        default:
          return null;
      }

      const recipientTokens = await getUserTokens(recipientId);
      if (recipientTokens.length === 0) {
        console.log("Recipient has no FCM tokens:", recipientId);
        return null;
      }

      // Send notification
      const message: Omit<admin.messaging.Message, "token"> = {
        notification: {
          title: `${emoji} ${title}`,
          body: body,
        },
        data: {
          type: "order_status_changed",
          orderId: orderId,
          orderNumber: orderNumber,
          status: after.status,
          listingId: after.listingId,
          channelId: after.channelId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high" as const,
          notification: {
            sound: "default",
            channelId: "orders",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      await sendToUserTokens(recipientTokens, message);
      console.log(
        `Order status notification sent to ${recipientId}, status: ${after.status}`
      );

      return null;
    } catch (error) {
      console.error("Error sending order status notification:", error);
      return null;
    }
  });
