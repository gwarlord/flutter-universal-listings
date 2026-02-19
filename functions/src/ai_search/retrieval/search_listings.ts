import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { SearchInterpretation } from "../interpretation/search_interpreter";

const db = admin.firestore();

export interface SearchResult {
  id: string;
  title: string;
  category: string;
  location: string;
  price?: number;
  rating: number;
  reviewCount: number;
  distance?: number; // in km
  imageUrl?: string;
  description: string;
  relevanceScore: number; // 0-100
  qualityScore: number; // 0-100
  distanceScore: number; // 0-100
  freshnessScore: number; // 0-100
  finalScore: number; // weighted score 0-100
  explainabilityChips: string[]; // ["Near you", "Highly rated", etc.]
}

/**
 * Search listings based on AI interpretation
 * Called from Flutter after interpretSearchQuery
 * 
 * Input: { interpretation: SearchInterpretation, limit?: number, location?: { lat, lng } }
 * Output: { results: SearchResult[], totalCount: number }
 */
export const searchListings = functions.https.onCall(
  async (
    data: {
      interpretation: SearchInterpretation;
      limit?: number;
      location?: { lat: number; lng: number };
    },
    context
  ) => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const userId = context.auth.uid;
    const limit = Math.min(data.limit || 20, 100); // Max 100 results
    const interpretation = data.interpretation as SearchInterpretation;
    const userLocation = data.location;

    if (!interpretation)  {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Interpretation is required"
      );
    }

    try {
      // Check user is not suspended
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.suspended) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "User not found or account is suspended"
        );
      }

      // Build query based on interpretation
      let query = db.collection("search_index_listings") as any;

      // Filter by category if specified
      if (interpretation.filters.category) {
        query = query.where(
          "category",
          "==",
          interpretation.filters.category.toLowerCase()
        );
      }

      // Filter by location if specified (exact match or contains)
      if (interpretation.filters.location) {
        query = query.where("searchableText", "array-contains", interpretation.filters.location.toLowerCase());
      }

      // Price range filters
      if (interpretation.filters.priceMin) {
        query = query.where("price", ">=", interpretation.filters.priceMin);
      }
      if (interpretation.filters.priceMax) {
        query = query.where("price", "<=", interpretation.filters.priceMax);
      }

      // Execute query
      const snapshot = await query.limit(limit * 2).get(); // Get 2x to account for filtering
      const results: SearchResult[] = [];

      for (const doc of snapshot.docs) {
        const data = doc.data();
        
        // Score this result
        const scores = scoreResult(
          data,
          interpretation,
          userLocation
        );

        const result: SearchResult = {
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
          explainabilityChips: generateExplainabilityChips(
            data,
            scores,
            userLocation ? scores.distance : undefined
          ),
        };

        results.push(result);
      }

      // Sort by final score (highest first)
      results.sort((a, b) => b.finalScore - a.finalScore);

      // Trim to requested limit
      const trimmedResults = results.slice(0, limit);

      // Log search results (non-blocking)
      logSearchResults(userId, interpretation, trimmedResults).catch(
        (err) => {
          functions.logger.warn("Failed to log search results", {
            error: err,
          });
        }
      );

      return {
        results: trimmedResults,
        totalCount: results.length,
      };
    } catch (error: any) {
      functions.logger.error("Error in searchListings", {
        userId,
        error: error.message || error,
      });

      if (error.code && error.code.startsWith("functions/")) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "An error occurred searching. Please try again."
      );
    }
  }
);

/**
 * Score a result using multi-factor algorithm
 * Weights: relevance 40%, quality 30%, distance 20%, freshness 10%
 */
function scoreResult(
  listing: any,
  interpretation: SearchInterpretation,
  userLocation?: { lat: number; lng: number }
): {
  relevanceScore: number;
  qualityScore: number;
  distanceScore: number;
  freshnessScore: number;
  finalScore: number;
  distance?: number;
} {
  // Relevance: keyword match against searchable text
  const searchableText =
    `${listing.title} ${listing.description} ${listing.category}`
      .toLowerCase();
  const queryWords = interpretation.naturalLanguageSummary
    .toLowerCase()
    .split(/\s+/);
  const matchedWords = queryWords.filter((word: string) =>
    searchableText.includes(word)
  );
  const relevanceScore = Math.min(
    100,
    (matchedWords.length / queryWords.length) * 150
  );

  // Quality: rating and review count
  const rating = Math.min(5, listing.rating || 0);
  const reviewCount = listing.reviewCount || 0;
  const qualityScore = (rating / 5) * 80 + Math.min(20, Math.log10(reviewCount + 1) * 5);

  // Distance: if user location provided, calculate and score
  let distanceScore = 50; // Default if no location data
  let distance: number | undefined;

  if (
    userLocation &&
    listing.latitude &&
    listing.longitude
  ) {
    distance = calculateDistance(
      userLocation.lat,
      userLocation.lng,
      listing.latitude,
      listing.longitude
    );
    // Score: closer = higher. 0-10km = 100, 50km+ = 10
    distanceScore = Math.max(10, 100 - distance * 1.5);
  }

  // Freshness: how recently listing was updated
  const updatedAt = listing.updatedAt?.toDate?.() || new Date(0);
  const daysSinceUpdate = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60 * 24);
  const freshnessScore = Math.max(10, 100 - daysSinceUpdate * 2);

  // Weighted final score
  const finalScore =
    relevanceScore * 0.4 +
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
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
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
function generateExplainabilityChips(
  listing: any,
  scores: any,
  distance?: number
): string[] {
  const chips: string[] = [];

  // Add distance chip if relevant
  if (distance !== undefined) {
    if (distance < 5) {
      chips.push("Near you");
    } else if (distance < 15) {
      chips.push("Nearby");
    }
  }

  // Add rating chip if good
  if (listing.rating && listing.rating >= 4.5) {
    chips.push("Top rated");
  } else if (listing.rating && listing.rating >= 4.0) {
    chips.push("Highly rated");
  }

  // Add popularity chip if many reviews
  if (listing.reviewCount && listing.reviewCount >= 50) {
    chips.push("Popular");
  } else if (listing.reviewCount && listing.reviewCount >= 10) {
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
async function logSearchResults(
  userId: string,
  interpretation: SearchInterpretation,
  results: SearchResult[]
) {
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
  } catch (error) {
    functions.logger.warn("Failed to log search results", { error });
  }
}
