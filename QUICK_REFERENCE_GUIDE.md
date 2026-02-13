# Multi-Location Brands - Quick Reference Guide

Fast lookup guide for implementation tasks and common operations.

## File Locations

### Code Files
| File | Purpose | Status |
|------|---------|--------|
| `lib/listings/model/brand_model.dart` | Brand data structure | ✅ Complete |
| `lib/listings/model/listing_model.dart` | Extended for brand linking | ✅ Complete |
| `lib/listings/services/brand_service.dart` | Data access + cloud functions | ✅ Complete |
| `lib/screens/brand/brand_locations_screen.dart` | All locations of brand | ✅ Complete |
| `lib/screens/brand/more_locations_section.dart` | Embeddable widget | ✅ Complete |
| `lib/screens/brand/my_brands_screen.dart` | Lister management | ✅ Complete |

### Documentation Files
| Document | Coverage | Length |
|----------|----------|--------|
| `MULTI_LOCATION_BRANDS_IMPLEMENTATION_GUIDE.md` | Overview + all aspects | 500+ lines |
| `MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md` | Cloud Functions + rules | 300+ lines |
| `CLOUD_FUNCTION_INTEGRATION_GUIDE.md` | UI integration code | 400+ lines |
| `FRESHNESS_LOGIC_INTEGRATION.md` | Freshness system update | 400+ lines |
| `ADMIN_BRAND_MANAGEMENT.md` | Admin interface | 500+ lines |
| `MULTI_LOCATION_BRANDS_DELIVERY_SUMMARY.md` | Complete summary | 600+ lines |

## Quick Integration Steps

### 1. Deploy Cloud Functions (Day 1)
```bash
# Copy code from MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md
# to your Firebase functions directory
firebase deploy --only functions
```
**Time:** 30 minutes
**Docs:** MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md

### 2. Create Brand Dialog (Day 1-2)
```dart
// Copy _createBrand() from CLOUD_FUNCTION_INTEGRATION_GUIDE.md
// Add to MyBrandsScreen._showCreateBrandDialog()
```
**Time:** 20 minutes
**Docs:** CLOUD_FUNCTION_INTEGRATION_GUIDE.md Part 1

### 3. Wire Link/Unlink (Day 2-3)
```dart
// Copy brand selector from CLOUD_FUNCTION_INTEGRATION_GUIDE.md
// Add link functionality to listing edit screen
```
**Time:** 45 minutes
**Docs:** CLOUD_FUNCTION_INTEGRATION_GUIDE.md Part 2-3

### 4. Add MoreLocationsSection to Listing Detail (Day 3)
```dart
// Add to ListingDetailScreen body:
if (listing.brandId != null) {
  MoreLocationsSection(
    currentListing: listing,
    brandId: listing.brandId!,
  );
}
```
**Time:** 10 minutes
**Docs:** MULTI_LOCATION_BRANDS_IMPLEMENTATION_GUIDE.md

### 5. Update Freshness Logic (Day 4)
```dart
// Update your shouldAutoHideListing() function
// Add brand exemption check
// See: FRESHNESS_LOGIC_INTEGRATION.md Pattern 1
```
**Time:** 30 minutes
**Docs:** FRESHNESS_LOGIC_INTEGRATION.md

### 6. Add Admin Controls (Day 5 - Optional)
```dart
// Add AdminBrandsManagementScreen to navigation
// Copy from ADMIN_BRAND_MANAGEMENT.md Part 1
```
**Time:** 60 minutes (optional)
**Docs:** ADMIN_BRAND_MANAGEMENT.md

## Data Models at a Glance

### BrandModel
```dart
class BrandModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? description;
  final String ownerUid;
  final bool isVerified;        // Admin
  final bool freshnessExempt;   // Admin
  final int createdAt;
  final int updatedAt;
}
```

### ListingModel (Extended)
```dart
class ListingModel {
  // ... existing fields ...
  String? brandId;              // NEW - Link to brand
  String? locationLabel;         // NEW - Display name
}
```

## Service Methods Quick Reference

### BrandService - Read Operations
```dart
BrandModel? brand = await brandService.getBrand(brandId);
List<BrandModel> brands = await brandService.getUserBrands(uid);
List<ListingModel> locations = await brandService.getBrandLocations(brandId);
List<ListingModel> siblings = await brandService.getOtherBrandLocations(listingId, brandId);

// Streams for real-time
Stream<List<BrandModel>> brandsStream = brandService.getUserBrandsStream(uid);
Stream<List<ListingModel>> locatingsStream = brandService.getBrandLocationsStream(brandId);
```

### BrandService - Cloud Function Callables
```dart
// Create brand
String brandId = await brandService.createBrand(
  name: 'Subway',
  logoUrl: 'https://...',
  description: 'Fast food chain',
);

// Update brand
await brandService.updateBrand(
  brandId: 'brand_123',
  name: 'Subway (Updated)',
  isVerified: true,  // Admin only
  freshnessExempt: true,  // Admin only
);

// Link listing
await brandService.linkListingToBrand(
  listingId: 'listing_456',
  brandId: 'brand_123',
  locationLabel: 'Subway – Port of Spain',
);

// Unlink listing
await brandService.unlinkListingFromBrand('listing_456');

// Delete brand
await brandService.deleteBrand(
  brandId: 'brand_123',
  unlinkListings: true,
);
```

### BrandService - Utilities
```dart
double distance = brandService.calculateDistance(lat1, lon1, lat2, lon2);
List<ListingModel> sorted = brandService.sortLocationsByDistance(locations, userLat, userLon);
String displayName = brandService.getLocationDisplayName(listing, brand);
bool isBrand = brandService.isBrandLocation(listing);
```

## Common Operations

### Create a Brand
```dart
try {
  final brandId = await brandService.createBrand(
    name: 'My Chain',
    description: 'Multi-location business',
  );
  // Success
} catch (e) {
  // Handle error
}
```
**Guide:** CLOUD_FUNCTION_INTEGRATION_GUIDE.md Part 1

### Link Listings Together
```dart
// Get user's brands
final brands = await brandService.getUserBrands(currentUserId);

// Show selector
showBrandSelectorDialog(
  context: context,
  userBrands: brands,
  onBrandSelected: (brand) {
    brandService.linkListingToBrand(
      listingId: listing.id,
      brandId: brand.id,
      locationLabel: 'Name – Location',
    );
  },
);
```
**Guide:** CLOUD_FUNCTION_INTEGRATION_GUIDE.md Part 2

### Show Brand Locations
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BrandLocationsScreen(
      brandId: brand.id,
      brandName: brand.name,
    ),
  ),
);
```

### Embed Other Locations on Listing Detail
```dart
if (listing.brandId != null) {
  MoreLocationsSection(
    currentListing: listing,
    brandId: listing.brandId!,
    onLocationsLoaded: () {},
  );
}
```

### Check Brand Freshness Exemption
```dart
Future<bool> shouldHideListing(ListingModel listing) async {
  // New: Check brand exemption
  if (listing.brandId != null) {
    final brand = await brandService.getBrand(listing.brandId!);
    if (brand?.freshnessExempt == true) {
      return false; // Keep visible
    }
  }
  
  // Continue with age check...
}
```
**Guide:** FRESHNESS_LOGIC_INTEGRATION.md

### Verify and Exempt Brands (Admin)
```dart
// Show admin interface
AdminBrandsManagementScreen()

// Or programmatically:
await brandService.updateBrand(
  brandId: 'brand_123',
  isVerified: true,
  freshnessExempt: true,
);
```
**Guide:** ADMIN_BRAND_MANAGEMENT.md

## Error Handling

### Cloud Function Errors
```dart
try {
  await brandService.createBrand(name: 'Brand');
} on FirebaseFunctionsException catch (e) {
  print('Code: ${e.code}');      // 'already-exists', 'permission-denied'
  print('Message: ${e.message}'); // Backend error message
  print('Details: ${e.details}'); // Additional info
} catch (e) {
  print('Network or other error: $e');
}
```

## Testing Checklist

### MVP Testing (Required)
- [ ] Create brand via dialog
- [ ] Link 2 listings to brand
- [ ] View linked listings in MyBrandsScreen
- [ ] Tap "View all" to see BrandLocationsScreen
- [ ] See "More Locations" on listing detail
- [ ] Tap other location to navigate
- [ ] Unlink listing from brand
- [ ] Auto-hide logic respects brand exemption

### Full Testing (Recommended)
- [ ] Create multiple brands
- [ ] Link/unlink multiple times
- [ ] Test with old listings
- [ ] Test freshness exemption
- [ ] Test admin toggles
- [ ] Test sort options (distance, name, newest)
- [ ] Test dark mode on all screens
- [ ] Test error cases (validation, permissions)
- [ ] Test with 10+ locations per brand
- [ ] Test real-time updates

## Troubleshooting

### Cloud Functions Not Calling
**Check:**
1. Functions deployed: `firebase deploy --only functions`
2. Rules updated in Firestore
3. User authenticated
4. FirebaseFunctions instance initialized

### Brand Not Showing in UI
**Check:**
1. BrandId saved in listing correctly
2. Brand document exists in Firestore
3. User has read permissions
4. Network connectivity

### Real-Time Updates Not Working
**Check:**
1. Using `.snapshots()` method (not `.get()`)
2. Widgets using StreamBuilder
3. User has read permissions for collection

### Freshness Exemption Not Working
**Check:**
1. Brand exists and has brandId
2. Admin set `freshnessExempt = true`
3. Listing freshness check includes brand check
4. Listing has `brandId` field populated

## Performance Tips

### Reduce Brand Lookups
```dart
// Cache brands instead of looking up repeatedly
final _brandCache = <String, BrandModel>{};

Future<BrandModel?> getCachedBrand(String id) async {
  if (_brandCache.containsKey(id)) {
    return _brandCache[id];
  }
  final brand = await brandService.getBrand(id);
  if (brand != null) _brandCache[id] = brand;
  return brand;
}
```

### Batch Location Lookups
```dart
// Get multiple brands at once
final brandIds = [...]; // List of IDs
final brands = await firestore
    .collection('brands')
    .where(FieldPath.documentId, whereIn: brandIds)
    .get();
```

### Limit Real-Time Streams
```dart
// Only stream what you're displaying
Stream<List<ListingModel>> locations = 
  brandService.getBrandLocationsStream(brandId)
    .map((list) => list.take(20).toList());
```

## Navigation Integration

### Add to Lister Menu
```dart
ListTile(
  leading: Icon(Icons.storefront),
  title: Text('My Brands'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MyBrandsScreen()),
  ),
)
```

### Add to Admin Menu
```dart
ListTile(
  leading: Icon(Icons.verified),
  title: Text('Brand Management'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AdminBrandsManagementScreen()),
  ),
)
```

## Feature Flags

### Enable for Phase Rollout
```dart
// Config
const BRANDS_FEATURE_ENABLED = true;
const SHOW_VERIFIED_BADGE = true;
const SHOW_MORE_LOCATIONS = true;
const ADMIN_BRAND_MANAGEMENT = false; // Enable later

// Usage
if (BRANDS_FEATURE_ENABLED && listing.brandId != null) {
  MoreLocationsSection(...);
}
```

## Key Dates & Dependencies

**Features Dependent On This:**
- Listing detail screen (show more locations)
- Search results (group by brand)
- Admin dashboard (brand management)
- Freshness system (exemption logic)

**Dependent On These:**
- Firebase Cloud Functions deployment
- Firestore indexes creation
- Security rules update

## Support & Documentation

**Implementation Questions:**
- Overview: `MULTI_LOCATION_BRANDS_IMPLEMENTATION_GUIDE.md`
- Data models: See "Data Model Changes" section
- Cloud functions: See "Cloud Functions Reference" section

**Integration Questions:**
- UI wiring: `CLOUD_FUNCTION_INTEGRATION_GUIDE.md`
- Freshness: `FRESHNESS_LOGIC_INTEGRATION.md`
- Admin: `ADMIN_BRAND_MANAGEMENT.md`

**Code Examples:**
All guides include ready-to-copy code snippets.

## Status Summary

| Component | Status | Location |
|-----------|--------|----------|
| BrandModel | ✅ Complete | `lib/listings/model/brand_model.dart` |
| ListingModel extension | ✅ Complete | `lib/listings/model/listing_model.dart` |
| BrandService queries | ✅ Complete | `lib/listings/services/brand_service.dart` |
| Cloud function callables | ✅ Complete | Same file |
| Cloud Functions code | ✅ Complete | `MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md` |
| BrandLocationsScreen | ✅ Complete | `lib/screens/brand/brand_locations_screen.dart` |
| MoreLocationsSection | ✅ Complete | `lib/screens/brand/more_locations_section.dart` |
| MyBrandsScreen | ✅ Complete | `lib/screens/brand/my_brands_screen.dart` |
| Documentation | ✅ Complete | 6 comprehensive guides |

**Overall Status:** 🟢 Ready for Deployment

