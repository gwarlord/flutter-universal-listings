# CaribTap AI-Assisted Search - Data & Indexing Strategy

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Search Index Schema](#search-index-schema)
3. [Denormalization Strategy](#denormalization-strategy)
4. [Index Maintenance](#index-maintenance)
5. [Geospatial Indexing](#geospatial-indexing)
6. [Firestore Compound Indexes](#firestore-compound-indexes)
7. [Performance Optimization](#performance-optimization)

---

## Overview

### Design Principles

1. **Additive Only**: New collections added; existing `listings` and `deal_ads` collections UNCHANGED
2. **Denormalized for Speed**: Search index contains flattened, optimized data for fast queries
3. **Eventual Consistency**: Index updates triggered by Cloud Functions; brief lag acceptable
4. **Cost-Effective**: Minimize Firestore reads through denormalization and pagination

### New Firestore Collections

```
/search_index_listings/{listingId}      ← Denormalized listing data for search
/search_index_deals/{dealId}             ← Denormalized deal data for search
/search_query_cache/{cacheKey}           ← Cached AI interpretations (1-hour TTL)
/saved_searches/{searchId}               ← User-saved searches
/search_rate_limits/{userId}             ← Rate limiting tracker
```

---

## Search Index Schema

### 1. `search_index_listings/{listingId}`

**Purpose**: Flattened, searchable representation of listings optimized for retrieval.

**Schema**:

```typescript
interface SearchIndexListing {
  // ===== Core Identity =====
  id: string;                    // Same as listing doc ID
  sourceCollection: 'listings';  // For unified search
  
  // ===== Searchable Text Fields =====
  title: string;
  titleLower: string;            // Lowercase for case-insensitive search
  description: string;
  descriptionLower: string;
  place: string;
  placeLower: string;
  searchKeywords: string[];      // Extracted keywords: ["barber", "haircut", "salon"]
  
  // ===== Category =====
  categoryID: string;
  categoryTitle: string;
  categoryTitleLower: string;
  
  // ===== Location =====
  latitude: number;
  longitude: number;
  geohash: string;               // Geohash (precision 6 for ~1.2km) for location queries
  countryCode: string;           // e.g., "TT" for Trinidad
  
  // ===== Price =====
  priceMin: number | null;       // Parsed numeric value (or null if free/not applicable)
  priceMax: number | null;
  currencyCode: string;
  
  // ===== Quality Signals =====
  reviewsCount: number;
  reviewsSum: number;
  averageRating: number;         // Computed: reviewsSum / reviewsCount
  viewCount: number;
  verified: boolean;             // Vouched badge
  isFeatured: boolean;
  
  // ===== Status / Availability =====
  isActive: boolean;             // !suspended && isApproved
  suspended: boolean;
  isApproved: boolean;
  bookingEnabled: boolean;
  chatEnabled: boolean;
  
  // ===== Opening Hours (parsed for "open now") =====
  openingHours: string;          // Raw string
  isOpenNow: boolean | null;     // Null if hours not parsable
  
  // ===== Author =====
  authorID: string;
  authorName: string;
  
  // ===== Timestamps =====
  createdAt: number;             // Seconds since epoch
  updatedAt: number;             // For freshness
  freshnessStatus: string;       // "ACTIVE", "WARN_10", "WARN_1", "HIDDEN"
  
  // ===== Media =====
  photo: string;                 // Primary image URL
  hasVideos: boolean;
  
  // ===== Custom Filters (optional) =====
  filters: { [key: string]: string }; // E.g., {"delivery": "yes", "parking": "yes"}
  
  // ===== Indexed At =====
  indexedAt: Timestamp;          // When this doc was last indexed
}
```

**Estimated Size**: ~1-2 KB per doc (well within Firestore limits).

---

### 2. `search_index_deals/{dealId}`

**Purpose**: Flattened, searchable representation of deals.

**Schema**:

```typescript
interface SearchIndexDeal {
  // ===== Core Identity =====
  id: string;
  sourceCollection: 'deal_ads';
  
  // ===== Searchable Text Fields =====
  caption: string;
  captionLower: string;
  searchKeywords: string[];
  
  // ===== Associated Listing Info =====
  listingId: string;
  listingTitle: string;
  listingCategoryID: string;
  listingCategoryTitle: string;
  
  // ===== Location (from associated listing) =====
  latitude: number;
  longitude: number;
  geohash: string;
  countryCode: string;
  
  // ===== Deal-Specific =====
  redemptionType: string;        // "PROMO_CODE" | "IN_APP_CLAIM"
  promoCode: string | null;
  redemptionLimitTotal: number | null;
  redemptionLimitPerUser: number | null;
  redemptionCountTotal: number;
  
  // ===== Engagement Signals =====
  viewCount: number;
  saveCount: number;
  claimCount: number;
  popularityScore: number;       // Computed: (viewCount * 0.1 + saveCount * 1 + claimCount * 2)
  
  // ===== Timing =====
  startDate: Timestamp;
  endDate: Timestamp;
  expireAt: Timestamp;
  isActive: boolean;             // !expired && status=='approved'
  daysRemaining: number;         // Computed daily
  
  // ===== Status =====
  status: string;                // "pending", "approved", "rejected", "expired"
  
  // ===== Author =====
  listerId: string;
  authorID: string;
  
  // ===== Targeting =====
  visibilityCountries: string[]; // Empty = all
  adType: string;                // "advert" | "promo"
  targetingSummary: string;
  
  // ===== Media =====
  mediaUrl: string;
  mediaType: string;             // "image" | "video"
  thumbnailUrl: string | null;
  
  // ===== Timestamps =====
  createdAt: number;
  updatedAt: number;
  
  // ===== Indexed At =====
  indexedAt: Timestamp;
}
```

---

### 3. `search_query_cache/{cacheKey}`

**Purpose**: Cache AI interpretations to reduce costs and latency.

**Schema**:

```typescript
interface SearchQueryCache {
  cacheKey: string;              // Hash of normalized query + contentType
  query: string;                 // Original query
  contentType: 'all' | 'listings' | 'deals';
  
  interpretation: {              // AI output (see AI_SEARCH_AI_INTERPRETATION.md)
    intent: string;
    category: string | null;
    location: {
      place: string | null;
      coordinates: { lat: number; lng: number } | null;
      radius: number | null;
    };
    priceRange: { min: number | null; max: number | null } | null;
    filters: { [key: string]: any };
    sortBy: string | null;
    extractedKeywords: string[];
    confidence: number;
  };
  
  createdAt: Timestamp;
  expiresAt: Timestamp;          // TTL: 1 hour (default)
  hitCount: number;              // Analytics: how often this cache entry was used
}
```

**TTL**: 1 hour (Cloud Function sets expiresAt).

**Cache Key Generation**:
```typescript
function generateCacheKey(query: string, contentType: string): string {
  const normalized = query.trim().toLowerCase();
  return crypto
    .createHash('sha256')
    .update(`${normalized}:${contentType}`)
    .digest('hex');
}
```

---

### 4. `saved_searches/{searchId}`

**Purpose**: User-saved searches for quick re-execution and notifications.

**Schema**:

```typescript
interface SavedSearch {
  id: string;                    // Auto-generated doc ID
  userId: string;
  
  // Query
  queryText: string;             // E.g., "barber near Gulf City"
  friendlyName: string;          // User-editable name
  contentType: 'all' | 'listings' | 'deals';
  
  // Filters (from AI interpretation + user edits)
  filters: {
    category: string | null;
    location: { place: string; radius: number } | null;
    priceRange: { min: number; max: number } | null;
    quality: { onlyVouched: boolean; minRating: number | null };
    availability: { openNow: boolean; delivery: boolean };
    [key: string]: any;          // Extensible
  };
  
  // Notifications
  notificationsEnabled: boolean;
  lastNotificationSentAt: Timestamp | null;
  matchCountAtLastNotification: number;
  
  // Metadata
  createdAt: Timestamp;
  lastRunAt: Timestamp | null;
  runCount: number;
}
```

---

### 5. `search_rate_limits/{userId}`

**Purpose**: Track per-user rate limits for AI queries.

**Schema**:

```typescript
interface SearchRateLimit {
  userId: string;
  
  // Per-minute limits
  requestsThisMinute: number;
  currentMinuteWindow: Timestamp; // Start of current 1-minute window
  
  // Per-day limits
  requestsToday: number;
  currentDayWindow: string;       // YYYY-MM-DD
  
  // Tier info (denormalized from user doc for performance)
  subscriptionTier: string;       // "free", "pro", "premium", "business"
  
  // Violations
  violationCount: number;
  lastViolationAt: Timestamp | null;
  
  // Metadata
  updatedAt: Timestamp;
}
```

---

## Denormalization Strategy

### Why Denormalize?

1. **Reduce Firestore Reads**: Single query to `search_index_listings` instead of multiple queries + joins
2. **Faster Queries**: All search-relevant data in one doc
3. **Computed Fields**: Pre-compute derived values (e.g., `averageRating`, `isOpenNow`)

### What to Denormalize

| Source Collection | Denormalized To | Fields |
|-------------------|-----------------|--------|
| `listings` | `search_index_listings` | All searchable fields + computed values |
| `deal_ads` | `search_index_deals` | All searchable fields + associated listing info |
| `users` | `search_rate_limits` | `subscriptionTier` (for quick rate limit checks) |

### Update Triggers

#### Trigger 1: `onListingCreate` / `onListingUpdate`

```typescript
// functions/src/search_index_triggers.ts

export const onListingWritten = functions.firestore
  .document('listings/{listingId}')
  .onWrite(async (change, context) => {
    const listingId = context.params.listingId;
    
    if (!change.after.exists) {
      // Listing deleted → delete from index
      await admin.firestore()
        .collection('search_index_listings')
        .doc(listingId)
        .delete();
      return;
    }
    
    const listing = change.after.data() as ListingModel;
    
    // Build search index doc
    const indexDoc: SearchIndexListing = {
      id: listingId,
      sourceCollection: 'listings',
      title: listing.title,
      titleLower: listing.title.toLowerCase(),
      description: listing.description,
      descriptionLower: listing.description.toLowerCase(),
      place: listing.place,
      placeLower: listing.place.toLowerCase(),
      searchKeywords: extractKeywords(listing.title + ' ' + listing.description + ' ' + listing.categoryTitle),
      categoryID: listing.categoryID,
      categoryTitle: listing.categoryTitle,
      categoryTitleLower: listing.categoryTitle.toLowerCase(),
      latitude: listing.latitude,
      longitude: listing.longitude,
      geohash: geohashEncode(listing.latitude, listing.longitude, 6),
      countryCode: listing.countryCode || 'TT',
      priceMin: parsePriceMin(listing.price),
      priceMax: parsePriceMax(listing.price),
      currencyCode: listing.currencyCode || 'TTD',
      reviewsCount: listing.reviewsCount || 0,
      reviewsSum: listing.reviewsSum || 0,
      averageRating: (listing.reviewsCount > 0) ? (listing.reviewsSum / listing.reviewsCount) : 0,
      viewCount: listing.viewCount || 0,
      verified: listing.verified || false,
      isFeatured: listing.isFeatured || false,
      isActive: !listing.suspended && listing.isApproved,
      suspended: listing.suspended || false,
      isApproved: listing.isApproved || false,
      bookingEnabled: listing.bookingEnabled || false,
      chatEnabled: listing.chatEnabled !== false, // Default true
      openingHours: listing.openingHours || '',
      isOpenNow: computeIsOpenNow(listing.openingHours),
      authorID: listing.authorID,
      authorName: listing.authorName,
      createdAt: listing.createdAt,
      updatedAt: admin.firestore.Timestamp.now().seconds,
      freshnessStatus: listing.freshness?.status || 'ACTIVE',
      photo: listing.photo || '',
      hasVideos: (listing.videos?.length > 0),
      filters: listing.filters || {},
      indexedAt: admin.firestore.Timestamp.now(),
    };
    
    // Write to index
    await admin.firestore()
      .collection('search_index_listings')
      .doc(listingId)
      .set(indexDoc);
  });
```

#### Trigger 2: `onDealAdWritten`

```typescript
export const onDealAdWritten = functions.firestore
  .document('deal_ads/{dealId}')
  .onWrite(async (change, context) => {
    const dealId = context.params.dealId;
    
    if (!change.after.exists) {
      await admin.firestore()
        .collection('search_index_deals')
        .doc(dealId)
        .delete();
      return;
    }
    
    const deal = change.after.data() as DealAdModel;
    
    // Fetch associated listing for location/category
    const listingSnap = await admin.firestore()
      .collection('listings')
      .doc(deal.listingId)
      .get();
    
    const listing = listingSnap.data() as ListingModel | undefined;
    
    const indexDoc: SearchIndexDeal = {
      id: dealId,
      sourceCollection: 'deal_ads',
      caption: deal.caption,
      captionLower: deal.caption.toLowerCase(),
      searchKeywords: extractKeywords(deal.caption + ' ' + (listing?.title || '')),
      listingId: deal.listingId,
      listingTitle: listing?.title || '',
      listingCategoryID: listing?.categoryID || '',
      listingCategoryTitle: listing?.categoryTitle || '',
      latitude: listing?.latitude || 0,
      longitude: listing?.longitude || 0,
      geohash: listing ? geohashEncode(listing.latitude, listing.longitude, 6) : '',
      countryCode: listing?.countryCode || 'TT',
      redemptionType: deal.redemptionType || 'IN_APP_CLAIM',
      promoCode: deal.promoCode || null,
      redemptionLimitTotal: deal.redemptionLimitTotal || null,
      redemptionLimitPerUser: deal.redemptionLimitPerUser || null,
      redemptionCountTotal: deal.redemptionCountTotal || 0,
      viewCount: deal.viewCount || 0,
      saveCount: deal.saveCount || 0,
      claimCount: deal.claimCount || 0,
      popularityScore: computePopularityScore(deal),
      startDate: deal.startDate,
      endDate: deal.endDate,
      expireAt: deal.expireAt,
      isActive: (deal.status === 'approved') && (deal.expireAt.toDate() > new Date()),
      daysRemaining: computeDaysRemaining(deal.expireAt),
      status: deal.status,
      listerId: deal.listerId,
      authorID: deal.authorID,
      visibilityCountries: deal.visibilityCountries || [],
      adType: deal.adType || 'promo',
      targetingSummary: deal.targetingSummary || '',
      mediaUrl: deal.mediaUrl,
      mediaType: deal.mediaType,
      thumbnailUrl: deal.thumbnailUrl || null,
      createdAt: deal.createdAt.seconds,
      updatedAt: admin.firestore.Timestamp.now().seconds,
      indexedAt: admin.firestore.Timestamp.now(),
    };
    
    await admin.firestore()
      .collection('search_index_deals')
      .doc(dealId)
      .set(indexDoc);
  });
```

---

## Index Maintenance

### Daily Consistency Check (Scheduled Function)

**Purpose**: Ensure index stays in sync with source collections (handles edge cases like failed triggers).

**Schedule**: Daily at 2am UTC.

```typescript
// functions/src/scheduled_backfill.ts

export const scheduledBackfillSearchIndex = functions.pubsub
  .schedule('0 2 * * *') // Every day at 2am UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    const batch = admin.firestore().batch();
    let updates = 0;
    
    // 1. Check for listings not in index
    const listingsSnap = await admin.firestore()
      .collection('listings')
      .where('suspended', '==', false)
      .limit(1000) // Process in batches
      .get();
    
    for (const doc of listingsSnap.docs) {
      const indexDoc = await admin.firestore()
        .collection('search_index_listings')
        .doc(doc.id)
        .get();
      
      if (!indexDoc.exists) {
        // Missing from index → add it
        const listing = doc.data() as ListingModel;
        batch.set(
          admin.firestore().collection('search_index_listings').doc(doc.id),
          buildSearchIndexListing(listing, doc.id)
        );
        updates++;
      }
    }
    
    // 2. Check for orphaned index docs (listing deleted but index remains)
    const indexSnap = await admin.firestore()
      .collection('search_index_listings')
      .limit(1000)
      .get();
    
    for (const doc of indexSnap.docs) {
      const listingDoc = await admin.firestore()
        .collection('listings')
        .doc(doc.id)
        .get();
      
      if (!listingDoc.exists) {
        // Orphaned → delete from index
        batch.delete(doc.ref);
        updates++;
      }
    }
    
    if (updates > 0) {
      await batch.commit();
      console.log(`Scheduled backfill: ${updates} updates`);
    }
    
    // Repeat for deals...
  });
```

---

## Geospatial Indexing

**Approach**: Use **geohash** for efficient radius-based queries.

### Geohash Precision Levels

| Precision | Cell Width | Use Case |
|-----------|-----------|----------|
| 4 | ~20 km | Country-level |
| 5 | ~5 km | City-level |
| 6 | ~1.2 km | Neighborhood-level (RECOMMENDED) |
| 7 | ~150 m | Street-level |

**Why Precision 6?**
- Balance between precision and query efficiency
- Most searches are neighborhood-level ("near Gulf City")
- Firestore index on `geohash` enables efficient prefix queries

### Computing Geohash

```typescript
import * as geohash from 'ngeohash';

function geohashEncode(lat: number, lng: number, precision: number = 6): string {
  return geohash.encode(lat, lng, precision);
}
```

### Querying by Radius

**Strategy**: Compute geohash bounding box.

```typescript
function getGeohashRange(centerLat: number, centerLng: number, radiusKm: number): { lower: string; upper: string } {
  // Compute bounding box geohashes
  const centerGeohash = geohashEncode(centerLat, centerLng, 6);
  
  // Approximate: increase geohash prefix based on radius
  // For 5km radius, use same precision (6)
  // For larger radius, reduce precision
  
  const precision = radiusKm <= 5 ? 6 : (radiusKm <= 20 ? 5 : 4);
  
  const lower = centerGeohash.substring(0, precision);
  const upper = lower.slice(0, -1) + String.fromCharCode(lower.charCodeAt(lower.length - 1) + 1);
  
  return { lower, upper };
}

// Firestore query
const { lower, upper } = getGeohashRange(centerLat, centerLng, 5);
const results = await admin.firestore()
  .collection('search_index_listings')
  .where('geohash', '>=', lower)
  .where('geohash', '<', upper)
  .where('isActive', '==', true)
  .limit(50)
  .get();
```

**Post-Processing**: Filter by exact distance (Haversine formula) on client or server.

```typescript
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Filter results
const filtered = results.filter((doc) => {
  const data = doc.data();
  const distance = calculateDistance(centerLat, centerLng, data.latitude, data.longitude);
  return distance <= radiusKm;
});
```

---

## Firestore Compound Indexes

**Required Indexes** (create via Firebase Console or `firestore.indexes.json`):

### Index 1: Listings by Category + Active + Rating
```json
{
  "collectionGroup": "search_index_listings",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "categoryID", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "averageRating", "order": "DESCENDING" }
  ]
}
```

### Index 2: Listings by Geohash + Active
```json
{
  "collectionGroup": "search_index_listings",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "geohash", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "averageRating", "order": "DESCENDING" }
  ]
}
```

### Index 3: Deals by Active + Days Remaining
```json
{
  "collectionGroup": "search_index_deals",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "daysRemaining", "order": "ASCENDING" }
  ]
}
```

### Index 4: Deals by Geohash + Active
```json
{
  "collectionGroup": "search_index_deals",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "geohash", "order": "ASCENDING" },
    { "fieldPath": "isActive", "order": "ASCENDING" },
    { "fieldPath": "popularityScore", "order": "DESCENDING" }
  ]
}
```

**Note**: More indexes may be needed based on query patterns. Monitor Firestore logs for missing index errors.

---

## Performance Optimization

### 1. Pagination

**Strategy**: Cursor-based pagination (not offset-based).

```typescript
// First page
let query = admin.firestore()
  .collection('search_index_listings')
  .where('isActive', '==', true)
  .orderBy('averageRating', 'desc')
  .limit(20);

const firstPage = await query.get();

// Next page
const lastDoc = firstPage.docs[firstPage.docs.length - 1];
query = query.startAfter(lastDoc);
const secondPage = await query.get();
```

### 2. Caching Strategy

**Client-Side**:
- Cache recent search results (5 minutes)
- Use `shared_preferences` to store last 10 searches

**Server-Side**:
- Cache AI interpretations in `search_query_cache` (1 hour)
- Cache geohash bounding box calculations (1 hour)

### 3. Field Selection

**Minimize Data Transfer**: Only fetch fields needed for result cards.

```typescript
const results = await admin.firestore()
  .collection('search_index_listings')
  .where('isActive', '==', true)
  .select(
    'id', 'title', 'categoryTitle', 'photo', 'averageRating', 
    'reviewsCount', 'priceMin', 'priceMax', 'latitude', 'longitude', 
    'verified', 'place'
  )
  .limit(20)
  .get();
```

### 4. Batch Reads

When fetching listings for details (after search), use batch reads:

```typescript
const batch = admin.firestore().batch();
const listingIds = resultIds.slice(0, 10); // Max 10 per batch

const promises = listingIds.map((id) =>
  admin.firestore().collection('listings').doc(id).get()
);

const listings = await Promise.all(promises);
```

---

## Cost Estimate

### Firestore Read Costs

- **Index Creation**: One-time batch write (100K listings × 1 write = $0.18)
- **Ongoing Updates**: ~1000 listing updates/day × 2 writes (source + index) = $0.36/day
- **Search Queries**: Avg 20 reads/search × 10K searches/day = 200K reads/day = $1.20/day

**Monthly**: ~$50/month for reads/writes at scale.

### Storage Costs

- **Search Index**: 100K docs × 2 KB = 200 MB = $0.036/month (negligible)

**Total Estimated Monthly Cost**: ~$50-60 for Firestore at 10K searches/day.

---

## Firestore Security Rules

**Add to `firestore.rules`**:

```javascript
// Search Index: Read-only for authenticated users
match /search_index_listings/{listingId} {
  allow read: if request.auth != null;
  allow write: if false; // Only Cloud Functions can write
}

match /search_index_deals/{dealId} {
  allow read: if request.auth != null;
  allow write: if false;
}

// Query Cache: Read-only for authenticated users
match /search_query_cache/{cacheKey} {
  allow read: if request.auth != null;
  allow write: if false;
}

// Saved Searches: User owns their searches
match /saved_searches/{searchId} {
  allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
  allow create: if request.auth != null && request.auth.uid == request.resource.data.userId;
}

// Rate Limits: Read-only for users (write by Cloud Functions only)
match /search_rate_limits/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if false;
}
```

---

## Migration Plan

### Phase 1: Create Collections (Week 1)

1. Deploy Cloud Functions for index triggers (disabled initially)
2. Run one-time backfill script to populate `search_index_listings` and `search_index_deals`
3. Verify data integrity (spot checks)

**Backfill Script**:

```typescript
// Run locally or as one-time Cloud Function
async function backfillSearchIndex() {
  const listingsSnap = await admin.firestore().collection('listings').get();
  const batch = admin.firestore().batch();
  
  let count = 0;
  for (const doc of listingsSnap.docs) {
    const listing = doc.data() as ListingModel;
    const indexDoc = buildSearchIndexListing(listing, doc.id);
    
    batch.set(
      admin.firestore().collection('search_index_listings').doc(doc.id),
      indexDoc
    );
    
    count++;
    if (count % 500 === 0) {
      await batch.commit();
      console.log(`Backfilled ${count} listings`);
    }
  }
  
  await batch.commit();
  console.log(`Total backfilled: ${count} listings`);
}
```

### Phase 2: Enable Triggers (Week 2)

1. Enable Cloud Functions triggers
2. Monitor for 1 week
3. Verify new listings/deals are indexed within 1 minute

### Phase 3: Deploy Search UI (Weeks 3-6)

Start using `search_index_*` collections in client app.

---

## Monitoring & Alerts

### Metrics to Track

1. **Index Lag**: Time between listing update and index update (target: < 30s)
2. **Index Size**: Number of docs in index vs source collections (should match ±1%)
3. **Read/Write Costs**: Daily Firestore costs
4. **Query Performance**: p95 latency for search queries (target: < 500ms)

### Alerts

- **Index Lag > 5 minutes**: Investigate trigger issues
- **Index Size Mismatch > 5%**: Run consistency check
- **Daily Cost > $10**: Review query patterns, optimize indexes

---

## Next Steps

1. **Review Schema**: Ensure all required fields included
2. **Implement Triggers**: Code review for index functions
3. **Test Backfill**: Run on staging environment with sample data
4. **Deploy**: Production rollout with monitoring

---

**Document Owner**: CaribTap Backend Team  
**Reviewers**: Engineering, DevOps  
**Next Review**: After Phase 1 completion
