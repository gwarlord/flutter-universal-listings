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
exports.searchListingsRest = exports.searchListingsCallable = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
/**
 * Search listings based on AI interpretation
 * Called from Flutter after interpretSearchQuery
 *
 * Input: { interpretation: SearchInterpretation, limit?: number, location?: { lat, lng } }
 * Output: { results: SearchResult[], totalCount: number }
 */
exports.searchListingsCallable = functions.https.onCall(async (data, context) => {
    // Require authentication
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }
    const userId = context.auth.uid;
    const limit = Math.min(data.limit || 20, 100); // Max 100 results
    const interpretation = data.interpretation;
    const userLocation = data.location;
    if (!interpretation) {
        throw new functions.https.HttpsError("invalid-argument", "Interpretation is required");
    }
    try {
        // Check user is not suspended
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists || userDoc.data()?.suspended) {
            throw new functions.https.HttpsError("permission-denied", "User not found or account is suspended");
        }
        // Build query - use listings collection directly for comprehensive search
        let query = db.collection("listings");
        // Filter by category if specified
        if (interpretation.filters.category) {
            const category = typeof interpretation.filters.category === 'string'
                ? interpretation.filters.category
                : interpretation.filters.category?.title;
            if (category) {
                query = query.where("categoryTitle", "==", category);
            }
        }
        // Execute query with higher limit to allow client-side filtering
        const snapshot = await query.limit(limit * 5).get(); // Get more to account for filtering
        const results = [];
        // Apply additional filters and scoring on client side
        for (const doc of snapshot.docs) {
            const data = doc.data();
            // Skip suspended or hidden listings
            if (data.suspended || data.hidden)
                continue;
            const scores = scoreResult(data, interpretation, userLocation);
            // Only include results with minimum relevance score
            if (scores.relevanceScore < 10)
                continue;
            const result = {
                id: doc.id,
                title: data.title || "",
                category: data.categoryTitle || "",
                location: data.place || "",
                price: data.price ? parseFloat(data.price) : undefined,
                rating: data.reviewsSum && data.reviewsCount ? data.reviewsSum / data.reviewsCount : 0,
                reviewCount: data.reviewsCount || 0,
                distance: scores.distance,
                imageUrl: data.photo,
                description: data.description || "",
                relevanceScore: scores.relevanceScore,
                qualityScore: scores.qualityScore,
                distanceScore: scores.distanceScore,
                freshnessScore: scores.freshnessScore,
                finalScore: scores.finalScore,
                explainabilityChips: generateExplainabilityChips(data, scores),
            };
            results.push(result);
        }
        // Sort by final score and return top results
        results.sort((a, b) => b.finalScore - a.finalScore);
        const topResults = results.slice(0, limit);
        // Log search results (non-blocking)
        logSearchResults(userId, interpretation, topResults).catch((err) => {
            functions.logger.warn("Failed to log search results", {
                error: err,
            });
        });
        return {
            results: topResults,
            totalCount: results.length,
        };
    }
    catch (error) {
        functions.logger.error("Error in searchListings", {
            userId,
            error: error.message || error,
        });
        if (error.code && error.code.startsWith("functions/")) {
            throw error;
        }
        throw new functions.https.HttpsError("internal", "An error occurred searching. Please try again.");
    }
});
/**
 * Score a result using multi-factor algorithm
 * Weights: relevance 40%, quality 30%, distance 20%, freshness 10%
 */
function scoreResult(listing, interpretation, userLocation) {
    // Relevance: keyword match against all searchable text fields
    // Include title, description, category, place, author, services, hours, and website
    const searchableFields = [
        listing.title || "",
        listing.description || "",
        listing.categoryTitle || "",
        listing.place || "",
        listing.authorName || "",
        listing.openingHours || "",
        listing.website || "",
        listing.phone || "",
        listing.email || "",
    ];
    // Add service names to searchable text
    if (Array.isArray(listing.services)) {
        listing.services.forEach((service) => {
            if (service && service.name) {
                searchableFields.push(service.name);
            }
        });
    }
    const searchableText = searchableFields.join(" ").toLowerCase();
    const queryWords = interpretation.naturalLanguageSummary
        .toLowerCase()
        .split(/\s+/)
        .filter((word) => word.length > 2); // Ignore very short words
    const matchedWords = queryWords.filter((word) => searchableText.includes(word));
    const relevanceScore = queryWords.length > 0
        ? Math.min(100, (matchedWords.length / queryWords.length) * 150)
        : 0;
    // Quality: rating and review count
    const rating = Math.min(5, listing.reviewsSum && listing.reviewsCount
        ? listing.reviewsSum / listing.reviewsCount
        : 0);
    const reviewCount = listing.reviewsCount || 0;
    const qualityScore = (rating / 5) * 80 + Math.min(20, Math.log10(reviewCount + 1) * 5);
    // Distance: if user location provided, calculate and score
    let distanceScore = 50; // Default if no location data
    let distance;
    if (userLocation &&
        listing.latitude &&
        listing.longitude) {
        distance = calculateDistance(userLocation.lat, userLocation.lng, listing.latitude, listing.longitude);
        // Score: closer = higher. 0-10km = 100, 50km+ = 10
        distanceScore = Math.max(10, 100 - distance * 1.5);
    }
    // Freshness: how recently listing was updated
    const createdAt = listing.createdAt ? new Date(listing.createdAt * 1000) : new Date(0);
    const daysSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);
    const freshnessScore = Math.max(10, 100 - daysSinceCreation * 0.5); // Freshness degrades slower
    // Weighted final score
    // Relevance (40%) > Quality (30%) > Distance (20%) > Freshness (10%)
    const finalScore = relevanceScore * 0.4 +
        qualityScore * 0.3 +
        distanceScore * 0.2 +
        freshnessScore * 0.1;
    return {
        relevanceScore,
        qualityScore,
        distanceScore,
        freshnessScore,
        finalScore,
        distance,
    };
}
/**
 * Calculate distance between two coordinates (Haversine formula)
 * Returns distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((lat1 * Math.PI) / 180) *
            Math.cos((lat2 * Math.PI) / 180) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}
/**
 * Generate user-friendly explanation chips for why this result matched
 */
function generateExplainabilityChips(listing, scores, distance) {
    const chips = [];
    // Add distance chip if relevant
    if (distance !== undefined) {
        if (distance < 5) {
            chips.push("Near you");
        }
        else if (distance < 15) {
            chips.push("Nearby");
        }
    }
    // Add rating chip if good
    if (listing.rating && listing.rating >= 4.5) {
        chips.push("Top rated");
    }
    else if (listing.rating && listing.rating >= 4.0) {
        chips.push("Highly rated");
    }
    // Add popularity chip if many reviews
    if (listing.reviewCount && listing.reviewCount >= 50) {
        chips.push("Popular");
    }
    else if (listing.reviewCount && listing.reviewCount >= 10) {
        chips.push("Trusted");
    }
    // Add verification chip
    if (listing.verified) {
        chips.push("Verified");
    }
    // Add freshness chip if recently updated
    const updatedAt = listing.updatedAt?.toDate?.() || new Date(0);
    const daysSinceUpdate = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60 * 24);
    if (daysSinceUpdate < 7) {
        chips.push("Recently updated");
    }
    // Add price chip if relevant
    if (listing.price && scores.relevanceScore > 70) {
        chips.push(`$${listing.price.toFixed(2)}`);
    }
    return chips.slice(0, 4); // Max 4 chips
}
/**
 * Log search results for analytics
 */
async function logSearchResults(userId, interpretation, results) {
    try {
        const topIds = results.slice(0, 5).map((r) => r.id);
        await db.collection("search_analytics").add({
            userId,
            interpretation,
            resultIds: topIds,
            resultCount: results.length,
            type: "search_completed",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        functions.logger.warn("Failed to log search results", { error });
    }
}
/**
 * REST endpoint for search (avoids App Check issues)
 */
exports.searchListingsRest = functions.https.onRequest(async (req, res) => {
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
        const authHeader = req.headers.authorization;
        if (!authHeader?.startsWith("Bearer ")) {
            res.status(401).json({ error: "Missing or invalid Authorization header" });
            return;
        }
        const token = authHeader.substring(7);
        let userId;
        try {
            const decodedToken = await admin.auth().verifyIdToken(token);
            userId = decodedToken.uid;
        }
        catch (error) {
            res.status(401).json({ error: "Invalid authentication token" });
            return;
        }
        const interpretation = req.body?.interpretation;
        const contentType = req.body?.contentType || "listings";
        const limit = Math.min(req.body?.limit || 20, 100);
        if (!interpretation) {
            res.status(400).json({ error: "Interpretation is required" });
            return;
        }
        // Check user is not suspended
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists || userDoc.data()?.suspended) {
            res.status(403).json({ error: "User not found or account is suspended" });
            return;
        }
        // Build query
        let query = db.collection("search_index_listings");
        // Filter by category if specified
        if (interpretation.filters.category) {
            const category = typeof interpretation.filters.category === 'string'
                ? interpretation.filters.category
                : interpretation.filters.category?.title;
            if (category) {
                query = query.where("category", "==", category.toLowerCase());
            }
        }
        // Filter by location if specified
        const locationPlace = typeof interpretation.filters.location === 'string'
            ? interpretation.filters.location
            : interpretation.filters.location?.place;
        if (locationPlace) {
            query = query.where("searchableText", "array-contains", locationPlace.toLowerCase());
        }
        // Price range filters
        if (interpretation.filters.priceMin) {
            query = query.where("price", ">=", interpretation.filters.priceMin);
        }
        if (interpretation.filters.priceMax) {
            query = query.where("price", "<=", interpretation.filters.priceMax);
        }
        // Execute query
        const snapshot = await query.limit(limit * 2).get();
        const results = [];
        for (const doc of snapshot.docs) {
            const data = doc.data();
            const scores = scoreResult(data, interpretation, undefined);
            const result = {
                id: doc.id,
                title: data.title || "",
                category: data.category || "",
                location: data.location || "",
                price: data.price,
                rating: data.rating || 0,
                reviewCount: data.reviewCount || 0,
                distance: scores.distance,
                imageUrl: data.imageUrl,
                description: data.description || "",
                relevanceScore: scores.relevanceScore,
                qualityScore: scores.qualityScore,
                distanceScore: scores.distanceScore,
                freshnessScore: scores.freshnessScore,
                finalScore: scores.finalScore,
                explainabilityChips: generateExplainabilityChips(data, scores),
            };
            results.push(result);
        }
        results.sort((a, b) => b.finalScore - a.finalScore);
        const topResults = results.slice(0, limit);
        await logSearchResults(userId, interpretation, topResults);
        res.json({ results: topResults, totalCount: results.length });
    }
    catch (error) {
        functions.logger.error("Error in searchListingsRest", {
            message: error?.message,
            stack: error?.stack
        });
        res.status(500).json({ error: "An error occurred while searching" });
    }
});
