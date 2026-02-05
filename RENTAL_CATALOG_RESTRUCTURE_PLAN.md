# Rental Catalog Restructure Plan

## Restore Point
✅ Created git tag: `rental-v1-basic`
- To restore: `git checkout rental-v1-basic`

## Current Issue
The rental system treats the **listing itself** as the item being rented. This doesn't scale when a lister wants to rent multiple different items (e.g., tools, vehicles, equipment).

## Desired Structure (Store Model)
Like the Mini Store where:
- **Listing** = The business/lister
- **Catalog Items** = Individual products for sale
- **Catalog Manager** = Interface to manage inventory
- **Store Browse** = Customer shopping experience

## New Rental Structure

### 1. **Rental Catalog Item Model**
Similar to `CatalogItem`, but rental-specific:

```dart
class RentalCatalogItem {
  String id;
  String listingId;  // Parent listing
  String name;
  String? description;
  String category;  // 'Tools', 'Vehicles', 'Equipment', etc.
  double basePrice;
  RentalPricingUnit pricingUnit;  // hourly, daily, weekly, monthly
  String currencyCode;
  List<String> photos;
  List<String> videos;
  bool isAvailable;
  int stockQty;  // Number of units available
  
  // Vehicle-specific (optional)
  VehicleDetails? vehicleDetails;
  
  // Rental-specific
  double? depositAmount;
  int bufferMinutes;
  bool requiresLicense;
  String? termsAndConditions;
  
  Timestamp? createdAt;
  Timestamp? updatedAt;
}
```

### 2. **Firestore Structure**
```
listings/{listingId}/
  - (listing data with rentalConfig: global settings)
  - rental_catalog/
      {itemId}/
        - (RentalCatalogItem data)
```

### 3. **Screens to Create**

#### A. **RentalCatalogManagerScreen** (Like CatalogManagerScreen)
- Lists all rental items for the lister
- Add/Edit/Delete items
- Category filtering
- Search functionality
- Access from Add/Edit Listing Screen

#### B. **RentalItemEditorScreen** (Like CatalogItemEditorScreen)  
- Add/Edit individual rental items
- Upload photos/videos
- Set pricing and availability
- Vehicle details (if applicable)
- Deposit and terms

#### C. **RentalBrowseScreen** (Already exists, needs updating)
- Browse rental catalog (not listing)
- Category filters
- Search
- Date availability checking per item
- Add to cart

#### D. **RentalCheckoutScreen** (Already exists, works as-is)
- Review cart
- Complete booking

### 4. **Service Layer**

#### **RentalCatalogService**
```dart
- getRentalCatalogItems(listingId) → Stream<List<RentalCatalogItem>>
- getRentalItem(listingId, itemId) → Future<RentalCatalogItem?>
- upsertRentalItem(listingId, item) → Future<void>
- deleteRentalItem(listingId, itemId) → Future<void>
- uploadRentalMedia(listingId, itemId, file) → Future<String>
- checkItemAvailability(itemId, startDate, endDate) → Future<bool>
```

### 5. **Integration Points**

#### Add/Edit Listing Screen
```dart
// Replace current "Manage Rental Bookings" button with two buttons:
if (rentalConfig?.isRentalEnabled ?? false) {
  - "Manage Rental Catalog" → RentalCatalogManagerScreen
  - "Manage Bookings" → RentalBookingsScreen
}
```

#### Listing Details Screen
```dart
// Replace "Browse & Book Rentals" with:
if (rentalConfig?.isRentalEnabled ?? false) {
  - Check if rental catalog has items
  - "Browse Rentals" → RentalBrowseScreen (updated)
}
```

### 6. **Migration Strategy**

#### Phase 1: Create New Components (Non-Breaking)
- Create RentalCatalogItem model
- Create RentalCatalogService  
- Create RentalCatalogManagerScreen
- Create RentalItemEditorScreen

#### Phase 2: Update Existing Components
- Update RentalBrowseScreen to fetch from rental_catalog subcollection
- Update RentalCheckoutScreen (minimal changes, mostly works)
- Update integration points in Add Listing and Listing Details

#### Phase 3: Data Migration (if needed)
- Create migration script for existing rental_units → rental_catalog
- Maintain backward compatibility during transition

### 7. **Key Differences from Store**

| Feature | Store | Rentals |
|---------|-------|---------|
| **Item Type** | Product/Service | Rental Item |
| **Pricing** | One-time | Per time unit |
| **Booking** | Immediate | Date range required |
| **Availability** | Stock count | Calendar-based |
| **Deposit** | N/A | Optional deposit |
| **Terms** | N/A | Rental T&C |
| **License** | N/A | May require (vehicles) |

### 8. **Benefits**

✅ **Scalability**: Lister can have unlimited rental items
✅ **Organization**: Categories, search, filtering
✅ **Flexibility**: Different pricing per item
✅ **Professional**: Matches store experience
✅ **Familiar UX**: Users already understand catalog model
✅ **Stock Management**: Track multiple units of same item

### 9. **Files to Create**

```
lib/listings/model/rental_catalog_item.dart
lib/listings/services/rental_catalog_service.dart
lib/screens/rentals/rental_catalog_manager_screen.dart
lib/screens/rentals/rental_item_editor_screen.dart
```

### 10. **Files to Update**

```
lib/screens/rentals/rental_browse_screen.dart
lib/screens/rentals/rental_browse_service.dart
lib/listings/listings_module/add_listing/add_listing_screen.dart
lib/listings/listings_module/listing_details/listing_details_screen.dart
```

## Implementation Order

1. ✅ Create restore point (rental-v1-basic tag)
2. ⏭️ Create RentalCatalogItem model
3. ⏭️ Create RentalCatalogService
4. ⏭️ Create RentalCatalogManagerScreen (like CatalogManagerScreen)
5. ⏭️ Create RentalItemEditorScreen (like CatalogItemEditorScreen)
6. ⏭️ Update RentalBrowseScreen to use new data source
7. ⏭️ Update integration points
8. ⏭️ Test end-to-end flow
9. ⏭️ Document changes
