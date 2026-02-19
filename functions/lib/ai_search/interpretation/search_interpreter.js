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
exports.processSearchQuery = void 0;
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
        throw new Error("Gemini API key is not configured.");
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
exports.processSearchQuery = functions.https.onRequest(async (req, res) => {
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
        const genAI = await getGenAI();
        const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
        const prompt = `You are a Caribbean business search assistant. Interpret this search query: "${query}" and return structured JSON...`; // Your full prompt
        const result = await model.generateContent(prompt);
        const responseText = result.response.text();
        let interpretation;
        try {
            const cleanedText = responseText.replace(/```json\n?|```/g, "").trim();
            interpretation = JSON.parse(cleanedText);
        }
        catch (parseError) {
            functions.logger.error("Failed to parse Gemini response", { responseText, parseError });
            interpretation = {
                intent: "find",
                contentType: "listings",
                filters: {},
                naturalLanguageSummary: query,
                confidence: 0.3,
            };
        }
        res.json({ interpretation, cachedFromIndex: false });
    }
    catch (error) {
        functions.logger.error("Error in processSearchQuery", { message: error.message });
        if (error.message?.includes("authentication")) {
            res.status(401).json({ error: "Authentication failed." });
        }
        else {
            res.status(500).json({ error: "An internal error occurred." });
        }
    }
});
