# CaribTap Services Cost Tracking & Monitoring

**Last Updated:** January 20, 2026  
**Purpose:** Track all paid services to ensure costs don't exceed revenue

---

## 📊 Revenue Model

### Subscription Tiers
| Tier | Monthly Price | Features |
|------|--------------|----------|
| **Free** | $0 | Basic listings, view only |
| **Professional** | ~$9.99/mo | Booking services, priority listings |
| **Premium** | ~$19.99/mo | All Professional + Direct Messaging + Advanced Analytics |

**Revenue Source:** RevenueCat handles all subscription payments (70% after app store fees)

---

## 💰 Active Services & Monthly Costs

### 1. **Firebase Services** (Google Cloud)
**Monthly Budget:** ~$50-200 (free tier + pay-as-you-go)

#### Firestore Database
- **Usage:** User profiles, listings, reviews, bookings, chat messages
- **Reads:** ~100K-500K/month (mostly chat + listings)
- **Writes:** ~50K-200K/month (messages, bookings, user updates)
- **Storage:** ~5-20GB
- **Cost:** 
  - Free tier: 50K reads, 20K writes, 1GB storage/day
  - Overage: $0.06 per 100K reads, $0.18 per 100K writes
  - **Estimated:** $10-30/month

#### Firebase Storage
- **Usage:** Listing images, videos, user profile photos, chat media
- **Storage:** ~50-200GB
- **Downloads:** ~100-500GB/month
- **Cost:**
  - Free tier: 5GB storage, 1GB download/day
  - Overage: $0.026/GB storage, $0.12/GB download
  - **Estimated:** $15-50/month

#### Firebase Authentication
- **Usage:** User sign-up/login (Email, Google, Facebook, Apple)
- **Users:** Free for unlimited users
- **Cost:** **FREE**

#### Firebase Cloud Messaging (FCM)
- **Usage:** Push notifications for bookings, messages
- **Messages:** ~10K-50K/month
- **Cost:** **FREE** (unlimited)

#### Firebase Hosting (if used)
- **Usage:** Privacy policy, terms of service pages
- **Cost:** **FREE** (10GB storage, 360MB/day transfer)

**Firebase Total Estimated:** $25-80/month

---

### 2. **RevenueCat** (Subscription Management)
**Purpose:** Handle in-app purchases, subscription management, paywall

- **Free Tier:** Up to $2,500 monthly tracked revenue (MTR)
- **Paid Tier:** 1% of revenue > $2,500 MTR
- **Current Usage:** ~$0-50/month depending on revenue
- **Features Used:**
  - iOS/Android subscription management
  - Entitlement management
  - Customer info sync with Firestore
  - Offering/package configuration

**Estimated:** $0-50/month (scales with revenue)

---

### 3. **Google Maps Platform**
**Purpose:** Maps, geolocation, place autocomplete for listings

#### Maps SDK for Android/iOS
- **Usage:** Display listing locations
- **Cost:** $0.007 per map load
- **Estimated loads:** ~5K-20K/month
- **Cost:** $35-140/month

#### Places API (Autocomplete)
- **Usage:** Location search when creating listings
- **Cost:** $0.017 per session
- **Estimated sessions:** ~500-2K/month
- **Cost:** $8.50-34/month

**Maps Credit:** $200/month free credit
**Google Maps Total Estimated:** $0-50/month (usually covered by free tier)

---

### 4. **Google Mobile Ads** (Optional - Currently Integrated)
**Purpose:** Display ads to free users

- **Cost:** **REVENUE GENERATOR** (not a cost)
- **Earnings:** ~$0.50-5 per 1,000 impressions
- **Note:** Currently integrated but may conflict with premium model

**Recommendation:** Remove ads or only show to free tier users

---

### 5. **SendGrid** (Email Service)
**Purpose:** Transactional emails (booking confirmations, notifications)

- **Free Tier:** 100 emails/day (3,000/month)
- **Paid Tier:** $19.95/month for 50K emails
- **Current Usage:** ~100-1,000 emails/month
- **Cost:** **FREE** (within free tier)

---

### 6. **Cloud Functions** (Firebase/Google Cloud)
**Purpose:** Backend logic (currently minimal usage)

- **Invocations:** ~1K-5K/month (booking notifications)
- **Compute Time:** Minimal
- **Free Tier:** 2M invocations/month
- **Cost:** **FREE** (well within limits)

**Note:** Chat functions removed (direct Firestore instead) ✅

---

## 📈 Total Monthly Cost Breakdown

| Service | Minimum | Average | Maximum |
|---------|---------|---------|---------|
| Firebase (Firestore + Storage) | $10 | $40 | $80 |
| RevenueCat | $0 | $25 | $50 |
| Google Maps | $0 | $20 | $50 |
| SendGrid | $0 | $0 | $0 |
| Cloud Functions | $0 | $0 | $0 |
| **TOTAL** | **$10** | **$85** | **$180** |

---

## 🎯 Break-Even Analysis

### Minimum Revenue Needed (Monthly)
- **Fixed Costs:** ~$85/month average
- **Break-even Users:**
  - Professional ($9.99): 9 subscribers
  - Premium ($19.99): 5 subscribers
  - Mixed (50/50): 7 subscribers

### Healthy Targets
- **50 Premium subscribers:** $999/month revenue - $85 costs = **$914 profit**
- **100 Premium subscribers:** $1,999/month revenue - $85 costs = **$1,914 profit**
- **200 Premium subscribers:** $3,999/month revenue - $125 costs = **$3,874 profit**

**Note:** Costs scale slowly while revenue scales linearly

---

## 🚨 Cost Optimization Strategies

### Implemented ✅
1. **Removed Cloud Functions for chat** - Direct Firestore writes (saves invocations)
2. **Lazy loading images** - Cached network images reduce storage downloads
3. **Pagination** - Infinite scroll reduces read operations
4. **Live streams** - Real-time listeners instead of polling

### Recommended 🔧
1. **Image compression** - Reduce storage costs (already using flutter_image_compress)
2. **CDN for static assets** - Offload Firebase Storage downloads
3. **Firestore query optimization** - Use composite indexes, limit reads
4. **Scheduled cleanup** - Delete old chat messages, expired bookings
5. **Rate limiting** - Prevent abuse of analytics/search features

---

## 📊 Monitoring Dashboard URLs

### Firebase Console
- **Project:** https://console.firebase.google.com/project/caribtap
- **Firestore Usage:** https://console.firebase.google.com/project/caribtap/firestore/usage
- **Storage Usage:** https://console.firebase.google.com/project/caribtap/storage/usage
- **Authentication:** https://console.firebase.google.com/project/caribtap/authentication/users

### Google Cloud Console  
- **Billing:** https://console.cloud.google.com/billing
- **Maps Usage:** https://console.cloud.google.com/google/maps-apis/metrics

### RevenueCat Dashboard
- **Revenue:** https://app.revenuecat.com/overview
- **Customers:** https://app.revenuecat.com/customers
- **Charts:** https://app.revenuecat.com/charts

---

## 🔔 Alert Thresholds

### Set up billing alerts:
- **Firebase:** Alert at $50, $100, $150
- **Google Maps:** Alert at $150 (within free credit)
- **RevenueCat:** Alert at 80% of free tier ($2,000 MTR)

### Firebase Budget Alert Setup:
```bash
# Set in Google Cloud Console > Billing > Budgets & Alerts
1. Budget amount: $100
2. Alert thresholds: 50%, 90%, 100%
3. Email: admin@caribtap.com
```

---

## 📝 Monthly Review Checklist

- [ ] Check Firebase usage metrics (Firestore reads/writes)
- [ ] Review Storage usage and downloads
- [ ] Monitor Google Maps API calls
- [ ] Check RevenueCat subscription revenue
- [ ] Review active subscriber count
- [ ] Calculate profit margin (revenue - costs)
- [ ] Identify top cost drivers
- [ ] Look for usage anomalies/spikes
- [ ] Update cost estimates based on actual usage

---

## 🎯 Scale Planning

### At 500 Premium Subscribers (~$10K/month revenue)
- Firebase costs: ~$200-300/month
- RevenueCat: ~$80/month (1% of $8K after app store fees)
- Maps: ~$100/month
- **Total costs:** ~$400/month
- **Profit:** ~$9,600/month (96% margin)

### At 1,000 Premium Subscribers (~$20K/month revenue)
- Firebase costs: ~$400-500/month
- RevenueCat: ~$160/month
- Maps: ~$150/month
- **Total costs:** ~$700/month
- **Profit:** ~$19,300/month (96.5% margin)

**Conclusion:** Excellent scaling economics - costs grow much slower than revenue

---

## 🛡️ Cost Safety Measures

### Firestore Rules Optimization
- ✅ Read restrictions prevent abuse
- ✅ Chat requires Premium (reduces free tier abuse)
- ✅ Analytics restricted to Premium/Admin

### Rate Limiting (Recommended)
```dart
// Implement in Cloud Functions or Firestore Security Rules
// Limit analytics queries to 100/day per user
// Limit message sends to 500/day per user
```

### Data Retention Policy
```
- Chat messages: Keep 90 days
- Expired bookings: Archive after 30 days
- Deleted listings: Hard delete after 7 days
- User analytics: Aggregate monthly, delete raw data
```

---

## 📌 Key Contacts

- **Firebase Support:** https://firebase.google.com/support/contact
- **RevenueCat Support:** support@revenuecat.com
- **Google Maps Support:** https://support.google.com/googleapi

---

## 🔄 Last Cost Review
**Date:** January 20, 2026  
**Actual Monthly Costs:** Not yet tracked (new deployment)  
**Next Review:** February 20, 2026

**Action Items:**
1. Set up billing alerts in Firebase Console
2. Monitor first month of production usage
3. Establish baseline metrics
4. Optimize highest cost drivers
