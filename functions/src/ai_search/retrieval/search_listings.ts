import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { SearchInterpretation } from "../interpretation/search_interpreter";

const db = admin.firestore();
const MIN_RELEVANCE_SCORE = 20;
const QUERY_STOPWORDS = new Set([
  "i", "me", "my", "mine", "we", "our", "you", "your",
  "a", "an", "the", "to", "for", "of", "and", "or", "in", "on", "at", "with",
  "want", "need", "looking", "find", "show", "anyone", "please",
  "who", "what", "where", "when", "how",
  "sell", "sells", "selling", "buy", "buys", "buying",
]);

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

type NormalizedSearchInterpretation = SearchInterpretation & {
  filters: {
    [key: string]: any;
    category?: any;
    location?: any;
    priceMin?: number;
    priceMax?: number;
  };
  queryTerms: string[];
  queryPhrase: string;
};

/**
 * Search listings based on AI interpretation
 * Called from Flutter after interpretSearchQuery
 * 
 * Input: { interpretation: SearchInterpretation, limit?: number, location?: { lat, lng } }
 * Output: { results: SearchResult[], totalCount: number }
 */
export const searchListingsCallable = functions.https.onCall(
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
    const interpretation = normalizeInterpretation(
      data.interpretation as SearchInterpretation
    );
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

      // Build query - use listings collection directly for comprehensive search
      let query = db.collection("listings") as any;

      // NOTE: category/location are handled as soft ranking signals.
      // Avoid strict Firestore pre-filters here to prevent false negatives.

      // Execute query with higher limit to allow client-side filtering
      const snapshot = await query.limit(limit * 5).get(); // Get more to account for filtering
      const results: SearchResult[] = [];

      // Apply additional filters and scoring on client side
      for (const doc of snapshot.docs) {
        const data = doc.data();
        
        // Skip suspended or hidden listings
        if (data.suspended || data.hidden) continue;
        
        const scores = scoreResult(data, interpretation, userLocation);
        
        // Only include results with minimum relevance score
        if (scores.relevanceScore < MIN_RELEVANCE_SCORE) continue;

        const result: SearchResult = {
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
      logSearchResults(userId, interpretation, topResults).catch(
        (err) => {
          functions.logger.warn("Failed to log search results", {
            error: err,
          });
        }
      );

      return {
        results: topResults,
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
  interpretation: NormalizedSearchInterpretation,
  userLocation?: { lat: number; lng: number }
): {
  relevanceScore: number;
  qualityScore: number;
  distanceScore: number;
  freshnessScore: number;
  intentScore: number;
  finalScore: number;
  distance?: number;
} {
  const titleText = String(listing.title || "").toLowerCase();
  const categoryText = String(listing.categoryTitle || listing.category || "").toLowerCase();
  const descriptionText = String(listing.description || "").toLowerCase();
  const locationText = String(listing.place || listing.location || "").toLowerCase();
  const servicesMenuText = extractServicesAndMenuText(listing).toLowerCase();
  const keywordText = String((listing.searchKeywords || []).join(" ")).toLowerCase();
  const searchableBlob = String(listing.searchableBlob || "").toLowerCase();
  const fallbackSearchableBlob = (
    searchableBlob ||
    [
      titleText,
      categoryText,
      descriptionText,
      locationText,
      keywordText,
      servicesMenuText,
    ].join(" ")
  ).trim();

  const weightedFields: Array<{ weight: number; text: string }> = [
    { weight: 3.2, text: titleText },
    { weight: 2.6, text: categoryText },
    { weight: 2.2, text: keywordText },
    { weight: 2.0, text: servicesMenuText },
    { weight: 1.3, text: descriptionText },
    { weight: 1.0, text: locationText },
  ];

  const semanticScore = computeWeightedSemanticScore(interpretation.queryTerms, weightedFields);
  const phraseScore = computePhraseScore(interpretation.queryPhrase, [
    titleText,
    categoryText,
    servicesMenuText,
    descriptionText,
    fallbackSearchableBlob,
  ]);
  const relevanceScore = Math.min(100, semanticScore * 0.75 + phraseScore * 0.25);

  // Quality: rating and review count
  const rating = Math.min(5, listing.reviewsSum && listing.reviewsCount 
    ? listing.reviewsSum / listing.reviewsCount 
    : 0);
  const reviewCount = listing.reviewsCount || 0;
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
  const createdAtRaw = typeof listing.createdAt === "number"
    ? listing.createdAt
    : listing.createdAt?.seconds;
  const createdAt = createdAtRaw ? new Date(createdAtRaw * 1000) : new Date(0);
  const daysSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);
  const freshnessScore = Math.max(10, 100 - daysSinceCreation * 0.5); // Freshness degrades slower

  const intentScore = computeIntentScore(
    listing,
    interpretation,
    relevanceScore,
    qualityScore,
    freshnessScore
  );

  // Weighted final score
  // Relevance (45%) > Quality (20%) > Distance (15%) > Freshness (10%) > Intent-fit (10%)
  const finalScore =
    relevanceScore * 0.45 +
    qualityScore * 0.2 +
    distanceScore * 0.15 +
    freshnessScore * 0.1 +
    intentScore * 0.1;

  return {
    relevanceScore,
    qualityScore,
    distanceScore,
    freshnessScore,
    intentScore,
    finalScore,
    distance,
  };
}

function normalizeInterpretation(
  raw: SearchInterpretation | undefined
): NormalizedSearchInterpretation {
  const base = (raw || {}) as any;
  const filters = { ...(base.filters || {}) } as any;

  if (!filters.category && base.category) {
    filters.category = base.category;
  }
  if (!filters.location && base.location) {
    filters.location = base.location;
  }
  if (filters.priceMin === undefined && base.priceMin !== undefined) {
    filters.priceMin = base.priceMin;
  }
  if (filters.priceMax === undefined && base.priceMax !== undefined) {
    filters.priceMax = base.priceMax;
  }

  const categorySource = filters.category || base.category;
  const categoryKeywords = new Set<string>();
  if (typeof categorySource === "string") {
    categoryKeywords.add(categorySource);
  }
  if (categorySource?.title && typeof categorySource.title === "string") {
    categoryKeywords.add(categorySource.title);
  }
  if (Array.isArray(categorySource?.keywords)) {
    for (const item of categorySource.keywords) {
      if (typeof item === "string" && item.trim()) {
        categoryKeywords.add(item.trim());
      }
    }
  }

  const locationSource = filters.location || base.location;
  const locationHints = new Set<string>();
  if (typeof locationSource === "string") {
    locationHints.add(locationSource);
  }
  if (locationSource?.place && typeof locationSource.place === "string") {
    locationHints.add(locationSource.place);
  }

  const summary = String(base.naturalLanguageSummary || "").trim();
  const normalizedSummaryPhrase = buildPhraseFromInput(summary);

  return {
    intent: String(base.intent || "find").toLowerCase(),
    contentType: String(base.contentType || "listings"),
    filters,
    naturalLanguageSummary: summary,
    confidence: typeof base.confidence === "number" ? base.confidence : 0.5,
    queryTerms: buildQueryTerms([
      summary,
      String(base.intent || ""),
      ...Array.from(categoryKeywords),
      ...Array.from(locationHints),
    ]),
    queryPhrase: normalizedSummaryPhrase || summary.toLowerCase(),
  };
}

function buildQueryTerms(inputs: string[]): string[] {
  const tokens = new Set<string>();
  for (const input of inputs) {
    const words = String(input || "")
      .toLowerCase()
      .split(/[^a-z0-9]+/g)
      .map((word) => word.trim())
      .filter((word) => word.length >= 2)
      .filter((word) => !QUERY_STOPWORDS.has(word));
    for (const word of words) {
      for (const variant of generateTokenVariants(word)) {
        tokens.add(variant);
      }
    }
  }
  return Array.from(tokens);
}

function buildPhraseFromInput(input: string): string {
  const cleanedTokens = String(input || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/g)
    .map((word) => word.trim())
    .filter((word) => word.length >= 2)
    .filter((word) => !QUERY_STOPWORDS.has(word));

  return cleanedTokens.join(" ").trim();
}

function generateTokenVariants(token: string): string[] {
  const variants = new Set<string>();
  const base = token.trim().toLowerCase();
  if (!base) return [];

  variants.add(base);

  // Basic plural/singular normalization
  if (base.length > 3 && base.endsWith("ies")) {
    variants.add(`${base.slice(0, -3)}y`);
  }
  if (base.length > 3 && base.endsWith("es")) {
    variants.add(base.slice(0, -2));
  }
  if (base.length > 3 && base.endsWith("s")) {
    variants.add(base.slice(0, -1));
  }

  // UK/US spelling normalization for colour/color family
  if (base.includes("colour")) {
    variants.add(base.replace(/colour/g, "color"));
  }
  if (base.includes("color")) {
    variants.add(base.replace(/color/g, "colour"));
  }

  return Array.from(variants).filter((item) => item.length >= 2);
}

function computeWeightedSemanticScore(
  terms: string[],
  fields: Array<{ weight: number; text: string }>
): number {
  if (!terms.length) return 0;

  const totalWeightPerTerm = fields.reduce((sum, field) => sum + field.weight, 0);
  const totalPossible = totalWeightPerTerm * terms.length;
  let matchedWeight = 0;

  for (const term of terms) {
    for (const field of fields) {
      if (field.text.includes(term)) {
        matchedWeight += field.weight;
      }
    }
  }

  return totalPossible > 0 ? Math.min(100, (matchedWeight / totalPossible) * 180) : 0;
}

function computePhraseScore(phrase: string, fields: string[]): number {
  if (!phrase || phrase.length < 4) return 0;
  if (fields[0]?.includes(phrase)) return 100;
  if (fields[1]?.includes(phrase)) return 90;
  if (fields[2]?.includes(phrase)) return 75;
  if (fields[3]?.includes(phrase)) return 65;
  return 0;
}

function computeIntentScore(
  listing: any,
  interpretation: NormalizedSearchInterpretation,
  relevanceScore: number,
  qualityScore: number,
  freshnessScore: number
): number {
  const intent = String(interpretation.intent || "find").toLowerCase();
  const query = interpretation.queryPhrase;

  let score = relevanceScore * 0.5 + qualityScore * 0.3 + freshnessScore * 0.2;

  const hasServices = Array.isArray(listing.services) && listing.services.length > 0;
  const hasMenu = Array.isArray(listing.menuSections) && listing.menuSections.length > 0;
  const hasCommerceSignals = Boolean(listing.price) || hasMenu;
  const hasContactSignals = Boolean(listing.phone || listing.email || listing.website || listing.whatsapp);

  if (intent.includes("book") || intent.includes("appointment") || intent.includes("reserve")) {
    if (hasServices) score += 18;
    if (hasContactSignals) score += 10;
  }

  if (intent.includes("buy") || intent.includes("order") || intent.includes("shop")) {
    if (hasCommerceSignals) score += 16;
    if (hasMenu) score += 8;
  }

  if (query.includes("best") || query.includes("top")) {
    score += qualityScore * 0.1;
  }
  if (query.includes("new") || query.includes("recent")) {
    score += freshnessScore * 0.08;
  }
  if (query.includes("cheap") || query.includes("affordable")) {
    const price = typeof listing.price === "number"
      ? listing.price
      : parseFloat(String(listing.price || "0"));
    if (price > 0 && price <= 25) score += 12;
    else if (price > 0 && price <= 50) score += 7;
  }

  return Math.max(0, Math.min(100, score));
}

function extractServicesAndMenuText(listing: any): string {
  const chunks: string[] = [];

  if (Array.isArray(listing.services)) {
    for (const service of listing.services) {
      if (!service || typeof service !== "object") continue;
      if (service.name) chunks.push(String(service.name));
      if (service.description) chunks.push(String(service.description));
    }
  }

  if (Array.isArray(listing.menuSections)) {
    for (const section of listing.menuSections) {
      if (!section || typeof section !== "object") continue;
      if (section.title) chunks.push(String(section.title));
      if (Array.isArray(section.items)) {
        for (const item of section.items) {
          if (!item || typeof item !== "object") continue;
          if (item.name) chunks.push(String(item.name));
          if (item.description) chunks.push(String(item.description));
          if (Array.isArray(item.tags)) chunks.push(item.tags.join(" "));
        }
      }
    }
  }

  return chunks.join(" ");
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
  const rating = listing.rating || listing.averageRating || (
    listing.reviewsSum && listing.reviewsCount ? listing.reviewsSum / listing.reviewsCount : 0
  );
  if (rating && rating >= 4.5) {
    chips.push("Top rated");
  } else if (rating && rating >= 4.0) {
    chips.push("Highly rated");
  }

  // Add popularity chip if many reviews
  const reviewCount = listing.reviewCount || listing.reviewsCount || 0;
  if (reviewCount && reviewCount >= 50) {
    chips.push("Popular");
  } else if (reviewCount && reviewCount >= 10) {
    chips.push("Trusted");
  }

  // Add verification chip
  if (listing.verified) {
    chips.push("Verified");
  }

  // Add freshness chip if recently updated
  const updatedAt = typeof listing.updatedAt === "number"
    ? new Date(listing.updatedAt * 1000)
    : listing.updatedAt?.toDate?.() || new Date(0);
  const daysSinceUpdate = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60 * 24);
  if (daysSinceUpdate < 7) {
    chips.push("Recently updated");
  }

  if (typeof scores.intentScore === "number" && scores.intentScore >= 75) {
    chips.push("Great intent match");
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
/**
 * REST endpoint for search (avoids App Check issues)
 */
export const searchListingsRest = functions.https.onRequest(async (req, res) => {
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
    let userId: string;
    try {
      const decodedToken = await admin.auth().verifyIdToken(token);
      userId = decodedToken.uid;
    } catch (error) {
      res.status(401).json({ error: "Invalid authentication token" });
      return;
    }

    const interpretation = normalizeInterpretation(
      req.body?.interpretation as SearchInterpretation
    );
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
    let query = db.collection("search_index_listings") as any;

    // NOTE: category/location are applied as soft ranking signals.
    // Keep retrieval broad here to preserve recall for AI reranking.

    // Price range filters
    if (interpretation.filters.priceMin) {
      query = query.where("price", ">=", interpretation.filters.priceMin);
    }
    if (interpretation.filters.priceMax) {
      query = query.where("price", "<=", interpretation.filters.priceMax);
    }

    // Execute query
    // First try targeted token retrieval to avoid missing relevant listings
    // due to arbitrary default document ordering.
    let candidateDocs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    const canUseTargetedTokenQuery =
      !interpretation.filters.priceMin &&
      !interpretation.filters.priceMax &&
      interpretation.queryTerms.length > 0;

    if (canUseTargetedTokenQuery) {
      const tokenTerms = interpretation.queryTerms.slice(0, 25);
      const targetedSnapshot = await db
        .collection("search_index_listings")
        .where("searchableText", "array-contains-any", tokenTerms)
        .limit(limit * 8)
        .get();
      candidateDocs = targetedSnapshot.docs;
    }

    if (candidateDocs.length === 0) {
      const snapshot = await query.limit(limit * 4).get();
      candidateDocs = snapshot.docs;
    }

    const results: SearchResult[] = [];

    for (const doc of candidateDocs) {
      const data = doc.data();

      if (data.suspended || data.hidden || data.isApproved === false) {
        continue;
      }

      const scores = scoreResult(data, interpretation, undefined);
      if (scores.relevanceScore < MIN_RELEVANCE_SCORE) continue;

      const result: SearchResult = {
        id: doc.id,
        title: data.title || "",
        category: data.categoryTitle || data.category || "",
        location: data.place || data.location || "",
        price: data.price,
        rating: data.rating || data.averageRating || 0,
        reviewCount: data.reviewCount || data.reviewsCount || 0,
        distance: scores.distance,
        imageUrl: data.photo || data.imageUrl,
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
    let topResults = results.slice(0, limit);

    // Fallback: if indexed search returns nothing, query canonical listings collection directly.
    if (topResults.length == 0) {
      functions.logger.info("Indexed search returned 0, falling back to listings", {
        userId,
        query: interpretation.naturalLanguageSummary,
      });

      let listingsQuery = db.collection("listings") as any;

      // Apply price filters where possible
      if (interpretation.filters.priceMin) {
        listingsQuery = listingsQuery.where("price", ">=", interpretation.filters.priceMin);
      }
      if (interpretation.filters.priceMax) {
        listingsQuery = listingsQuery.where("price", "<=", interpretation.filters.priceMax);
      }

      const listingsSnapshot = await listingsQuery.limit(Math.min(limit * 30, 500)).get();
      const fallbackResults: SearchResult[] = [];

      for (const doc of listingsSnapshot.docs) {
        const listingData = doc.data();

        // Skip hidden/suspended listings
        if (listingData.suspended || listingData.hidden) continue;

        const scores = scoreResult(listingData, interpretation, undefined);
        if (scores.relevanceScore < MIN_RELEVANCE_SCORE) continue;

        fallbackResults.push({
          id: doc.id,
          title: listingData.title || "",
          category: listingData.categoryTitle || listingData.category || "",
          location: listingData.place || listingData.location || "",
          price: listingData.price ? parseFloat(listingData.price) : undefined,
          rating: listingData.reviewsSum && listingData.reviewsCount
            ? listingData.reviewsSum / listingData.reviewsCount
            : (listingData.rating || 0),
          reviewCount: listingData.reviewsCount || listingData.reviewCount || 0,
          distance: scores.distance,
          imageUrl: listingData.photo || listingData.imageUrl,
          description: listingData.description || "",
          relevanceScore: scores.relevanceScore,
          qualityScore: scores.qualityScore,
          distanceScore: scores.distanceScore,
          freshnessScore: scores.freshnessScore,
          finalScore: scores.finalScore,
          explainabilityChips: generateExplainabilityChips(listingData, scores),
        });
      }

      fallbackResults.sort((a, b) => b.finalScore - a.finalScore);
      topResults = fallbackResults.slice(0, limit);
    }

    await logSearchResults(userId, interpretation, topResults);

    res.json({ results: topResults, totalCount: topResults.length, contentType });
  } catch (error: any) {
    functions.logger.error("Error in searchListingsRest", { 
      message: error?.message,
      stack: error?.stack 
    });
    res.status(500).json({ error: "An error occurred while searching" });
  }
});
