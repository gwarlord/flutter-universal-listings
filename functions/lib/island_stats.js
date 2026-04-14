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
exports.getIslandStats = void 0;
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
function normalizeCountryId(value, fallbackIsoCode) {
    if (typeof value !== "string")
        return fallbackIsoCode.toLowerCase();
    const normalized = value.trim().toLowerCase();
    return normalized.length > 0 ? normalized : fallbackIsoCode.toLowerCase();
}
exports.getIslandStats = functions.https.onCall(async (data) => {
    const countriesInput = (data?.countries ?? []);
    if (!Array.isArray(countriesInput) || countriesInput.length === 0) {
        throw new functions.https.HttpsError("invalid-argument", "countries is required and must be a non-empty array");
    }
    if (countriesInput.length > 80) {
        throw new functions.https.HttpsError("invalid-argument", "countries cannot exceed 80 items");
    }
    try {
        const statsWithUserIds = await Promise.all(countriesInput.map(async (country) => {
            const isoCode = normalizeIsoCode(country.isoCode);
            if (!isoCode) {
                throw new functions.https.HttpsError("invalid-argument", "Each country must include a valid 2-letter isoCode");
            }
            const [listingsAgg, usersHomeSnap, usersCountrySnap] = await Promise.all([
                db.collection("listings").where("countryCode", "==", isoCode).count().get(),
                db.collection("users").where("homeCountry", "==", isoCode).get(),
                db.collection("users").where("countryCode", "==", isoCode).get(),
            ]);
            const userIds = new Set();
            usersHomeSnap.docs.forEach((doc) => userIds.add(doc.id));
            usersCountrySnap.docs.forEach((doc) => userIds.add(doc.id));
            const usersCount = userIds.size;
            return {
                id: normalizeCountryId(country.id, isoCode),
                isoCode,
                name: typeof country.name === "string" ? country.name : isoCode,
                listingsCount: listingsAgg.data().count,
                usersCount,
                _userIds: userIds,
            };
        }));
        const caribbeanUserIds = new Set();
        const stats = statsWithUserIds.map((item) => {
            item._userIds.forEach((id) => caribbeanUserIds.add(id));
            const { _userIds, ...publicItem } = item;
            return publicItem;
        });
        const totalUsersAgg = await db.collection("users").count().get();
        const totalUsers = totalUsersAgg.data().count;
        const visitorsOutsideCaribbeanUsers = Math.max(0, totalUsers - caribbeanUserIds.size);
        return {
            updatedAt: admin.firestore.Timestamp.now().toMillis(),
            stats,
            visitorsOutsideCaribbeanUsers,
        };
    }
    catch (error) {
        functions.logger.error("Failed to aggregate island stats", error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "Could not load island statistics");
    }
});
