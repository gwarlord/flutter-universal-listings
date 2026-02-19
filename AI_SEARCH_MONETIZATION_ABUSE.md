# CaribTap AI-Assisted Search - Monetization & Abuse Prevention

**Version:** 1.0  
**Status:** Production-Ready Design  
**Last Updated:** February 18, 2026

---

## Table of Contents

1. [Monetization Strategy](#monetization-strategy)
2. [Rate Limiting](#rate-limiting)
3. [Abuse Prevention](#abuse-prevention)
4. [Fallback Behavior](#fallback-behavior)
5. [Monitoring & Observability](#monitoring--observability)

---

## Monetization Strategy

### Tier Breakdown

| Feature | Free | Professional | Business |
|---------|------|--------------|----------|
| **Basic Search (Keyword)** | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| **AI-Assisted Search** | 5/day, 1/min | 50/day, 5/min | Unlimited |
| **Conversational Refinement** | ❌ | ✅ | ✅ |
| **Saved Searches** | 3 max | 10 max | Unlimited |
| **Search Alerts (Notifications)** | ❌ | ✅ (daily) | ✅ (real-time) |
| **Search Insights (for listers)** | ❌ | ❌ | ✅ |
| **Priority Ranking** | ❌ | ❌ | ✅ Boosted |
| **Customer Support** | Email | Priority Email | Dedicated |

### Pricing (Monthly)

- **Free**: $0
- **Professional**: $9.99 TTD (~$1.50 USD)
- **Business**: $49.99 TTD (~$7.50 USD)

### Monetization Goals

1. **Conversion Target**: 5% of active users upgrade to paid tier
2. **Revenue Target**: $1000 TTD/month from search upgrades
3. **Upsell Path**: Free → Professional (search power users) → Business (sellers wanting insights)

---

## Rate Limiting

### Architecture

```typescript
// functions/src/rate_limiting/rate_limiter.ts

interface RateLimitConfig {
  perMinute: number;
  perDay: number;
}

const RATE_LIMITS: Record<string, RateLimitConfig> = {
  free: { perMinute: 1, perDay: 5 },
  pro: { perMinute: 5, perDay: 50 },
  premium: { perMinute: 5, perDay: 50 },
  business: { perMinute: 10, perDay: 9999 }, // Effectively unlimited
};

async function checkRateLimit(userId: string): Promise<RateLimitResult> {
  const limitDoc = await admin.firestore()
    .collection('search_rate_limits')
    .doc(userId)
    .get();
  
  const now = admin.firestore.Timestamp.now();
  const currentMinute = Math.floor(now.seconds / 60);
  const currentDay = new Date(now.toDate()).toISOString().split('T')[0];
  
  let limitData = limitDoc.exists ? limitDoc.data()! : {
    userId,
    subscriptionTier: 'free',
    requestsThisMinute: 0,
    currentMinuteWindow: currentMinute,
    requestsToday: 0,
    currentDayWindow: currentDay,
    violationCount: 0,
    lastViolationAt: null,
  };
  
  const limits = RATE_LIMITS[limitData.subscriptionTier] || RATE_LIMITS.free;
  
  // Reset minute window if new minute
  if (limitData.currentMinuteWindow < currentMinute) {
    limitData.requestsThisMinute = 0;
    limitData.currentMinuteWindow = currentMinute;
  }
  
  // Reset day window if new day
  if (limitData.currentDayWindow < currentDay) {
    limitData.requestsToday = 0;
    limitData.currentDayWindow = currentDay;
  }
  
  // Check limits
  if (limitData.requestsThisMinute >= limits.perMinute) {
    limitData.violationCount++;
    limitData.lastViolationAt = now;
    await admin.firestore().collection('search_rate_limits').doc(userId).set(limitData);
    
    return {
      allowed: false,
      reason: 'rate_limit_minute',
      retryAfter: 60 - (now.seconds % 60), // seconds until next minute
      limit: limits.perMinute,
      remaining: 0,
    };
  }
  
  if (limitData.requestsToday >= limits.perDay) {
    limitData.violationCount++;
    limitData.lastViolationAt = now;
    await admin.firestore().collection('search_rate_limits').doc(userId).set(limitData);
    
    return {
      allowed: false,
      reason: 'rate_limit_day',
      retryAfter: null, // Wait until next day
      limit: limits.perDay,
      remaining: 0,
    };
  }
  
  // Increment counters
  limitData.requestsThisMinute++;
  limitData.requestsToday++;
  limitData.updatedAt = now;
  
  await admin.firestore().collection('search_rate_limits').doc(userId).set(limitData);
  
  return {
    allowed: true,
    reason: null,
    retryAfter: null,
    limit: limits.perDay,
    remaining: limits.perDay - limitData.requestsToday,
  };
}
```

### Client-Side Enforcement

```dart
// lib/listings/services/search_rate_limit_service.dart

class SearchRateLimitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<RateLimitResult> checkLimit(String userId) async {
    final doc = await _firestore
        .collection('search_rate_limits')
        .doc(userId)
        .get();
    
    if (!doc.exists) {
      return RateLimitResult(allowed: true, remaining: 5);
    }
    
    final data = doc.data()!;
    final tier = data['subscriptionTier'] as String;
    final requestsToday = data['requestsToday'] as int;
    
    final limits = {
      'free': 5,
      'pro': 50,
      'premium': 50,
      'business': 9999,
    };
    
    final limit = limits[tier] ?? 5;
    final remaining = limit - requestsToday;
    
    if (remaining <= 0) {
      return RateLimitResult(
        allowed: false,
        remaining: 0,
        reason: 'You\'ve reached your daily AI search limit',
        upgradeMessage: tier == 'free' 
            ? 'Upgrade to Professional for 50 searches/day'
            : null,
      );
    }
    
    return RateLimitResult(allowed: true, remaining: remaining);
  }
  
  void showRateLimitDialog(BuildContext context, RateLimitResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.reason ?? 'Daily limit reached'),
            SizedBox(height: 16),
            if (result.upgradeMessage != null)
              Text(result.upgradeMessage!,
                  style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('You can still use keyword search (unlimited)'),
          ],
        ),
        actions: [
          if (result.upgradeMessage != null)
            TextButton(
              child: Text('Upgrade Now'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/subscription');
              },
            ),
          TextButton(
            child: Text('Use Keyword Search'),
            onPressed: () {
              Navigator.pop(context);
              // Fallback to keyword search
            },
          ),
        ],
      ),
    );
  }
}
```

### Rate Limit Headers (API)

**Cloud Function Response Headers**:

```typescript
export const interpretSearchQueryHTTPS = functions.https.onCall(async (data, context) => {
  const userId = context.auth?.uid;
  if (!userId) throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  
  // Check rate limit
  const rateLimit = await checkRateLimit(userId);
  
  if (!rateLimit.allowed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      rateLimit.reason!,
      {
        retryAfter: rateLimit.retryAfter,
        limit: rateLimit.limit,
        remaining: 0,
      }
    );
  }
  
  // Process query
  const interpretation = await interpretSearchQuery(data.query, data.contentType, data.userContext);
  
  // Return with rate limit info
  return {
    interpretation,
    rateLimit: {
      limit: rateLimit.limit,
      remaining: rateLimit.remaining,
    },
  };
});
```

---

## Abuse Prevention

### 1. Spam Queries

**Detection**: Repeated identical queries within short time.

```typescript
async function detectSpam(userId: string, query: string): Promise<boolean> {
  const recentQueries = await admin.firestore()
    .collection('search_analytics')
    .where('userId', '==', userId)
    .where('timestamp', '>', admin.firestore.Timestamp.fromMillis(Date.now() - 60000)) // Last minute
    .get();
  
  const identicalQueries = recentQueries.docs.filter((doc) => doc.data().query === query);
  
  if (identicalQueries.length >= 5) {
    // 5+ identical queries in 1 minute = spam
    await flagUser(userId, 'spam_queries');
    return true;
  }
  
  return false;
}
```

**Action**: Temporarily block user (15 minutes), send warning.

### 2. Prompt Injection

**Detection**: Query contains code, SQL, or unusual characters.

```typescript
const INJECTION_PATTERNS = [
  /ignore\s+previous\s+instructions/i,
  /system\s+prompt/i,
  /<script>/i,
  /sql/i,
  /drop\s+table/i,
  /\b(exec|eval|execute)\s*\(/i,
];

function detectPromptInjection(query: string): boolean {
  return INJECTION_PATTERNS.some((pattern) => pattern.test(query));
}
```

**Action**: Reject query, log incident, flag user after 3 attempts.

### 3. Profanity & Inappropriate Content

**Detection**: Use profanity filter library.

```typescript
import * as Filter from 'bad-words';

const filter = new Filter();

function filterProfanity(query: string): { clean: boolean; filtered: string } {
  const clean = !filter.isProfane(query);
  const filtered = filter.clean(query);
  
  return { clean, filtered };
}
```

**Action**: 
- **Soft**: Replace profanity with asterisks, continue search
- **Hard**: Reject query if excessive (3+ profane words)

### 4. IP-Based Rate Limiting (Bot Protection)

**Detection**: Too many requests from single IP.

```typescript
async function checkIPRateLimit(ip: string): Promise<boolean> {
  const key = `ip_limit:${ip}`;
  const count = await redis.incr(key);
  
  if (count === 1) {
    await redis.expire(key, 3600); // 1 hour window
  }
  
  const limit = 100; // 100 requests per hour per IP
  return count <= limit;
}
```

**Action**: Temporary IP block (1 hour), CAPTCHA challenge.

### 5. User Account Suspension

**Criteria**:
- 10+ rate limit violations in 24 hours
- 3+ prompt injection attempts
- 5+ flagged queries (inappropriate content)

**Action**:
```typescript
async function suspendUser(userId: string, reason: string, durationHours: number = 24) {
  await admin.firestore()
    .collection('users')
    .doc(userId)
    .update({
      suspended: true,
      suspendedUntil: admin.firestore.Timestamp.fromMillis(Date.now() + durationHours * 3600000),
      suspensionReason: reason,
    });
  
  // Send email notification
  await sendSuspensionEmail(userId, reason, durationHours);
}
```

---

## Fallback Behavior

### Scenario 1: AI Service Down

**Detection**: `interpretSearchQuery` throws error.

**Fallback**: Use existing keyword search (SearchBloc).

```dart
Future<List<SearchResult>> search(String query) async {
  try {
    // Try AI search
    final interpretation = await _aiService.interpretQuery(query);
    final results = await _searchRepository.searchByInterpretation(interpretation);
    return results;
  } catch (e) {
    print('AI search failed: $e');
    
    // Fallback to keyword search
    showSnackBar(context, 'Using keyword search (AI temporarily unavailable)');
    return await _keywordSearch(query);
  }
}

Future<List<SearchResult>> _keywordSearch(String query) async {
  // Use existing SearchBloc fuzzy matching logic
  return _searchBloc.searchByKeywords(query);
}
```

### Scenario 2: Rate Limit Exceeded

**Action**: Offer keyword search OR upgrade prompt.

```dart
if (!rateLimit.allowed) {
  showDialog(
    context: context,
    builder: (context) => RateLimitDialog(
      onKeywordSearch: () => _keywordSearch(query),
      onUpgrade: () => Navigator.pushNamed(context, '/subscription'),
    ),
  );
}
```

### Scenario 3: Location Permission Denied

**Action**: Default to country-wide search OR ask for manual location input.

```dart
if (interpretation.location.useUserLocation && !hasLocationPermission) {
  // Option 1: Country-wide search
  interpretation.location.useUserLocation = false;
  interpretation.location.place = 'Trinidad and Tobago';
  interpretation.location.radius = null;
  
  // Option 2: Manual location input
  showLocationInputDialog(context);
}
```

### Scenario 4: Firestore Query Error

**Action**: Retry with exponential backoff, then fallback.

```dart
Future<List<SearchResult>> searchWithRetry(
  SearchInterpretation interpretation,
  {int maxRetries = 3}
) async {
  int attempt = 0;
  
  while (attempt < maxRetries) {
    try {
      return await _searchRepository.search(interpretation);
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) {
        throw SearchException('Search service unavailable. Please try again later.');
      }
      
      // Exponential backoff
      await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
    }
  }
  
  throw SearchException('Failed after $maxRetries attempts');
}
```

---

## Monitoring & Observability

### Metrics Dashboard

**Key Metrics**:

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| AI Search Latency (p95) | < 2s | > 5s |
| Cache Hit Rate | > 80% | < 50% |
| Rate Limit Violations | < 5% of users | > 15% |
| Fallback Usage | < 10% of searches | > 30% |
| Search → View Conversion | > 40% | < 20% |
| Daily Active Searchers | Growing | Declining 7 days |

### Logging

```typescript
// Log every search request
await admin.firestore()
  .collection('search_analytics')
  .add({
    userId,
    query,
    interpretation: interpretation,
    cacheHit: cacheHit,
    resultCount: results.length,
    aiLatency: aiLatency,
    totalLatency: totalLatency,
    fallbackUsed: fallbackUsed,
    timestamp: admin.firestore.Timestamp.now(),
  });
```

### Alerts

**Firebase Cloud Monitoring Alerts**:

1. **High Error Rate**: > 10% of searches fail (5-minute window)
   - Action: Page on-call engineer
   
2. **AI Service Down**: > 50% fallback usage (5-minute window)
   - Action: Check Gemini AI status, switch to backup model
   
3. **Abuse Spike**: > 100 rate limit violations (1-hour window)
   - Action: Review IP blocks, tighten limits temporarily

4. **Cost Spike**: Daily AI costs > $50
   - Action: Review query patterns, optimize caching

### Cost Tracking

```typescript
// Track AI costs
await admin.firestore()
  .collection('search_costs')
  .add({
    date: new Date().toISOString().split('T')[0],
    aiQueries: 1,
    estimatedCost: 0.000075, // Gemini Flash cost per query
    cacheHit: cacheHit,
    userId: userId,
    subscriptionTier: userTier,
  });
```

**Daily Aggregation**:
```typescript
export const aggregateDailyCosts = functions.pubsub
  .schedule('0 1 * * *') // 1am daily
  .onRun(async () => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split('T')[0];
    
    const costs = await admin.firestore()
      .collection('search_costs')
      .where('date', '==', dateStr)
      .get();
    
    const totalQueries = costs.size;
    const totalCost = costs.docs.reduce((sum, doc) => sum + doc.data().estimatedCost, 0);
    const cacheHits = costs.docs.filter((doc) => doc.data().cacheHit).length;
    
    await admin.firestore()
      .collection('search_cost_summary')
      .doc(dateStr)
      .set({
        date: dateStr,
        totalQueries,
        totalCost,
        cacheHitRate: (cacheHits / totalQueries) * 100,
      });
    
    console.log(`Daily costs for ${dateStr}: ${totalQueries} queries, $${totalCost.toFixed(4)}`);
  });
```

### User Engagement Tracking

**Funnel Metrics**:

```typescript
// Track search funnel
interface SearchFunnel {
  searchInitiated: number;
  resultsViewed: number;
  resultClicked: number;
  listingDetailViewed: number;
  actionTaken: number; // save, chat, booking
}

// Calculate conversion rates
const searchToViewRate = (resultsViewed / searchInitiated) * 100;
const viewToClickRate = (resultClicked / resultsViewed) * 100;
const clickToActionRate = (actionTaken / resultClicked) * 100;
```

### Health Check Endpoint

```typescript
export const searchHealthCheck = functions.https.onRequest(async (req, res) => {
  const checks = {
    firestoreRead: false,
    aiService: false,
    cacheAccess: false,
  };
  
  try {
    // Test Firestore read
    await admin.firestore().collection('search_index_listings').limit(1).get();
    checks.firestoreRead = true;
  } catch (e) {
    console.error('Firestore health check failed:', e);
  }
  
  try {
    // Test AI service
    await interpretSearchQuery('test', 'all');
    checks.aiService = true;
  } catch (e) {
    console.error('AI service health check failed:', e);
  }
  
  try {
    // Test cache access
    await admin.firestore().collection('search_query_cache').limit(1).get();
    checks.cacheAccess = true;
  } catch (e) {
    console.error('Cache health check failed:', e);
  }
  
  const allHealthy = Object.values(checks).every((v) => v === true);
  
  res.status(allHealthy ? 200 : 503).json({
    healthy: allHealthy,
    checks,
    timestamp: new Date().toISOString(),
  });
});
```

---

## Search Insights (Business Tier)

**Feature**: Show business owners how their listings perform in search.

**Insights**:

```typescript
interface SearchInsights {
  listingId: string;
  period: string; // '7d', '30d'
  
  // Visibility
  appearsInSearches: number;        // How many searches returned this listing
  averagePosition: number;           // Average ranking position
  impressions: number;               // How many times shown in results
  
  // Performance
  clickThroughRate: number;          // (clicks / impressions) * 100
  saveRate: number;                  // (saves / clicks) * 100
  
  // Top Queries
  topQueries: Array<{
    query: string;
    count: number;
    averagePosition: number;
  }>;
  
  // Missing Keywords
  missingKeywords: string[];         // Keywords users search but listing doesn't contain
  
  // Recommendations
  recommendations: string[];         // AI-generated suggestions to improve ranking
}
```

**Implementation**:

```typescript
async function getSearchInsights(listingId: string, period: string): Promise<SearchInsights> {
  const daysAgo = period === '7d' ? 7 : 30;
  const since = new Date();
  since.setDate(since.getDate() - daysAgo);
  
  const analytics = await admin.firestore()
    .collection('search_analytics')
    .where('results', 'array-contains', listingId)
    .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(since))
    .get();
  
  // Compute metrics...
  
  return insights;
}
```

---

## Cost Optimization Strategies

### 1. Aggressive Caching

- Cache AI interpretations (1 hour TTL)
- Cache geolocation lookups (indefinite)
- Cache category mappings (indefinite)

### 2. Query Simplification

**Before AI**:
- Check if query matches common patterns (regex)
- If simple pattern ("barber Trinidad"), skip AI, use template

**Example**:
```typescript
const SIMPLE_PATTERNS = [
  { regex: /^(\w+)\s+(trinidad|tobago)$/i, template: (m) => ({ category: m[1], location: m[2] }) },
  { regex: /^(\w+)\s+near\s+me$/i, template: (m) => ({ category: m[1], useUserLocation: true }) },
];

function trySimpleParse(query: string): SearchInterpretation | null {
  for (const { regex, template } of SIMPLE_PATTERNS) {
    const match = query.match(regex);
    if (match) {
      return buildInterpretationFromTemplate(template(match));
    }
  }
  return null;
}
```

### 3. Batch Processing

**Saved Search Notifications**: Check once daily, batch all users.

```typescript
export const notifySavedSearches = functions.pubsub
  .schedule('0 8 * * *') // 8am daily
  .onRun(async () => {
    const savedSearches = await admin.firestore()
      .collection('saved_searches')
      .where('notificationsEnabled', '==', true)
      .get();
    
    for (const doc of savedSearches.docs) {
      const search = doc.data();
      
      // Check for new matches since last notification
      const newMatches = await findNewMatches(search);
      
      if (newMatches.length > 0) {
        await sendNotification(search.userId, newMatches);
        await doc.ref.update({
          lastNotificationSentAt: admin.firestore.Timestamp.now(),
          matchCountAtLastNotification: newMatches.length,
        });
      }
    }
  });
```

---

## Acceptance Criteria

### Monetization
- [ ] Free users limited to 5 AI searches/day, 1/minute
- [ ] Professional users get 50 AI searches/day, 5/minute
- [ ] Business users get unlimited AI searches
- [ ] Rate limit exceeded dialog shows upgrade prompt
- [ ] Keyword search fallback always available

### Abuse Prevention
- [ ] Prompt injection attempts blocked and logged
- [ ] Profanity filtered or rejected
- [ ] Spam queries (5+ identical in 1 min) blocked
- [ ] IP rate limiting (100 req/hour) enforced
- [ ] Users suspended after 10 violations

### Fallback
- [ ] AI service failure falls back to keyword search
- [ ] No user-facing errors, graceful degradation
- [ ] Location permission denial handled smoothly
- [ ] Firestore errors retry 3x before failing

### Monitoring
- [ ] All searches logged to `search_analytics`
- [ ] Daily cost aggregation runs automatically
- [ ] Health check endpoint returns status
- [ ] Alerts configured for error spikes
- [ ] Dashboard shows key metrics (latency, cache hit rate, etc.)

---

**Document Owner**: CaribTap Backend & Product Teams  
**Reviewers**: Engineering, Product, Finance, Legal  
**Next Review**: After beta testing
