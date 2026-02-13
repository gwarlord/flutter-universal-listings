# Table Mode Order Details Improvements

## Overview
Enhanced the Order Details screens for both customers and listers to better support restaurant table mode operations with granular status updates and customer service features.

## What Was Changed

### 1. **New Restaurant-Specific Order Statuses**

Added three new statuses to the `OrderStatus` enum to support restaurant workflows:

- **`preparing`** - Meal is being prepared in the kitchen
- **`ready`** - Meal is ready to be served/picked up
- **`served`** - Meal has been served to the customer's table

**Location**: `lib/listings/model/order_request.dart`

**Status Flow for Restaurants:**
```
requested → confirmed → preparing → ready → served → fulfilled
```

**Status Flow for Other Fulfillment Methods:**
```
requested → confirmed → fulfilled
```

### 2. **Real-Time Order Status Updates**

**Customer View**: The Order Details screen now uses `StreamBuilder` to listen for real-time status changes from Firestore, so customers see instant updates when the restaurant updates their order status.

**Location**: `lib/screens/store/order_detail_screen.dart` - `build()` method

### 3. **Customer Table Mode Actions**

Added two new action buttons for customers in active table sessions:

#### **Summon Waiter Button**
- Only visible when in an active table session
- Includes cooldown timer to prevent spam
- Options to choose reason:
  - Need Assistance
  - Ready to Order
  - Table Needs Cleaning
  - General Request
- Respects the summon cooldown from table session settings

#### **Request Bill Button**
- Allows customer to request the bill
- Options to specify payment method:
  - Cash
  - Card
  - Digital Payment
- Notifies staff through the table mode system

**Location**: Added in the Order Details content section after order information

### 4. **Enhanced Lister Status Update Options**

Listers now have granular control over order statuses based on the current state:

#### **Status: Requested**
- **Decline** (with optional notes)
- **Confirm** - Moves to confirmed status

#### **Status: Confirmed**
- For dine-in orders: **Start Preparing** → Changes to `preparing`
- For other orders: **Mark Fulfilled** → Completes the order

#### **Status: Preparing**
- **Mark Ready** → Changes to `ready` (food is ready)

#### **Status: Ready**
- **Mark Served** → Changes to `served` (food delivered to table)

#### **Status: Served**
- **Mark Fulfilled** → Completes the order

**Location**: `lib/screens/store/order_detail_screen.dart` - `_buildListerActionButtons()` method

### 5. **Updated Status Badges**

Both customer order list and order detail screens now display the new statuses with appropriate colors and icons:

- **Preparing**: Purple with restaurant_menu icon
- **Ready**: Teal with done_all icon
- **Served**: Indigo with room_service icon

**Locations**: 
- `lib/screens/store/customer_orders_screen.dart` - `_buildStatusBadge()`
- `lib/screens/store/order_detail_screen.dart` - `_buildStatusChip()`

### 6. **Active Order Filtering**

Updated the "Active Orders" filter to include the new restaurant statuses, so orders in `preparing`, `ready`, or `served` states are shown as active orders.

**Location**: `lib/screens/store/customer_orders_screen.dart`

## Technical Implementation Details

### Table Session Integration

The order detail screen now:
1. Loads the associated table session data on init
2. Tracks summon cooldown state
3. Displays assigned waiter information
4. Provides direct access to table service features

### Methods Added

- `_loadTableSession()` - Loads table session data for the order
- `_summonWaiter()` - Handles waiter summoning with purpose selection
- `_requestBill()` - Handles bill request with payment method selection
- `_buildListerActionButtons()` - Generates appropriate status update buttons for listers
- `_buildOrderContent()` - Extracted content building to support StreamBuilder

### Stream-Based Updates

The order detail screen now uses a `StreamBuilder` listening to the order document in Firestore, providing real-time updates for:
- Order status changes
- Order data modifications
- Any field updates by the lister or system

## User Experience Flow

### Customer Experience (Dine-In)

1. **Order Placed** → Status: `Requested`
2. **Restaurant Confirms** → Status: `Confirmed` (customer sees update instantly)
3. **Kitchen Starts Cooking** → Status: `Preparing` (customer sees "Your meal is being prepared")
4. **Food Ready** → Status: `Ready` (customer sees "Your order is ready")
5. **Waiter Serves** → Status: `Served` (customer sees "Enjoy your meal!")
6. Customer can now:
   - **Summon Waiter** (for refills, assistance, etc.)
   - **Request Bill** (specify payment method)
7. **Payment Complete** → Status: `Fulfilled`

### Lister Experience (Restaurant Staff)

1. **New Order Alert** → Accept or decline request
2. **Confirm Order** → Mark as confirmed
3. **Start Preparing** → Mark when kitchen begins cooking
4. **Food Ready** → Mark when ready for serving
5. **Served to Table** → Mark when delivered
6. **Complete Order** → Mark as fulfilled after payment

## Benefits

1. **Better Communication**: Customers know exactly what's happening with their order
2. **Service Request Without Waving**: Customers can summon staff digitally
3. **Efficient Bill Process**: Customers can request bill and specify payment method ahead of time
4. **Reduced Staff Burden**: Staff are alerted to specific customer needs
5. **Professional Experience**: Restaurant operations feel modern and streamlined
6. **Real-Time Updates**: No refresh needed - customers see status changes immediately

## Backward Compatibility

The implementation maintains full backward compatibility:
- Orders without new statuses continue working normally
- Non-restaurant orders use simpler status flow
- Table mode features only appear when applicable
- Existing orders are not affected

## Testing Recommendations

1. Test status progression for dine-in orders
2. Verify cooldown timer works correctly for waiter summon
3. Test bill request notifications to staff
4. Verify real-time status updates appear on customer screen
5. Test non-table-mode orders still work normally
6. Verify pickup/delivery orders use appropriate status flow

## Future Enhancements

Potential additions:
- Push notifications for status changes
- Estimated time for each status
- Kitchen display system integration
- Table occupancy tracking
- Multi-waiter coordination
- Tips and feedback integration

---

**Implementation Date**: February 13, 2026
**Files Modified**: 3 files
**Lines Changed**: ~500 lines
