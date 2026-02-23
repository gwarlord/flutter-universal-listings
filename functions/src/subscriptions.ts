import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { google } from "googleapis";
import * as crypto from "crypto";
import {
  appleSharedSecret,
  entitlementTokenKeySecret,
  googleServiceAccountJsonSecret,
} from "./common/secrets";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const PRODUCT_TIER_MAP: Record<string, number> = {
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

function getTierForProduct(productId: string): number {
  return PRODUCT_TIER_MAP[productId] ?? 0;
}

function getSubscriptionTierName(tier: number): string {
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

function isEmulator(): boolean {
  return !!process.env.FUNCTIONS_EMULATOR || !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
}

function normalizeAesKey(keyValue: string): Buffer {
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

  functions.logger.warn(
    "Entitlement key is not 32 bytes after decoding; deriving with SHA-256.",
    {
      base64Len: base64Key.length,
      utf8Len: utf8Key.length,
    }
  );

  return crypto.createHash("sha256").update(keyValue, "utf8").digest();
}

function encryptPayload(payload: string, keyBase64: string) {
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

function hashToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

async function getGoogleAuth() {
  const serviceJson = await googleServiceAccountJsonSecret.value();
  if (serviceJson) {
    const credentials = JSON.parse(serviceJson);
    return new google.auth.GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
  }

  return new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
}

async function verifyAndroidSubscription(
  packageName: string,
  productId: string,
  purchaseToken: string
) {
  const auth = await getGoogleAuth();
  const androidpublisher = google.androidpublisher({
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

async function verifyIosReceipt(receiptData: string): Promise<any> {
  const sharedSecret = await appleSharedSecret.value();
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

  const data = (await response.json()) as any;

  if (data.status === 21007) {
    const sandboxResponse = await fetch(IOS_SANDBOX_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    return (await sandboxResponse.json()) as any;
  }

  return data;
}

function pickLatestReceiptInfo(receiptInfo: any[], productId: string) {
  const matching = receiptInfo.filter((item) => item.product_id === productId);
  if (matching.length === 0) {
    return null;
  }
  matching.sort((a, b) => Number(b.expires_date_ms || 0) - Number(a.expires_date_ms || 0));
  return matching[0];
}

export const verifyPurchase = functions
  .runWith({
    secrets: [appleSharedSecret, entitlementTokenKeySecret, googleServiceAccountJsonSecret],
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
    let expiresAt: Date | null = null;
    let willRenew: boolean | null = null;
    let originalTransactionId: string | null = null;
    let purchaseTokenHash: string | null = null;

    if (isEmulator()) {
      status = "active";
      expiresAt = new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
      willRenew = true;
    } else if (platform === "android") {
      const purchaseToken = data?.purchaseToken;
      const packageName = data?.packageName || DEFAULT_ANDROID_PACKAGE;
      if (!purchaseToken) {
        throw new functions.https.HttpsError("invalid-argument", "Missing purchase token");
      }

      const androidResult = await verifyAndroidSubscription(
        packageName,
        productId,
        purchaseToken
      );

      status = androidResult.status;
      expiresAt = androidResult.expiresAt ?? null;
      willRenew = androidResult.willRenew;
      purchaseTokenHash = hashToken(purchaseToken);

      const key = await entitlementTokenKeySecret.value();
      if (key) {
        const encrypted = encryptPayload(purchaseToken, key);
        await db
          .collection("users")
          .doc(uid)
          .collection("entitlements")
          .doc("subscription")
          .collection("private_tokens")
          .doc("latest")
          .set(
            {
              platform,
              productId,
              encryptedPayload: encrypted.cipherText,
              iv: encrypted.iv,
              tag: encrypted.tag,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      }
    } else if (platform === "ios") {
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
      const renewalMatch = renewalInfo.find(
        (item: any) => item.product_id === productId
      );
      willRenew = renewalMatch?.auto_renew_status === "1";

      const key = await entitlementTokenKeySecret.value();
      if (key) {
        const encrypted = encryptPayload(receiptData, key);
        await db
          .collection("users")
          .doc(uid)
          .collection("entitlements")
          .doc("subscription")
          .collection("private_tokens")
          .doc("latest")
          .set(
            {
              platform,
              productId,
              encryptedPayload: encrypted.cipherText,
              iv: encrypted.iv,
              tag: encrypted.tag,
              originalTransactionId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      }
    } else {
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
      .set(
        {
          subscriptionTier: userTier,
          subscriptionExpiresAt: expiresAt
            ? admin.firestore.Timestamp.fromDate(expiresAt)
            : null,
        },
        { merge: true }
      );

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

export const refreshEntitlementsDaily = functions
  .runWith({ secrets: [appleSharedSecret, entitlementTokenKeySecret, googleServiceAccountJsonSecret] })
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
      const status = data.status as string | undefined;

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
      const platform = tokenData.platform as string | undefined;
      const productId = tokenData.productId as string | undefined;

      if (!platform || !productId) {
        continue;
      }

      const key = await entitlementTokenKeySecret.value();
      if (!key) {
        continue;
      }

      try {
        const iv = Buffer.from(tokenData.iv as string, "base64");
        const tag = Buffer.from(tokenData.tag as string, "base64");
        const encrypted = Buffer.from(tokenData.encryptedPayload as string, "base64");
        const normalizedKey = normalizeAesKey(key);
        const decipher = crypto.createDecipheriv("aes-256-gcm", normalizedKey, iv);
        decipher.setAuthTag(tag);
        const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");

        if (platform === "android") {
          const androidResult = await verifyAndroidSubscription(
            DEFAULT_ANDROID_PACKAGE,
            productId,
            decrypted
          );

          await db
            .collection("users")
            .doc(uid)
            .collection("entitlements")
            .doc("subscription")
            .set(
              {
                status: androidResult.status,
                expiresAt: androidResult.expiresAt
                  ? admin.firestore.Timestamp.fromDate(androidResult.expiresAt)
                  : null,
                willRenew: androidResult.willRenew,
                lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
        } else if (platform === "ios") {
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
            .set(
              {
                status: isActive ? "active" : "expired",
                expiresAt: expiresAtDate
                  ? admin.firestore.Timestamp.fromDate(expiresAtDate)
                  : null,
                lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
        }
      } catch (error) {
        functions.logger.warn("Entitlement refresh failed", { uid, error });
      }
    }

    return null;
  });
