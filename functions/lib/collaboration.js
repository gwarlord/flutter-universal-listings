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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendOrderChatMessage = exports.setBookingStatus = exports.setRentalStatus = exports.updateListingEditableFields = exports.setOrderFulfillment = exports.setOrderStatus = exports.updateListingCollaboratorPermissions = exports.removeListingCollaborator = exports.addListingCollaborator = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const secrets_1 = require("./common/secrets");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
// =============================================================================
// REVENUECAT VERIFICATION
// =============================================================================
/**
 * Check if user is an admin
 */
async function isAdminUser(uid) {
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists && userSnap.data()?.isAdmin === true) {
        return true;
    }
    const adminDoc = await db.collection("admins").doc("admins").get();
    if (!adminDoc.exists)
        return false;
    const adminUserIds = adminDoc.data()?.adminUserIds || [];
    return adminUserIds.includes(uid);
}
/**
 * Verify if user has active Premium entitlement via RevenueCat
 * Admins bypass premium check
 * If RevenueCat is not configured (development), allow access
 */
async function verifyPremiumEntitlement(uid) {
    // 1. Check if user is admin (admins always have access)
    const isAdmin = await isAdminUser(uid);
    if (isAdmin) {
        functions.logger.info("Premium check bypassed for admin", { uid });
        return true;
    }
    // 2. Check RevenueCat
    try {
        const revenueCatApiKey = await secrets_1.revenuecatKeySecret.value();
        if (!revenueCatApiKey) {
            functions.logger.warn("RevenueCat API key not configured - allowing access for development");
            // In development (no API key configured), allow access
            return true;
        }
        // Note: You need to set this via firebase functions:secrets:set revenuecat_key
        const response = await axios_1.default.get(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
            headers: {
                Authorization: `Bearer ${revenueCatApiKey}`,
                "Content-Type": "application/json",
            },
        });
        const customer = response.data.subscriber;
        const activeEntitlements = customer.entitlements.active || {};
        // Check for "CaribTap Pro" entitlement
        const hasProEntitlement = "CaribTap Pro" in activeEntitlements;
        functions.logger.info("Premium check", {
            uid,
            hasProEntitlement,
            entitlements: Object.keys(activeEntitlements),
        });
        return hasProEntitlement;
    }
    catch (error) {
        functions.logger.error("RevenueCat verification failed", {
            uid,
            error: error.message,
        });
        // Return false on any error (failed security check = deny)
        return false;
    }
}
// =============================================================================
// ACTIVITY LOGGING
// =============================================================================
/**
 * Log activity to a listing's activity stream
 */
async function logActivity(listingId, data) {
    try {
        const activityId = db.collection("listings").doc().id;
        const activityData = {
            ...data,
            createdAt: admin.firestore.Timestamp.now(),
        };
        await db
            .collection("listings")
            .doc(listingId)
            .collection("activity")
            .doc(activityId)
            .set(activityData);
        functions.logger.info("Activity logged", {
            listingId,
            actionType: data.actionType,
            actor: data.actorUid,
        });
    }
    catch (error) {
        functions.logger.error("Failed to log activity", {
            listingId,
            error,
        });
    }
}
// =============================================================================
// COLLABORATOR MANAGEMENT FUNCTIONS
// =============================================================================
/**
 * Callable: Add a collaborator to a listing
 * Requires:
 *  - Caller is listing owner/admin
 *  - Caller has active Premium subscription (RevenueCat)
 *  - Valid collaborator email or UID
 */
exports.addListingCollaborator = functions.https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, collaboratorEmailOrUid, permissions: incomingPermissions } = data;
    try {
        // 1. Verify caller owns the listing
        const listingDoc = await db.collection("listings").doc(listingId).get();
        if (!listingDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listing = listingDoc.data();
        const callerId = context.auth.uid;
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            throw new functions.https.HttpsError("permission-denied", "Only listing owner/admin can add collaborators");
        }
        // 2. Verify Premium subscription
        const isPremium = await verifyPremiumEntitlement(callerId);
        if (!isPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required to manage collaborators");
        }
        // 3. Resolve collaborator UID
        let collaboratorUid = collaboratorEmailOrUid;
        if (collaboratorEmailOrUid.includes("@")) {
            // It's an email; find user by email
            const usersSnapshot = await db
                .collection("users")
                .where("email", "==", collaboratorEmailOrUid)
                .limit(1)
                .get();
            if (usersSnapshot.empty) {
                throw new functions.https.HttpsError("not-found", `User with email ${collaboratorEmailOrUid} not found`);
            }
            collaboratorUid = usersSnapshot.docs[0].id;
        }
        // 4. Ensure deleteListing is always false
        const finalPermissions = {
            manageOrders: incomingPermissions.manageOrders ?? true,
            manageBookings: incomingPermissions.manageBookings ?? true,
            manageRentals: incomingPermissions.manageRentals ?? true,
            manageChats: incomingPermissions.manageChats ?? true,
            editListing: incomingPermissions.editListing ?? true,
            changeOrderStatus: incomingPermissions.changeOrderStatus ?? true,
            changeFulfillment: incomingPermissions.changeFulfillment ?? true,
            deleteListing: false, // ALWAYS false
        };
        // 5. Write collaborator document
        const collaboratorData = {
            isActive: true,
            role: "COLLABORATOR",
            permissions: finalPermissions,
            addedBy: callerId,
            addedAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
        };
        await db
            .collection("listings")
            .doc(listingId)
            .collection("collaborators")
            .doc(collaboratorUid)
            .set(collaboratorData);
        // 6. Create assignedListings mapping (for easy lookup)
        await db
            .collection("users")
            .doc(collaboratorUid)
            .collection("assignedListings")
            .doc(listingId)
            .set({
            ownerUid: listing.authorID,
            isActive: true,
            addedAt: admin.firestore.Timestamp.now(),
            permissionsSummary: Object.entries(finalPermissions)
                .filter(([, value]) => value)
                .map(([key]) => key),
        });
        // 7. Update listing chat participants
        const listingChatId = `listing_${listingId}`;
        await db
            .collection("listing_chats")
            .doc(listingChatId)
            .set({
            listingId,
            ownerUid: listing.authorID,
            participantUids: admin.firestore.FieldValue.arrayUnion(collaboratorUid),
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // 8. Add collaborator to existing order chat threads for this listing
        const ordersSnapshot = await db
            .collection("listings")
            .doc(listingId)
            .collection("orders")
            .get();
        for (const orderDoc of ordersSnapshot.docs) {
            const orderId = orderDoc.id;
            const orderChatId = `order_${orderId}`;
            // Only add if manageChats is true
            if (finalPermissions.manageChats) {
                await db
                    .collection("order_chats")
                    .doc(orderChatId)
                    .set({
                    orderId,
                    listingId,
                    ownerUid: listing.authorID,
                    participantUids: admin.firestore.FieldValue.arrayUnion(collaboratorUid),
                    updatedAt: admin.firestore.Timestamp.now(),
                }, { merge: true });
            }
        }
        // 9. Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: "OWNER",
            actionType: "COLLABORATOR_ADDED",
            targetType: "COLLABORATOR",
            targetId: collaboratorUid,
            listingId,
            note: `Added as COLLABORATOR with permissions: ${Object.keys(finalPermissions)
                .filter((k) => finalPermissions[k])
                .join(", ")}`,
        });
        functions.logger.info("Collaborator added successfully", {
            callerUid: callerId,
            listingId,
            collaboratorUid,
        });
        return {
            success: true,
            collaboratorUid,
        };
    }
    catch (error) {
        functions.logger.error("addListingCollaborator error", {
            error: error.message,
            data,
        });
        throw error;
    }
});
/**
 * Callable: Remove a collaborator from a listing (soft delete)
 */
exports.removeListingCollaborator = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, collaboratorUid } = data;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        if (!listingDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listing = listingDoc.data();
        const callerId = context.auth.uid;
        // Verify ownership
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            throw new functions.https.HttpsError("permission-denied", "Unauthorized");
        }
        // Verify Premium
        const isPremium = await verifyPremiumEntitlement(callerId);
        if (!isPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required");
        }
        // Soft delete: set isActive to false
        await db
            .collection("listings")
            .doc(listingId)
            .collection("collaborators")
            .doc(collaboratorUid)
            .set({
            isActive: false,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Remove from assignedListings
        await db
            .collection("users")
            .doc(collaboratorUid)
            .collection("assignedListings")
            .doc(listingId)
            .set({
            isActive: false,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Remove from listing chat participants
        const listingChatId = `listing_${listingId}`;
        await db
            .collection("listing_chats")
            .doc(listingChatId)
            .set({
            participantUids: admin.firestore.FieldValue.arrayRemove([collaboratorUid]),
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Remove from order chat participants for this listing's orders
        const ordersSnapshot = await db
            .collection("listings")
            .doc(listingId)
            .collection("orders")
            .get();
        for (const orderDoc of ordersSnapshot.docs) {
            const orderId = orderDoc.id;
            const orderChatId = `order_${orderId}`;
            await db
                .collection("order_chats")
                .doc(orderChatId)
                .set({
                participantUids: admin.firestore.FieldValue.arrayRemove([collaboratorUid]),
                updatedAt: admin.firestore.Timestamp.now(),
            }, { merge: true });
        }
        // Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: "OWNER",
            actionType: "COLLABORATOR_REMOVED",
            targetType: "COLLABORATOR",
            targetId: collaboratorUid,
            listingId,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("removeListingCollaborator error", {
            error: error.message,
        });
        throw error;
    }
});
/**
 * Callable: Update collaborator permissions
 */
exports.updateListingCollaboratorPermissions = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, collaboratorUid, permissions: incomingPermissions } = data;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        if (!listingDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listing = listingDoc.data();
        const callerId = context.auth.uid;
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            throw new functions.https.HttpsError("permission-denied", "Unauthorized");
        }
        const isPremium = await verifyPremiumEntitlement(callerId);
        if (!isPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required");
        }
        // Ensure deleteListing is always false
        const finalPermissions = {
            manageOrders: incomingPermissions.manageOrders ?? incomingPermissions.manageOrders,
            manageBookings: incomingPermissions.manageBookings ?? incomingPermissions.manageBookings,
            manageRentals: incomingPermissions.manageRentals ?? incomingPermissions.manageRentals,
            manageChats: incomingPermissions.manageChats ?? incomingPermissions.manageChats,
            editListing: incomingPermissions.editListing ?? incomingPermissions.editListing,
            changeOrderStatus: incomingPermissions.changeOrderStatus ?? incomingPermissions.changeOrderStatus,
            changeFulfillment: incomingPermissions.changeFulfillment ?? incomingPermissions.changeFulfillment,
            deleteListing: false,
        };
        // Update permissions
        await db
            .collection("listings")
            .doc(listingId)
            .collection("collaborators")
            .doc(collaboratorUid)
            .set({
            permissions: finalPermissions,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Update assignedListings summary
        await db
            .collection("users")
            .doc(collaboratorUid)
            .collection("assignedListings")
            .doc(listingId)
            .set({
            permissionsSummary: Object.entries(finalPermissions)
                .filter(([, value]) => value)
                .map(([key]) => key),
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // If manageChats changed, update chat access
        const oldCollab = await db
            .collection("listings")
            .doc(listingId)
            .collection("collaborators")
            .doc(collaboratorUid)
            .get();
        const oldPermissions = oldCollab.data()?.permissions;
        const chatPermissionChanged = oldPermissions?.manageChats !== finalPermissions.manageChats;
        if (chatPermissionChanged) {
            if (finalPermissions.manageChats) {
                // Add to chats
                const listingChatId = `listing_${listingId}`;
                await db
                    .collection("listing_chats")
                    .doc(listingChatId)
                    .set({
                    participantUids: admin.firestore.FieldValue.arrayUnion([collaboratorUid]),
                }, { merge: true });
                // Add to order chats
                const ordersSnapshot = await db
                    .collection("listings")
                    .doc(listingId)
                    .collection("orders")
                    .get();
                for (const orderDoc of ordersSnapshot.docs) {
                    const orderId = orderDoc.id;
                    const orderChatId = `order_${orderId}`;
                    await db
                        .collection("order_chats")
                        .doc(orderChatId)
                        .set({
                        participantUids: admin.firestore.FieldValue.arrayUnion([
                            collaboratorUid,
                        ]),
                    }, { merge: true });
                }
            }
            else {
                // Remove from chats
                const listingChatId = `listing_${listingId}`;
                await db
                    .collection("listing_chats")
                    .doc(listingChatId)
                    .set({
                    participantUids: admin.firestore.FieldValue.arrayRemove([collaboratorUid]),
                }, { merge: true });
                const ordersSnapshot = await db
                    .collection("listings")
                    .doc(listingId)
                    .collection("orders")
                    .get();
                for (const orderDoc of ordersSnapshot.docs) {
                    const orderId = orderDoc.id;
                    const orderChatId = `order_${orderId}`;
                    await db
                        .collection("order_chats")
                        .doc(orderChatId)
                        .set({
                        participantUids: admin.firestore.FieldValue.arrayRemove([
                            collaboratorUid,
                        ]),
                    }, { merge: true });
                }
            }
        }
        // Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: "OWNER",
            actionType: "COLLABORATOR_PERMISSIONS_UPDATED",
            targetType: "COLLABORATOR",
            targetId: collaboratorUid,
            listingId,
            note: `Updated permissions to: ${Object.keys(finalPermissions)
                .filter((k) => finalPermissions[k])
                .join(", ")}`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("updateListingCollaboratorPermissions error", {
            error: error.message,
        });
        throw error;
    }
});
// =============================================================================
// STATE CHANGE FUNCTIONS (with activity logging)
// =============================================================================
/**
 * Callable: Set order status (with permission check)
 */
exports.setOrderStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { orderId, newStatus, listingId } = data;
    const callerId = context.auth.uid;
    try {
        // If caller is not owner, verify collaborator permission
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            // Verify collaborator has permission
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            if (!collabDoc.exists || !collabDoc.data()?.permissions.changeOrderStatus) {
                throw new functions.https.HttpsError("permission-denied", "Collaborator does not have changeOrderStatus permission");
            }
        }
        // Update order status
        await db
            .collection("listings")
            .doc(listingId)
            .collection("orders")
            .doc(orderId)
            .set({
            status: newStatus,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        const callerRole = listing?.authorID === callerId ? "OWNER" : "COLLABORATOR";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: callerRole,
            actionType: "ORDER_STATUS_CHANGED",
            targetType: "ORDER",
            targetId: orderId,
            listingId,
            note: `Status changed to: ${newStatus}`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("setOrderStatus error", { error: error.message });
        throw error;
    }
});
/**
 * Callable: Set order fulfillment
 */
exports.setOrderFulfillment = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { orderId, fulfillmentData, listingId } = data;
    const callerId = context.auth.uid;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        // Permission check
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            if (!collabDoc.exists || !collabDoc.data()?.permissions.changeFulfillment) {
                throw new functions.https.HttpsError("permission-denied", "Collaborator does not have changeFulfillment permission");
            }
        }
        // Update fulfillment
        await db
            .collection("listings")
            .doc(listingId)
            .collection("orders")
            .doc(orderId)
            .set({
            fulfillment: fulfillmentData,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        const callerRole = listing?.authorID === callerId ? "OWNER" : "COLLABORATOR";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: callerRole,
            actionType: "FULFILLMENT_UPDATED",
            targetType: "ORDER",
            targetId: orderId,
            listingId,
            note: `Fulfillment updated`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("setOrderFulfillment error", { error: error.message });
        throw error;
    }
});
/**
 * Callable: Update listing editable fields
 */
exports.updateListingEditableFields = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, patch } = data;
    const callerId = context.auth.uid;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        // Permission check
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            if (!collabDoc.exists || !collabDoc.data()?.permissions.editListing) {
                throw new functions.https.HttpsError("permission-denied", "Collaborator does not have editListing permission");
            }
        }
        // Update listing
        await db.collection("listings").doc(listingId).set({
            ...patch,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        // Log activity
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        const callerRole = listing?.authorID === callerId ? "OWNER" : "COLLABORATOR";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: callerRole,
            actionType: "LISTING_EDITED",
            targetType: "LISTING",
            targetId: listingId,
            listingId,
            note: `Updated fields: ${Object.keys(patch).join(", ")}`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("updateListingEditableFields error", {
            error: error.message,
        });
        throw error;
    }
});
/**
 * Callable: Update rental status
 */
exports.setRentalStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, rentalId, newStatus } = data;
    const callerId = context.auth.uid;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            if (!collabDoc.exists || !collabDoc.data()?.permissions.manageRentals) {
                throw new functions.https.HttpsError("permission-denied", "Collaborator does not have manageRentals permission");
            }
        }
        await db
            .collection("listings")
            .doc(listingId)
            .collection("rentals")
            .doc(rentalId)
            .set({
            status: newStatus,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        const callerRole = listing?.authorID === callerId ? "OWNER" : "COLLABORATOR";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: callerRole,
            actionType: "RENTAL_STATUS_CHANGED",
            targetType: "RENTAL",
            targetId: rentalId,
            listingId,
            note: `Status changed to: ${newStatus}`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("setRentalStatus error", { error: error.message });
        throw error;
    }
});
/**
 * Callable: Update booking status
 */
exports.setBookingStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { listingId, bookingId, newStatus } = data;
    const callerId = context.auth.uid;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        if (listing?.authorID !== callerId && !listing?.admins?.includes(callerId)) {
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            if (!collabDoc.exists || !collabDoc.data()?.permissions.manageBookings) {
                throw new functions.https.HttpsError("permission-denied", "Collaborator does not have manageBookings permission");
            }
        }
        await db
            .collection("listings")
            .doc(listingId)
            .collection("bookings")
            .doc(bookingId)
            .set({
            status: newStatus,
            updatedAt: admin.firestore.Timestamp.now(),
        }, { merge: true });
        const callerDoc = await db.collection("users").doc(callerId).get();
        const callerName = callerDoc.data()?.firstName || "Unknown";
        const callerRole = listing?.authorID === callerId ? "OWNER" : "COLLABORATOR";
        await logActivity(listingId, {
            actorUid: callerId,
            actorName: callerName,
            actorRole: callerRole,
            actionType: "BOOKING_UPDATED",
            targetType: "BOOKING",
            targetId: bookingId,
            listingId,
            note: `Status changed to: ${newStatus}`,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("setBookingStatus error", { error: error.message });
        throw error;
    }
});
/**
 * Callable: Send order thread chat message with activity logging
 */
exports.sendOrderChatMessage = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }
    const { orderId, listingId, messageId, message } = data;
    const callerId = context.auth.uid;
    try {
        const listingDoc = await db.collection("listings").doc(listingId).get();
        const listing = listingDoc.data();
        const orderDoc = await db
            .collection("listings")
            .doc(listingId)
            .collection("orders")
            .doc(orderId)
            .get();
        const order = orderDoc.data();
        // Verify participant (owner, collaborator with manageChats, or customer)
        const isOwner = listing?.authorID === callerId;
        const isCustomer = order?.customerId === callerId;
        let isCollaborator = false;
        if (!isOwner && !isCustomer) {
            const collabDoc = await db
                .collection("listings")
                .doc(listingId)
                .collection("collaborators")
                .doc(callerId)
                .get();
            isCollaborator =
                collabDoc.exists &&
                    collabDoc.data()?.permissions.manageChats &&
                    collabDoc.data()?.isActive;
        }
        if (!isOwner && !isCustomer && !isCollaborator) {
            throw new functions.https.HttpsError("permission-denied", "Not authorized to message this order chat");
        }
        // Write message
        const messageRef = db
            .collection("order_chats")
            .doc(`order_${orderId}`)
            .collection("messages")
            .doc(messageId);
        await messageRef.set({
            senderUid: callerId,
            content: message.content,
            type: message.type || "text",
            attachments: message.attachments || [],
            createdAt: admin.firestore.Timestamp.now(),
        });
        // Log activity (only for owner/collab, not customer)
        if (isOwner || isCollaborator) {
            const callerDoc = await db.collection("users").doc(callerId).get();
            const callerName = callerDoc.data()?.firstName || "Unknown";
            await logActivity(listingId, {
                actorUid: callerId,
                actorName: callerName,
                actorRole: isOwner ? "OWNER" : "COLLABORATOR",
                actionType: "CHAT_MESSAGE_SENT",
                targetType: "CHAT",
                targetId: orderId,
                listingId,
                note: "Message sent to order thread",
            });
        }
        return { success: true };
    }
    catch (error) {
        functions.logger.error("sendOrderChatMessage error", { error: error.message });
        throw error;
    }
});
