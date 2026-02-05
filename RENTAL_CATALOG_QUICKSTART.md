# Rental Catalog System - Quick Start Guide

## For Listers: Adding Rental Items

### Step 1: Enable Rentals on Your Listing
1. Go to **My Listings** → Select your listing
2. Scroll to **Rentals** section
3. Toggle **Enable Rentals** ON
4. Set default pricing unit (hourly/daily/weekly/monthly)
5. Save listing

### Step 2: Manage Your Rental Catalog
1. In listing editor, scroll to Rentals section
2. Click **"Manage Rental Catalog"** button
3. You'll see your rental inventory (empty at first)

### Step 3: Add Your First Rental Item
1. Click the **➕ floating action button**
2. Fill out the form:

   **Basic Info**:
   - Item Name (e.g., "Power Drill", "Toyota Camry 2020")
   - Category (e.g., "Power Tools", "Vehicles")
   - Description (optional)

   **Pricing**:
   - Base Price (per hour/day/week/month)
   - Pricing Unit (select from dropdown)
   - Security Deposit (optional, refundable)

   **Availability**:
   - Stock Quantity (how many units you have)
   - Buffer Time (minutes between rentals for cleaning/prep)

   **Requirements**:
   - License Required? (toggle if customer needs valid license)

   **Photos & Videos**:
   - Add up to 6 photos
   - Add up to 2 videos

3. If renting vehicles, toggle **"Vehicle Rental"** and add:
   - Make, Model, Year, Color
   - License Plate, VIN

4. Add rental terms if needed
5. Click **"Save"**

### Step 4: Manage Your Items
- **Edit Item**: Tap item → Menu (⋮) → Edit
- **Delete Item**: Tap item → Menu (⋮) → Delete
- **Filter by Category**: Use category chips at top
- **View Bookings**: Go back and click "View Rental Bookings"

## For Customers: Booking Rentals

### Step 1: Browse Rentals
1. View listing details
2. Scroll to Rentals section
3. Click **"Browse & Book Rentals"**

### Step 2: Select Items
1. Browse available items in grid view
2. Use search bar to find specific items
3. Sort by: Name, Price Low→High, Price High→Low
4. Tap item card for details

### Step 3: Choose Dates & Add to Cart
1. Select **Start Date & Time**
2. Select **End Date & Time**
3. Review pricing breakdown:
   - Rental duration
   - Unit price
   - Deposit (if applicable)
   - Total cost
4. Click **"Add to Cart"**

### Step 4: Checkout
1. Tap **🛒 Cart icon** (shows item count)
2. Review all items in cart
3. See total breakdown:
   - Subtotal (all rentals)
   - Deposits
   - Grand Total
4. Review lister info
5. Agree to terms
6. Click **"Complete Booking"**

### Step 5: Track Your Booking
1. Go to **"My Rentals"** (in app menu)
2. View booking status:
   - **Pending**: Awaiting lister confirmation
   - **Confirmed**: Lister approved
   - **Active**: Currently renting
   - **Completed**: Rental finished
   - **Cancelled**: Booking cancelled

## Pricing Calculation

### Hourly
- **1 hour rental** = Base price × 1
- **3 hours rental** = Base price × 3
- **5 hours rental** = Base price × 5

### Daily  
- **1 day rental** = Base price × 1
- **3 days rental** = Base price × 3
- **1 week rental** = Base price × 7

### Weekly
- **1 week rental** = Base price × 1
- **10 days rental** = Base price × 2 (rounded up to 2 weeks)
- **2 weeks rental** = Base price × 2

### Monthly
- **1 month rental** = Base price × 1
- **45 days rental** = Base price × 2 (rounded up to 2 months)

## Availability Rules

### Stock Management
- Each item has a stock quantity (e.g., 3 drills available)
- Bookings consume stock for the date range
- If all units booked, item shows as unavailable

### Buffer Time
- Time between bookings for cleaning/maintenance
- Example: 30-minute buffer
  - Booking 1 ends at 3:00 PM
  - Booking 2 can start at 3:30 PM

### Overlap Detection
- System automatically prevents double-booking
- Checks all existing bookings for conflicts
- Shows availability in real-time

## Categories

### Suggested Categories for General Rentals
- Power Tools
- Hand Tools  
- Lawn Equipment
- Party Supplies
- Electronics
- Sports Equipment
- Camping Gear
- Photography Equipment

### Vehicle Categories
- Sedans
- SUVs
- Trucks
- Vans
- Motorcycles
- Bicycles
- Boats
- ATVs

## Best Practices

### For Listers

**Photos**:
- ✅ Use high-quality, well-lit photos
- ✅ Show item from multiple angles
- ✅ Include close-ups of unique features
- ❌ Don't use blurry or dark images

**Pricing**:
- ✅ Research competitors
- ✅ Offer weekly/monthly discounts
- ✅ Set appropriate deposits
- ❌ Don't overprice or underprice

**Descriptions**:
- ✅ Be specific and accurate
- ✅ Mention included accessories
- ✅ Note any damage or wear
- ❌ Don't exaggerate condition

**Stock Management**:
- ✅ Keep quantities accurate
- ✅ Update availability regularly
- ✅ Set realistic buffer times
- ❌ Don't overbook

**Terms & Conditions**:
- ✅ Specify usage rules
- ✅ Define damage fees
- ✅ State cancellation policy
- ✅ Mention insurance requirements

### For Customers

**Booking**:
- ✅ Book in advance
- ✅ Read terms carefully
- ✅ Contact lister with questions
- ❌ Don't book last minute

**Usage**:
- ✅ Follow usage guidelines
- ✅ Return on time
- ✅ Report damage immediately
- ❌ Don't misuse equipment

**Communication**:
- ✅ Respond to lister promptly
- ✅ Be clear about needs
- ✅ Leave honest reviews
- ❌ Don't ignore messages

## Troubleshooting

### "Premium subscription required" error
- **Cause**: Rentals require Premium tier
- **Solution**: Upgrade to Premium subscription

### Can't find "Manage Rental Catalog" button
- **Cause**: Must save listing first
- **Solution**: Save listing, then edit to see button

### Item not showing in browse screen
- **Cause**: No items in catalog yet
- **Solution**: Add items via catalog manager

### Dates unavailable
- **Cause**: Item already booked or insufficient stock
- **Solution**: Try different dates or contact lister

### Photos not uploading
- **Cause**: Network issue or file too large
- **Solution**: Check connection, resize images

### Can't delete item
- **Cause**: Active bookings exist
- **Solution**: Wait for bookings to complete or cancel them first (consider future enhancement)

## System Limits

- **Photos per item**: 6 maximum
- **Videos per item**: 2 maximum
- **Stock quantity**: No limit (practical: 1-100)
- **Buffer time**: 0-480 minutes (8 hours)
- **Pricing**: No limits
- **Description**: 1000 characters recommended
- **Categories**: Unlimited custom categories

## Support

### Common Questions

**Q: Can I have multiple pricing units in one listing?**  
A: Yes! Each catalog item can have its own pricing unit. You can have some items priced hourly, others daily, etc.

**Q: What happens to deposits?**  
A: Deposits are held during rental period and refunded after successful return (minus any damage fees).

**Q: Can customers book multiple items?**  
A: Yes! Customers can add multiple items to cart and book them together.

**Q: Do I need Premium for rentals?**  
A: Yes, rental catalog management requires Premium tier subscription.

**Q: Can I pause rentals temporarily?**  
A: Yes, disable rentals in listing editor or set stock quantity to 0.

**Q: How do I handle maintenance periods?**  
A: Create a booking for yourself (admin booking) to block dates.

## Feature Comparison

### Before Catalog Restructure
- ❌ One rental configuration per listing
- ❌ Limited to listing-level pricing
- ❌ No individual item management
- ❌ Basic availability tracking
- ❌ No category organization

### After Catalog Restructure  
- ✅ Unlimited items per listing
- ✅ Item-level pricing and photos
- ✅ Full catalog management
- ✅ Advanced availability system
- ✅ Category filtering
- ✅ Vehicle-specific tracking
- ✅ Individual terms per item
- ✅ Stock-based availability

## Quick Reference

### Lister Actions
| Action | Location | Notes |
|--------|----------|-------|
| Enable rentals | Listing Editor → Rentals | Required first step |
| Add items | Catalog Manager → ➕ | Premium required |
| Edit items | Catalog Manager → Item → ⋮ → Edit | - |
| Delete items | Catalog Manager → Item → ⋮ → Delete | Check for bookings first |
| View bookings | Listing Editor → View Rental Bookings | All statuses |
| Confirm booking | Bookings → Pending → Confirm | Customer gets notified |

### Customer Actions
| Action | Location | Notes |
|--------|----------|-------|
| Browse items | Listing Details → Browse & Book | - |
| Search items | Browse Screen → Search bar | Filters by name |
| Add to cart | Item Details → Select dates → Add | Can add multiple |
| View cart | Browse Screen → 🛒 icon | Shows total |
| Checkout | Cart → Complete Booking | Login required |
| Track booking | My Rentals | All your bookings |

### Status Flow
```
Customer Books → PENDING → Lister Confirms → CONFIRMED → 
Rental Starts → ACTIVE → Rental Ends → COMPLETED
                  ↓
              CANCELLED (by either party)
```

---

**Need help?** Contact support or check the full documentation in [RENTAL_CATALOG_IMPLEMENTATION.md](RENTAL_CATALOG_IMPLEMENTATION.md)
