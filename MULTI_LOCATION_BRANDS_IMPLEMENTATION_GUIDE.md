# Multi-Location Brands - Implementation Guide

Complete guide for implementing and integrating multi-location brands into the CaribTap Flutter application.

## Overview

This feature enables businesses to group multiple physical locations under a single brand identity. Examples:
- Restaurant chains (KFC, Subway, etc.)
- Retail stores (multiple branches)
- Service providers with multiple offices

## Data Model Changes

### 1. Brand Model (`lib/listings/model/brand_model.dart`)
New complete brand entity with verification and freshness exemption flags.

**Key Fields:**
- `id`: Unique brand identifier
- `name`: Brand display name
- `logoUrl`: Optional brand logo
- `description`: Optional brand description
- `ownerUid`: User who created the brand
- `isVerified`: Admin-only flag indicating verified brands
- `freshnessExempt`: Admin-only flag to exempt all locations from auto-hide
- `createdAt`, `updatedAt`: Timestamps

### 2. Listing Model Updates (`lib/listings/model/listing_model.dart`)
Added two new optional fields:

```dart
String? brandId;              // Links to brand
String? locationLabel;         // Custom display name (e.g., "KFC – Maraval")
```

## Services

### BrandService (`lib/listings/services/brand_service.dart`)
Comprehensive service for brand operations:

**Key Methods:**
- `getBrand(brandId)`: Fetch a single brand
- `getUserBrands(uid)`: Get user's brands
- `getBrandLocations(brandId)`: Get all listings for a brand
- `getOtherBrandLocations(listingId, brandId)`: Get other locations for a listing
- `getBrandLocationsStream(brandId)`: Real-time updates
- `isBrandLocation(listing)`: Check if listing is part of a brand
- `getLocationDisplayName(listing, brand)`: Derive display name with fallback
- `calculateDistance()`: Haversine formula for distance
- `sortLocationsByDistance()`: Sort locations by proximity

**Usage Examples:**

```dart
// Get a brand
BrandModel? brand = await brandService.getBrand('brand123');

// Stream brand locations
Stream<List<ListingModel>> locations = 
  brandService.getBrandLocationsStream('brand123');

// Display location with brand context
String displayName = brandService.getLocationDisplayName(listing, brand);
// Result: "KFC – Maraval" or "KFC – Port of Spain"
```

## Cloud Functions (Callables)

All CRUD operations for brands should use Cloud Functions for security. See `MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md` for complete implementation.

**Functions:**
1. `createBrand()` - Create new brand
2. `updateBrand()` - Update brand details (admin-only for verification flags)
3. `linkListingToBrand()` - Link listing to brand
4. `unlinkListingFromBrand()` - Remove listing from brand
5. `deleteBrand()` - Delete brand

## UI Components

### 1. MoreLocationsSection Widget
(`lib/screens/brand/more_locations_section.dart`)

**Purpose:** Display up to 3 other brand locations on listing detail screen

**Usage in listing detail:**
```dart
if (listing.brandId != null && listing.brandId!.isNotEmpty) {
  MoreLocationsSection(
    currentListing: listing,
    brandId: listing.brandId!,
    onLocationsLoaded: () {
      // Optional callback
    },
  );
}
```

**Features:**
- Horizontal carousel of nearby locations
- "View all" button links to BrandLocationsScreen
- Tap any location to navigate to its detail screen
- Dark mode support

### 2. BrandLocationsScreen
(`lib/screens/brand/brand_locations_screen.dart`)

**Purpose:** Full brand locations display with map/list and sorting

**Navigation:**
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

**Features:**
- Brand header with logo and description
- Verified brand indicator
- Location list with:
  - Photos
  - Name and address
  - Phone number
  - Distance (future)
- Sorting options:
  - Nearest (default)
  - Name (A-Z)
  - Newest
- Tap location to view detail

### 3. MyBrandsScreen
(`lib/screens/brand/my_brands_screen.dart`)

**Purpose:** Lister dashboard for managing brands

**Navigation (add to lister menu):**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MyBrandsScreen(
      currentUser: currentUser,
    ),
  ),
);
```

**Features:**
- List user's brands with real-time updates
- Create new brand dialog
- Edit brand details
- Manage linked locations
- Show verified badge

### 4. BrandDetailScreen
(Part of MyBrandsScreen file)

**Purpose:** Manage locations for a specific brand

**Shows:**
- Brand header
- List of linked locations
- Options to add/remove locations

## Listing Freshness Integration

Update your listing freshness checking logic to respect brand exemption:

### Updated Auto-Hide Logic

```dart
Future<bool> shouldAutoHideListing(ListingModel listing) async {
  // 1. Check listing-level exemption
  if (listing.freshness.exempt) {
    return false;
  }

  // 2. Check lister-level exemption
  final lister = await getUserData(listing.authorID);
  if (lister.listingFreshnessExempt) {
    return false;
  }

  // 3. Check brand-level exemption
  if (listing.brandId != null && listing.brandId!.isNotEmpty) {
    final brand = await brandService.getBrand(listing.brandId!);
    if (brand?.freshnessExempt == true) {
      return false; // Brand is exempt from auto-hide
    }
  }

  // 4. Apply freshness rules
  final daysSinceListing = DateTime.now()
      .difference(DateTime.fromMillisecondsSinceEpoch(listing.createdAt))
      .inDays;

  return daysSinceListing > FRESHNESS_THRESHOLD;
}
```

### Where to Update

1. **Auto-hide background job:**
   - Update Cloud Function that checks listing freshness
   - Add brand exemption check before marking hidden

2. **Listing detail screen:**
   - Show exemption reason if brand is exempt
   - Display badge: "Part of verified chain" if isVerified

3. **Lister dashboard:**
   - Show exemption status
   - Display "Grouped under [Brand Name]"

## Admin Features

### Admin Panel Updates

Add these sections to existing admin control panel:

#### 1. Verify Brands
```dart
// Admin can toggle isVerified=true
// Shows verified brand badge on customer UI
// Verified brands get priority in search/discovery
```

#### 2. Manage Brand Freshness Exemption
```dart
// Admin can toggle freshnessExempt=true
// When true, ALL locations under brand are exempt from auto-hide
// Use for established chains that should always be visible
```

#### 3. Reassign Brand Ownership
```dart
// Admin callable: changeChannelOwner({ brandId, newOwnerUid })
// Allows admin to transfer brands between users
```

**Implementation in admin screen:**
```dart
if (isAdmin) {
  // In brand list
  Switch(
    value: brand.isVerified,
    onChanged: (value) => updateBrandVerification(brand.id, value),
    label: 'Verified',
  );
  
  Switch(
    value: brand.freshnessExempt,
    onChanged: (value) => updateBrandFreshnessExempt(brand.id, value),
    label: 'Freshness Exempt',
  );
}
```

## Firestore Indexes

Required indexes for efficient querying:

```json
{
  "indexes": [
    {
      "collectionGroup": "listings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "brandId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "brands",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerUid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "brands",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isVerified", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

## Firestore Security Rules

See `MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md` for complete rules.

**Key principles:**
- Brands are readable by all authenticated users
- Brand creation is open to all or can require Premium
- Brand updates restricted to owner or admin
- Freshness exemption edits are admin-only
- Listing-brand connections verified via callable functions

## Feature Flags / Phased Rollout

### Phase 1 (MVP)
- ✅ Brand CRUD via Cloud Functions
- ✅ Link/unlink listings
- ✅ Display other locations on listing detail
- ✅ BrandLocationsScreen
- ✅ Lister brand management (MyBrandsScreen)

### Phase 2 (Polish)
- Admin verification UI
- Verified brand badges (UI only, flag exists)
- Freshness exemption admin controls
- Search/discovery improvements for verified brands

### Phase 3 (Advanced)
- Map view of brand locations
- Distance-based sorting with user location
- Brand search/discovery as primary feature
- Brand-level analytics
- Multi-owner collaborators on brands

## Integration Checklist

- [ ] Create `lib/listings/model/brand_model.dart`
- [ ] Update `lib/listings/model/listing_model.dart` (add brandId, locationLabel)
- [ ] Create `lib/listings/services/brand_service.dart`
- [ ] Deploy Cloud Functions from `MULTI_LOCATION_BRANDS_CLOUD_FUNCTIONS.md`
- [ ] Create `lib/screens/brand/brand_locations_screen.dart`
- [ ] Create `lib/screens/brand/more_locations_section.dart`
- [ ] Create `lib/screens/brand/my_brands_screen.dart`
- [ ] Add MoreLocationsSection to existing listing detail screen
- [ ] Add "My Brands" link to lister menu
- [ ] Update listing freshness logic with brand exemption check
- [ ] Add admin brand management UI (optional for MVP)
- [ ] Create Firestore indexes from `firestore.indexes.json`
- [ ] Update Firestore security rules
- [ ] Test complete flow:
  1. Create brand
  2. Link 2+ listings
  3. Verify other locations show on detail
  4. Verify BrandLocationsScreen works
  5. Test sorting options
  6. Verify freshness exemption logic

## Testing Scenarios

### Scenario 1: Customer View
1. Open listing detail for "Subway – Port of Spain"
2. See "More Locations" section with "Subway – San Fernando" and "Subway – Maraval"
3. Tap "View all" to see BrandLocationsScreen
4. Tap a location to navigate to its detail

### Scenario 2: Lister Setup
1. Go to "My Brands" from menu
2. Create brand "Subway"
3. Click manage locations
4. Add "Port of Spain" location
5. Add "San Fernando" and "Maraval" locations
6. See all 3 in list

### Scenario 3: Freshness Exemption
1. Admin verifies brand "Subway" and sets freshnessExempt=true
2. All 3 Subway locations have old createdAt timestamps
3. Auto-hide job runs but SKIPS these 3 listings
4. They remain visible in search/discovery
5. Non-brand listing with same age gets auto-hidden

### Scenario 4: Discovery
1. Customer searches "Subway"
2. All 3 locations appear (grouped by brand)
3. Shows "Subway – Port of Spain", "Subway – San Fernando", "Subway – Maraval"
4. Can tap to navigate to any location detail

## Deployment Steps

1. **Deploy Cloud Functions:** Deploy all 5 callables
2. **Update Firestore Rules:** Apply rules with brand collection
3. **Create Indexes:** Add required indexes to Firestore
4. **Update Flutter App:**
   - Add all new model files
   - Add BrandService
   - Add all UI screens
   - Update listing detail to include MoreLocationsSection
   - Update listings freshness logic
5. **Test Thoroughly:** Follow testing scenarios
6. **Roll Out:** Enable feature for Premium users first, then all

## Performance Considerations

- Brand locations queries use index on `brandId` (ascending) + `createdAt` (descending)
- Real-time updates via Firestore streams used for MyBrandsScreen
- MoreLocationsSection limits to 3 items for performance
- Distance calculations done client-side (later can be moved to Cloud Function)
- Caching: Consider caching brand details for frequently accessed brands

## Future Enhancements

1. **Map View:** Interactive map showing all brand locations
2. **Distance Sorting:** Server-side geohashing for efficient distance queries
3. **Collaborators:** Multiple users can manage a brand
4. **Analytics:** Brand-level analytics dashboard
5. **API Integration:** Public API for partners to query brands/locations
6. **Dynamic Links:** Deep links to brand locations
7. **Reviews Aggregation:** Combined reviews across all brand locations
8. **Bulk Operations:** Admin tools to manage multiple brands
9. **Branding Rules:** Define brand guidelines (colors, fonts, imagery)
10. **Location Hours:** Extend to per-location hours within brand

