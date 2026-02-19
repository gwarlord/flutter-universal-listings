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
exports.checkRateLimit = void 0;
exports.getRateLimitStatus = getRateLimitStatus;
exports.incrementRateLimit = incrementRateLimit;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Check and enforce rate limits for a user
 * Can be called independently to get status, or automatically by AI search functions
 *
 * Input: (none - uses authenticated user context)
 * Output: { allowed: boolean, status: RateLimitStatus, message?: string }
 */
exports.checkRateLimit = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const userId = context.auth.uid;
    try {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found");
        }
        const userData = userDoc.data();
        const tier = userData?.subscriptionTier || "free";
        const status = await getRateLimitStatus(userId, tier);
        const allowed = status.dailyRemaining > 0 && status.monthlyRemaining > 0;
        return {
            allowed,
            status: {
                ...status,
                nextReset: status.nextReset.getTime(), // Convert to timestamp for JSON
            },
            message: allowed
                ? `You have ${status.dailyRemaining} searches remaining today`
                : `You have reached your daily limit of ${status.dailyLimit} searches. Upgrade to continue.`,
        };
    }
    catch (error) {
        functions.logger.error("Error checking rate limit", {
            userId,
            error: error.message,
        });
        if (error.code && error.code.startsWith("functions/")) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "Error checking rate limit");
    }
});
/**
 * Get current rate limit status for a user
 */
async function getRateLimitStatus(userId, tier) {
    const tierLimits = {
        free: { daily: 5, monthly: 50 },
        professional: { daily: 50, monthly: 1000 },
        business: { daily: 500, monthly: 10000 },
    };
    const limits = tierLimits[tier] || tierLimits.free;
    const now = new Date();
    const rateLimitRef = db.collection("search_rate_limits").doc(userId);
    const doc = await rateLimitRef.get();
    if (!doc.exists) {
        // First time user or just reset
        const dailyResetTime = new Date(now);
        dailyResetTime.setHours(24, 0, 0, 0);
        return {
            dailyRemaining: limits.daily,
            dailyLimit: limits.daily,
            monthlyRemaining: limits.monthly,
            monthlyLimit: limits.monthly,
            tier,
            nextReset: dailyResetTime,
        };
    }
    const data = doc.data() || {};
    const dailyResetDate = new Date(data.dailyResetTime?.toDate?.() || data.dailyResetTime);
    const monthlyResetDate = new Date(data.monthlyResetTime?.toDate?.() || data.monthlyResetTime);
    // Check if daily/monthly limits need reset
    const dailyCount = dailyResetDate.getTime() > now.getTime() ? data.dailyCount || 0 : 0;
    const monthlyCount = monthlyResetDate.getTime() > now.getTime() ? data.monthlyCount || 0 : 0;
    const dailyRemaining = Math.max(0, limits.daily - dailyCount);
    const monthlyRemaining = Math.max(0, limits.monthly - monthlyCount);
    return {
        dailyRemaining,
        dailyLimit: limits.daily,
        monthlyRemaining,
        monthlyLimit: limits.monthly,
        tier,
        nextReset: dailyResetDate.getTime() > now.getTime() ? dailyResetDate : new Date(now.setHours(24, 0, 0, 0)),
    };
}
/**
 * Increment rate limit counters (called after each search)
 */
async function incrementRateLimit(userId, tier) {
    const tierLimits = {
        free: { daily: 5, monthly: 50 },
        professional: { daily: 50, monthly: 1000 },
        business: { daily: 500, monthly: 10000 },
    };
    const limits = tierLimits[tier] || tierLimits.free;
    const now = new Date();
    const dailyResetTime = new Date(now);
    dailyResetTime.setHours(24, 0, 0, 0);
    const monthlyResetDate = new Date(now);
    monthlyResetDate.setDate(1);
    monthlyResetDate.setHours(0, 0, 0, 0);
    const rateLimitRef = db.collection("search_rate_limits").doc(userId);
    return db.runTransaction(async (transaction) => {
        const doc = await transaction.get(rateLimitRef);
        if (!doc.exists) {
            transaction.set(rateLimitRef, {
                userId,
                tier,
                dailyCount: 1,
                dailyLimit: limits.daily,
                dailyResetTime,
                monthlyCount: 1,
                monthlyLimit: limits.monthly,
                monthlyResetTime: monthlyResetDate,
                lastSearchAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            const data = doc.data() || {};
            const existingDailyReset = new Date(data.dailyResetTime?.toDate?.() || data.dailyResetTime);
            const existingMonthlyReset = new Date(data.monthlyResetTime?.toDate?.() || data.monthlyResetTime);
            const shouldResetDaily = existingDailyReset.getTime() <= now.getTime();
            const shouldResetMonthly = existingMonthlyReset.getTime() <= now.getTime();
            const newDailyCount = shouldResetDaily ? 1 : (data.dailyCount || 0) + 1;
            const newMonthlyCount = shouldResetMonthly
                ? 1
                : (data.monthlyCount || 0) + 1;
            const newDailyReset = shouldResetDaily
                ? new Date(now.getTime() + 24 * 60 * 60 * 1000)
                : existingDailyReset;
            const newMonthlyReset = shouldResetMonthly
                ? new Date(now.getFullYear(), now.getMonth() + 1, 1)
                : existingMonthlyReset;
            transaction.update(rateLimitRef, {
                tier,
                dailyCount: newDailyCount,
                dailyLimit: limits.daily,
                dailyResetTime: newDailyReset,
                monthlyCount: newMonthlyCount,
                monthlyLimit: limits.monthly,
                monthlyResetTime: newMonthlyReset,
                lastSearchAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    });
}
