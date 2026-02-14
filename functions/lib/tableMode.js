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
exports.closeTableSession = exports.requestBill = exports.acknowledgeSummon = exports.summonWaiter = exports.assignWaiterToSession = exports.createTableSession = exports.deactivateTable = exports.upsertTable = exports.setTableModeSettings = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const crypto = __importStar(require("crypto"));
const db = admin.firestore();
const messaging = admin.messaging();
// =============================================================================
// CONSTANTS
// =============================================================================
const MAX_SESSIONS_PER_USER_PER_HOUR = 3;
const MAX_SUMMONS_PER_SESSION_PER_HOUR = 20;
const BILL_REQUEST_COOLDOWN_SECONDS = 60;
// =============================================================================
// HELPER FUNCTIONS
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
 */
async function verifyPremiumEntitlement(uid) {
    const isAdmin = await isAdminUser(uid);
    if (isAdmin) {
        return true;
    }
    try {
        const revenueCatApiKey = functions.config().revenuecat?.key;
        if (!revenueCatApiKey) {
            functions.logger.warn("RevenueCat API key not configured - allowing for development");
            return true;
        }
        const response = await axios_1.default.get(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
            headers: {
                Authorization: `Bearer ${revenueCatApiKey}`,
                "Content-Type": "application/json",
            },
        });
        const customer = response.data.subscriber;
        const activeEntitlements = customer.entitlements.active || {};
        return "CaribTap Pro" in activeEntitlements;
    }
    catch (error) {
        functions.logger.error("RevenueCat verification failed", { uid, error: error.message });
        return false;
    }
}
/**
 * Check if user is listing owner
 */
async function isListingOwner(listingId, uid) {
    const listingSnap = await db.collection("listings").doc(listingId).get();
    return listingSnap.exists && listingSnap.data()?.authorID === uid;
}
/**
 * Check if user is a collaborator with specific permissions
 */
async function hasCollaboratorPermission(listingId, uid, ...permissionKeys) {
    const collabSnap = await db
        .collection("listings")
        .doc(listingId)
        .collection("collaborators")
        .doc(uid)
        .get();
    if (!collabSnap.exists)
        return false;
    const data = collabSnap.data();
    if (!data?.isActive)
        return false;
    const permissions = data.permissions || {};
    return permissionKeys.some((key) => permissions[key] === true);
}
/**
 * Check if user can manage table mode for a listing
 */
async function canManageTableMode(listingId, uid) {
    const isOwner = await isListingOwner(listingId, uid);
    if (isOwner)
        return true;
    const isAdmin = await isAdminUser(uid);
    if (isAdmin)
        return true;
    return await hasCollaboratorPermission(listingId, uid, "manageTableMode");
}
/**
 * Generate secure random string
 */
function generateSecureRandom(length = 32) {
    return crypto.randomBytes(length).toString("hex");
}
/**
 * Generate next table code public
 */
async function generateNextTableCode(listingId) {
    const tablesSnap = await db
        .collection("listings")
        .doc(listingId)
        .collection("tables")
        .get();
    const existingCodes = tablesSnap.docs
        .map((doc) => doc.data().tableCodePublic || "")
        .filter((code) => code.startsWith("T") && /^\d+$/.test(code.substring(1)));
    const numbers = existingCodes
        .map((code) => parseInt(code.substring(1), 10))
        .filter((n) => !isNaN(n));
    const nextNumber = numbers.length > 0 ? Math.max(...numbers) + 1 : 1;
    return `T${nextNumber}`;
}
/**
 * Log session event
 */
async function logSessionEvent(sessionId, type, actorUid, actorRole, metadata = {}) {
    const eventId = db.collection("table_sessions").doc().id;
    await db
        .collection("table_sessions")
        .doc(sessionId)
        .collection("events")
        .doc(eventId)
        .set({
        type,
        actorUid,
        actorRole,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata,
    });
}
/**
 * Send push notification
 */
async function sendPushNotification(recipientUid, title, body, data = {}) {
    try {
        const userSnap = await db.collection("users").doc(recipientUid).get();
        const userData = userSnap.data();
        // Support both new (fcmTokens array) and legacy (pushToken string) field names
        let fcmTokens = [];
        // New format: array of FCM tokens
        if (Array.isArray(userData?.fcmTokens) && userData.fcmTokens.length > 0) {
            fcmTokens = userData.fcmTokens;
        }
        // Legacy format: single pushToken string
        else if (userData?.pushToken && typeof userData.pushToken === "string" && userData.pushToken.trim().length > 0) {
            fcmTokens = [userData.pushToken];
        }
        if (fcmTokens.length === 0) {
            functions.logger.info("No FCM tokens for user", { recipientUid, hasLegacyToken: !!userData?.pushToken, hasNewTokens: !!userData?.fcmTokens });
            return;
        }
        const message = {
            notification: { title, body },
            data,
            tokens: fcmTokens,
        };
        const response = await messaging.sendMulticast(message);
        functions.logger.info("Push sent", {
            recipientUid,
            tokenCount: fcmTokens.length,
            successCount: response.successCount,
            failureCount: response.failureCount,
        });
    }
    catch (error) {
        functions.logger.error("Push notification failed", { error: error.message });
    }
}
/**
 * Notify staff about pending session
 */
async function notifyStaffPendingSession(listingId, sessionId, tableName, customerName) {
    const listingSnap = await db.collection("listings").doc(listingId).get();
    const ownerUid = listingSnap.data()?.authorID;
    const notifyUids = [];
    if (ownerUid)
        notifyUids.push(ownerUid);
    const collabsSnap = await db
        .collection("listings")
        .doc(listingId)
        .collection("collaborators")
        .where("isActive", "==", true)
        .get();
    collabsSnap.docs.forEach((doc) => {
        const data = doc.data();
        const permissions = data.permissions || {};
        if (permissions.manageOrders || permissions.manageChats) {
            notifyUids.push(doc.id);
        }
    });
    for (const uid of [...new Set(notifyUids)]) {
        await sendPushNotification(uid, "New Table Session", `${customerName} is at ${tableName}`, {
            type: "table_session",
            sessionId,
            listingId,
            scope: "LISTING_TABLE_MODE",
        });
    }
}
// =============================================================================
// CALLABLE FUNCTIONS
// =============================================================================
/**
 * 1. Set Table Mode settings for a listing
 */
exports.setTableModeSettings = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { listingId, tableModeEnabled, summonCooldownSeconds, sessionMaxMinutes } = data;
        if (!listingId) {
            throw new functions.https.HttpsError("invalid-argument", "listingId is required");
        }
        // Verify user can manage this listing
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        if (!canManage) {
            throw new functions.https.HttpsError("permission-denied", "Only listing owner or authorized collaborators can manage table mode");
        }
        // Verify premium entitlement for the listing owner
        const listingSnap = await db.collection("listings").doc(listingId).get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const ownerUid = listingSnap.data()?.authorID;
        const hasPremium = await verifyPremiumEntitlement(ownerUid);
        if (!hasPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required to enable Table Mode");
        }
        // Validate settings
        const cooldown = summonCooldownSeconds || 120;
        const maxMinutes = sessionMaxMinutes || 180;
        if (cooldown < 30 || cooldown > 600) {
            throw new functions.https.HttpsError("invalid-argument", "summonCooldownSeconds must be between 30 and 600");
        }
        // Update listing settings
        await db
            .collection("listings")
            .doc(listingId)
            .update({
            tableModeEnabled: tableModeEnabled || false,
            tableMode: {
                summonCooldownSeconds: cooldown,
                sessionMaxMinutes: maxMinutes,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        functions.logger.info("Table mode settings updated", {
            listingId,
            tableModeEnabled,
            uid: context.auth.uid,
        });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("setTableModeSettings error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to update table mode settings: ${error.message || String(error)}`);
    }
});
/**
 * 2. Upsert Table (create or update)
 */
exports.upsertTable = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { listingId, tableId, tableName, tableCodePublic, regenerateSecret } = data;
        if (!listingId || !tableName) {
            throw new functions.https.HttpsError("invalid-argument", "listingId and tableName are required");
        }
        // Verify permissions and premium
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        if (!canManage) {
            throw new functions.https.HttpsError("permission-denied", "Permission denied");
        }
        const listingSnap = await db.collection("listings").doc(listingId).get();
        const ownerUid = listingSnap.data()?.authorID;
        const hasPremium = await verifyPremiumEntitlement(ownerUid);
        if (!hasPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required");
        }
        const now = admin.firestore.FieldValue.serverTimestamp();
        if (tableId) {
            // Update existing table
            const updateData = {
                tableName,
                tableCodePublic: tableCodePublic || tableId.substring(0, 6).toUpperCase(),
                updatedAt: now,
            };
            // Regenerate secret if requested
            if (regenerateSecret === true) {
                updateData.tableSecret = generateSecureRandom(32);
                functions.logger.info("Table secret regenerated", { listingId, tableId });
            }
            await db
                .collection("listings")
                .doc(listingId)
                .collection("tables")
                .doc(tableId)
                .update(updateData);
            functions.logger.info("Table updated", { listingId, tableId });
            return { success: true, tableId };
        }
        else {
            // Create new table
            const newTableId = db.collection("listings").doc().id;
            const generatedCode = tableCodePublic || (await generateNextTableCode(listingId));
            const tableSecret = generateSecureRandom(32);
            await db
                .collection("listings")
                .doc(listingId)
                .collection("tables")
                .doc(newTableId)
                .set({
                tableName,
                tableCodePublic: generatedCode,
                tableSecret,
                isActive: true,
                createdAt: now,
                updatedAt: now,
            });
            functions.logger.info("Table created", { listingId, tableId: newTableId });
            return { success: true, tableId: newTableId };
        }
    }
    catch (error) {
        functions.logger.error("upsertTable error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to upsert table: ${error.message || String(error)}`);
    }
});
/**
 * 3. Deactivate/Activate Table
 */
exports.deactivateTable = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { listingId, tableId, isActive } = data;
        if (!listingId || !tableId) {
            throw new functions.https.HttpsError("invalid-argument", "listingId and tableId are required");
        }
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        if (!canManage) {
            throw new functions.https.HttpsError("permission-denied", "Permission denied");
        }
        const listingSnap = await db.collection("listings").doc(listingId).get();
        const ownerUid = listingSnap.data()?.authorID;
        const hasPremium = await verifyPremiumEntitlement(ownerUid);
        if (!hasPremium) {
            throw new functions.https.HttpsError("permission-denied", "Premium subscription required");
        }
        await db
            .collection("listings")
            .doc(listingId)
            .collection("tables")
            .doc(tableId)
            .update({
            isActive: isActive !== false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        functions.logger.info("Table status updated", { listingId, tableId, isActive });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("deactivateTable error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to deactivate table: ${error.message || String(error)}`);
    }
});
/**
 * 4. Create Table Session (customer-initiated)
 */
exports.createTableSession = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { listingId, mode, tableId, secret, tableCodePublic } = data;
        if (!listingId || !mode) {
            throw new functions.https.HttpsError("invalid-argument", "listingId and mode are required");
        }
        // Check if table mode is enabled
        const listingSnap = await db.collection("listings").doc(listingId).get();
        if (!listingSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Listing not found");
        }
        const listingData = listingSnap.data();
        if (!listingData?.tableModeEnabled) {
            throw new functions.https.HttpsError("failed-precondition", "Table Mode is not enabled for this listing");
        }
        // Rate limiting: check sessions created in the last hour
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const recentSessionsSnap = await db
            .collection("table_sessions")
            .where("customerUid", "==", context.auth.uid)
            .where("listingId", "==", listingId)
            .where("createdAt", ">", oneHourAgo)
            .get();
        if (recentSessionsSnap.size >= MAX_SESSIONS_PER_USER_PER_HOUR) {
            throw new functions.https.HttpsError("resource-exhausted", "Too many attempts. Please ask staff for help.");
        }
        // Validate table and get table data
        let validatedTableId;
        let validatedTableName;
        if (mode === "QR") {
            if (!tableId || !secret) {
                throw new functions.https.HttpsError("invalid-argument", "tableId and secret required for QR mode");
            }
            const tableSnap = await db
                .collection("listings")
                .doc(listingId)
                .collection("tables")
                .doc(tableId)
                .get();
            if (!tableSnap.exists) {
                throw new functions.https.HttpsError("not-found", "Table not found");
            }
            const tableData = tableSnap.data();
            if (!tableData?.isActive) {
                throw new functions.https.HttpsError("failed-precondition", "Table is inactive");
            }
            if (tableData.tableSecret !== secret) {
                throw new functions.https.HttpsError("permission-denied", "Invalid table secret");
            }
            validatedTableId = tableId;
            validatedTableName = tableData.tableName;
        }
        else if (mode === "MANUAL") {
            if (!tableCodePublic) {
                throw new functions.https.HttpsError("invalid-argument", "tableCodePublic required for MANUAL mode");
            }
            const tablesSnap = await db
                .collection("listings")
                .doc(listingId)
                .collection("tables")
                .where("tableCodePublic", "==", tableCodePublic)
                .where("isActive", "==", true)
                .limit(1)
                .get();
            if (tablesSnap.empty) {
                throw new functions.https.HttpsError("not-found", "Table code not found or inactive");
            }
            const tableDoc = tablesSnap.docs[0];
            validatedTableId = tableDoc.id;
            validatedTableName = tableDoc.data().tableName;
        }
        else {
            throw new functions.https.HttpsError("invalid-argument", "Invalid mode");
        }
        // Get customer data
        const userSnap = await db.collection("users").doc(context.auth.uid).get();
        const userData = userSnap.data();
        const customerName = `${userData?.firstName || ""} ${userData?.lastName || ""}`.trim() || "Guest";
        const customerPhotoUrl = userData?.profilePictureURL || "";
        // Create session
        const sessionId = db.collection("table_sessions").doc().id;
        const tableMode = listingData.tableMode || {};
        const summonCooldownSeconds = tableMode.summonCooldownSeconds || 120;
        await db
            .collection("table_sessions")
            .doc(sessionId)
            .set({
            listingId,
            tableId: validatedTableId,
            tableName: validatedTableName,
            customerUid: context.auth.uid,
            customerName,
            customerPhotoUrl,
            status: "PENDING",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            activatedAt: null,
            closedAt: null,
            assignedStaff: [],
            summonCooldownSeconds,
            lastSummonAt: null,
            lastBillRequestAt: null,
        });
        // Log event
        await logSessionEvent(sessionId, "SESSION_CREATED", context.auth.uid, "CUSTOMER", { mode });
        // Notify staff
        await notifyStaffPendingSession(listingId, sessionId, validatedTableName, customerName);
        functions.logger.info("Table session created", { sessionId, listingId, mode });
        return { success: true, sessionId };
    }
    catch (error) {
        functions.logger.error("createTableSession error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to create table session: ${error.message || String(error)}`);
    }
});
/**
 * 5. Assign Waiter to Session
 */
exports.assignWaiterToSession = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { sessionId, waiterUids } = data;
        if (!sessionId || !waiterUids || !Array.isArray(waiterUids) || waiterUids.length === 0) {
            throw new functions.https.HttpsError("invalid-argument", "sessionId and waiterUids array required");
        }
        // Get session
        const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
        if (!sessionSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Session not found");
        }
        const sessionData = sessionSnap.data();
        const listingId = sessionData?.listingId;
        // Verify permissions
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        if (!canManage) {
            throw new functions.https.HttpsError("permission-denied", "Permission denied");
        }
        // Build assigned staff array
        const assignedStaff = [];
        for (const uid of waiterUids) {
            const waiterSnap = await db.collection("users").doc(uid).get();
            const waiterData = waiterSnap.data();
            assignedStaff.push({
                uid,
                firstName: waiterData?.firstName || "Staff",
                photoUrl: waiterData?.profilePictureURL || "",
                role: "WAITER",
            });
        }
        // Update session
        const updates = {
            assignedStaff,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        const isPending = sessionData?.status === "PENDING";
        const isActive = sessionData?.status === "ACTIVE";
        if (isPending) {
            updates.status = "ACTIVE";
            updates.activatedAt = admin.firestore.FieldValue.serverTimestamp();
        }
        await db.collection("table_sessions").doc(sessionId).update(updates);
        // Log events
        if (isPending) {
            await logSessionEvent(sessionId, "SESSION_ACTIVATED", context.auth.uid, "OWNER", {});
            await logSessionEvent(sessionId, "WAITER_ASSIGNED", context.auth.uid, "OWNER", {
                waiterUids,
            });
        }
        else if (isActive) {
            await logSessionEvent(sessionId, "WAITER_REASSIGNED", context.auth.uid, "OWNER", {
                waiterUids,
            });
        }
        // Notify customer
        const customerUid = sessionData?.customerUid;
        if (customerUid) {
            const waiterNames = assignedStaff.map((s) => s.firstName).join(", ");
            await sendPushNotification(customerUid, "Waiter Assigned", `${waiterNames} will assist you today`, {
                type: "table_session",
                sessionId,
                listingId,
                scope: "LISTING_TABLE_MODE",
            });
        }
        functions.logger.info("Waiters assigned", { sessionId, waiterUids });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("assignWaiterToSession error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to assign waiter: ${error.message || String(error)}`);
    }
});
/**
 * 6. Summon Waiter
 */
exports.summonWaiter = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { sessionId, purpose } = data;
        if (!sessionId) {
            throw new functions.https.HttpsError("invalid-argument", "sessionId is required");
        }
        const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
        if (!sessionSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Session not found");
        }
        const sessionData = sessionSnap.data();
        if (!sessionData) {
            throw new functions.https.HttpsError("not-found", "Session data is empty");
        }
        // Verify caller is the customer
        if (sessionData.customerUid !== context.auth.uid) {
            throw new functions.https.HttpsError("permission-denied", "Only session customer can summon waiter");
        }
        // Check session is active
        if (sessionData.status !== "ACTIVE") {
            throw new functions.https.HttpsError("failed-precondition", "Session must be active");
        }
        // Enforce cooldown
        let lastSummonAt = null;
        if (sessionData.lastSummonAt) {
            try {
                lastSummonAt = sessionData.lastSummonAt.toDate?.() || sessionData.lastSummonAt;
            }
            catch (e) {
                functions.logger.warn("Failed to parse lastSummonAt", { lastSummonAt: sessionData.lastSummonAt });
            }
        }
        const cooldownSeconds = sessionData.summonCooldownSeconds || 120;
        if (lastSummonAt && lastSummonAt instanceof Date) {
            const elapsed = (Date.now() - lastSummonAt.getTime()) / 1000;
            if (elapsed < cooldownSeconds) {
                const remainingSeconds = Math.ceil(cooldownSeconds - elapsed);
                throw new functions.https.HttpsError("resource-exhausted", `Please wait ${remainingSeconds} seconds before summoning again`, { remainingSeconds });
            }
        }
        // Rate limit summons per session per hour
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const recentSummonsSnap = await db
            .collection("table_sessions")
            .doc(sessionId)
            .collection("events")
            .where("type", "==", "WAITER_SUMMONED")
            .where("createdAt", ">", oneHourAgo)
            .get();
        if (recentSummonsSnap.size >= MAX_SUMMONS_PER_SESSION_PER_HOUR) {
            throw new functions.https.HttpsError("resource-exhausted", "Too many summons. Please ask staff directly.");
        }
        // Update lastSummonAt
        await db
            .collection("table_sessions")
            .doc(sessionId)
            .update({
            lastSummonAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log event
        await logSessionEvent(sessionId, "WAITER_SUMMONED", context.auth.uid, "CUSTOMER", { purpose });
        // Notify assigned staff (don't fail if this errors)
        const assignedStaff = sessionData.assignedStaff || [];
        if (Array.isArray(assignedStaff) && assignedStaff.length > 0) {
            for (const staff of assignedStaff) {
                if (staff && staff.uid) {
                    try {
                        await sendPushNotification(staff.uid, `${sessionData.tableName || "Table"} needs assistance`, purpose || "Customer summoned waiter", {
                            type: "table_session",
                            sessionId,
                            listingId: sessionData.listingId,
                            scope: "LISTING_TABLE_MODE",
                        });
                    }
                    catch (pushError) {
                        functions.logger.warn("Failed to send push notification to staff", {
                            staffUid: staff.uid,
                            error: pushError.message
                        });
                    }
                }
            }
        }
        // Also notify listing owner and collaborators so they're aware
        const listingSnap = await db.collection("listings").doc(sessionData.listingId).get();
        const ownerUid = listingSnap.data()?.authorID;
        const notifyOwnerUids = [];
        if (ownerUid)
            notifyOwnerUids.push(ownerUid);
        const collabsSnap = await db
            .collection("listings")
            .doc(sessionData.listingId)
            .collection("collaborators")
            .where("isActive", "==", true)
            .get();
        collabsSnap.docs.forEach((doc) => {
            const data = doc.data();
            const permissions = data.permissions || {};
            if (permissions.manageOrders || permissions.manageChats) {
                notifyOwnerUids.push(doc.id);
            }
        });
        // Send notifications to owner/collaborators (but don't fail if errors)
        for (const uid of [...new Set(notifyOwnerUids)]) {
            try {
                await sendPushNotification(uid, `Waiter Summon: ${sessionData.tableName || "Table"}`, `${sessionData.customerName} needs assistance${purpose ? `: ${purpose}` : ""}`, {
                    type: "table_session",
                    sessionId,
                    listingId: sessionData.listingId,
                    scope: "LISTING_TABLE_MODE",
                    action: "WAITER_SUMMON",
                });
            }
            catch (pushError) {
                functions.logger.warn("Failed to send waiter summon notification to owner", {
                    ownerUid: uid,
                    error: pushError.message
                });
            }
        }
        functions.logger.info("Waiter summoned", { sessionId, purpose });
        return { success: true };
    }
    catch (error) {
        // Log the actual error for debugging
        functions.logger.error("summonWaiter error", {
            error: error.message || String(error),
            code: error.code,
            stack: error.stack
        });
        // If it's already an HttpsError, rethrow it
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        // Convert unexpected errors to internal error with details
        throw new functions.https.HttpsError("internal", `Failed to summon waiter: ${error.message || String(error)}`);
    }
});
/**
 * 7. Acknowledge Summon
 */
exports.acknowledgeSummon = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { sessionId } = data;
        if (!sessionId) {
            throw new functions.https.HttpsError("invalid-argument", "sessionId is required");
        }
        const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
        if (!sessionSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Session not found");
        }
        const sessionData = sessionSnap.data();
        const listingId = sessionData?.listingId;
        // Verify caller is assigned staff or has management permissions
        const assignedStaffUids = (sessionData?.assignedStaff || []).map((s) => s.uid);
        const isAssignedStaff = assignedStaffUids.includes(context.auth.uid);
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        if (!isAssignedStaff && !canManage) {
            throw new functions.https.HttpsError("permission-denied", "Permission denied");
        }
        // Log event
        await logSessionEvent(sessionId, "WAITER_ACKNOWLEDGED", context.auth.uid, "WAITER", {});
        // Notify customer
        const customerUid = sessionData?.customerUid;
        if (customerUid) {
            await sendPushNotification(customerUid, "Your waiter is on the way", "Help is coming shortly", {
                type: "table_session",
                sessionId,
                listingId,
                scope: "LISTING_TABLE_MODE",
            });
        }
        functions.logger.info("Summon acknowledged", { sessionId });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("acknowledgeSummon error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to acknowledge summon: ${error.message || String(error)}`);
    }
});
/**
 * 8. Request Bill
 */
exports.requestBill = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { sessionId, paymentMethod } = data;
        if (!sessionId) {
            throw new functions.https.HttpsError("invalid-argument", "sessionId is required");
        }
        const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
        if (!sessionSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Session not found");
        }
        const sessionData = sessionSnap.data();
        // Verify caller is the customer
        if (sessionData?.customerUid !== context.auth.uid) {
            throw new functions.https.HttpsError("permission-denied", "Only session customer can request bill");
        }
        // Check session is active
        if (sessionData?.status !== "ACTIVE") {
            throw new functions.https.HttpsError("failed-precondition", "Session must be active");
        }
        // Enforce cooldown
        const lastBillRequestAt = sessionData?.lastBillRequestAt?.toDate();
        if (lastBillRequestAt) {
            const elapsed = (Date.now() - lastBillRequestAt.getTime()) / 1000;
            if (elapsed < BILL_REQUEST_COOLDOWN_SECONDS) {
                const remainingSeconds = Math.ceil(BILL_REQUEST_COOLDOWN_SECONDS - elapsed);
                throw new functions.https.HttpsError("resource-exhausted", `Please wait ${remainingSeconds} seconds before requesting bill again`, { remainingSeconds });
            }
        }
        // Update lastBillRequestAt
        await db
            .collection("table_sessions")
            .doc(sessionId)
            .update({
            lastBillRequestAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log event
        await logSessionEvent(sessionId, "BILL_REQUESTED", context.auth.uid, "CUSTOMER", { paymentMethod });
        // Notify assigned staff
        const assignedStaff = sessionData?.assignedStaff || [];
        for (const staff of assignedStaff) {
            if (staff && staff.uid) {
                try {
                    await sendPushNotification(staff.uid, `Bill requested at ${sessionData?.tableName}`, `Payment method: ${paymentMethod || "Not specified"}`, {
                        type: "table_session",
                        sessionId,
                        listingId: sessionData?.listingId,
                        scope: "LISTING_TABLE_MODE",
                    });
                }
                catch (pushError) {
                    functions.logger.warn("Failed to send notification to staff", {
                        staffUid: staff.uid,
                        error: pushError.message
                    });
                }
            }
        }
        // Also notify listing owner and collaborators
        const listingSnap = await db.collection("listings").doc(sessionData?.listingId).get();
        const ownerUid = listingSnap.data()?.authorID;
        const notifyOwnerUids = [];
        if (ownerUid)
            notifyOwnerUids.push(ownerUid);
        const collabsSnap = await db
            .collection("listings")
            .doc(sessionData?.listingId)
            .collection("collaborators")
            .where("isActive", "==", true)
            .get();
        collabsSnap.docs.forEach((doc) => {
            const data = doc.data();
            const permissions = data.permissions || {};
            if (permissions.manageOrders || permissions.manageChats) {
                notifyOwnerUids.push(doc.id);
            }
        });
        // Send notifications to owner/collaborators (but don't fail if errors)
        for (const uid of [...new Set(notifyOwnerUids)]) {
            try {
                await sendPushNotification(uid, `Bill Request: ${sessionData?.tableName}`, `${sessionData?.customerName} requested bill${paymentMethod ? ` (${paymentMethod})` : ""}`, {
                    type: "table_session",
                    sessionId,
                    listingId: sessionData?.listingId,
                    scope: "LISTING_TABLE_MODE",
                    action: "BILL_REQUEST",
                });
            }
            catch (pushError) {
                functions.logger.warn("Failed to send bill request notification to owner", {
                    ownerUid: uid,
                    error: pushError.message
                });
            }
        }
        functions.logger.info("Bill requested", { sessionId, paymentMethod });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("requestBill error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to request bill: ${error.message || String(error)}`);
    }
});
/**
 * 9. Close Table Session
 */
exports.closeTableSession = functions.https.onCall(async (data, context) => {
    try {
        if (!context.auth) {
            throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
        }
        const { sessionId } = data;
        if (!sessionId) {
            throw new functions.https.HttpsError("invalid-argument", "sessionId is required");
        }
        const sessionSnap = await db.collection("table_sessions").doc(sessionId).get();
        if (!sessionSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Session not found");
        }
        const sessionData = sessionSnap.data();
        const listingId = sessionData?.listingId;
        // Verify permissions (owner/collab can close, customer can request)
        const canManage = await canManageTableMode(listingId, context.auth.uid);
        const isCustomer = sessionData?.customerUid === context.auth.uid;
        if (!canManage && !isCustomer) {
            throw new functions.https.HttpsError("permission-denied", "Permission denied");
        }
        // Update session
        await db
            .collection("table_sessions")
            .doc(sessionId)
            .update({
            status: "CLOSED",
            closedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log event
        const actorRole = canManage ? "OWNER" : "CUSTOMER";
        await logSessionEvent(sessionId, "SESSION_CLOSED", context.auth.uid, actorRole, {});
        functions.logger.info("Table session closed", { sessionId });
        return { success: true };
    }
    catch (error) {
        functions.logger.error("closeTableSession error", {
            error: error.message || String(error),
            code: error.code,
        });
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", `Failed to close table session: ${error.message || String(error)}`);
    }
});
