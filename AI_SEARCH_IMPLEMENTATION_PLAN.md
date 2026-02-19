# CaribTap AI-Assisted Search - Implementation Plan

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Implementation Phases](#implementation-phases)
3. [File Organization](#file-organization)
4. [Development Guidelines](#development-guidelines)
5. [Deployment Strategy](#deployment-strategy)
6. [Security Rules](#security-rules)
7. [Dependencies](#dependencies)

---

## Project Structure

### Flutter App Structure

```
lib/
├── listings/
│   ├── ai_search/                          # NEW MODULE
│   │   ├── blocs/
│   │   │   ├── ai_search_cubit.dart
│   │   │   └── ai_search_state.dart
│   │   ├── models/
│   │   │   ├── search_interpretation.dart
│   │   │   ├── search_result.dart
│   │   │   ├── saved_search.dart
│   │   │   └── search_filter.dart
│   │   ├── repositories/
│   │   │   └── ai_search_repository.dart
│   │   ├── services/
│   │   │   ├── ai_interpretation_service.dart
│   │   │   ├── search_rate_limit_service.dart
│   │   │   └── geolocation_service.dart
│   │   ├── ui/
│   │   │   ├── screens/
│   │   │   │   ├── ai_search_screen.dart
│   │   │   │   ├── search_results_screen.dart
│   │   │   │   └── saved_searches_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── ai_search_bar.dart
│   │   │   │   ├── search_result_card.dart
│   │   │   │   ├── explainability_chip.dart
│   │   │   │   ├── filter_chip_group.dart
│   │   │   │   ├── conversation_bubble.dart
│   │   │   │   └── rate_limit_dialog.dart
│   │   │   └── ai_search_module.dart
│   │   └── utils/
│   │       ├── search_helpers.dart
│   │       └── search_constants.dart
│   └── listings_module/
│       └── search/                          # EXISTING (KEEP)
│           └── search_bloc.dart             # Fallback keyword search
```

### Cloud Functions Structure

```
functions/
├── src/
│   ├── ai_search/                           # NEW MODULE
│   │   ├── interpretation/
│   │   │   ├── interpret_query.ts
│   │   │   ├── gemini_client.ts
│   │   │   └── query_sanitizer.ts
│   │   ├── indexing/
│   │   │   ├── index_listing_trigger.ts
│   │   │   ├── index_deal_trigger.ts
│   │   │   └── index_builder.ts
│   │   ├── retrieval/
│   │   │   ├── retrieve_candidates.ts
│   │   │   ├── score_results.ts
│   │   │   └── explainability.ts
│   │   ├── rate_limiting/
│   │   │   ├── rate_limiter.ts
│   │   │   └── abuse_detector.ts
│   │   ├── analytics/
│   │   │   ├── log_search.ts
│   │   │   └── aggregate_costs.ts
│   │   └── index.ts                         # Export all functions
│   └── index.ts                             # Root exports
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal**: Set up data models, Cloud Functions skeleton, basic UI.

**Tasks**:

#### Backend
- [ ] **Setup Cloud Functions project structure**
  - Create `functions/src/ai_search/` directory
  - Install dependencies (`@google-cloud/aiplatform`, `geofire-common`)
  - Configure TypeScript paths

- [ ] **Create Firestore collections**
  - Deploy empty collections with indexes:
    ```bash
    firebase deploy --only firestore:indexes
    ```

- [ ] **Implement basic Gemini AI client**
  - File: `functions/src/ai_search/interpretation/gemini_client.ts`
  - Test with sample queries in Firebase Functions emulator

#### Frontend
- [ ] **Create search models**
  - `search_interpretation.dart`
  - `search_result.dart`
  - `search_filter.dart`

- [ ] **Implement basic UI skeleton**
  - `ai_search_screen.dart` (just search bar + placeholder)
  - `search_results_screen.dart` (just list view)

**Deliverable**: User can type query, see "Coming Soon" message.

---

### Phase 2: AI Interpretation (Week 3-4)

**Goal**: Connect AI interpretation pipeline.

**Tasks**:

#### Backend
- [ ] **Implement `interpretSearchQuery` Cloud Function**
  - File: `functions/src/ai_search/interpretation/interpret_query.ts`
  - Input validation & sanitization
  - Gemini API call with structured JSON output
  - Return `SearchInterpretation` object

- [ ] **Add query caching**
  - Check `search_query_cache` before calling AI
  - Store AI responses with 1-hour TTL

- [ ] **Deploy Cloud Function**
  ```bash
  firebase deploy --only functions:interpretSearchQuery
  ```

#### Frontend
- [ ] **Create `AiInterpretationService`**
  - File: `lib/listings/ai_search/services/ai_interpretation_service.dart`
  - Call Cloud Function via Firebase Functions SDK
  - Parse response into `SearchInterpretation` model

- [ ] **Update UI to show interpretation**
  - Display detected filters as chips
  - Show "Searching for [category] in [location]"

**Deliverable**: User types "barbers near me", sees "Searching for Hair & Beauty in Your Area".

---

### Phase 3: Data Indexing (Week 4-5)

**Goal**: Build search indexes for listings and deals.

**Tasks**:

#### Backend
- [ ] **Implement indexing triggers**
  - `onListingWrite` trigger → update `search_index_listings`
  - `onDealWrite` trigger → update `search_index_deals`
  - Files:
    - `functions/src/ai_search/indexing/index_listing_trigger.ts`
    - `functions/src/ai_search/indexing/index_deal_trigger.ts`

- [ ] **Implement geohash indexing**
  - Use `geofire-common` to compute geohashes
  - Store in `geohashPrecision6` field

- [ ] **Backfill existing data**
  - Create one-time Cloud Function to index all existing listings:
    ```typescript
    export const backfillSearchIndex = functions.https.onRequest(async (req, res) => {
      const listings = await admin.firestore().collection('listings').get();
      
      for (const doc of listings.docs) {
        await indexListing(doc.data());
      }
      
      res.send(`Indexed ${listings.size} listings`);
    });
    ```
  - Call via curl: `curl https://us-central1-caribtap.cloudfunctions.net/backfillSearchIndex`

**Deliverable**: All listings have corresponding search index documents.

---

### Phase 4: Search Retrieval (Week 5-7)

**Goal**: Retrieve and rank search results.

**Tasks**:

#### Backend
- [ ] **Implement `searchListings` Cloud Function**
  - File: `functions/src/ai_search/retrieval/retrieve_candidates.ts`
  - Build Firestore query from interpretation
  - Apply filters (category, location, price, etc.)
  - Handle geohash range queries

- [ ] **Implement scoring algorithm**
  - File: `functions/src/ai_search/retrieval/score_results.ts`
  - Four components: relevance, quality, distance, freshness
  - Weight: 40%, 30%, 20%, 10%

- [ ] **Implement explainability**
  - File: `functions/src/ai_search/retrieval/explainability.ts`
  - Generate chips: "Near you", "Vouched", "Top rated", etc.
  - Return with each result

- [ ] **Deploy Cloud Function**
  ```bash
  firebase deploy --only functions:searchListings
  ```

#### Frontend
- [ ] **Create `AiSearchRepository`**
  - File: `lib/listings/ai_search/repositories/ai_search_repository.dart`
  - Call `searchListings` Cloud Function
  - Parse results into `SearchResult` models

- [ ] **Implement `AiSearchCubit`**
  - File: `lib/listings/ai_search/blocs/ai_search_cubit.dart`
  - States: idle, loading, loaded, error
  - Methods: `search()`, `refine()`, `loadMore()`

- [ ] **Update `SearchResultsScreen`**
  - Display results in list
  - Show explainability chips
  - Handle empty state

**Deliverable**: User searches "restaurants trinidad", sees real results with chips.

---

### Phase 5: UI Polish (Week 7-8)

**Goal**: Refine UX, add animations, conversational refinement.

**Tasks**:

#### Frontend
- [ ] **Implement conversational refinement**
  - Add "Refine Search" button
  - Show conversation bubbles (user query → AI response)
  - Update filters without re-searching

- [ ] **Add animations**
  - Shimmer loading effect
  - Slide-in result cards
  - Chip tap animations

- [ ] **Implement filter chip groups**
  - Category chips (scrollable)
  - Location chips
  - Price range slider

- [ ] **Saved Searches feature**
  - File: `saved_searches_screen.dart`
  - CRUD operations on `saved_searches` collection
  - Enable/disable notifications

- [ ] **Empty state illustrations**
  - "No results found" with suggestions
  - "Network error" with retry button

**Deliverable**: Beautiful, polished search experience.

---

### Phase 6: Monetization & Rate Limiting (Week 8-9)

**Goal**: Implement subscription tiers and rate limits.

**Tasks**:

#### Backend
- [ ] **Implement rate limiting**
  - File: `functions/src/ai_search/rate_limiting/rate_limiter.ts`
  - Check `search_rate_limits` collection
  - Enforce per-minute and per-day limits

- [ ] **Implement abuse detection**
  - File: `functions/src/ai_search/rate_limiting/abuse_detector.ts`
  - Detect spam, prompt injection, profanity
  - Flag and suspend users

- [ ] **Add rate limit middleware**
  - Apply to `interpretSearchQuery` and `searchListings` functions
  - Return rate limit headers

#### Frontend
- [ ] **Create `SearchRateLimitService`**
  - File: `lib/listings/ai_search/services/search_rate_limit_service.dart`
  - Check user's remaining searches
  - Show rate limit dialog when exceeded

- [ ] **Implement upgrade flow**
  - "Upgrade to Professional" dialog
  - Link to subscription screen

- [ ] **Add fallback to keyword search**
  - If rate limit exceeded, offer keyword search
  - Use existing `SearchBloc`

**Deliverable**: Free users limited to 5 searches/day with upgrade prompts.

---

### Phase 7: Analytics & Monitoring (Week 9-10)

**Goal**: Track usage, performance, and costs.

**Tasks**:

#### Backend
- [ ] **Implement search analytics logging**
  - File: `functions/src/ai_search/analytics/log_search.ts`
  - Log every search to `search_analytics` collection
  - Track: query, interpretation, results, latency, cache hits

- [ ] **Implement cost tracking**
  - Log AI query costs to `search_costs` collection
  - Daily aggregation function

- [ ] **Set up Firebase Cloud Monitoring alerts**
  - High error rate (>10%)
  - High latency (p95 >5s)
  - Cost spikes (>$50/day)

- [ ] **Create admin dashboard queries**
  - Top search queries
  - Search → view → action funnel
  - Average latency per tier

#### Frontend
- [ ] **Add Firebase Analytics events**
  - `search_initiated`
  - `search_results_viewed`
  - `search_result_clicked`
  - `search_saved`

- [ ] **Implement error reporting**
  - Use Crashlytics to log search errors
  - Include context: query, interpretation, user tier

**Deliverable**: Full visibility into search performance and costs.

---

### Phase 8: Testing & QA (Week 10)

**Goal**: Comprehensive testing before production launch.

**Tasks**:

- [ ] **Unit tests**
  - Test all models (serialization/deserialization)
  - Test services in isolation
  - Test Cubit state transitions

- [ ] **Integration tests**
  - End-to-end search flow
  - Rate limiting enforcement
  - Fallback behavior

- [ ] **Manual QA**
  - Test 50+ sample queries (see AI_SEARCH_TESTING.md)
  - Test on multiple devices (Android, iOS)
  - Test edge cases (no location, no results, etc.)

- [ ] **Performance testing**
  - Load test: 100 concurrent searches
  - Measure p50, p95, p99 latency
  - Verify cache hit rates >80%

- [ ] **Security audit**
  - Review Firestore security rules
  - Test authorization (can users access only their data?)
  - Test prompt injection defenses

**Deliverable**: All tests pass, ready for production.

---

## File Organization

### New Files to Create

#### Flutter (Dart)

| File Path | Purpose |
|-----------|---------|
| `lib/listings/ai_search/models/search_interpretation.dart` | AI interpretation model |
| `lib/listings/ai_search/models/search_result.dart` | Search result wrapper model |
| `lib/listings/ai_search/models/saved_search.dart` | Saved search model |
| `lib/listings/ai_search/models/search_filter.dart` | Filter models (category, price, etc.) |
| `lib/listings/ai_search/services/ai_interpretation_service.dart` | Call Cloud Function for AI interpretation |
| `lib/listings/ai_search/services/search_rate_limit_service.dart` | Check rate limits |
| `lib/listings/ai_search/services/geolocation_service.dart` | Get user location |
| `lib/listings/ai_search/repositories/ai_search_repository.dart` | Search repository (calls Cloud Functions) |
| `lib/listings/ai_search/blocs/ai_search_cubit.dart` | State management for search |
| `lib/listings/ai_search/blocs/ai_search_state.dart` | Search states |
| `lib/listings/ai_search/ui/screens/ai_search_screen.dart` | Main search screen |
| `lib/listings/ai_search/ui/screens/search_results_screen.dart` | Results screen |
| `lib/listings/ai_search/ui/screens/saved_searches_screen.dart` | Saved searches screen |
| `lib/listings/ai_search/ui/widgets/ai_search_bar.dart` | Search input widget |
| `lib/listings/ai_search/ui/widgets/search_result_card.dart` | Result card widget |
| `lib/listings/ai_search/ui/widgets/explainability_chip.dart` | Explainability chip widget |
| `lib/listings/ai_search/ui/widgets/filter_chip_group.dart` | Filter chips widget |
| `lib/listings/ai_search/ui/widgets/conversation_bubble.dart` | Conversational refinement bubbles |
| `lib/listings/ai_search/ui/widgets/rate_limit_dialog.dart` | Rate limit dialog |
| `lib/listings/ai_search/utils/search_helpers.dart` | Helper functions |
| `lib/listings/ai_search/utils/search_constants.dart` | Constants (chip colors, etc.) |

#### Cloud Functions (TypeScript)

| File Path | Purpose |
|-----------|---------|
| `functions/src/ai_search/interpretation/interpret_query.ts` | Main AI interpretation function |
| `functions/src/ai_search/interpretation/gemini_client.ts` | Gemini AI SDK client |
| `functions/src/ai_search/interpretation/query_sanitizer.ts` | Sanitize/validate queries |
| `functions/src/ai_search/indexing/index_listing_trigger.ts` | Firestore trigger for listing writes |
| `functions/src/ai_search/indexing/index_deal_trigger.ts` | Firestore trigger for deal writes |
| `functions/src/ai_search/indexing/index_builder.ts` | Build index documents |
| `functions/src/ai_search/retrieval/retrieve_candidates.ts` | Candidate retrieval logic |
| `functions/src/ai_search/retrieval/score_results.ts` | Scoring algorithm |
| `functions/src/ai_search/retrieval/explainability.ts` | Generate explainability chips |
| `functions/src/ai_search/rate_limiting/rate_limiter.ts` | Rate limiting enforcement |
| `functions/src/ai_search/rate_limiting/abuse_detector.ts` | Abuse detection (spam, injection, etc.) |
| `functions/src/ai_search/analytics/log_search.ts` | Log search to analytics |
| `functions/src/ai_search/analytics/aggregate_costs.ts` | Daily cost aggregation |
| `functions/src/ai_search/index.ts` | Export all AI search functions |

---

## Development Guidelines

### Code Style

**Dart (Flutter)**:
- Follow existing CaribTap patterns (BLoC/Cubit)
- Use `flutter_bloc` for state management
- Use `equatable` for models
- Follow `analysis_options.yaml` lint rules

**TypeScript (Functions)**:
- Use `async/await` (no callbacks)
- Enable strict mode in `tsconfig.json`
- Use `eslint` for linting
- Use descriptive variable names

### Naming Conventions

**Collections**:
- Lowercase with underscores: `search_index_listings`

**Fields**:
- camelCase: `searchableText`, `geohashPrecision6`

**Models**:
- PascalCase: `SearchInterpretation`, `SearchResult`

**Functions**:
- camelCase: `interpretSearchQuery()`, `checkRateLimit()`

### Error Handling

**Cloud Functions**:
```typescript
try {
  // Function logic
} catch (error) {
  console.error('Error in functionName:', error);
  throw new functions.https.HttpsError(
    'internal',
    'An error occurred processing your request',
    { originalError: error.message }
  );
}
```

**Flutter**:
```dart
try {
  final results = await _repository.search(query);
  emit(SearchLoaded(results));
} catch (e) {
  print('Search error: $e');
  emit(SearchError('Failed to search. Please try again.'));
  Crashlytics.recordError(e, StackTrace.current);
}
```

### Testing Requirements

**Every feature must have**:
- Unit tests (models, services)
- Widget tests (UI components)
- Integration tests (end-to-end flows)
- Manual QA checklist

**Test coverage target**: 80%+

---

## Deployment Strategy

### Development Environment

**Firebase Projects**:
- `caribtap-dev` (development/staging)
- `caribtap-prod` (production)

**Workflow**:
1. Develop locally with Firebase emulators
2. Deploy to `caribtap-dev` for testing
3. QA approval → deploy to `caribtap-prod`

### Deployment Commands

**Firestore Rules & Indexes**:
```bash
firebase deploy --only firestore:rules,firestore:indexes --project caribtap-dev
```

**Cloud Functions**:
```bash
# Deploy specific function
firebase deploy --only functions:interpretSearchQuery --project caribtap-dev

# Deploy all AI search functions
firebase deploy --only functions:ai_search --project caribtap-dev
```

**Flutter App**:
```bash
# Android
flutter build appbundle --release
# Upload to Google Play Console (internal testing track first)

# iOS
flutter build ipa --release
# Upload to TestFlight
```

### Rollout Plan

**Week 10**: Internal beta (CaribTap team only)  
**Week 11**: Closed beta (50 selected users)  
**Week 12**: Open beta (all users, feature flag enabled)  
**Week 13**: Production launch (announce publicly)

### Feature Flags

Use Firebase Remote Config:

```dart
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.setDefaults({
  'ai_search_enabled': false,
  'ai_search_beta_users': '[]', // JSON array of user IDs
});

await remoteConfig.fetchAndActivate();

bool isAiSearchEnabled() {
  if (!remoteConfig.getBool('ai_search_enabled')) return false;
  
  final betaUsers = jsonDecode(remoteConfig.getString('ai_search_beta_users')) as List;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  return betaUsers.contains(currentUserId);
}
```

**Gradual Rollout**:
- Week 10: `beta_users = [admin_uids]`
- Week 11: `beta_users = [50 user IDs]`
- Week 12: `ai_search_enabled = true` (all users)

---

## Security Rules

### Firestore Security Rules

Add to `firestore.rules`:

```javascript
// Search Index Collections (read-only for clients)
match /search_index_listings/{docId} {
  allow read: if request.auth != null;
  allow write: if false; // Only Cloud Functions can write
}

match /search_index_deals/{docId} {
  allow read: if request.auth != null;
  allow write: if false;
}

// Query Cache (read-only for clients)
match /search_query_cache/{docId} {
  allow read: if request.auth != null;
  allow write: if false;
}

// Saved Searches (user-specific)
match /saved_searches/{docId} {
  allow read: if request.auth != null && resource.data.userId == request.auth.uid;
  allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
  allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
}

// Rate Limits (user-specific read, Cloud Functions write)
match /search_rate_limits/{userId} {
  allow read: if request.auth != null && userId == request.auth.uid;
  allow write: if false; // Only Cloud Functions
}

// Analytics (no client access)
match /search_analytics/{docId} {
  allow read, write: if false;
}

match /search_costs/{docId} {
  allow read, write: if false;
}
```

### Cloud Functions Authorization

**All functions require authentication**:

```typescript
export const interpretSearchQuery = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = context.auth.uid;
  
  // Check if user is suspended
  const user = await admin.firestore().collection('users').doc(userId).get();
  if (user.data()?.suspended) {
    throw new functions.https.HttpsError('permission-denied', 'Your account is suspended');
  }
  
  // Proceed with function logic...
});
```

---

## Dependencies

### Flutter Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  # Existing dependencies...
  
  # AI Search specific
  geolocator: ^10.1.0           # Get user location
  geocoding: ^2.1.1             # Reverse geocoding
  cloud_functions: ^4.5.1       # Call Cloud Functions
  
  # Already exist (verify versions)
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_auth: ^4.15.3
  firebase_analytics: ^10.7.4
  firebase_crashlytics: ^3.4.9
```

### Cloud Functions Dependencies

Add to `functions/package.json`:

```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "@google-cloud/aiplatform": "^3.10.0",
    "geofire-common": "^6.0.0",
    "bad-words": "^3.0.4"
  },
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/node": "^20.10.5",
    "eslint": "^8.55.0"
  }
}
```

**Install**:
```bash
cd functions
npm install
```

---

## Risk Mitigation

### Risk 1: AI Latency Too High

**Mitigation**:
- Use Gemini Flash (faster model)
- Aggressive caching (1-hour TTL)
- Simple pattern matching before AI call

**Fallback**: If p95 latency >3s, disable AI for free tier, enable only for paid.

### Risk 2: AI Costs Exceed Budget

**Mitigation**:
- Daily cost monitoring
- Alert if costs >$50/day
- Disable AI if monthly budget reached

**Fallback**: Switch to keyword search for all users.

### Risk 3: Abuse/Spam

**Mitigation**:
- Rate limiting (5 searches/day free tier)
- Abuse detection (prompt injection, profanity)
- IP-based rate limiting

**Fallback**: Temporarily disable AI search if abuse spike detected.

### Risk 4: Low Adoption

**Mitigation**:
- Prominent placement in app (home screen)
- Onboarding tutorial
- Example queries shown

**Fallback**: A/B test AI vs keyword search, measure engagement.

---

## Success Metrics (Post-Launch)

**Week 1-2**:
- [ ] 20% of active users try AI search
- [ ] Average latency p95 <2s
- [ ] Cache hit rate >70%
- [ ] Zero critical bugs

**Month 1**:
- [ ] 50% of active users try AI search
- [ ] 2% upgrade to paid tier (from AI search upsell)
- [ ] Search → view conversion >40%
- [ ] Daily AI costs <$20

**Month 3**:
- [ ] AI search becomes default search method
- [ ] 5% of users on paid tier
- [ ] Search satisfaction score >4.5/5

---

## Acceptance Criteria (Before Launch)

### Backend
- [ ] All Cloud Functions deployed and tested
- [ ] Firestore indexes created
- [ ] Security rules deployed and tested
- [ ] Rate limiting enforced
- [ ] Monitoring alerts configured
- [ ] All existing listings indexed

### Frontend
- [ ] All screens implemented and tested
- [ ] Conversational refinement works
- [ ] Rate limit dialog shows correctly
- [ ] Fallback to keyword search works
- [ ] Saved searches CRUD operations work
- [ ] Firebase Analytics events tracked

### Testing
- [ ] All unit tests pass (80%+ coverage)
- [ ] All integration tests pass
- [ ] 50+ sample queries tested manually
- [ ] Performance targets met (p95 <2s)
- [ ] Security audit completed

### Documentation
- [ ] All 7 specification documents complete
- [ ] API documentation for Cloud Functions
- [ ] User-facing help articles
- [ ] Internal runbook for troubleshooting

---

**Document Owner**: CaribTap Engineering Team  
**Reviewers**: Tech Lead, Product Manager, QA Lead  
**Next Review**: After Phase 3 completion
