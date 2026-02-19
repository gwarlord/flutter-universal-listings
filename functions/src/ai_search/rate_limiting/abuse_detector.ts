import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

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

export interface AbuseDetectionResult {
  isAbuse: boolean;
  severity: "low" | "medium" | "high";
  categories: string[];
  message: string;
}

/**
 * Detect abuse patterns in search queries
 * Called by interpretSearchQuery before processing
 */
export async function detectAbuse(
  query: string,
  userId: string
): Promise<AbuseDetectionResult> {
  const normalizedQuery = query.toLowerCase();
  const result: AbuseDetectionResult = {
    isAbuse: false,
    severity: "low",
    categories: [],
    message: "",
  };

  // Check for spam keywords
  const spamMatches = SPAM_KEYWORDS.filter((keyword) =>
    normalizedQuery.includes(keyword)
  );
  if (spamMatches.length > 0) {
    result.categories.push("spam");
    result.severity = "high";
  }

  // Check for prompt injection
  const injectionMatches = PROMPT_INJECTION_KEYWORDS.filter((keyword) =>
    normalizedQuery.includes(keyword)
  );
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
    } else if (result.severity === "medium") {
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
async function logAbuseAttempt(
  userId: string,
  query: string,
  result: AbuseDetectionResult
): Promise<void> {
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
  } catch (error) {
    functions.logger.warn("Failed to log abuse attempt", { error });
  }
}

/**
 * Get count of abuse attempts by user in last 24 hours
 */
async function getRecentAbuseCount(userId: string): Promise<number> {
  try {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const snapshot = await db
      .collection("abuse_reports")
      .where("userId", "==", userId)
      .where("timestamp", ">=", oneDayAgo)
      .get();

    return snapshot.size;
  } catch (error) {
    functions.logger.warn("Failed to get abuse count", { error });
    return 0;
  }
}

/**
 * Suspend user for repeated abuse
 */
async function suspendUserForAbuse(userId: string): Promise<void> {
  try {
    await db.collection("users").doc(userId).update({
      suspended: true,
      suspensionReason: "Abusive behavior in AI search",
      suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log suspension
    functions.logger.warn("User suspended for abuse", { userId });
  } catch (error) {
    functions.logger.error("Failed to suspend user", { error, userId });
  }
}

/**
 * Sanitize query by removing or escaping dangerous content
 * Used as fallback after abuse detection
 */
export function sanitizeQuery(query: string): string {
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
