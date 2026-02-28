import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { geminiKeySecret } from "../../common/secrets";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const getGenAI = async () => {
  const apiKey = await geminiKeySecret.value();
  if (!apiKey) {
    throw new Error("Gemini API key is not configured.");
  }
  return new GoogleGenerativeAI(apiKey);
};

async function validateBearerToken(authHeader?: string): Promise<string> {
    if (!authHeader?.startsWith("Bearer ")) {
        throw new Error("Missing or invalid Authorization header");
    }
    const token = authHeader.substring(7);
    try {
        const decodedToken = await admin.auth().verifyIdToken(token);
        return decodedToken.uid;
    } catch (error) {
        throw new Error(`Invalid authentication token: ${error}`);
    }
}

export interface SearchInterpretation {
  intent: string;
  contentType: string;
  filters: { [key: string]: any };
  naturalLanguageSummary: string;
  confidence: number;
}


export const processSearchQuery = functions
    .runWith({ secrets: [geminiKeySecret] })
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
        const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
        
        const prompt = `You are searching for businesses in the Caribbean. Interpret this query STRICTLY as a structured JSON object with NO other text.

Query: "${query}"

Return ONLY this JSON structure (no markdown, no explanation, no text before or after):
{
  "intent": "user's goal (e.g. find, buy, book)",
  "contentType": "listings",
  "category": {
    "keywords": ["${query.split(" ").join('", "')}"]
  },
  "location": {
    "useUserLocation": true
  },
  "filters": {},
  "naturalLanguageSummary": "${query}",
  "confidence": 0.7
}`;

        const result = await model.generateContent(prompt);
        const responseText = result.response.text();
        let interpretation: SearchInterpretation;

        try {
            // Try to extract JSON from the response (may be wrapped in markdown or text)
            let jsonText = responseText;
            
            // Remove markdown code blocks if present
            const jsonMatch = responseText.match(/```(?:json)?\s*([\s\S]*?)\s*```/);
            if (jsonMatch) {
              jsonText = jsonMatch[1];
            } else {
              // Try to find JSON object directly
              const objectMatch = responseText.match(/\{[\s\S]*\}/);
              if (objectMatch) {
                jsonText = objectMatch[0];
              }
            }
            
            interpretation = JSON.parse(jsonText.trim());
        } catch (parseError) {
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

    } catch (error: any) {
        const message = error?.message || "";
        functions.logger.error("Error in processSearchQuery", {
            message,
            name: error?.name,
            stack: error?.stack,
        });

        const normalized = message.toLowerCase();
        if (normalized.includes("authorization") || normalized.includes("authentication")) {
            res.status(401).json({ error: "Authentication failed." });
            return;
        }

        if (normalized.includes("gemini api key")) {
            res.status(500).json({ error: "AI service not configured." });
            return;
        }

        res.status(500).json({ error: "An internal error occurred." });
    }
});