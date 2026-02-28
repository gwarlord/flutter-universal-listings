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
exports.processActivityAutoRefresh = exports.onListingCreated = exports.bulkRefreshListings = exports.refreshListingFreshness = exports.processListingFreshness = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const mail_1 = __importDefault(require("@sendgrid/mail"));
const secrets_1 = require("./common/secrets");
// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const messaging = admin.messaging();
const EMAIL_FROM = { email: "admin@caribtap.com", name: "CaribTap" };
const DAY_MS = 24 * 60 * 60 * 1000;
const DEV_MODE = process.env.NODE_ENV === "development" ||
    process.env.FUNCTIONS_EMULATOR === "true";
const DEFAULT_FRESHNESS_DAYS = DEV_MODE ? 1 : 90;
const WARN_10D_OFFSET_MS = DEV_MODE ? 10 * 60 * 1000 : 10 * DAY_MS;
const WARN_1D_OFFSET_MS = DEV_MODE ? 1 * 60 * 1000 : 1 * DAY_MS;
const WARNING_WINDOW_MS = DEV_MODE ? 5 * 60 * 1000 : 12 * 60 * 60 * 1000;
exports.processListingFreshness = functions.pubsub
    .schedule("every 6 hours")
    .onRun(async () => {
    const now = new Date();
    await backfillMissingFreshness(now);
    await sendFreshnessWarnings(now, "10d");
    await sendFreshnessWarnings(now, "1d");
    await hideExpiredListings(now);
    return null;
});
exports.refreshListingFreshness = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const listingId = data?.listingId;
    if (!listingId || typeof listingId !== "string") {
        throw new functions.https.HttpsError("invalid-argument", "listingId is required");
    }
    const listingRef = db.collection("listings").doc(listingId);
    const listingSnap = await listingRef.get();
    if (!listingSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Listing not found");
    }
    const listing = listingSnap.data() || {};
    const uid = context.auth.uid;
    const isAdmin = await isAdminUser(uid);
    if (listing.authorID !== uid && !isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "You do not have permission to refresh this listing");
    }
    const days = getFreshnessForCategory(listing.category, listing.freshness?.days);
    const now = admin.firestore.Timestamp.now();
    const hideAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + days * DAY_MS);
    const updateData = {
        hidden: false,
        "freshness.enabled": true,
        "freshness.days": days,
        "freshness.lastRefreshedAt": now,
        "freshness.hideAt": hideAt,
        "freshness.status": "ACTIVE",
        "freshness.warn10SentAt": admin.firestore.FieldValue.delete(),
        "freshness.warn1SentAt": admin.firestore.FieldValue.delete(),
        "freshness.hiddenNotifiedAt": admin.firestore.FieldValue.delete(),
    };
    // Track verification if provided
    if (data?.verified) {
        updateData["freshness.lastVerified"] = now;
        updateData["freshness.verificationChecklist"] = data.verificationChecklist || {};
    }
    await listingRef.update(updateData);
    return { ok: true, hideAt: hideAt.toDate().toISOString() };
});
// Bulk refresh multiple listings
exports.bulkRefreshListings = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const listingIds = data?.listingIds;
    if (!Array.isArray(listingIds) || listingIds.length === 0) {
        throw new functions.https.HttpsError("invalid-argument", "listingIds array is required");
    }
    if (listingIds.length > 50) {
        throw new functions.https.HttpsError("invalid-argument", "Cannot refresh more than 50 listings at once");
    }
    const uid = context.auth.uid;
    const isAdmin = await isAdminUser(uid);
    const now = admin.firestore.Timestamp.now();
    const batch = db.batch();
    let refreshedCount = 0;
    const errors = [];
    for (const listingId of listingIds) {
        try {
            const listingRef = db.collection("listings").doc(listingId);
            const listingSnap = await listingRef.get();
            if (!listingSnap.exists) {
                errors.push(`${listingId}: Not found`);
                continue;
            }
            const listing = listingSnap.data() || {};
            if (listing.authorID !== uid && !isAdmin) {
                errors.push(`${listingId}: Permission denied`);
                continue;
            }
            const days = getFreshnessForCategory(listing.category, listing.freshness?.days);
            const hideAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + days * DAY_MS);
            const updateData = {
                hidden: false,
                "freshness.enabled": true,
                "freshness.days": days,
                "freshness.lastRefreshedAt": now,
                "freshness.hideAt": hideAt,
                "freshness.status": "ACTIVE",
                "freshness.warn10SentAt": admin.firestore.FieldValue.delete(),
                "freshness.warn1SentAt": admin.firestore.FieldValue.delete(),
                "freshness.hiddenNotifiedAt": admin.firestore.FieldValue.delete(),
            };
            if (data?.verified) {
                updateData["freshness.lastVerified"] = now;
            }
            batch.update(listingRef, updateData);
            refreshedCount++;
        }
        catch (error) {
            errors.push(`${listingId}: ${error}`);
        }
    }
    await batch.commit();
    return {
        ok: true,
        refreshedCount,
        totalCount: listingIds.length,
        errors: errors.length > 0 ? errors : null,
    };
});
exports.onListingCreated = functions.firestore
    .document("listings/{listingId}")
    .onCreate(async (snapshot) => {
    const listing = snapshot.data();
    if (listing.freshness && listing.freshness.hideAt) {
        return;
    }
    const now = new Date();
    const createdAt = resolveListingCreatedAt(listing, now);
    // Use category-based freshness period
    const days = getFreshnessForCategory(listing.category, listing.freshness?.days);
    const hideAt = new Date(createdAt.getTime() + days * DAY_MS);
    await snapshot.ref.set({
        freshness: {
            enabled: true,
            days,
            lastRefreshedAt: admin.firestore.Timestamp.fromDate(createdAt),
            hideAt: admin.firestore.Timestamp.fromDate(hideAt),
            status: "ACTIVE",
            exempt: false,
        },
    }, { merge: true });
});
async function backfillMissingFreshness(now) {
    const missingHideAtQuery = db
        .collection("listings")
        .where("freshness.hideAt", "==", null)
        .limit(200);
    await backfillQuery(missingHideAtQuery, now);
}
async function backfillQuery(query, now) {
    const snap = await query.get();
    if (snap.empty)
        return;
    const batch = db.batch();
    for (const doc of snap.docs) {
        const listing = doc.data();
        const createdAt = resolveListingCreatedAt(listing, now);
        const existing = listing.freshness || {};
        const days = parseFreshnessDays(existing.days);
        const lastRefreshedAt = resolveTimestamp(existing.lastRefreshedAt) || createdAt;
        const hideAt = resolveTimestamp(existing.hideAt) ||
            new Date(lastRefreshedAt.getTime() + days * DAY_MS);
        const freshnessUpdate = {
            enabled: existing.enabled !== false,
            days,
            lastRefreshedAt: admin.firestore.Timestamp.fromDate(lastRefreshedAt),
            hideAt: admin.firestore.Timestamp.fromDate(hideAt),
            status: existing.status || "ACTIVE",
            exempt: existing.exempt === true,
        };
        if (resolveTimestamp(existing.warn10SentAt)) {
            freshnessUpdate.warn10SentAt = existing.warn10SentAt;
        }
        if (resolveTimestamp(existing.warn1SentAt)) {
            freshnessUpdate.warn1SentAt = existing.warn1SentAt;
        }
        if (resolveTimestamp(existing.hiddenNotifiedAt)) {
            freshnessUpdate.hiddenNotifiedAt = existing.hiddenNotifiedAt;
        }
        batch.set(doc.ref, { freshness: freshnessUpdate }, { merge: true });
    }
    await batch.commit();
}
async function sendFreshnessWarnings(now, type) {
    const offsetMs = type === "10d" ? WARN_10D_OFFSET_MS : WARN_1D_OFFSET_MS;
    const lowerBound = new Date(now.getTime() + offsetMs - WARNING_WINDOW_MS);
    const upperBound = new Date(now.getTime() + offsetMs + WARNING_WINDOW_MS);
    const snapshot = await db
        .collection("listings")
        .where("freshness.enabled", "==", true)
        .where("freshness.exempt", "==", false)
        .where("hidden", "==", false)
        .where("suspended", "==", false)
        .where("freshness.hideAt", ">=", lowerBound)
        .where("freshness.hideAt", "<=", upperBound)
        .get();
    if (snapshot.empty)
        return;
    for (const doc of snapshot.docs) {
        const listing = doc.data();
        const freshness = listing.freshness || {};
        const warnField = type === "10d" ? "warn10SentAt" : "warn1SentAt";
        if (freshness[warnField])
            continue;
        const isExempt = await isListerExempt(listing.authorID);
        if (isExempt)
            continue;
        let shouldSend = false;
        try {
            await db.runTransaction(async (transaction) => {
                const freshDoc = await transaction.get(doc.ref);
                if (!freshDoc.exists)
                    return;
                const freshData = freshDoc.data() || {};
                const freshFreshness = freshData.freshness || {};
                if (freshFreshness[warnField]) {
                    shouldSend = false;
                    return;
                }
                transaction.update(doc.ref, {
                    [`freshness.${warnField}`]: admin.firestore.FieldValue.serverTimestamp(),
                });
                shouldSend = true;
            });
        }
        catch (error) {
            functions.logger.error("Transaction failed for warning marker", {
                error,
                listingId: doc.id,
                warnField,
            });
            continue;
        }
        if (!shouldSend)
            continue;
        const hideAt = resolveTimestamp(freshness.hideAt) || upperBound;
        const daysRemaining = Math.max(0, Math.ceil((hideAt.getTime() - now.getTime()) / DAY_MS));
        const result = await sendFreshnessNotification({
            listingId: doc.id,
            listingTitle: listing.title || "Your listing",
            authorId: listing.authorID,
            hideAt,
            type,
            daysRemaining,
        });
        if (!result.emailSent && !result.pushSent) {
            await doc.ref.update({
                "freshness.lastNotifyError": "Both email and push failed",
                "freshness.lastNotifyErrorAt": admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    }
}
async function hideExpiredListings(now) {
    const snapshot = await db
        .collection("listings")
        .where("freshness.enabled", "==", true)
        .where("freshness.exempt", "==", false)
        .where("hidden", "==", false)
        .where("suspended", "==", false)
        .where("freshness.hideAt", "<=", now)
        .get();
    if (snapshot.empty)
        return;
    for (const doc of snapshot.docs) {
        const listing = doc.data();
        const freshness = listing.freshness || {};
        const isExempt = await isListerExempt(listing.authorID);
        if (isExempt)
            continue;
        let shouldNotify = false;
        try {
            await db.runTransaction(async (transaction) => {
                const freshDoc = await transaction.get(doc.ref);
                if (!freshDoc.exists)
                    return;
                const freshData = freshDoc.data() || {};
                const freshFreshness = freshData.freshness || {};
                if (freshData.hidden === true || freshFreshness.hiddenNotifiedAt) {
                    shouldNotify = false;
                    return;
                }
                transaction.update(doc.ref, {
                    hidden: true,
                    "freshness.status": "HIDDEN_EXPIRED",
                    "freshness.hiddenNotifiedAt": admin.firestore.FieldValue.serverTimestamp(),
                });
                shouldNotify = true;
            });
        }
        catch (error) {
            functions.logger.error("Transaction failed for hiding listing", {
                error,
                listingId: doc.id,
            });
            continue;
        }
        if (shouldNotify) {
            const hideAt = resolveTimestamp(freshness.hideAt) || now;
            const result = await sendFreshnessNotification({
                listingId: doc.id,
                listingTitle: listing.title || "Your listing",
                authorId: listing.authorID,
                hideAt,
                type: "hidden",
                daysRemaining: 0,
            });
            if (!result.emailSent && !result.pushSent) {
                await doc.ref.update({
                    "freshness.lastNotifyError": "Both email and push failed",
                    "freshness.lastNotifyErrorAt": admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
    }
}
async function sendFreshnessNotification(params) {
    let emailSent = false;
    let pushSent = false;
    const userSnap = await db.collection("users").doc(params.authorId).get();
    if (!userSnap.exists)
        return { emailSent, pushSent };
    const user = userSnap.data() || {};
    const email = user.email;
    const pushToken = user.pushToken;
    const allowPush = user.settings?.allowPushNotifications !== false;
    const hideAtFormatted = formatDateForTimezone(params.hideAt, "America/Port_of_Spain");
    // Get secrets asynchronously
    const appUrl = await secrets_1.appUrlSecret.value() || "https://caribtap.com";
    const sendgridKey = await secrets_1.sendgridKeySecret.value();
    const deepLink = `caribtap://listing_manage?listingId=${params.listingId}`;
    const webLink = `${appUrl}/l/${params.listingId}`;
    const emailContent = buildEmailTemplate({
        listingTitle: params.listingTitle,
        hideAtFormatted,
        deepLink,
        webLink,
        type: params.type,
    });
    if (email && sendgridKey) {
        try {
            mail_1.default.setApiKey(sendgridKey);
            await mail_1.default.send({
                to: email,
                from: EMAIL_FROM,
                subject: emailContent.subject,
                html: emailContent.html,
            });
            emailSent = true;
        }
        catch (error) {
            functions.logger.error("Error sending listing freshness email", {
                error,
                listingId: params.listingId,
            });
        }
    }
    if (pushToken && allowPush) {
        try {
            const push = buildPushPayload({
                listingTitle: params.listingTitle,
                type: params.type,
                daysRemaining: params.daysRemaining,
            });
            await messaging.send({
                token: pushToken,
                notification: {
                    title: push.title,
                    body: push.body,
                },
                data: {
                    type: "listing_freshness",
                    listingId: params.listingId,
                    action: "RESET",
                },
            });
            pushSent = true;
        }
        catch (error) {
            functions.logger.error("Error sending listing freshness push", {
                error,
                listingId: params.listingId,
            });
        }
    }
    return { emailSent, pushSent };
}
function buildEmailTemplate(params) {
    let subject = "Listing freshness update";
    let headline = "Listing freshness update";
    let message = "";
    if (params.type === "10d") {
        subject = `Your listing will be hidden in 10 days`;
        headline = "10-day listing reminder";
        message =
            "Your listing will be hidden in 10 days unless you reset it.";
    }
    else if (params.type === "1d") {
        subject = `Your listing will be hidden tomorrow`;
        headline = "1-day listing reminder";
        message =
            "Your listing will be hidden tomorrow unless you reset it.";
    }
    else {
        subject = `Your listing has been hidden due to inactivity`;
        headline = "Listing hidden";
        message =
            "Your listing has been hidden due to inactivity. Open My Listings to reactivate.";
    }
    const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #222;">${headline}</h2>
      <p>${message}</p>
      <p><strong>Listing:</strong> ${params.listingTitle}</p>
      <p><strong>Hide date:</strong> ${params.hideAtFormatted}</p>
      <p>
        <a href="${params.deepLink}" style="display: inline-block; padding: 10px 16px; background: #ff5a66; color: white; text-decoration: none; border-radius: 6px;">Open My Listings</a>
      </p>
      <p style="font-size: 12px; color: #666;">If the button does not open the app, use this link: <a href="${params.webLink}">${params.webLink}</a></p>
    </div>
  `;
    return { subject, html };
}
function buildPushPayload(params) {
    if (params.type === "hidden") {
        return {
            title: "Listing hidden",
            body: `"${params.listingTitle}" was hidden due to inactivity.`,
        };
    }
    const daysText = params.type === "1d" ? "tomorrow" : "in 10 days";
    return {
        title: "Listing expiring soon",
        body: `"${params.listingTitle}" will be hidden ${daysText}.`,
    };
}
function formatDateForTimezone(date, timeZone) {
    return new Intl.DateTimeFormat("en-US", {
        timeZone,
        dateStyle: "medium",
        timeStyle: "short",
    }).format(date);
}
function resolveTimestamp(value) {
    if (!value)
        return null;
    if (value instanceof admin.firestore.Timestamp) {
        return value.toDate();
    }
    if (value.toDate) {
        return value.toDate();
    }
    if (typeof value === "number") {
        return new Date(value * 1000);
    }
    return null;
}
function resolveListingCreatedAt(listing, fallback) {
    const createdAt = resolveTimestamp(listing.createdAt);
    if (createdAt)
        return createdAt;
    if (typeof listing.createdAt === "number") {
        return new Date(listing.createdAt * 1000);
    }
    return fallback;
}
function parseFreshnessDays(value) {
    if (typeof value === "number")
        return value;
    const parsed = parseInt(value, 10);
    if (!isNaN(parsed) && parsed > 0)
        return parsed;
    return DEFAULT_FRESHNESS_DAYS;
}
async function isListerExempt(userId) {
    if (!userId)
        return true;
    const userSnap = await db.collection("users").doc(userId).get();
    const data = userSnap.data();
    return data?.listingFreshnessExempt === true;
}
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
// Category-based freshness periods (in days)
const CATEGORY_FRESHNESS = {
    // Short-term
    deals: 30,
    flash_sales: 14,
    events: 14,
    limited_offers: 21,
    seasonal: 30,
    daily_specials: 7,
    market_fresh: 7,
    // Standard
    restaurants: 90,
    services: 90,
    products: 90,
    retail: 90,
    beauty: 90,
    fitness: 90,
    automotive: 90,
    home_services: 90,
    // Long-term
    real_estate: 120,
    rentals: 120,
    property_management: 120,
    professionals: 180,
    healthcare: 120,
    education: 120,
    legal_services: 180,
};
function getFreshnessForCategory(category, customDays) {
    if (customDays && customDays > 0)
        return customDays;
    if (!category)
        return DEFAULT_FRESHNESS_DAYS;
    const normalized = category.toLowerCase().replace(/\s+/g, "_");
    return CATEGORY_FRESHNESS[normalized] || DEFAULT_FRESHNESS_DAYS;
}
// Activity-based auto-refresh
exports.processActivityAutoRefresh = functions.pubsub
    .schedule("every 12 hours")
    .onRun(async () => {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * DAY_MS);
    // Find listings expiring in next 14 days
    const expiringListings = await db
        .collection("listings")
        .where("freshness.enabled", "==", true)
        .where("freshness.exempt", "==", false)
        .where("hidden", "==", false)
        .where("freshness.hideAt", "<=", new Date(now.getTime() + 14 * DAY_MS))
        .where("freshness.hideAt", ">", now)
        .get();
    let autoRefreshed = 0;
    let skipped = 0;
    for (const doc of expiringListings.docs) {
        const listing = doc.data();
        // Check if lister is exempt
        if (await isListerExempt(listing.authorID)) {
            skipped++;
            continue;
        }
        // Calculate activity score
        const activityScore = await calculateActivityScore(doc.id);
        // Check if qualifies for auto-refresh
        if (activityScore.score30Days >= 20 ||
            activityScore.score7Days >= 15 ||
            activityScore.totalBookings >= 3 ||
            (activityScore.totalReviews >= 2 && activityScore.totalMessages >= 5)) {
            // Auto-refresh the listing
            const days = getFreshnessForCategory(listing.category, listing.freshness?.days);
            const newHideAt = admin.firestore.Timestamp.fromMillis(now.getTime() + days * DAY_MS);
            await doc.ref.update({
                "freshness.lastRefreshedAt": admin.firestore.FieldValue.serverTimestamp(),
                "freshness.hideAt": newHideAt,
                "freshness.status": "ACTIVE",
                "freshness.warn10SentAt": admin.firestore.FieldValue.delete(),
                "freshness.warn1SentAt": admin.firestore.FieldValue.delete(),
                "freshness.autoRefreshedAt": admin.firestore.FieldValue.serverTimestamp(),
                "freshness.autoRefreshReason": "customer_engagement",
            });
            // Record auto-refresh event
            await doc.ref.collection("auto_refreshes").add({
                refreshedAt: admin.firestore.FieldValue.serverTimestamp(),
                reason: "customer_engagement",
                activityScore: activityScore.score30Days,
                activityBreakdown: {
                    bookings: activityScore.totalBookings,
                    reviews: activityScore.totalReviews,
                    messages: activityScore.totalMessages,
                    saves: activityScore.totalSaves,
                    shares: activityScore.totalShares,
                },
                notificationSent: false,
            });
            // Send notification to lister
            await sendAutoRefreshNotification(listing, activityScore);
            autoRefreshed++;
        }
        else {
            skipped++;
        }
    }
    functions.logger.info("Activity auto-refresh completed", {
        autoRefreshed,
        skipped,
    });
    return null;
});
async function calculateActivityScore(listingId) {
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * DAY_MS);
    const sevenDaysAgo = new Date(now.getTime() - 7 * DAY_MS);
    const activitiesSnap = await db
        .collection("listings")
        .doc(listingId)
        .collection("activities")
        .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(thirtyDaysAgo))
        .get();
    let score30Days = 0;
    let score7Days = 0;
    let totalBookings = 0;
    let totalReviews = 0;
    let totalMessages = 0;
    let totalSaves = 0;
    let totalShares = 0;
    for (const actDoc of activitiesSnap.docs) {
        const activity = actDoc.data();
        const activityValue = activity.value || 0;
        const activityTime = activity.timestamp.toDate();
        score30Days += activityValue;
        if (activityTime >= sevenDaysAgo) {
            score7Days += activityValue;
        }
        switch (activity.type) {
            case "booking":
                totalBookings++;
                break;
            case "review":
                totalReviews++;
                break;
            case "message":
                totalMessages++;
                break;
            case "save":
                totalSaves++;
                break;
            case "share":
                totalShares++;
                break;
        }
    }
    return {
        score30Days,
        score7Days,
        totalBookings,
        totalReviews,
        totalMessages,
        totalSaves,
        totalShares,
    };
}
async function sendAutoRefreshNotification(listing, activityScore) {
    const userSnap = await db.collection("users").doc(listing.authorID).get();
    if (!userSnap.exists)
        return;
    const user = userSnap.data() || {};
    const email = user.email;
    const pushToken = user.pushToken;
    const allowPush = user.settings?.allowPushNotifications !== false;
    const message = `Great news! Your listing "${listing.title}" was automatically refreshed for another ${listing.freshness?.days || 90} days due to strong customer engagement!`;
    // Send push notification
    if (pushToken && allowPush) {
        try {
            await messaging.send({
                token: pushToken,
                notification: {
                    title: "🎉 Listing Auto-Refreshed!",
                    body: message,
                },
                data: {
                    type: "listing_auto_refresh",
                    listingId: listing.id,
                    activityScore: activityScore.score30Days.toString(),
                },
            });
        }
        catch (error) {
            functions.logger.error("Error sending auto-refresh push", { error });
        }
    }
    // Send email if available
    const sendgridKey = await secrets_1.sendgridKeySecret.value();
    if (email && sendgridKey) {
        try {
            mail_1.default.setApiKey(sendgridKey);
            await mail_1.default.send({
                to: email,
                from: EMAIL_FROM,
                subject: "🎉 Your Listing Was Auto-Refreshed!",
                html: buildAutoRefreshEmail(listing, activityScore),
            });
        }
        catch (error) {
            functions.logger.error("Error sending auto-refresh email", { error });
        }
    }
}
function buildAutoRefreshEmail(listing, activityScore) {
    return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #4CAF50;">🎉 Great News!</h2>
      <p>Your listing <strong>"${listing.title}"</strong> has been automatically refreshed!</p>
      
      <div style="background: #f5f5f5; padding: 16px; border-radius: 8px; margin: 16px 0;">
        <h3 style="margin-top: 0;">Why?</h3>
        <p>Your listing has shown strong customer engagement:</p>
        <ul>
          <li>📊 Activity Score: ${activityScore.score30Days} points</li>
          <li>📅 Bookings: ${activityScore.totalBookings}</li>
          <li>⭐ Reviews: ${activityScore.totalReviews}</li>
          <li>💬 Messages: ${activityScore.totalMessages}</li>
        </ul>
      </div>

      <p>Your listing will now remain active for another <strong>${listing.freshness?.days || 90} days</strong>.</p>
      
      <p style="color: #666; font-size: 14px;">
        Keep up the great work! Active listings with customer engagement are automatically kept fresh.
      </p>
    </div>
  `;
}
