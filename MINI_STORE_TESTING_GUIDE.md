# Mini Store Testing Guide

## Quick Test Scenarios

### 1. Premium Lister - Create Listing with Mini Store

**Steps:**
1. Login as Premium user
2. Navigate to "Add Listing"
3. Enable "Store/Ecommerce" toggle
4. Select "Internal Catalog" or "Both" from Store Mode dropdown
5. Set Lead Time Hours (e.g., 24)
6. Fill other required fields
7. Click "Post Listing"
8. After save, edit listing again
9. Click "Manage Catalog Items"
10. Add 2-3 catalog items with photos and variants

**Expected:**
- Internal Catalog option available (no lock)
- "Manage Catalog Items" button appears
- Can navigate to catalog manager
- Can add/edit/delete items
- listerTierSnapshot = 'premium' in Firestore

**Firestore Check:**
```
listings/{listingId}
  storeEnabled: true
  storeMode: "internal_catalog" or "both"
  storeLeadTimeHours: 24
  listerTierSnapshot: "premium"

catalog_items collection
  - Multiple items with listingId reference
```

---

### 2. Professional User - Cannot Use Internal Catalog

**Steps:**
1. Login as Professional user (NOT Premium)
2. Navigate to "Add Listing"
3. Enable "Store/Ecommerce" toggle
4. Try to select "Internal Catalog" from dropdown

**Expected:**
- "Internal Catalog" option shows PREMIUM badge
- Selecting it shows error: "Internal Catalog requires Premium subscription"
- Can only use "External URL Only" mode
- "Manage Catalog Items" button not visible
- "Order Requests" menu item NOT in drawer

---

### 3. Customer - Browse and Order

**Steps:**
1. Login as any user (free, professional, or premium)
2. Navigate to a listing with Mini Store enabled (Premium lister)
3. Scroll down to "Mini Store" section
4. Click "Browse Full Store"
5. Search for item or browse categories
6. Click item card to see detail modal
7. Select variant (if available)
8. Add 2-3 items to cart
9. Click cart icon in app bar
10. Select fulfillment method (delivery or pickup)
11. Enter address (if delivery)
12. Select preferred date
13. Add notes
14. Click "Submit Order"

**Expected:**
- Mini Store section only shows if lister is Premium
- Can browse all catalog items
- Cart badge updates with item count
- Item detail modal shows photos, variants, stock
- Cart screen shows all items with subtotal
- After submit, navigates to chat conversation
- Chat shows order summary message
- Order created in Firestore

**Firestore Check:**
```
order_requests collection
  orderId: {
    listingId: "...",
    customerId: "...",
    listerUserId: "...",
    status: "requested",
    items: [...],
    fulfillmentInfo: {...},
    channelId: "...",
    createdAt: timestamp
  }

channels collection
  - Channel exists between customer and lister
  - Contains order summary message
```

---

### 4. Premium Lister - Manage Orders

**Steps:**
1. Login as Premium lister (who has received orders)
2. Open drawer
3. Click "Order Requests" (should show PREMIUM badge)
4. View orders in "All" tab
5. Click "Requested" tab (filter)
6. Click an order card
7. Review order details
8. Click "Confirm Order"
9. Go back to list, click same order
10. Click "Mark as Fulfilled"
11. Click "View Chat" button

**Expected:**
- "Order Requests" menu item visible with PREMIUM badge
- Orders shown in tabs by status
- Customer info displayed (name, email)
- Items list with variants and quantities
- Fulfillment info shown (method, address, date)
- Status update buttons work (Confirm, Decline, Fulfill)
- Status changes post to chat channel
- Can navigate to chat from order detail

**Firestore Check:**
```
order_requests/{orderId}
  status: "confirmed" (then "fulfilled")
  confirmedAt: timestamp
  fulfilledAt: timestamp

channels/{channelId}/thread/messages
  - Contains status update messages
  - "Order confirmed by [lister name]"
  - "Order marked as fulfilled"
```

---

### 5. Security Tests

#### A. Non-Premium Trying to Access OrdersManagement
**Test:**
```dart
// Try to navigate directly
Navigator.push(context, MaterialPageRoute(
  builder: (_) => OrdersManagementScreen(currentUser: professionalUser)
));
```

**Expected:**
- Screen shows error snackbar
- Auto-exits back to previous screen
- No data loaded

#### B. Professional User Editing Premium Listing
**Test:**
1. Create listing as Premium user with internal catalog
2. Downgrade to Professional
3. Try to edit listing

**Expected:**
- Can edit other fields
- Cannot select "Internal Catalog" mode
- "Manage Catalog Items" button disabled
- If mode changes to external_url, catalog items remain in Firestore but not accessible

#### C. Firestore Rules Test
**Test:** Try to write catalog_items or update order_requests from non-Premium account using Firestore console

**Expected:**
- Write denied with permission error
- Rules enforce Premium tier at database level

---

## Test Accounts Needed

1. **Premium User** (subscriptionTier = "premium", isSubscriptionActive = true)
   - Can use all Mini Store features
   - Create listings with internal catalog
   - Manage orders

2. **Professional User** (subscriptionTier = "professional", isSubscriptionActive = true)
   - Can only use external URL store mode
   - Cannot access Order Requests
   - Cannot manage catalog

3. **Free User** (subscriptionTier = "free")
   - Can only use external URL store mode
   - Can browse and order from Premium listers

4. **Customer User** (any tier)
   - Browse catalogs
   - Place orders
   - Chat with listers

---

## Common Issues & Fixes

### Issue: "Order Requests" not showing in drawer
**Fix:** Check user.isPremium and user.isSubscriptionActive are true

### Issue: Cannot select Internal Catalog mode
**Fix:** Verify user has Premium subscription active

### Issue: Catalog items not showing in listing details
**Fix:** Check listing.listerTierSnapshot == 'premium' and storeMode includes 'internal'

### Issue: Order submission fails
**Fix:** Verify cart has items and fulfillment info is complete

### Issue: Chat integration not working
**Fix:** Check channel exists in Firestore and channelId is set in order

### Issue: Status updates not posting to chat
**Fix:** Verify OrderChatHelper.postOrderStatusMessage() is called after updateOrderStatus()

---

## Performance Checks

1. **Catalog Loading**: Should load within 2 seconds for 100 items
2. **Order List**: Should render smoothly with 50+ orders
3. **Search**: Should filter instantly as user types
4. **Cart Updates**: Badge should update immediately
5. **Status Changes**: Should reflect in UI within 1 second

---

## Firestore Console Queries

### Get all orders for a lister
```javascript
db.collection('order_requests')
  .where('listerUserId', '==', 'LISTER_USER_ID')
  .orderBy('createdAt', 'desc')
```

### Get all catalog items for a listing
```javascript
db.collection('catalog_items')
  .where('listingId', '==', 'LISTING_ID')
  .where('isActive', '==', true)
```

### Get pending orders
```javascript
db.collection('order_requests')
  .where('listerUserId', '==', 'LISTER_USER_ID')
  .where('status', '==', 'requested')
```

---

## Debug Logs to Check

Look for these console outputs:
- `"DEBUG: User is not Premium, exiting OrdersManagementScreen"`
- `"DEBUG: Creating order request with fulfillment: ..."`
- `"DEBUG: Ensuring order channel between customer:... and lister:..."`
- `"DEBUG: Posting order status message: ... -> ..."`
- `"DEBUG: Setting listerTierSnapshot to: premium"`

---

## Edge Cases to Test

1. **Downgrade scenario**: Premium user downgrades mid-order
2. **Empty catalog**: Listing with store enabled but no items
3. **Out of stock**: Item with stockCount = 0
4. **Multiple variants**: Item with 10+ size/color combinations
5. **Large orders**: 20+ items in single order
6. **Concurrent orders**: Multiple customers ordering simultaneously
7. **Status race condition**: Customer and lister both viewing order during update
8. **Network offline**: Submit order without internet, then reconnect

---

**Testing Status Template:**

```markdown
## Test Run - [Date]

### Environment
- Flutter version: 
- Device: 
- User tier tested: 

### Test Results
- [ ] Premium Lister - Create Listing: ✅/❌
- [ ] Professional User - Blocked Access: ✅/❌
- [ ] Customer - Browse and Order: ✅/❌
- [ ] Premium Lister - Manage Orders: ✅/❌
- [ ] Security Tests: ✅/❌

### Issues Found
1. [Issue description] - [Severity: High/Medium/Low]
2. ...

### Notes
[Any additional observations]
```
