# Premium Rentals - Full Booking Solution

## Overview

A complete rental booking system built to mirror the familiar store/catalog browsing experience. Customers can browse available rental items, select dates, add to cart, and checkout - just like shopping for products.

## Architecture

### 1. **Rental Item Models** (`rental_item_models.dart`)

#### RentalCartItem
- Represents a rental item in the shopping cart
- Contains: unit details, date range, pricing, photos
- Calculates duration automatically

#### RentalItemBrowse
- Browse-friendly model for displaying rental inventory
- Fetched from `rental_units` Firestore collection
- Supports vehicle details (license plate, make, model, year, color)

### 2. **Rental Browse Service** (`rental_browse_service.dart`)

Core service handling all rental operations:

#### Key Methods:
- **`getAvailableRentalItems(listingId)`** - Stream of available units
- **`isAvailableForDates()`** - Check availability for specific dates
- **`calculatePrice()`** - Price calculation based on duration and pricing unit
- **`createRentalBooking()`** - Create booking with cart items
- **`getCustomerBookings()`** - Fetch customer's booking history
- **`getActiveRentals()`** - Get currently active rentals
- **`searchRentalItems()`** - Search/filter rental items

### 3. **User-Facing Screens**

#### RentalBrowseScreen (Main Interface)
**Path**: `lib/screens/rentals/rental_browse_screen.dart`

Features:
- Grid display of available rental items (like store catalog)
- Search functionality
- Sort by: name, price (low to high), price (high to low)
- Shopping cart with item count badge
- Bottom sheet for item details and date selection

**Components**:
- `_RentalItemCard` - Grid item showing unit photo, name, price, "Book Now" button
- `_RentalItemDetailSheet` - Modal for selecting rental dates and checking availability
  - Date picker (start and end dates)
  - Real-time price calculation
  - Availability checking before adding to cart
  - Visual price summary

#### RentalCheckoutScreen (Booking Completion)
**Path**: `lib/screens/rentals/rental_checkout_screen.dart`

Features:
- Cart review with all booked items
- Lister information card
- Rental terms & conditions display
- Deposit calculation (if required)
- Additional notes field for customer
- Price breakdown (subtotal, deposit, total)
- Terms agreement checkbox
- One-click booking submission

## User Flow

### Customer Journey:

1. **Browse Rental Items**
   - Navigate from listing details → "Browse & Book Rentals"
   - View grid of available items
   - Search/filter by name
   - Sort by price or name

2. **Select Rental Details**
   - Tap item to open detail sheet
   - Choose start and end dates
   - See real-time price calculation
   - System checks availability
   - Add to cart

3. **Review Cart**
   - View all selected rentals
   - See duration and pricing breakdown
   - Can remove items
   - See lister information

4. **Checkout**
   - Review rental terms and conditions
   - See deposit requirement (if applicable)
   - Add special notes/requests
   - Agree to terms
   - Complete booking

5. **Confirmation**
   - Booking created with "pending" status
   - Awaits lister confirmation
   - Customer receives confirmation

### Lister/Owner Journey:

1. **Configure Rentals** (Add Listing Screen)
   - Enable rentals with toggle
   - Set pricing unit (hourly/daily/weekly/monthly)
   - Set base price
   - Configure deposit requirement
   - Add terms & conditions
   - Set buffer time between bookings

2. **Manage Rental Inventory**
   - Add rental units (individual items)
   - Upload photos
   - Set availability status
   - For vehicles: add license plate, make, model, year, color

3. **Manage Bookings** (Add Listing Screen)
   - View incoming booking requests
   - Confirm or decline bookings
   - Track active rentals
   - Handle disputes

## Database Schema

### Collections

#### `rental_units`
```javascript
{
  id: string,
  listingId: string,
  unitName: string,
  description: string,
  rentalType: 'general' | 'vehicle',
  basePrice: double,
  pricingUnit: 'hourly' | 'daily' | 'weekly' | 'monthly',
  currencyCode: string,
  photos: [string], // URLs
  status: 'available' | 'rented' | 'maintenance' | 'unavailable',
  stockQty: number,
  vehicleDetails: {
    licensePlate: string,
    make: string,
    model: string,
    year: number,
    color: string,
    odometer: number,
    fuelLevel: number
  },
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### `rental_bookings`
```javascript
{
  id: string,
  listingId: string,
  rentalUnitId: string,
  customerId: string,
  listerId: string,
  startTime: timestamp,
  endTime: timestamp,
  totalAmount: double,
  status: 'pending' | 'confirmed' | 'active' | 'completed' | 'cancelled' | 'disputed',
  cartItems: [
    {
      rentalUnitId: string,
      unitName: string,
      startDate: timestamp,
      endDate: timestamp,
      pricePerDay: double,
      totalPrice: double
    }
  ],
  depositAmount: double,
  customerNotes: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## Integration Points

### 1. **Listing Details Screen**
- Import: `RentalBrowseScreen`
- Button: "Browse & Book Rentals" (replaces old dialog)
- Navigation: Opens full rental browsing interface

### 2. **Add/Edit Listing Screen**
- `RentalConfigEditor` - Configure rental settings
- "Manage Rental Bookings" button - Opens RentalBookingsScreen
- Only visible when editing and rentals enabled

### 3. **Price Calculation**
Supports all pricing units:
```dart
calculatePrice(basePrice, unit, startDate, endDate)
- hourly: basePrice * hours
- daily: basePrice * (days + 1)
- weekly: basePrice * ceil((days + 1) / 7)
- monthly: basePrice * ceil((days + 1) / 30)
```

## Features Implemented

✅ **Browsing**
- Grid view of available items
- Search functionality
- Sorting options
- Item detail sheets

✅ **Booking**
- Date range selection
- Availability checking
- Real-time price calculation
- Shopping cart interface
- Multiple items per booking

✅ **Checkout**
- Price breakdown with deposits
- Terms & conditions display
- Customer notes
- One-click booking

✅ **Management**
- Rental configuration editor
- Booking management dashboard
- Status workflow (pending → confirmed → active → completed/cancelled/disputed)

✅ **Search & Filter**
- Search by name
- Sort by price and name
- Filter by availability
- Filter by date range

## Key Differences from Old Solution

| Aspect | Old | New |
|--------|-----|-----|
| **UX** | Simple dialog | Full browse experience |
| **Cart** | Single item | Multiple items support |
| **Interface** | Modal dialog | Full screen navigation |
| **Familiarity** | Basic form | Store-like experience |
| **Inventory** | Not shown | Full grid display |
| **Checkout** | Single step | Multi-step review |

## File Structure

```
lib/screens/rentals/
├── rental_item_models.dart          # RentalCartItem, RentalItemBrowse
├── rental_browse_service.dart       # RentalBrowseService
├── rental_browse_screen.dart        # Main browsing interface
└── rental_checkout_screen.dart      # Booking review & completion
```

## Next Steps / Future Enhancements

- [ ] **Payment Integration** - Connect to payment processor for deposits
- [ ] **Insurance Options** - Add optional rental insurance
- [ ] **Mileage Overage** - For vehicle rentals, track and charge mileage
- [ ] **Damage Assessment** - Photo evidence capture for checkout/checkin
- [ ] **Reviews & Ratings** - Customer feedback on rental items
- [ ] **Rental Calendar** - Visual availability calendar
- [ ] **Email Notifications** - Booking confirmations, reminders
- [ ] **Analytics** - Track popular items, peak seasons
