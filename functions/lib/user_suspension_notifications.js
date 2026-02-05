"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserUnsuspended = exports.onUserSuspended = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Sends a notification to a user when they are suspended
 */
exports.onUserSuspended = functions.firestore
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
    if (!user.pushToken) {
        console.log("No push token for suspended user:", userId);
        return null;
    }
    // Check if push notifications are enabled
    if (user.settings?.allowPushNotifications === false) {
        console.log("Push notifications disabled for suspended user:", userId);
        return null;
    }
    const suspensionInfo = user.suspensionInfo || {};
    const reasonText = suspensionInfo.reasonText
        ? `Reason: ${suspensionInfo.reasonText}`
        : "Your account has been suspended due to a policy violation.";
    const message = {
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
        token: user.pushToken,
    };
    try {
        await admin.messaging().send(message);
        console.log("Suspension notification sent to user:", userId);
        return null;
    }
    catch (error) {
        console.error("Error sending suspension notification:", error);
        return null;
    }
});
/**
 * Sends a notification to a user when they are unsuspended
 */
exports.onUserUnsuspended = functions.firestore
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
    if (!user.pushToken) {
        console.log("No push token for unsuspended user:", userId);
        return null;
    }
    // Check if push notifications are enabled
    if (user.settings?.allowPushNotifications === false) {
        console.log("Push notifications disabled for unsuspended user:", userId);
        return null;
    }
    const message = {
        notification: {
            title: "✅ Account Restored",
            body: "Your account suspension has been lifted. You can now log in again.",
        },
        data: {
            type: "account_unsuspended",
            userId: userId,
            timestamp: new Date().toISOString(),
        },
        token: user.pushToken,
    };
    try {
        await admin.messaging().send(message);
        console.log("Unsuspension notification sent to user:", userId);
        return null;
    }
    catch (error) {
        console.error("Error sending unsuspension notification:", error);
        return null;
    }
});
