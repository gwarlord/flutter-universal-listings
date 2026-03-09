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
const MODEL_FALLBACKS = [
    "gemini-2.0-flash",
    "gemini-2.0-flash-lite",
    "gemini-1.5-flash-latest",
    "gemini-1.5-pro-latest",
];
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
exports.processSearchQuery = functions
    .runWith({ secrets: [secrets_1.geminiKeySecret] })
    .https.onRequest(async (req, res) => {
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
        const prompt = `You are searching for businesses in the Caribbean. Interpret this query STRICTLY as a structured JSON object with NO other text.

Query: "${query}"

Return ONLY this JSON structure (no markdown, no explanation, no text before or after):
{
  "intent": "user's goal (e.g. find, buy, book)",
  "contentType": "listings",
  "filters": {
    "category": {
      "keywords": ["${query.split(" ").join('", "')}"]
    },
    "location": {
      "useUserLocation": true
    }
  },
  "naturalLanguageSummary": "${query}",
  "confidence": 0.7
}`;
        let result = null;
        let lastError = null;
        for (const modelName of MODEL_FALLBACKS) {
            try {
                const model = genAI.getGenerativeModel({ model: modelName }, { apiVersion: "v1" });
                result = await model.generateContent(prompt);
                functions.logger.info("AI model selected", { modelName });
                break;
            }
            catch (modelError) {
                lastError = modelError;
                const message = modelError?.message || "";
                functions.logger.warn("AI model attempt failed", {
                    modelName,
                    message,
                });
                if (!message.includes("404") && !message.includes("not found")) {
                    throw modelError;
                }
            }
        }
        if (!result) {
            throw lastError ?? new Error("No compatible Gemini model available for generateContent.");
        }
        const responseText = result.response.text();
        let interpretation;
        try {
            let jsonText = responseText;
            const jsonMatch = responseText.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
            if (jsonMatch) {
                jsonText = jsonMatch[1];
            }
            else {
                const objectMatch = responseText.match(/\{[\s\S]*\}/);
                if (objectMatch) {
                    jsonText = objectMatch[0];
                }
            }
            interpretation = JSON.parse(jsonText.trim());
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
        const message = error?.message || "";
        functions.logger.error("Error in processSearchQuery", {
            message,
            name: error?.name,
            stack: error?.stack,
        });
        res.status(500).json({
            error: "An internal error occurred.",
            details: message
        });
    }
});
