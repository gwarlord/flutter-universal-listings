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
exports.interpretSearchQueryRest = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const generative_ai_1 = require("@google/generative-ai");
const secrets_1 = require("../../common/secrets");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
const getGenAI = async () => {
    const apiKey = await secrets_1.geminiKeySecret.value();
    if (!apiKey) {
        throw new Error("Gemini API key is not configured in Secret Manager.");
    }
    return new generative_ai_1.GoogleGenerativeAI(apiKey);
};
async function validateBearerToken(authHeader) {
    if (!authHeader?.startsWith("Bearer ")) {
        throw new Error("Missing or invalid Authorization header");
    }
    const token = authHeader.substring(7);
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        return decodedToken.uid;
    }
    catch (error) {
        throw new Error(`Invalid authentication token: ${error}`);
    }
}
async function updateRateLimit(userId, tier = "free") {
    // Implementation from previous version
    const tierLimits = {
        free: { daily: 5, monthly: 50 },
        professional: { daily: 50, monthly: 1000 },
        business: { daily: 500, monthly: 10000 },
    };
    const limits = tierLimits[tier] || tierLimits.free;
    const now = new Date();
    const dailyResetTime = new Date(now);
    dailyResetTime.setHours(24, 0, 0, 0);
    const rateLimitRef = db.collection("search_rate_limits").doc(userId);
    await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(rateLimitRef);
        if (!doc.exists) {
            transaction.set(rateLimitRef, {
                userId,
                dailyCount: 1,
                dailyLimit: limits.daily,
                dailyResetTime,
                monthlyCount: 1,
                monthlyLimit: limits.monthly,
                lastSearchAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            const data = doc.data() || {};
            const dailyResetDate = data.dailyResetTime?.toDate() || new Date(0);
            const dailyCount = dailyResetDate > now ? (data.dailyCount || 0) + 1 : 1;
            transaction.update(rateLimitRef, {
                dailyCount,
                dailyLimit: limits.daily,
                dailyResetTime: dailyResetDate > now ? dailyResetDate : dailyResetTime,
                monthlyCount: (data.monthlyCount || 0) + 1,
                lastSearchAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
    });
}
async function logSearchQuery(userId, query, interpretation) {
    try {
        await db.collection("search_analytics").add({
            userId,
            query,
            interpretation,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        functions.logger.warn("Failed to log search query", { userId, error });
    }
}
exports.interpretSearchQueryRest = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
    }
    try {
        const userId = await validateBearerToken(req.headers.authorization);
        const query = (req.body?.query || "").trim();
        if (query.length < 2 || query.length > 500) {
            res.status(400).json({ error: "Query must be 2-500 characters." });
            return;
        }
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
            res.status(404).json({ error: "User not found." });
            return;
        }
        const userData = userDoc.data();
        if (userData.suspended) {
            res.status(403).json({ error: "Your account is suspended." });
            return;
        }
        const rateLimitDoc = await db.collection("search_rate_limits").doc(userId).get();
        if (rateLimitDoc.exists) {
            const data = rateLimitDoc.data();
            if (data.dailyCount >= data.dailyLimit && data.dailyResetTime.toDate() > new Date()) {
                res.status(429).json({ error: "Daily search limit exceeded." });
                return;
            }
        }
        const cacheKey = query.toLowerCase().replace(/\s+/g, "_");
        const cacheDoc = await db.collection("search_query_cache").doc(cacheKey).get();
        if (cacheDoc.exists) {
            const cache = cacheDoc.data();
            if (cache.expiresAt.toDate() > new Date()) {
                functions.logger.info("Cache hit for query", { userId, query });
                res.json({ interpretation: cache.interpretation, cachedFromIndex: true });
                return;
            }
        }
        const genAI = await getGenAI();
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const prompt = `You are a Caribbean business search assistant. Interpret this search query and return structured JSON...`; // Your full prompt here
        const result = await model.generateContent(prompt);
        const responseText = result.response.text();
        let interpretation;
        try {
            const cleanedText = responseText.replace(/```json\n?|```/g, "").trim();
            interpretation = JSON.parse(cleanedText);
        }
        catch (parseError) {
            functions.logger.error("Failed to parse Gemini response", { response: responseText, error: parseError });
            interpretation = {
                intent: "find",
                contentType: "listings",
                filters: {},
                naturalLanguageSummary: query,
                confidence: 0.3,
            };
        }
        if (!interpretation.intent || !interpretation.contentType) {
            res.status(500).json({ error: "AI response was invalid." });
            return;
        }
        const expiresAt = new Date(Date.now() + 3600 * 1000);
        await db.collection("search_query_cache").doc(cacheKey).set({
            interpretation,
            expiresAt,
        });
        await logSearchQuery(userId, query, interpretation);
        await updateRateLimit(userId, userData.subscriptionTier);
        res.json({ interpretation, cachedFromIndex: false });
    }
    catch (error) {
        functions.logger.error("Error in interpretSearchQuery", { error: error.message || error });
        if (error.message?.includes("authentication")) {
            res.status(401).json({ error: "Authentication failed." });
        }
        else {
            res.status(500).json({ error: "An internal error occurred." });
        }
    }
});
