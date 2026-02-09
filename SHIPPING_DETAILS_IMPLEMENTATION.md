# Shipping Details Collection & Display - Implementation Guide

## Overview
Customers can now enter shipping details (address, location, instructions) during checkout when selecting the Shipping fulfillment method. Listers can view these details in the Order Details Screen.

---

## Changes Made

### 1. Order Model (`lib/listings/model/order_request.dart`)

**Extended ShippingInfo Class:**
- Added customer-provided shipping details fields:
  - `String? address` - Full shipping address
  - `double? latitude` - Pinned location latitude
  - `double? longitude` - Pinned location longitude
  - `String? instructions` - Special shipping instructions (e.g., "Leave at front door")

- Updated serialization:
  - `fromJson()` - Deserializes all fields including coordinates
  - `toJson()` - Serializes all fields to Firestore
  - Constructor updated with all new parameters

- Added helper getter:
  - `bool get hasDeliveryAddress` - Checks if address is populated
  - Updated `bool get hasData` - Now includes customer details

**Example structure in Firestore:**
```dart
shipping: {
  // Customer-provided
  address: "123 Main St, Springfield, IL 62701",
  latitude: 39.7817,
  longitude: -89.6501,
  instructions: "Leave at front door, ring doorbell",
  
  // Lister-provided (filled later)
  carrierName: "FedEx",
  trackingNumber: "123456789",
  trackingUrl: "https://track.fedex.com/...",
  status: "IN_TRANSIT",
  updatedAt: Timestamp(...),
  updatedBy: "listerUserId"
}
```

---

### 2. Checkout Flow (`lib/screens/store/cart_screen.dart`)

**New Controller:**
```dart
final TextEditingController _shippingInstructionsController = TextEditingController();
```

**Validation (in `_submitOrder()`):**
```dart
// Validate shipping address
if (_fulfillmentMethod == FulfillmentMethod.shipping && _addressController.text.trim().isEmpty) {
  showSnackBar(context, 'Please enter shipping address'.tr());
  return;
}
```

**Shipping Details UI (shown conditionally when shipping is selected):**
1. **Shipping Address Field** *(Required)*
   - 3-line text input
   - Placeholder: "Street address, city, state, postal code"
   - Label: "Shipping Address *"

2. **Location Pin Button**
   - Reuses existing `_buildLocationPinButton()` method
   - Allows customer to pin exact delivery location
   - Populates latitude/longitude fields

3. **Shipping Instructions Field** *(Optional)*
   - 3-line text input
   - Placeholder: "e.g., Leave at front door, signature required"
   - Label: "Shipping Instructions (Optional)"

**Order Creation:**
When order is submitted with `FulfillmentMethod.shipping`:
```dart
ShippingInfo? shippingInfo;
if (_fulfillmentMethod == FulfillmentMethod.shipping) {
  shippingInfo = ShippingInfo(
    address: _addressController.text.trim(),
    latitude: _deliveryLatitude,
    longitude: _deliveryLongitude,
    instructions: _shippingInstructionsController.text.trim().isEmpty 
        ? null 
        : _shippingInstructionsController.text.trim(),
  );
}

final orderRequest = OrderRequest(
  // ... other fields
  shipping: shippingInfo,
  // ...
);
```

---

### 3. Order Details Display (`lib/screens/store/order_detail_screen.dart`)

**Fixed Fulfillment Method Label:**
- Now correctly displays "Shipping" for shipping orders
- Was previously showing "Delivery" for all non-pickup/dine-in methods

**Added Shipping Details Section:**
Displays below the fulfillment method icon and is shown only when:
- `fulfillment.method == FulfillmentMethod.shipping`
- `shipping != null`

**Display Elements:**

#### Shipping Address
```
📍 Shipping Address
   123 Main St, Springfield, IL 62701
```

#### Shipping Instructions (if provided)
```
ℹ️ Instructions
   Leave at front door, ring doorbell
```

- Uses location pin icon for address section
- Uses info icon for instructions section
- Secondary text styling (smaller, lighter color)
- Responsive to dark mode

---

## Data Flow

### Checkout (Customer)
1. Customer selects "Shipping" fulfillment method
2. Shipping address field appears (required)
3. Customer enters full address or pins location
4. Customer enters optional shipping instructions
5. Order is created with `shipping: ShippingInfo(...)`
6. Shipping details are stored in Firestore

### Order Details (Lister)
1. Lister opens order detail screen
2. Fulfillment section shows "Shipping" with correct icon
3. Shipping details subsection displays:
   - Customer's provided address
   - Customer's provided instructions (if any)
4. Lister can later add tracking information:
   - Carrier name
   - Tracking number
   - Tracking URL
   - Status updates

---

## Customer Journey Visual

```
Cart Screen
├─ Select "Shipping" radio button
│
├─ Shipping Address Field Appears
│  ├─ Enter address manually
│  └─ Or tap "Pin Location" button
│
├─ Shipping Instructions Field Appears (Optional)
│  └─ Enter special delivery instructions
│
└─ Send Order Request
   └─ Order created with shipping details
```

**Order Details Screen (for Lister)**
```
Fulfillment Section
├─ 📦 Shipping
│
├─ 📍 Shipping Address
│  └─ 123 Main St, Springfield, IL 62701
│
├─ ℹ️ Instructions (if provided)
│  └─ Leave at front door, ring doorbell
│
└─ [Later filled by lister]
   ├─ Carrier: FedEx
   ├─ Tracking: 1234567890
   └─ Status: In Transit
```

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/listings/model/order_request.dart` | Extended ShippingInfo with customer details |
| `lib/screens/store/cart_screen.dart` | Added shipping form fields + validation + order creation |
| `lib/screens/store/order_detail_screen.dart` | Display shipping details + fix fulfillment labels |

---

## Validation Rules

✅ **Shipping Address:** Required when shipping method is selected
✅ **Shipping Instructions:** Optional
✅ **Location:** Optional (uses address if pin not provided)

---

## Internationalization

All new UI strings use `.tr()` for easy translation:
- "Shipping Address *"
- "Street address, city, state, postal code"
- "Shipping Instructions (Optional)"
- "e.g., Leave at front door, signature required"
- "Shipping Address" (display label)
- "Instructions" (display label)

---

## Testing Checklist

- [ ] Create shipping order with address only
- [ ] Create shipping order with address + instructions
- [ ] Create shipping order with pinned location
- [ ] Verify address is required (can't submit without it)
- [ ] Verify instructions are truly optional
- [ ] Verify lister can view shipping details in order detail
- [ ] Verify lister can add tracking info to shipped order
- [ ] Test dark mode for shipping details display
- [ ] Verify scrolling doesn't hide shipping fields on small screens
- [ ] Verify location pin button works with shipping method

---

## Integration Points

**With existing features:**
1. **Location Pinning:** Reuses existing `_buildLocationPinButton()` method
2. **Tracking Display:** ShippingInfo now contains both customer & lister data
3. **Firestore Rules:** No changes needed (shipping is part of order)
4. **Cloud Functions:** `setOrderTracking()` already writes to shipping field
5. **Chat Integration:** Order details posted to chat still work

---

## Future Enhancements

- Validate address format before submission
- Google Maps integration for address autocomplete
- Carrier-specific instruction templates
- Estimated delivery date calculation
- SMS/Push notifications on shipping status changes
- Delivery confirmation photo upload
- Signature capture on delivery

---

**Implementation Date:** February 8, 2026  
**Status:** ✅ Complete and Ready for Testing
