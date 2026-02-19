# CaribTap AI-Assisted Search - Retrieval & Ranking

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Candidate Retrieval](#candidate-retrieval)
3. [Ranking Algorithm](#ranking-algorithm)
4. [Explainability](#explainability)
5. [Pagination Strategy](#pagination-strategy)
6. [Performance Optimization](#performance-optimization)

---

## Overview

The retrieval and ranking system combines:
1. **Deterministic Firestore Queries**: Extract candidates using structured filters
2. **Scoring Algorithm**: Rank by relevance, distance, quality, freshness
3. **Optional AI Reranking**: Refine top N results using semantic similarity
4. **Explainability**: Generate reason chips for each result

---

## Candidate Retrieval

### Query Builder

```typescript
// functions/src/search/retrieval.ts

interface SearchQuery {
  interpretation: SearchInterpretation;
  userLocation?: { lat: number; lng: number };
  sortBy: SortOption;
  limit: number;
  startAfter?: FirebaseFirestore.DocumentSnapshot;
}

async function retrieveCandidates(query: SearchQuery): Promise<SearchResult[]> {
  const { interpretation, userLocation, sortBy, limit } = query;
  
  let firestoreQuery: FirebaseFirestore.Query;
  
  // 1. Choose collection
  const collection = interpretation.contentType === 'deals' 
    ? 'search_index_deals' 
    : 'search_index_listings';
  
  firestoreQuery = admin.firestore().collection(collection);
  
  // 2. Apply filters
  
  // Base filter: Active only
  firestoreQuery = firestoreQuery.where('isActive', '==', true);
  
  // Category filter
  if (interpretation.category.title) {
    firestoreQuery = firestoreQuery.where('categoryTitleLower', '==', interpretation.category.title.toLowerCase());
  }
  
  // Location filter (geohash)
  if (interpretation.location.place || interpretation.location.useUserLocation) {
    const centerLat = interpretation.location.coordinates?.lat || userLocation?.lat;
    const centerLng = interpretation.location.coordinates?.lng || userLocation?.lng;
    const radius = interpretation.location.radius || 5;
    
    if (centerLat && centerLng) {
      const { lower, upper } = getGeohashRange(centerLat, centerLng, radius);
      firestoreQuery = firestoreQuery
        .where('geohash', '>=', lower)
        .where('geohash', '<', upper);
    }
  }
  
  // Price filter
  if (interpretation.priceRange) {
    if (interpretation.priceRange.min !== null) {
      firestoreQuery = firestoreQuery.where('priceMax', '>=', interpretation.priceRange.min);
    }
    if (interpretation.priceRange.max !== null) {
      firestoreQuery = firestoreQuery.where('priceMin', '<=', interpretation.priceRange.max);
    }
  }
  
  // Quality filter: Vouched
  if (interpretation.quality.onlyVouched) {
    firestoreQuery = firestoreQuery.where('verified', '==', true);
  }
  
  // Quality filter: Min Rating
  if (interpretation.quality.minRating) {
    firestoreQuery = firestoreQuery.where('averageRating', '>=', interpretation.quality.minRating);
  }
  
  // Availability filters
  if (interpretation.availability.openNow) {
    firestoreQuery = firestoreQuery.where('isOpenNow', '==', true);
  }
  
  if (interpretation.availability.delivery) {
    firestoreQuery = firestoreQuery.where('filters.delivery', '==', 'yes');
  }
  
  if (interpretation.availability.bookingEnabled) {
    firestoreQuery = firestoreQuery.where('bookingEnabled', '==', true);
  }
  
  // 3. Apply sort
  switch (sortBy) {
    case 'distance':
      // Distance sort done post-query (requires lat/lng calculation)
      firestoreQuery = firestoreQuery.orderBy('averageRating', 'desc');
      break;
    case 'rating':
      firestoreQuery = firestoreQuery.orderBy('averageRating', 'desc');
      break;
    case 'price_low':
      firestoreQuery = firestoreQuery.orderBy('priceMin', 'asc');
      break;
    case 'price_high':
      firestoreQuery = firestoreQuery.orderBy('priceMax', 'desc');
      break;
    case 'ending_soon':
      if (collection === 'search_index_deals') {
        firestoreQuery = firestoreQuery.orderBy('daysRemaining', 'asc');
      }
      break;
    case 'relevance':
    default:
      // Relevance sort done post-query (scoring algorithm)
      firestoreQuery = firestoreQuery.orderBy('viewCount', 'desc');
      break;
  }
  
  // 4. Pagination
  if (query.startAfter) {
    firestoreQuery = firestoreQuery.startAfter(query.startAfter);
  }
  
  firestoreQuery = firestoreQuery.limit(limit);
  
  // 5. Execute query
  const snapshot = await firestoreQuery.get();
  
  // 6. Post-process: Distance filtering
  let results = snapshot.docs.map((doc) => ({
    ...doc.data(),
    docRef: doc,
  })) as any[];
  
  if (userLocation && (interpretation.location.useUserLocation || interpretation.location.coordinates)) {
    const centerLat = interpretation.location.coordinates?.lat || userLocation.lat;
    const centerLng = interpretation.location.coordinates?.lng || userLocation.lng;
    const maxRadius = interpretation.location.radius || 5;
    
    results = results
      .map((r) => ({
        ...r,
        distance: calculateDistance(centerLat, centerLng, r.latitude, r.longitude),
      }))
      .filter((r) => r.distance <= maxRadius);
  }
  
  return results;
}
```

---

## Ranking Algorithm

### Score Calculation

**Formula**:

```
Score = (RelevanceScore * 0.4) + (QualityScore * 0.3) + (DistanceScore * 0.2) + (FreshnessScore * 0.1)
```

**Component Breakdown**:

#### 1. Relevance Score (0-100)

Based on keyword matches:

```typescript
function calculateRelevanceScore(
  item: SearchIndexListing | SearchIndexDeal,
  interpretation: SearchInterpretation
): number {
  let score = 0;
  const keywords = interpretation.extractedKeywords.map((k) => k.toLowerCase());
  
  // Title match (highest weight)
  const titleLower = item.titleLower || item.captionLower;
  const titleMatches = keywords.filter((k) => titleLower.includes(k)).length;
  score += (titleMatches / keywords.length) * 60;
  
  // Category match
  if (interpretation.category.title && item.categoryTitleLower === interpretation.category.title.toLowerCase()) {
    score += 20;
  }
  
  // Keyword array match
  const itemKeywords = item.searchKeywords.map((k) => k.toLowerCase());
  const keywordMatches = keywords.filter((k) => itemKeywords.includes(k)).length;
  score += (keywordMatches / keywords.length) * 20;
  
  return Math.min(score, 100);
}
```

#### 2. Quality Score (0-100)

Based on engagement signals:

```typescript
function calculateQualityScore(item: SearchIndexListing | SearchIndexDeal): number {
  let score = 0;
  
  // Rating (0-50 points)
  if ('averageRating' in item) {
    score += (item.averageRating / 5) * 50;
  }
  
  // Verification badge (20 points)
  if ('verified' in item && item.verified) {
    score += 20;
  }
  
  // Featured listing (15 points)
  if ('isFeatured' in item && item.isFeatured) {
    score += 15;
  }
  
  // Engagement (reviews/views) (15 points)
  if ('reviewsCount' in item) {
    const engagementScore = Math.log10(Math.max(item.reviewsCount, 1)) * 5;
    score += Math.min(engagementScore, 15);
  } else if ('claimCount' in item) {
    const engagementScore = Math.log10(Math.max(item.claimCount + 1, 1)) * 5;
    score += Math.min(engagementScore, 15);
  }
  
  return Math.min(score, 100);
}
```

#### 3. Distance Score (0-100)

Inverse relationship with distance:

```typescript
function calculateDistanceScore(distance: number | undefined, maxRadius: number): number {
  if (distance === undefined) return 50; // No location filtering
  
  // Closer = higher score
  const normalizedDistance = Math.min(distance / maxRadius, 1);
  return (1 - normalizedDistance) * 100;
}
```

#### 4. Freshness Score (0-100)

Based on recency:

```typescript
function calculateFreshnessScore(item: SearchIndexListing | SearchIndexDeal): number {
  const now = Date.now() / 1000; // seconds
  const ageSeconds = now - item.updatedAt;
  const ageDays = ageSeconds / (24 * 60 * 60);
  
  // Fresh content gets higher score
  if (ageDays < 7) return 100;
  if (ageDays < 30) return 80;
  if (ageDays < 90) return 60;
  return 40;
}
```

### Combined Score

```typescript
function calculateFinalScore(
  item: SearchIndexListing | SearchIndexDeal,
  interpretation: SearchInterpretation,
  distance?: number
): number {
  const relevance = calculateRelevanceScore(item, interpretation) * 0.4;
  const quality = calculateQualityScore(item) * 0.3;
  const distanceScore = calculateDistanceScore(distance, interpretation.location.radius || 5) * 0.2;
  const freshness = calculateFreshnessScore(item) * 0.1;
  
  return relevance + quality + distanceScore + freshness;
}
```

### Sorting by Score

```typescript
async function rankResults(
  candidates: SearchResult[],
  interpretation: SearchInterpretation
): Promise<RankedSearchResult[]> {
  const ranked = candidates.map((item) => ({
    ...item,
    score: calculateFinalScore(item, interpretation, item.distance),
  }));
  
  // Sort by score descending
  ranked.sort((a, b) => b.score - a.score);
  
  return ranked;
}
```

---

## Explainability

### Generating Explanation Chips

**Purpose**: Show 2-3 reasons WHY each result matches.

**Chip Types**:

| Chip | Condition | Icon |
|------|-----------|------|
| "Near you" | distance < 2km | 📍 |
| "Vouched" | verified === true | 🔵 |
| "Top rated" | averageRating >= 4.5 | ⭐ |
| "Popular" | reviewsCount > 20 OR viewCount > 100 | 🔥 |
| "Open now" | isOpenNow === true | ⏰ |
| "Delivery" | filters.delivery === 'yes' | 🚚 |
| "Matches '[keyword]'" | keyword in title | 🔍 |
| "Featured" | isFeatured === true | ⭐ |
| "Ending soon" | (deals) daysRemaining <= 3 | ⏳ |
| "New" | createdAt within 7 days | ✨ |

**Implementation**:

```typescript
function generateExplanationChips(
  item: SearchIndexListing | SearchIndexDeal,
  interpretation: SearchInterpretation,
  distance?: number
): string[] {
  const chips: string[] = [];
  
  // Distance
  if (distance !== undefined && distance < 2) {
    chips.push('Near you');
  }
  
  // Verified
  if ('verified' in item && item.verified) {
    chips.push('Vouched');
  }
  
  // Rating
  if ('averageRating' in item && item.averageRating >= 4.5) {
    chips.push('Top rated');
  }
  
  // Popular
  if (('reviewsCount' in item && item.reviewsCount > 20) || 
      ('viewCount' in item && item.viewCount > 100)) {
    chips.push('Popular');
  }
  
  // Open now
  if ('isOpenNow' in item && item.isOpenNow) {
    chips.push('Open now');
  }
  
  // Delivery
  if ('filters' in item && item.filters.delivery === 'yes') {
    chips.push('Delivery');
  }
  
  // Keyword match
  const keywords = interpretation.extractedKeywords;
  const titleLower = 'titleLower' in item ? item.titleLower : item.captionLower;
  const matchedKeyword = keywords.find((k) => titleLower.includes(k.toLowerCase()));
  if (matchedKeyword) {
    chips.push(`Matches '${matchedKeyword}'`);
  }
  
  // Featured
  if ('isFeatured' in item && item.isFeatured) {
    chips.push('Featured');
  }
  
  // Ending soon (deals)
  if ('daysRemaining' in item && item.daysRemaining <= 3) {
    chips.push('Ending soon');
  }
  
  // New
  const ageSeconds = (Date.now() / 1000) - item.updatedAt;
  const ageDays = ageSeconds / (24 * 60 * 60);
  if (ageDays <= 7) {
    chips.push('New');
  }
  
  // Return top 3 chips
  return chips.slice(0, 3);
}
```

---

## Pagination Strategy

### Cursor-Based Pagination

**Why Cursor-Based?**
- No offset skipping (more efficient)
- Consistent results even with updates
- Required by Firestore `startAfter()`

**Implementation**:

```typescript
interface PaginatedResults {
  results: RankedSearchResult[];
  lastDoc: FirebaseFirestore.DocumentSnapshot | null;
  hasMore: boolean;
}

async function searchWithPagination(
  interpretation: SearchInterpretation,
  userLocation?: { lat: number; lng: number },
  limit: number = 20,
  startAfterDoc?: FirebaseFirestore.DocumentSnapshot
): Promise<PaginatedResults> {
  
  const candidates = await retrieveCandidates({
    interpretation,
    userLocation,
    sortBy: interpretation.sortBy || 'relevance',
    limit: limit + 1, // Fetch 1 extra to check if more exist
    startAfter: startAfterDoc,
  });
  
  const hasMore = candidates.length > limit;
  const results = candidates.slice(0, limit);
  
  const ranked = await rankResults(results, interpretation);
  
  // Add explanation chips
  const withExplanations = ranked.map((r) => ({
    ...r,
    explanationChips: generateExplanationChips(r, interpretation, r.distance),
  }));
  
  return {
    results: withExplanations,
    lastDoc: results.length > 0 ? results[results.length - 1].docRef : null,
    hasMore,
  };
}
```

**Client-Side**:

```dart
// Flutter
class SearchResultsState {
  List<SearchResult> results = [];
  DocumentSnapshot? lastDoc;
  bool hasMore = true;
  bool isLoadingMore = false;
  
  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore) return;
    
    isLoadingMore = true;
    
    final response = await searchRepository.searchWithPagination(
      interpretation: currentInterpretation,
      startAfter: lastDoc,
    );
    
    results.addAll(response.results);
    lastDoc = response.lastDoc;
    hasMore = response.hasMore;
    isLoadingMore = false;
  }
}
```

---

## Performance Optimization

### 1. Prefetch Next Page

**Strategy**: Start fetching next page when user scrolls to 80% of current results.

```dart
ScrollController _scrollController = ScrollController();

@override
void initState() {
  super.initState();
  _scrollController.addListener(() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMore();
    }
  });
}
```

### 2. Result Caching (Client-Side)

**Strategy**: Cache results for 5 minutes.

```dart
class SearchCache {
  final Map<String, CachedSearchResults> _cache = {};
  
  void cache(String cacheKey, List<SearchResult> results) {
    _cache[cacheKey] = CachedSearchResults(
      results: results,
      timestamp: DateTime.now(),
    );
  }
  
  List<SearchResult>? get(String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached == null) return null;
    
    final age = DateTime.now().difference(cached.timestamp);
    if (age.inMinutes > 5) {
      _cache.remove(cacheKey);
      return null;
    }
    
    return cached.results;
  }
}
```

### 3. Firestore Read Minimization

**Strategy**: Fetch only required fields in list view.

```typescript
firestoreQuery = firestoreQuery.select(
  'id', 'title', 'photo', 'categoryTitle', 
  'averageRating', 'reviewsCount', 'priceMin', 'priceMax',
  'latitude', 'longitude', 'place', 'verified'
);
```

Full data fetched only when user taps result.

### 4. Index Optimization

**Strategy**: Ensure compound indexes exist for all query patterns.

**Monitor**: Firestore logs for missing index warnings.

---

## Optional: AI-Powered Reranking

**Use Case**: Refine top 50 results using semantic similarity.

**Note**: This is **optional** and adds cost/latency. Only use for high-value queries (e.g., premium users).

**Implementation**:

```typescript
import { gemini } from './gemini_service';

async function aiRerank(
  results: RankedSearchResult[],
  query: string,
  topN: number = 50
): Promise<RankedSearchResult[]> {
  
  const topResults = results.slice(0, topN);
  
  // Generate embeddings for query
  const queryEmbedding = await gemini.embedContent({
    model: 'models/embedding-001',
    content: { parts: [{ text: query }] },
  });
  
  // Generate embeddings for each result
  const resultEmbeddings = await Promise.all(
    topResults.map((r) =>
      gemini.embedContent({
        model: 'models/embedding-001',
        content: { parts: [{ text: r.title + ' ' + r.description }] },
      })
    )
  );
  
  // Calculate cosine similarity
  const reranked = topResults.map((r, i) => ({
    ...r,
    semanticScore: cosineSimilarity(queryEmbedding.embedding.values, resultEmbeddings[i].embedding.values),
  }));
  
  // Re-sort by combined score
  reranked.sort((a, b) => 
    (b.score * 0.7 + b.semanticScore * 0.3) - (a.score * 0.7 + a.semanticScore * 0.3)
  );
  
  // Merge reranked results with rest
  return [...reranked, ...results.slice(topN)];
}

function cosineSimilarity(a: number[], b: number[]): number {
  const dotProduct = a.reduce((sum, val, i) => sum + val * b[i], 0);
  const magnitudeA = Math.sqrt(a.reduce((sum, val) => sum + val * val, 0));
  const magnitudeB = Math.sqrt(b.reduce((sum, val) => sum + val * val, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}
```

**Cost**: ~$0.0001 per result (embeddings) × 50 results = $0.005 per query.

**Decision**: Enable only for Professional/Business tier users.

---

## Testing & Validation

### Test Cases

| Query | Expected Top Result | Reason |
|-------|---------------------|--------|
| "barber Gulf City" | Barber in Gulf City with highest rating | Location + category match |
| "cheap car rental" | Lowest priced car rental | Price sort |
| "top rated plumber" | Plumber with 4.8+ rating, 50+ reviews | Quality filter |
| "pizza near me open now" | Closest open pizza place | Distance + availability |
| "deals ending soon" | Deal expiring in < 3 days | Deal-specific sort |

### Ranking Quality Metrics

1. **NDCG (Normalized Discounted Cumulative Gain)**: Measure ranking quality
2. **Click-Through Rate (CTR)**: % of results clicked in first 5 positions (target: > 40%)
3. **Time to First Click**: How long until user clicks a result (target: < 5s)

---

## Next Steps

1. Implement retrieval and ranking functions
2. Test with 100+ queries across diverse categories
3. Tune scoring weights based on user engagement data
4. Optimize Firestore compound indexes

---

**Document Owner**: CaribTap Backend Team  
**Reviewers**: Engineering, Product, Data Science  
**Next Review**: After initial testing
