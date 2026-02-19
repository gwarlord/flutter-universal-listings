# CaribTap AI-Assisted Search - Master Specification

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Executive Summary

This document provides the master architecture for CaribTap's AI-assisted search feature—a complete, production-ready system designed to enhance discovery of Listings and Deals through natural language queries while maintaining backward compatibility, cost efficiency, and explainability.

### Key Design Principles

1. **Backward Compatibility**: No changes to existing data models, Firestore collections, routes, or deep-links
2. **Firebase-First**: Leverages existing Firebase infrastructure (Firestore, Auth, Functions, Messaging)
3. **Explainability**: Every result includes visible reasoning (chips, filters, match explanations)
4. **Deterministic + AI-Enhanced**: Base retrieval is deterministic Firestore queries; AI interprets intent and optionally reranks
5. **Cost Control**: Aggressive caching, rate limiting, graceful fallback to keyword search
6. **BLoC/Cubit Patterns**: Follows existing Flutter state management conventions

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client (Flutter App)                      │
│                                                               │
│  ┌─────────────────┐    ┌──────────────────┐                │
│  │  SearchScreen   │    │ SearchResultsScreen│               │
│  └────────┬────────┘    └─────────┬─────────┘                │
│           │                       │                           │
│  ┌────────▼──────────────────────▼─────────┐                 │
│  │         SearchCubit/SearchBloc          │                 │
│  └────────┬───────────────────────┬────────┘                 │
│           │                       │                           │
│  ┌────────▼──────┐       ┌───────▼──────────┐               │
│  │ AI Query      │       │ Search Repository│               │
│  │ Service Client│       │ (Firestore)      │               │
│  └────────┬──────┘       └──────────────────┘               │
│           │                                                   │
└───────────┼───────────────────────────────────────────────────┘
            │
            │ HTTPS Callable
            │
┌───────────▼───────────────────────────────────────────────────┐
│              Firebase Cloud Functions                         │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │  interpretSearchQuery                      │              │
│  │  - Gemini AI integration                   │              │
│  │  - Caching layer (Firestore)               │              │
│  │  - Rate limiting (per-user)                │              │
│  │  - Returns: structured interpretation JSON │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │  updateSearchIndex (Firestore Triggers)    │              │
│  │  - onCreate/onUpdate for listings/deals   │              │
│  │  - Maintains denormalized search index    │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │  scheduledBackfillSearchIndex              │              │
│  │  - Daily consistency check                 │              │
│  └────────────────────────────────────────────┘              │
│                                                               │
│  ┌────────────────────────────────────────────┐              │
│  │  savedSearchNotifier (optional)            │              │
│  │  - Checks new listings/deals vs saved      │              │
│  │  - Sends FCM notifications                 │              │
│  └────────────────────────────────────────────┘              │
└───────────────────────────────────────────────────────────────┘
            │
            │
┌───────────▼──────────────────────────────────────────────────┐
│                    Firestore                                  │
│                                                               │
│  ▪ listings (existing)                                        │
│  ▪ deal_ads (existing)                                        │
│  ▪ search_index_listings (new, additive)                     │
│  ▪ search_index_deals (new, additive)                        │
│  ▪ search_query_cache (new, additive)                        │
│  ▪ saved_searches (new, additive)                            │
│  ▪ search_rate_limits (new, additive)                        │
│  ▪ users (existing - adds searchPreferences)                 │
└───────────────────────────────────────────────────────────────┘
```

---

## Document Structure

This master specification is broken down into detailed sub-documents:

### 1. [AI_SEARCH_UX_DESIGN.md](AI_SEARCH_UX_DESIGN.md)
Complete UX/UI design including:
- Search entry screens and interactions
- Results screen with filter chips
- Empty states and intelligent rescue
- Conversational refinement UI
- Saved searches and alerts UI

### 2. [AI_SEARCH_DATA_INDEXING.md](AI_SEARCH_DATA_INDEXING.md)
Data architecture including:
- Search index schema (additive collections)
- Denormalization strategy
- Index update triggers
- Consistency backfill jobs
- Geospatial indexing approach

### 3. [AI_SEARCH_AI_INTERPRETATION.md](AI_SEARCH_AI_INTERPRETATION.md)
AI query understanding including:
- Interpretation JSON schema
- Gemini AI prompt engineering
- 20+ Trinidad/Tobago query examples
- Safety constraints
- Caching strategy

### 4. [AI_SEARCH_RETRIEVAL_RANKING.md](AI_SEARCH_RETRIEVAL_RANKING.md)
Retrieval and ranking including:
- Deterministic Firestore queries
- Pagination strategy
- Ranking score formula
- Bounded AI reranking (optional)
- Explainability chip generation

### 5. [AI_SEARCH_MONETIZATION_ABUSE.md](AI_SEARCH_MONETIZATION_ABUSE.md)
Monetization and safety including:
- Free vs paid tier boundaries
- Rate limiting implementation
- Abuse prevention
- Fallback behavior
- Monitoring and observability

### 6. [AI_SEARCH_IMPLEMENTATION_PLAN.md](AI_SEARCH_IMPLEMENTATION_PLAN.md)
Concrete implementation guide including:
- File structure and module organization
- Flutter widget/cubit architecture
- Cloud Functions implementation
- Firestore security rules
- Step-by-step implementation phases

### 7. [AI_SEARCH_TESTING.md](AI_SEARCH_TESTING.md)
Testing and acceptance including:
- Unit test specifications
- Integration test scenarios
- QA test cases
- Performance benchmarks
- Acceptance criteria checklist

---

## Core Features Summary

### 1. Natural Language Query Understanding
- "barber near Gulf City open now" → structured filters
- "party supplies under $500 delivery" → category + price + filters
- "cheapest car rental in Tobago" → location + category + sort
- "electronics with vouched sellers" → category + quality filter

### 2. Explainable Results
Every result shows:
- **Match chips**: "Near you", "Vouched", "Top rated", "Matches 'party speaker'"
- **Filter pills**: Editable location radius, price range, category, etc.
- **"Why these results" drawer**: Shows AI interpretation + applied filters

### 3. Intelligent Fallback
When no results:
1. Broaden radius automatically
2. Relax strict filters
3. Show nearby popular items in similar categories
4. Propose alternate query rewrites

### 4. Conversational Refinement
Built-in follow-up input:
- "only delivery"
- "under $500"
- "open now"
- "in Tobago"

Contextually applied to previous search.

### 5. Saved Searches & Alerts
Users can:
- Save a search query + filters
- Enable/disable notifications
- Get alerted when new matching listings/deals appear (throttled)

### 6. Premium Features (Monetization)
- **Free tier**: Basic AI search (5 AI queries/day, 1/minute)
- **Professional tier**: 50 AI queries/day, saved search alerts, conversational refinement
- **Business tier**: Unlimited AI queries, search insights for sellers

---

## Technology Stack

### Client (Flutter)
- **State Management**: flutter_bloc / bloc
- **Networking**: http, cloud_functions
- **Location**: geolocator, geocoding
- **Local Storage**: shared_preferences (for caching)

### Server (Firebase)
- **Firestore**: Primary database
- **Cloud Functions**: Node.js TypeScript / Python (for AI)
- **AI Model**: Gemini 1.5 Flash (cost-effective, fast)
- **Storage**: Firebase Storage (for media)
- **Auth**: Firebase Auth
- **Messaging**: FCM (for notifications)

---

## Non-Functional Requirements

### Performance
- Search interpretation: < 2s (p95)
- Firestore query execution: < 500ms (p95)
- Cache hit rate: > 80% for common queries
- Client-side response rendering: < 200ms

### Scalability
- Support 100K+ listings + deals
- Handle 10K concurrent users
- AI interpretation: 1000 req/min burst capacity

### Cost Control
- AI queries: < $0.001 per interpretation (Gemini Flash)
- Aggressive caching: 1-hour TTL for query interpretations
- Firestore reads: < 50 reads per search (with index)
- Monthly budget ceiling: $500 for AI, $200 for Firestore reads

### Reliability
- Fallback to keyword search if AI unavailable: 100% success rate
- Graceful degradation on Firebase errors
- 99.9% uptime for search (excluding AI interpretation)

---

## Security & Privacy

### Data Privacy
- User location: Only used if permission granted
- Search queries: Not logged long-term (24-hour retention)
- Interpretations: Cached anonymously (no PII)

### Rate Limiting
- Per user: 5 AI queries/min (free), 20/min (premium)
- Per user daily: 50 AI queries (free), 500 (premium)
- Per IP: 100 queries/hour (to prevent abuse)

### Safety
- Prompt injection protection in AI service
- Profanity/unsafe query filtering
- No inference of sensitive user traits (race, religion, etc.)

---

## Success Metrics (KPIs)

### Engagement
- **Search-to-view rate**: % of searches that lead to listing/deal view (target: > 40%)
- **Search-to-action rate**: % searches → save/chat/booking (target: > 15%)

### AI Effectiveness
- **AI vs keyword conversion**: Lift in conversion rate (target: +20%)
- **Refinement usage**: % users who refine searches (target: > 25%)

### Quality
- **Empty search rate**: % searches with 0 results (target: < 10%)
- **Rescue success**: % empty searches rescued by broadening (target: > 60%)

### Business
- **Premium conversion**: % users who upgrade for search features (target: > 5%)
- **Search insights engagement**: % business users using insights (target: > 30%)

---

## Implementation Timeline

### Phase 1: Foundation (Weeks 1-2)
1. Implement additive Firestore collections (search_index_*)
2. Implement search index Cloud Functions (triggers)
3. Backfill existing data into search index
4. Unit tests for indexing logic

### Phase 2: AI Interpretation (Weeks 3-4)
1. Implement interpretSearchQuery Cloud Function
2. Integrate Gemini AI with prompt engineering
3. Implement caching layer
4. Unit tests for interpretation logic
5. 20+ query examples validation

### Phase 3: Client Search UI (Weeks 5-6)
1. Implement SearchScreen V2 with AI toggle
2. Implement SearchResultsScreen with filter chips
3. Implement "Why these results" drawer
4. Implement empty states and rescue
5. Unit + widget tests

### Phase 4: Retrieval & Ranking (Week 7)
1. Implement SearchRepository with Firestore queries
2. Implement ranking score calculation
3. Implement explainability chip generation
4. Integration tests

### Phase 5: Refinement & Saved Searches (Week 8)
1. Implement conversational refinement
2. Implement saved searches CRUD
3. Implement notification job (optional)
4. End-to-end tests

### Phase 6: Polish & Launch (Weeks 9-10)
1. Rate limiting and abuse prevention
2. Monitoring dashboards
3. Performance optimization
4. Beta testing with 100 users
5. Production rollout

---

## Dependencies

### External Services
- **Gemini AI**: Google Cloud Vertex AI (requires billing account)
- **Firebase**: Blaze plan required for Cloud Functions

### App Permissions
- **Location (optional)**: For "near me" queries
- **Notifications (optional)**: For saved search alerts

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| AI service downtime | Graceful fallback to keyword search |
| High AI costs | Aggressive caching, rate limits, per-user budgets |
| Poor query interpretation | Extensive testing with 100+ real queries, manual review |
| Firestore read costs | Denormalized index, pagination, efficient compound indexes |
| Abuse (spam queries) | Rate limiting, IP blocking, profanity filter |
| User confusion | Clear explanations, onboarding tooltips, help documentation |

---

## Next Steps

1. **Review**: Stakeholder review of this master spec and all sub-documents
2. **Approval**: Get sign-off from product, engineering, and legal teams
3. **Resource Allocation**: Assign 2 engineers (backend + frontend) and 1 QA
4. **Kick-off**: Start Phase 1 implementation
5. **Weekly Syncs**: Progress reviews, blockers, adjustments

---

## Document References

- [AI_SEARCH_UX_DESIGN.md](AI_SEARCH_UX_DESIGN.md) - Complete UX/UI specification
- [AI_SEARCH_DATA_INDEXING.md](AI_SEARCH_DATA_INDEXING.md) - Data model and indexing
- [AI_SEARCH_AI_INTERPRETATION.md](AI_SEARCH_AI_INTERPRETATION.md) - AI query understanding
- [AI_SEARCH_RETRIEVAL_RANKING.md](AI_SEARCH_RETRIEVAL_RANKING.md) - Retrieval and ranking
- [AI_SEARCH_MONETIZATION_ABUSE.md](AI_SEARCH_MONETIZATION_ABUSE.md) - Monetization and safety
- [AI_SEARCH_IMPLEMENTATION_PLAN.md](AI_SEARCH_IMPLEMENTATION_PLAN.md) - Implementation guide
- [AI_SEARCH_TESTING.md](AI_SEARCH_TESTING.md) - Testing and acceptance criteria

---

**Document Owner**: CaribTap Engineering Team  
**Reviewers**: Product, Engineering, Legal, QA  
**Approval Date**: TBD
