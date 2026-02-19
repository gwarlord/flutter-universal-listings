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
exports.detectAbuse = detectAbuse;
exports.sanitizeQuery = sanitizeQuery;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
// List of common abuse patterns and keywords
const SPAM_KEYWORDS = [
    "click here",
    "buy now",
    "winner",
    "congratulations",
    "claim prize",
    "free money",
    "verify account",
    "confirm identity",
    "update payment",
];
const PROMPT_INJECTION_KEYWORDS = [
    "ignore",
    "disregard",
    "forget",
    "system prompt",
    "instructions",
    "admin",
    "override",
    "forget all previous",
    "start new conversation",
];
const PROFANITY_PATTERN = /(\*{2,}|fuck|shit|damn|hell|asshole)/gi;
/**
 * Detect abuse patterns in search queries
 * Called by interpretSearchQuery before processing
 */
async function detectAbuse(query, userId) {
    const normalizedQuery = query.toLowerCase();
    const result = {
        isAbuse: false,
        severity: "low",
        categories: [],
        message: "",
    };
    // Check for spam keywords
    const spamMatches = SPAM_KEYWORDS.filter((keyword) => normalizedQuery.includes(keyword));
    if (spamMatches.length > 0) {
        result.categories.push("spam");
        result.severity = "high";
    }
    // Check for prompt injection
    const injectionMatches = PROMPT_INJECTION_KEYWORDS.filter((keyword) => normalizedQuery.includes(keyword));
    if (injectionMatches.length > 0) {
        result.categories.push("prompt_injection");
        result.severity = "high";
    }
    // Check for excessive URLs or suspicious patterns
    const urlCount = (query.match(/https?:\/\//gi) || []).length;
    if (urlCount > 2) {
        result.categories.push("suspicious_urls");
        result.severity = "medium";
    }
    // Check for profanity
    if (PROFANITY_PATTERN.test(query)) {
        result.categories.push("profanity");
        result.severity = "medium";
    }
    // Check for character encoding abuse (repeated special chars)
    if (/([!@#$%^&*]){5,}/.test(query)) {
        result.categories.push("character_abuse");
        result.severity = "medium";
    }
    // Check for extremely long queries (potential attack)
    if (query.length > 1000) {
        result.categories.push("excessive_length");
        result.severity = "medium";
    }
    // Check for repeated characters (spam pattern)
    if (/(.)\1{10,}/.test(query)) {
        result.categories.push("repeated_characters");
        result.severity = "medium";
    }
    // Determine if it's abuse
    result.isAbuse = result.categories.length > 0;
    if (result.isAbuse) {
        if (result.severity === "high") {
            result.message = "Your search appears to violate our policies.";
        }
        else if (result.severity === "medium") {
            result.message =
                "Your search contains suspicious content. Please rephrase.";
        }
        // Log the abuse attempt
        await logAbuseAttempt(userId, query, result);
        // Check if user should be warned or suspended
        const abuseCount = await getRecentAbuseCount(userId);
        if (abuseCount >= 5) {
            await suspendUserForAbuse(userId);
            result.message =
                "Your account has been suspended for violating our policies.";
        }
    }
    return result;
}
/**
 * Log abuse attempt for later review
 */
async function logAbuseAttempt(userId, query, result) {
    try {
        await db.collection("abuse_reports").add({
            userId,
            query,
            categories: result.categories,
            severity: result.severity,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            reviewed: false,
            action: null,
        });
    }
    catch (error) {
        functions.logger.warn("Failed to log abuse attempt", { error });
    }
}
/**
 * Get count of abuse attempts by user in last 24 hours
 */
async function getRecentAbuseCount(userId) {
    try {
        const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
        const snapshot = await db
            .collection("abuse_reports")
            .where("userId", "==", userId)
            .where("timestamp", ">=", oneDayAgo)
            .get();
        return snapshot.size;
    }
    catch (error) {
        functions.logger.warn("Failed to get abuse count", { error });
        return 0;
    }
}
/**
 * Suspend user for repeated abuse
 */
async function suspendUserForAbuse(userId) {
    try {
        await db.collection("users").doc(userId).update({
            suspended: true,
            suspensionReason: "Abusive behavior in AI search",
            suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Log suspension
        functions.logger.warn("User suspended for abuse", { userId });
    }
    catch (error) {
        functions.logger.error("Failed to suspend user", { error, userId });
    }
}
/**
 * Sanitize query by removing or escaping dangerous content
 * Used as fallback after abuse detection
 */
function sanitizeQuery(query) {
    // Remove URLs
    let sanitized = query.replace(/https?:\/\/[^\s]+/gi, "[URL REMOVED]");
    // Replace profanity with asterisks
    sanitized = sanitized.replace(PROFANITY_PATTERN, "***");
    // Remove excessive special characters
    sanitized = sanitized.replace(/([!@#$%^&*]){5,}/g, "$1$1");
    // Limit repeated characters
    sanitized = sanitized.replace(/(.)\1{10,}/g, "$1$1$1");
    // Trim if too long
    if (sanitized.length > 500) {
        sanitized = sanitized.substring(0, 500).trim();
    }
    return sanitized;
}
