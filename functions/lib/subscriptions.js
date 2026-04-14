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
exports.refreshEntitlementsDaily = exports.getProfessionalTrialConfig = exports.claimProfessionalTrial = exports.verifyPurchase = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const googleapis_1 = require("googleapis");
const crypto = __importStar(require("crypto"));
const secrets_1 = require("./common/secrets");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const PRODUCT_TIER_MAP = {
    caribtap_pro_t1_monthly: 1,
    caribtap_pro_t1_annual: 1,
    caribtap_pro_t2_monthly: 2,
    caribtap_pro_t2_annual: 2,
    caribtap_pro_t3_monthly: 3,
    caribtap_pro_t3_annual: 3,
};
const DEFAULT_ANDROID_PACKAGE = "com.caribtap.instaflutter.android";
const IOS_VERIFY_URL = "https://buy.itunes.apple.com/verifyReceipt";
const IOS_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const PROFESSIONAL_TRIAL_PRODUCT_ID = "trial_professional_30d";
const PROFESSIONAL_TRIAL_DAYS = 30;
const SUBSCRIPTION_CONFIG_COLLECTION = "settings";
const SUBSCRIPTION_CONFIG_DOC = "subscription_config";
function getTierForProduct(productId) {
    return PRODUCT_TIER_MAP[productId] ?? 0;
}
function getSubscriptionTierName(tier) {
    if (tier >= 3) {
        return "premium";
    }
    if (tier >= 2) {
        return "professional";
    }
    if (tier >= 1) {
        return "professional";
    }
    return "free";
}
function isEmulator() {
    return !!process.env.FUNCTIONS_EMULATOR || !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
}
function addDays(date, days) {
    return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}
function isActiveEntitlementSnapshot(data) {
    if (!data) {
        return false;
    }
    const status = data.status;
    const tier = Number(data.tier || 0);
    const expiresAt = data.expiresAt?.toDate?.();
    const now = new Date();
    if (status !== "active" || tier <= 0) {
        return false;
    }
    if (expiresAt && expiresAt <= now) {
        return false;
    }
    return true;
}
async function fetchProfessionalTrialConfig() {
    const doc = await db
        .collection(SUBSCRIPTION_CONFIG_COLLECTION)
        .doc(SUBSCRIPTION_CONFIG_DOC)
        .get();
    if (!doc.exists) {
        return {
            enabled: true,
            requiresPhoneVerified: false,
        };
    }
    const data = doc.data() || {};
    return {
        enabled: data.professionalTrialEnabled !== false,
        requiresPhoneVerified: data.professionalTrialRequiresPhoneVerified === true,
    };
}
function normalizeAesKey(keyValue) {
    const base64Key = Buffer.from(keyValue, "base64");
    if (base64Key.length === 32) {
        return base64Key;
    }
    if (/^[0-9a-fA-F]+$/.test(keyValue) && keyValue.length === 64) {
        return Buffer.from(keyValue, "hex");
    }
    const utf8Key = Buffer.from(keyValue, "utf8");
    if (utf8Key.length === 32) {
        return utf8Key;
    }
    functions.logger.warn("Entitlement key is not 32 bytes after decoding; deriving with SHA-256.", {
        base64Len: base64Key.length,
        utf8Len: utf8Key.length,
    });
    return crypto.createHash("sha256").update(keyValue, "utf8").digest();
}
function encryptPayload(payload, keyBase64) {
    const key = normalizeAesKey(keyBase64);
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
    const encrypted = Buffer.concat([cipher.update(payload, "utf8"), cipher.final()]);
    const tag = cipher.getAuthTag();
    return {
        cipherText: encrypted.toString("base64"),
        iv: iv.toString("base64"),
        tag: tag.toString("base64"),
    };
}
function hashToken(token) {
    return crypto.createHash("sha256").update(token).digest("hex");
}
async function getGoogleAuth() {
    const serviceJson = await secrets_1.googleServiceAccountJsonSecret.value();
    if (serviceJson) {
        const credentials = JSON.parse(serviceJson);
        return new googleapis_1.google.auth.GoogleAuth({
            credentials,
            scopes: ["https://www.googleapis.com/auth/androidpublisher"],
        });
    }
    return new googleapis_1.google.auth.GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
}
async function verifyAndroidSubscription(packageName, productId, purchaseToken) {
    const auth = await getGoogleAuth();
    const androidpublisher = googleapis_1.google.androidpublisher({
        version: "v3",
        auth,
    });
    const response = await androidpublisher.purchases.subscriptions.get({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
    });
    const data = response.data;
    const expiryMillis = data.expiryTimeMillis ? Number(data.expiryTimeMillis) : null;
    const expiresAt = expiryMillis ? new Date(expiryMillis) : null;
    const now = new Date();
    const isActive = expiresAt ? expiresAt > now : true;
    return {
        status: isActive ? "active" : "expired",
        expiresAt,
        willRenew: data.autoRenewing ?? null,
        cancelReason: data.cancelReason ?? null,
        orderId: data.orderId ?? null,
    };
}
async function verifyIosReceipt(receiptData) {
    const sharedSecret = await secrets_1.appleSharedSecret.value();
    const payload = {
        "receipt-data": receiptData,
        password: sharedSecret || undefined,
        "exclude-old-transactions": true,
    };
    const response = await fetch(IOS_VERIFY_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    const data = (await response.json());
    if (data.status === 21007) {
        const sandboxResponse = await fetch(IOS_SANDBOX_URL, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload),
        });
        return (await sandboxResponse.json());
    }
    return data;
}
function pickLatestReceiptInfo(receiptInfo, productId) {
    const matching = receiptInfo.filter((item) => item.product_id === productId);
    if (matching.length === 0) {
        return null;
    }
    matching.sort((a, b) => Number(b.expires_date_ms || 0) - Number(a.expires_date_ms || 0));
    return matching[0];
}
exports.verifyPurchase = functions
    .runWith({
    secrets: [secrets_1.appleSharedSecret, secrets_1.entitlementTokenKeySecret, secrets_1.googleServiceAccountJsonSecret],
})
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const uid = context.auth.uid;
    const platform = data?.platform;
    const productId = data?.productId;
    const tier = getTierForProduct(productId);
    if (!platform || !productId || tier === 0) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid purchase payload");
    }
    let status = "inactive";
    let expiresAt = null;
    let willRenew = null;
    let originalTransactionId = null;
    let purchaseTokenHash = null;
    if (isEmulator()) {
        status = "active";
        expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
        willRenew = true;
    }
    else if (platform === "android") {
        const purchaseToken = data?.purchaseToken;
        const packageName = data?.packageName || DEFAULT_ANDROID_PACKAGE;
        if (!purchaseToken) {
            throw new functions.https.HttpsError("invalid-argument", "Missing purchase token");
        }
        const androidResult = await verifyAndroidSubscription(packageName, productId, purchaseToken);
        status = androidResult.status;
        expiresAt = androidResult.expiresAt ?? null;
        willRenew = androidResult.willRenew;
        purchaseTokenHash = hashToken(purchaseToken);
        const key = await secrets_1.entitlementTokenKeySecret.value();
        if (key) {
            const encrypted = encryptPayload(purchaseToken, key);
            await db
                .collection("users")
                .doc(uid)
                .collection("entitlements")
                .doc("subscription")
                .collection("private_tokens")
                .doc("latest")
                .set({
                platform,
                productId,
                encryptedPayload: encrypted.cipherText,
                iv: encrypted.iv,
                tag: encrypted.tag,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    }
    else if (platform === "ios") {
        const receiptData = data?.receiptData;
        if (!receiptData) {
            throw new functions.https.HttpsError("invalid-argument", "Missing receipt data");
        }
        const iosResponse = await verifyIosReceipt(receiptData);
        if (iosResponse.status !== 0) {
            throw new functions.https.HttpsError("failed-precondition", "Receipt verification failed");
        }
        const receiptInfo = iosResponse.latest_receipt_info || [];
        const latest = pickLatestReceiptInfo(receiptInfo, productId);
        const expiryMs = latest?.expires_date_ms ? Number(latest.expires_date_ms) : null;
        expiresAt = expiryMs ? new Date(expiryMs) : null;
        const now = new Date();
        status = expiresAt && expiresAt > now ? "active" : "expired";
        originalTransactionId = latest?.original_transaction_id ?? null;
        const renewalInfo = iosResponse.pending_renewal_info || [];
        const renewalMatch = renewalInfo.find((item) => item.product_id === productId);
        willRenew = renewalMatch?.auto_renew_status === "1";
        const key = await secrets_1.entitlementTokenKeySecret.value();
        if (key) {
            const encrypted = encryptPayload(receiptData, key);
            await db
                .collection("users")
                .doc(uid)
                .collection("entitlements")
                .doc("subscription")
                .collection("private_tokens")
                .doc("latest")
                .set({
                platform,
                productId,
                encryptedPayload: encrypted.cipherText,
                iv: encrypted.iv,
                tag: encrypted.tag,
                originalTransactionId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    }
    else {
        throw new functions.https.HttpsError("invalid-argument", "Unsupported platform");
    }
    const entitlementDoc = {
        platform,
        productId,
        tier,
        status,
        expiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
        willRenew,
        lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        originalTransactionId,
        purchaseTokenHash,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    await db
        .collection("users")
        .doc(uid)
        .collection("entitlements")
        .doc("subscription")
        .set(entitlementDoc, { merge: true });
    const userTier = status === "active" || expiresAt
        ? getSubscriptionTierName(tier)
        : "free";
    await db
        .collection("users")
        .doc(uid)
        .set({
        subscriptionTier: userTier,
        subscriptionExpiresAt: expiresAt
            ? admin.firestore.Timestamp.fromDate(expiresAt)
            : null,
    }, { merge: true });
    await db
        .collection("users")
        .doc(uid)
        .collection("entitlements")
        .doc("subscription")
        .collection("purchases")
        .add({
        platform,
        productId,
        tier,
        status,
        expiresAt: entitlementDoc.expiresAt,
        willRenew,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return {
        tier,
        status,
        expiresAt: expiresAt ? expiresAt.toISOString() : null,
        willRenew,
    };
});
exports.claimProfessionalTrial = functions.https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const uid = context.auth.uid;
    const trialConfig = await fetchProfessionalTrialConfig();
    if (!trialConfig.enabled) {
        throw new functions.https.HttpsError("failed-precondition", "Free trial is not available right now");
    }
    const userRef = db.collection("users").doc(uid);
    const entitlementRef = userRef.collection("entitlements").doc("subscription");
    const purchaseRef = entitlementRef.collection("purchases").doc();
    const auditRef = db.collection("subscription_trial_claims").doc();
    const now = new Date();
    const expiresAt = addDays(now, PROFESSIONAL_TRIAL_DAYS);
    const expiresAtTs = admin.firestore.Timestamp.fromDate(expiresAt);
    let finalTier = 0;
    let finalStatus = "inactive";
    await db.runTransaction(async (transaction) => {
        const [userSnap, entitlementSnap] = await Promise.all([
            transaction.get(userRef),
            transaction.get(entitlementRef),
        ]);
        if (!userSnap.exists) {
            throw new functions.https.HttpsError("failed-precondition", "User profile not found");
        }
        const userData = userSnap.data() || {};
        const entitlementData = entitlementSnap.data();
        const profileTier = (userData.subscriptionTier || "free").toString().trim().toLowerCase();
        const profileExpiresAt = userData.subscriptionExpiresAt?.toDate?.();
        const profileActive = profileTier !== "free" && (!profileExpiresAt || profileExpiresAt > now);
        const entitlementActive = isActiveEntitlementSnapshot(entitlementData);
        if (userData.suspended === true) {
            throw new functions.https.HttpsError("permission-denied", "Suspended accounts are not eligible for the free trial");
        }
        if (trialConfig.requiresPhoneVerified && userData.phoneVerified !== true) {
            throw new functions.https.HttpsError("failed-precondition", "Phone verification is required to claim this trial");
        }
        if (userData.trialClaimedAt || userData.trialProductId) {
            throw new functions.https.HttpsError("already-exists", "Free trial already claimed");
        }
        if (profileActive || entitlementActive) {
            throw new functions.https.HttpsError("failed-precondition", "Account already has an active subscription");
        }
        finalTier = 2;
        finalStatus = "active";
        transaction.set(userRef, {
            subscriptionTier: "professional",
            isSubscriptionActive: true,
            subscriptionExpiresAt: expiresAtTs,
            trialClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
            trialExpiresAt: expiresAtTs,
            trialProductId: PROFESSIONAL_TRIAL_PRODUCT_ID,
            trialSource: "self_claim",
            trialTier: "professional",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(entitlementRef, {
            platform: "trial_promo",
            productId: PROFESSIONAL_TRIAL_PRODUCT_ID,
            tier: 2,
            status: "active",
            expiresAt: expiresAtTs,
            willRenew: false,
            grantSource: "self_claim",
            trialClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        transaction.set(purchaseRef, {
            platform: "trial_promo",
            productId: PROFESSIONAL_TRIAL_PRODUCT_ID,
            tier: 2,
            status: "active",
            expiresAt: expiresAtTs,
            willRenew: false,
            source: "trial_claim",
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.set(auditRef, {
            uid,
            email: (userData.email || "").toString().toLowerCase(),
            phoneNumber: (userData.phoneNumber || "").toString(),
            phoneVerified: userData.phoneVerified === true,
            source: "self_claim",
            trialProductId: PROFESSIONAL_TRIAL_PRODUCT_ID,
            tier: "professional",
            claimedAt: admin.firestore.FieldValue.serverTimestamp(),
            expiresAt: expiresAtTs,
            status: "active",
        });
    });
    try {
        const listingDocs = await db.collection("listings").where("authorID", "==", uid).get();
        if (!listingDocs.empty) {
            const batch = db.batch();
            for (const doc of listingDocs.docs) {
                batch.update(doc.ref, {
                    listerTierSnapshot: "professional",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            await batch.commit();
        }
    }
    catch (error) {
        functions.logger.warn("Trial claim listing snapshot update failed", { uid, error });
    }
    return {
        tier: finalTier,
        status: finalStatus,
        productId: PROFESSIONAL_TRIAL_PRODUCT_ID,
        expiresAt: expiresAt.toISOString(),
    };
});
exports.getProfessionalTrialConfig = functions.https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const config = await fetchProfessionalTrialConfig();
    return {
        enabled: config.enabled,
        requiresPhoneVerified: config.requiresPhoneVerified,
        trialDays: PROFESSIONAL_TRIAL_DAYS,
        tier: "professional",
    };
});
exports.refreshEntitlementsDaily = functions
    .runWith({ secrets: [secrets_1.appleSharedSecret, secrets_1.entitlementTokenKeySecret, secrets_1.googleServiceAccountJsonSecret] })
    .pubsub.schedule("every 24 hours")
    .onRun(async () => {
    const snapshot = await db.collectionGroup("entitlements").get();
    const now = new Date();
    for (const doc of snapshot.docs) {
        if (doc.id !== "subscription") {
            continue;
        }
        const uid = doc.ref.parent.parent?.id;
        if (!uid) {
            continue;
        }
        const data = doc.data();
        const expiresAt = data.expiresAt?.toDate?.() ?? null;
        const status = data.status;
        if (status !== "active" && status !== "canceled") {
            continue;
        }
        if (expiresAt && expiresAt > new Date(now.getTime() + 1000 * 60 * 60 * 24 * 7)) {
            continue;
        }
        const tokenDoc = await db
            .collection("users")
            .doc(uid)
            .collection("entitlements")
            .doc("subscription")
            .collection("private_tokens")
            .doc("latest")
            .get();
        if (!tokenDoc.exists) {
            continue;
        }
        const tokenData = tokenDoc.data() || {};
        const platform = tokenData.platform;
        const productId = tokenData.productId;
        if (!platform || !productId) {
            continue;
        }
        const key = await secrets_1.entitlementTokenKeySecret.value();
        if (!key) {
            continue;
        }
        try {
            const iv = Buffer.from(tokenData.iv, "base64");
            const tag = Buffer.from(tokenData.tag, "base64");
            const encrypted = Buffer.from(tokenData.encryptedPayload, "base64");
            const normalizedKey = normalizeAesKey(key);
            const decipher = crypto.createDecipheriv("aes-256-gcm", normalizedKey, iv);
            decipher.setAuthTag(tag);
            const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
            if (platform === "android") {
                const androidResult = await verifyAndroidSubscription(DEFAULT_ANDROID_PACKAGE, productId, decrypted);
                await db
                    .collection("users")
                    .doc(uid)
                    .collection("entitlements")
                    .doc("subscription")
                    .set({
                    status: androidResult.status,
                    expiresAt: androidResult.expiresAt
                        ? admin.firestore.Timestamp.fromDate(androidResult.expiresAt)
                        : null,
                    willRenew: androidResult.willRenew,
                    lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            else if (platform === "ios") {
                const iosResponse = await verifyIosReceipt(decrypted);
                if (iosResponse.status !== 0) {
                    continue;
                }
                const receiptInfo = iosResponse.latest_receipt_info || [];
                const latest = pickLatestReceiptInfo(receiptInfo, productId);
                const expiryMs = latest?.expires_date_ms ? Number(latest.expires_date_ms) : null;
                const expiresAtDate = expiryMs ? new Date(expiryMs) : null;
                const isActive = expiresAtDate ? expiresAtDate > new Date() : true;
                await db
                    .collection("users")
                    .doc(uid)
                    .collection("entitlements")
                    .doc("subscription")
                    .set({
                    status: isActive ? "active" : "expired",
                    expiresAt: expiresAtDate
                        ? admin.firestore.Timestamp.fromDate(expiresAtDate)
                        : null,
                    lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
        catch (error) {
            functions.logger.warn("Entitlement refresh failed", { uid, error });
        }
    }
    return null;
});
