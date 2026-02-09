# Shipping Fee Implementation

## Overview
Listers can now set an optional shipping fee when they enable the Shipping fulfillment method. The fee is automatically added to the order total and displayed to customers at checkout.

---

## Changes Made

### 1. **ListingModel** (`lib/listings/model/listing_model.dart`)

Added shipping fee field with 3 location updates:

**Declaration:**
```dart
bool storeShippingEnabled; // Shipping/carrier fulfillment
double storeShippingFee; // Shipping cost (0 for free shipping)
int storeLeadTimeHours;
```

**Constructor (default value):**
```dart
this.storeShippingFee = 0.0,
```

**Serialization (fromJson):**
```dart
storeShippingFee: (json['storeShippingFee'] ?? 0).toDouble(),
```

**Serialization (toJson):**
```dart
'storeShippingFee': storeShippingFee,
```

---

### 2. **Store Settings Screen** (`lib/screens/store/store_settings_screen.dart`)

**Added shipping fee state variable:**
```dart
late double _shippingFee;
```

**Initialize in initState:**
```dart
_shippingFee = widget.listing.storeShippingFee;
```

**Update in _saveSettings:**
```dart
updatedListing.storeShippingFee = _shippingFee;

// In service call
shippingFee: _shippingFee,
```

**Added Shipping Fee Input Card** (shown only when shipping is enabled):
- Text input for fee amount
- Currency symbol prefix (e.g., "$" for USD, "€" for EUR)
- Display listing's currency code
- Decimal number input (0.00, 5.99, etc.)
- Optional with "Leave empty or 0 for free shipping" hint
- Props resizing/padding for better UX

---

### 3. **Store Service** (`lib/listings/services/store_service.dart`)

Updated `updateListingStoreSettings()` method signature:

**Before:**
```dart
Future<void> updateListingStoreSettings({
  required String listingId,
  required bool pickupEnabled,
  required bool deliveryEnabled,
  required bool dineInEnabled,
  required bool shippingEnabled,
  required int leadTimeHours,
}) async { ... }
```

**After:**
```dart
Future<void> updateListingStoreSettings({
  required String listingId,
  required bool pickupEnabled,
  required bool deliveryEnabled,
  required bool dineInEnabled,
  required bool shippingEnabled,
  required double shippingFee,  // NEW
  required int leadTimeHours,
}) async {
  await _firestore.collection('listings').doc(listingId).update({
    'storePickupEnabled': pickupEnabled,
    'storeDeliveryEnabled': deliveryEnabled,
    'storeDineInEnabled': dineInEnabled,
    'storeShippingEnabled': shippingEnabled,
    'storeShippingFee': shippingFee,  // NEW
    'storeLeadTimeHours': leadTimeHours,
    'updatedAt': Timestamp.now(),
  });
}
```

---

### 4. **Cart Screen** (`lib/screens/store/cart_screen.dart`)

**Added new getters for price calculation:**
```dart
double get _subtotal {
  return widget.cartItems.fold(0, (sum, item) => sum + item.total);
}

double get _shippingCost {
  return _fulfillmentMethod == FulfillmentMethod.shipping 
      ? widget.listing.storeShippingFee 
      : 0.0;
}

double get _total {
  return _subtotal + _shippingCost;
}
```

**Updated _buildSubtotalRow()** to show breakdown:
- Shows "Subtotal" with amount (when shipping is free)
- Shows "Shipping" fee ONLY if shipping cost > 0 and selected
- Shows "Total" with "Subtotal + Shipping Fee"
- Color-codes shipping fee in primary color
- Divider between fee and total

**Example display:**
```
Subtotal    $45.00
Shipping    [not shown if free]
────────────────────
Total       $45.00
```

**With shipping fee:**
```
Subtotal    $45.00
Shipping    $5.99
────────────────────
Total       $50.99
```

**Updated order creation:**
```dart
final orderRequest = OrderRequest(
  estimatedTotal: _total,  // Was: _subtotal
  // ... other fields
);
```

---

### 5. **Order Detail Screen** (`lib/screens/store/order_detail_screen.dart`)

**Enhanced Total section** to show breakdown when shipping is used:

**Display Logic:**
- Always shows subtotal (calculated from items)
- Shows "Shipping Fee" row ONLY if:
  - Order fulfillment method is SHIPPING
  - AND shipping data exists (`_currentOrder.shipping?.hasData == true`)
- Shows divider and then total

**Subtotal Calculation (real-time from items):**
```dart
_currentOrder.items.fold(0.0, (sum, item) {
  return sum + (item.qty * item.unitPrice);
})
```

**Shipping Fee Calculation (derived from total):**
```dart
_currentOrder.estimatedTotal - [subtotal calculated above]
```

**Example display in order details:**
```
ITEMS SECTION
├─ Item 1: Burger   x2 @ $15.00
└─ Item 2: Drink    x1 @ $5.00

Subtotal    $35.00
Shipping    $5.99
────────────────────
Total       $40.99
```

---

## User Flows

### Lister Setting Shipping Fee

1. Open Store Settings
2. Enable "Shipping" checkbox
3. Shipping Fee card appears below
4. Enter fee amount with currency visible (e.g., "$ 5.99")
5. Leave empty or enter 0 for free shipping
6. Save Settings
7. Fee is stored in Firestore: `listings/{id}.storeShippingFee = 5.99`

### Customer Checkout

1. Add items to cart
2. Choose "Shipping" fulfillment method
3. Cart displays:
   - Subtotal: $35.00
   - Shipping: $5.99 (if fee exists)
   - Total: $40.99
4. Customer enters shipping address + instructions
5. Places order with total including fee

### Order Details (Both Views)

1. Lister/Customer opens order
2. See itemized cost breakdown
3. If shipping order: Shipping fee line shown
4. Total always reflects items + shipping fee (if applicable)

---

## Data Structure in Firestore

**Listing document:**
```json
{
  "id": "listing123",
  "storeShippingEnabled": true,
  "storeShippingFee": 5.99,
  "storeCurrencyCode": "USD"
}
```

**Order document:**
```json
{
  "id": "order456",
  "items": [
    { "qty": 2, "unitPrice": 15.00 },
    { "qty": 1, "unitPrice": 5.00 }
  ],
  "estimatedTotal": 40.99,
  "fulfillment": {
    "method": "shipping"
  },
  "shipping": {
    "address": "123 Main St, Springfield, IL",
    "instructions": "Leave at front door"
  }
}
```

---

## Currency Support

Displays the listing's currency code:
- **USD** → $
- **EUR** → €
- **GBP** → £
- **TTD/JMD** → $ (Caribbean currencies)
- Default fallback → $

Example display with different currencies:
- USD: $ 5.99
- EUR: € 5.99
- GBP: £ 5.99

---

## Validation

✅ **Shipping Fee Input:**
- Decimal numbers allowed (5.99, 10, 0.50)
- Zero and empty string treated as free shipping
- Negative numbers prevented (input type is number)
- Optional field (no required validation)

✅ **Order Total Calculation:**
- Formula: `Items Subtotal + Shipping Fee`
- Applied ONLY when fulfillment method is SHIPPING
- Other methods (pickup, delivery, dine-in) ignore shipping fee

---

## Testing Checklist

**Lister Settings:**
- [ ] Shipping fee card hidden when shipping is disabled
- [ ] Shipping fee card shown when shipping is enabled
- [ ] Currency symbol displays correctly (USD, EUR, etc.)
- [ ] Can enter decimal amounts (5.99, 10.00)
- [ ] Can leave empty for free shipping
- [ ] Fee is saved to Firestore
- [ ] Fee persists after navigation and reload

**Checkout:**
- [ ] Shipping fee hidden when other methods selected
- [ ] Shipping fee shown correctly at checkout
- [ ] Order total = items + shipping fee
- [ ] Order created with correct total including fee
- [ ] Free shipping (fee = 0) works correctly

**Order Details:**
- [ ] Shipping fee line visible only for shipping orders
- [ ] Shipping fee calculated correctly from items
- [ ] Total matches database estimatedTotal
- [ ] Works in both lister and customer views
- [ ] Dark mode displays correctly
- [ ] Divider appears between fee and total

---

**Implementation Date:** February 8, 2026  
**Status:** ✅ Complete and Ready for Testing
