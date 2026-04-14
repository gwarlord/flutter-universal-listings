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
exports.backfillUserCountryFields = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
function normalizeIsoCode(value) {
    if (typeof value !== "string")
        return null;
    const normalized = value.trim().toUpperCase();
    if (!/^[A-Z]{2}$/.test(normalized))
        return null;
    return normalized;
}
exports.backfillUserCountryFields = functions.https.onCall(async (_data, context) => {
    if (!context.auth?.uid) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication is required");
    }
    const callerDoc = await db.collection("users").doc(context.auth.uid).get();
    const isAdmin = callerDoc.exists && callerDoc.data()?.isAdmin === true;
    if (!isAdmin) {
        throw new functions.https.HttpsError("permission-denied", "Admin access is required");
    }
    const usersSnap = await db.collection("users").get();
    let scanned = 0;
    let updated = 0;
    let skipped = 0;
    const batch = db.batch();
    usersSnap.docs.forEach((doc) => {
        scanned += 1;
        const data = doc.data() || {};
        const currentHome = normalizeIsoCode(data.homeCountry);
        const currentCountry = normalizeIsoCode(data.countryCode);
        const nextHome = currentHome ?? currentCountry;
        const nextCountry = currentCountry ?? currentHome;
        const patch = {};
        if (nextHome && nextHome !== data.homeCountry) {
            patch.homeCountry = nextHome;
        }
        if (nextCountry && nextCountry !== data.countryCode) {
            patch.countryCode = nextCountry;
        }
        if (Object.keys(patch).length === 0) {
            skipped += 1;
            return;
        }
        updated += 1;
        batch.set(doc.ref, patch, { merge: true });
    });
    if (updated > 0) {
        await batch.commit();
    }
    functions.logger.info("User country backfill completed", {
        scanned,
        updated,
        skipped,
        requestedBy: context.auth.uid,
    });
    return {
        scanned,
        updated,
        skipped,
    };
});
