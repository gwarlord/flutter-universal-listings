# Listing Freshness Logic - Brand Integration Guide

Complete guide for integrating brand freshness exemption into your existing listing auto-hide/freshness logic.

## Overview

The freshness system automatically hides old listings to keep the catalog fresh. With brands, we add an exemption flag so verified chains stay visible.

**Exemption Priority (most to least specific):**
1. Listing-level: `listing.freshness.exempt` → Skip auto-hide
2. Lister-level: `lister.listingFreshnessExempt` → Skip auto-hide for all their listings
3. Brand-level: `brand.freshnessExempt` → Skip auto-hide for all brand locations
4. Age check: If no exemption, hide listing if older than threshold

## Finding Your Freshness Logic

Search your codebase for these patterns:

```
// Auto-hide function name variations:
- shouldAutoHideListing()
- isListingFresh()
- shouldHideListing()
- getListingFreshness()
- checkListingAge()

// Auto-hide cleanup function variations:
- autoHideOldListings()
- deleteExpiredListings()
- refreshListings()
- Firestore Cloud Function name: onListingCreated, onListingUpdated
```

## Implementation Pattern 1: Frontend Listing Display Logic

If you have frontend code that filters/displays listings based on freshness:

### Current Implementation (Example)
```dart
// In your listing repository or store logic
List<ListingModel> getVisibleListings(List<ListingModel> allListings) {
  return allListings.where((listing) {
    // Skip if explicitly marked as exempt
    if (listing.freshness?.exempt ?? false) {
      return true; // Keep visible
    }

    // Skip if owner has blanket exemption
    if (listing.authorID != null) {
      final lister = getListerData(listing.authorID!);
      if (lister?.listingFreshnessExempt == true) {
        return true; // Keep visible
      }
    }

    // Check age
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(listing.createdAt),
    ).inDays;

    return age <= FRESHNESS_THRESHOLD; // e.g., 90 days
  }).toList();
}
```

### Updated Implementation (Add Brand Check)
```dart
Future<List<ListingModel>> getVisibleListings(List<ListingModel> allListings) async {
  final visibleListings = <ListingModel>[];
  final brandService = BrandService();
  
  for (final listing in allListings) {
    // Skip if explicitly marked as exempt
    if (listing.freshness?.exempt ?? false) {
      visibleListings.add(listing);
      continue;
    }

    // Skip if owner has blanket exemption
    if (listing.authorID != null) {
      final lister = await getListerData(listing.authorID!);
      if (lister?.listingFreshnessExempt == true) {
        visibleListings.add(listing);
        continue;
      }
    }

    // NEW: Skip if brand is freshness-exempt
    if (listing.brandId != null && listing.brandId!.isNotEmpty) {
      final brand = await brandService.getBrand(listing.brandId!);
      if (brand?.freshnessExempt == true) {
        visibleListings.add(listing);
        continue;
      }
    }

    // Check age
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(listing.createdAt),
    ).inDays;

    if (age <= FRESHNESS_THRESHOLD) {
      visibleListings.add(listing);
    }
  }
  
  return visibleListings;
}
```

### With Caching for Performance

```dart
class ListingFreshnessController {
  final _brandService = BrandService();
  final Map<String, BrandModel> _brandCache = {};

  Future<bool> shouldShowListing(ListingModel listing) async {
    // Check exemptions
    if (listing.freshness?.exempt ?? false) return true;

    // Check lister exemption
    if (listing.authorID != null) {
      final lister = await _getUserData(listing.authorID!);
      if (lister?.listingFreshnessExempt == true) return true;
    }

    // Check brand exemption with caching
    if (listing.brandId != null && listing.brandId!.isNotEmpty) {
      final brand = await _getCachedBrand(listing.brandId!);
      if (brand?.freshnessExempt == true) return true;
    }

    // Check age
    final ageInDays = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(listing.createdAt))
        .inDays;

    return ageInDays <= FRESHNESS_THRESHOLD;
  }

  Future<BrandModel?> _getCachedBrand(String brandId) async {
    if (_brandCache.containsKey(brandId)) {
      return _brandCache[brandId];
    }

    final brand = await _brandService.getBrand(brandId);
    if (brand != null) {
      _brandCache[brandId] = brand;
    }
    return brand;
  }

  void clearBrandCache() {
    _brandCache.clear();
  }
}
```

## Implementation Pattern 2: Cloud Function Cleanup

If you have a Cloud Function that automatically hides old listings:

### TypeScript Cloud Function (Firebase)

**Current Function (Example):**
```typescript
export const hideExpiredListings = functions
  .pubsub.schedule('every 24 hours')
  .timeZone('America/Puerto_Rico')
  .onRun(async (context) => {
    const firestore = admin.firestore();
    const now = new Date();
    const thresholdDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    const expiredListings = await firestore
      .collection('listings')
      .where('createdAt', '<', thresholdDate.getTime())
      .where('freshness.exempt', '==', false)
      .get();

    const batch = firestore.batch();
    let updateCount = 0;

    for (const doc of expiredListings.docs) {
      batch.update(doc.ref, { hidden: true });
      updateCount++;
    }

    await batch.commit();
    console.log(`Hidden ${updateCount} expired listings`);
    return null;
  });
```

**Updated Function (Add Brand Check):**
```typescript
export const hideExpiredListings = functions
  .pubsub.schedule('every 24 hours')
  .timeZone('America/Puerto_Rico')
  .onRun(async (context) => {
    const firestore = admin.firestore();
    const now = new Date();
    const thresholdDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    // Get all expired listings (without exemptions applied)
    const expiredListings = await firestore
      .collection('listings')
      .where('createdAt', '<', thresholdDate.getTime())
      .where('freshness.exempt', '==', false)
      .get();

    const batch = firestore.batch();
    let hideCount = 0;
    let skipCount = 0;

    for (const doc of expiredListings.docs) {
      const listing = doc.data() as any;
      
      // Check lister-level exemption
      if (listing.authorID) {
        const lister = await firestore
          .collection('users')
          .doc(listing.authorID)
          .get();

        if (lister.data()?.listingFreshnessExempt === true) {
          skipCount++;
          continue;
        }
      }

      // NEW: Check brand-level exemption
      if (listing.brandId) {
        const brand = await firestore
          .collection('brands')
          .doc(listing.brandId)
          .get();

        if (brand.data()?.freshnessExempt === true) {
          console.log(`Skipping listing ${doc.id} - brand ${listing.brandId} is exempt`);
          skipCount++;
          continue;
        }
      }

      // Hide the listing
      batch.update(doc.ref, { hidden: true });
      hideCount++;
    }

    await batch.commit();
    
    console.log(`
      Freshness cleanup completed:
      - Listings processed: ${expiredListings.size}
      - Hidden: ${hideCount}
      - Skipped (exempt): ${skipCount}
    `);
    
    return null;
  });
```

**With Logging to Firestore (for admin monitoring):**
```typescript
export const hideExpiredListings = functions
  .pubsub.schedule('every 24 hours')
  .timeZone('America/Puerto_Rico')
  .onRun(async (context) => {
    const firestore = admin.firestore();
    const now = new Date();
    const thresholdDate = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    const logEntry = {
      timestamp: now.getTime(),
      type: 'freshness_cleanup',
      stats: {
        processed: 0,
        hidden: 0,
        skipped: 0,
      },
      details: [] as any[],
    };

    try {
      const expiredListings = await firestore
        .collection('listings')
        .where('createdAt', '<', thresholdDate.getTime())
        .where('freshness.exempt', '==', false)
        .get();

      logEntry.stats.processed = expiredListings.size;

      const batch = firestore.batch();

      for (const doc of expiredListings.docs) {
        const listing = doc.data() as any;
        let skipReason: string | null = null;

        // Check lister exemption
        if (listing.authorID) {
          const lister = await firestore
            .collection('users')
            .doc(listing.authorID)
            .get();

          if (lister.data()?.listingFreshnessExempt === true) {
            skipReason = 'lister_exempt';
          }
        }

        // Check brand exemption
        if (!skipReason && listing.brandId) {
          const brand = await firestore
            .collection('brands')
            .doc(listing.brandId)
            .get();

          if (brand.data()?.freshnessExempt === true) {
            skipReason = 'brand_exempt';
          }
        }

        if (skipReason) {
          logEntry.stats.skipped++;
          logEntry.details.push({
            listingId: doc.id,
            action: 'skipped',
            reason: skipReason,
          });
        } else {
          batch.update(doc.ref, { hidden: true });
          logEntry.stats.hidden++;
          logEntry.details.push({
            listingId: doc.id,
            action: 'hidden',
          });
        }
      }

      await batch.commit();

      // Log the cleanup execution
      await firestore
        .collection('admin/logs/freshness_cleanup')
        .add(logEntry);

    } catch (error) {
      console.error('Error in freshness cleanup:', error);
      logEntry.stats.processed = -1; // Error indicator
      
      await firestore
        .collection('admin/logs/freshness_cleanup')
        .add(logEntry);
    }

    return null;
  });
```

## Implementation Pattern 3: Listing Detail Screen

Show exemption reason to users when they view a listing:

```dart
class ListingDetailScreen extends StatelessWidget {
  final ListingModel listing;
  final _brandService = BrandService();

  ListingDetailScreen({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing Details')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Existing listing content...

            // NEW: Show exemption badge if applicable
            FutureBuilder<String?>(
              future: _getExemptionReason(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            snapshot.data!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Rest of listing detail...
          ],
        ),
      ),
    );
  }

  Future<String?> _getExemptionReason() async {
    // Listing-level exemption
    if (listing.freshness?.exempt ?? false) {
      return '✓ This listing is manually exempt from auto-hide';
    }

    // Lister-level exemption
    // (You'd need access to lister data here)
    
    // Brand-level exemption
    if (listing.brandId != null && listing.brandId!.isNotEmpty) {
      final brand = await _brandService.getBrand(listing.brandId!);
      if (brand?.freshnessExempt == true) {
        return '✓ Part of verified chain "${brand!.name}" - stays fresh indefinitely';
      }
    }

    return null;
  }
}
```

## Testing Freshness Logic

### Test Case 1: Old Listing Without Exemption
```dart
void testOldListingGetsHidden() async {
  final listing = ListingModel(
    // ... other fields
    createdAt: DateTime.now().subtract(Duration(days: 100)).millisecondsSinceEpoch,
    freshness: Freshness(exempt: false),
    brandId: null,
  );

  expect(await shouldShowListing(listing), isFalse);
}
```

### Test Case 2: Old Listing With Brand Exemption
```dart
void testOldListingWithExemptBrandStaysVisible() async {
  final listing = ListingModel(
    createdAt: DateTime.now().subtract(Duration(days: 100)).millisecondsSinceEpoch,
    freshness: Freshness(exempt: false),
    brandId: 'brand123',
  );

  // Mock brand with exemption
  mockBrand('brand123', freshnessExempt: true);

  expect(await shouldShowListing(listing), isTrue);
}
```

### Test Case 3: New Listing Without Exemption
```dart
void testNewListingAlwaysShowsShouldShowListing() async {
  final listing = ListingModel(
    createdAt: DateTime.now().subtract(Duration(days: 5)).millisecondsSinceEpoch,
    freshness: Freshness(exempt: false),
    brandId: null,
  );

  expect(await shouldShowListing(listing), isTrue);
}
```

### Test Case 4: Old Listing With Listing-Level Exemption
```dart
void testListingLevelExemptionOverridesAge() async {
  final listing = ListingModel(
    createdAt: DateTime.now().subtract(Duration(days: 365)).millisecondsSinceEpoch,
    freshness: Freshness(exempt: true), // Explicit exemption
    brandId: null,
  );

  expect(await shouldShowListing(listing), isTrue);
}
```

## Integration Checklist

- [ ] Locate your existing freshness checking code
- [ ] Add BrandService dependency
- [ ] Add brand exemption check to get visible listings function
- [ ] Update Cloud Function (if applicable) to check brand exemption
- [ ] Add caching to avoid repeated brand lookups
- [ ] Test with listings in each exemption category
- [ ] Test with multiple brands
- [ ] Monitor performance (number of brand lookups per operation)
- [ ] Add logging to track exemptions being applied
- [ ] Document exemption reason in UI if relevant

## Performance Optimization

### Batch Brand Lookups
```dart
Future<Map<String, BrandModel>> _getBrandsBatch(List<String> brandIds) async {
  final unique = brandIds.toSet();
  final result = <String, BrandModel>{};

  final docs = await firestore
      .collection('brands')
      .where(FieldPath.documentId, whereIn: unique.toList())
      .get();

  for (final doc in docs.docs) {
    result[doc.id] = BrandModel.fromJson(doc.data(), doc.id);
  }

  return result;
}

Future<List<ListingModel>> getVisibleListingsOptimized(
  List<ListingModel> allListings,
) async {
  // Extract unique brand IDs
  final brandIds = allListings
      .where((l) => l.brandId != null && l.brandId!.isNotEmpty)
      .map((l) => l.brandId!)
      .toSet()
      .toList();

  // Fetch all brands in one query
  final brands = await _getBrandsBatch(brandIds);

  // Filter locally
  return allListings.where((listing) {
    if (listing.freshness?.exempt ?? false) return true;
    
    if (listing.brandId != null && brands.containsKey(listing.brandId)) {
      if (brands[listing.brandId]?.freshnessExempt == true) return true;
    }

    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(listing.createdAt))
        .inDays;

    return age <= FRESHNESS_THRESHOLD;
  }).toList();
}
```

## Monitoring & Admin Tools

Add to your admin dashboard:

```dart
// Show exemption statistics
FutureBuilder<Map<String, int>>(
  future: _getExemptionStats(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const SizedBox.shrink();
    
    final stats = snapshot.data!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Freshness Exemptions'),
            Text('Listing-level: ${stats['listing'] ?? 0}'),
            Text('Lister-level: ${stats['lister'] ?? 0}'),
            Text('Brand-level: ${stats['brand'] ?? 0}'),
          ],
        ),
      ),
    );
  },
)

Future<Map<String, int>> _getExemptionStats() async {
  final firestore = FirebaseFirestore.instance;
  
  final listingExempt = await firestore
      .collection('listings')
      .where('freshness.exempt', '==', true)
      .count()
      .get();

  final brandExempt = await firestore
      .collection('brands')
      .where('freshnessExempt', '==', true)
      .count()
      .get();

  return {
    'listing': listingExempt.count,
    'brand': brandExempt.count,
  };
}
```

