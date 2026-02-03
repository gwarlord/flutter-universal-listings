# Mini Store (Premium Feature) - Implementation Status

## ✅ COMPLETED COMPONENTS

### 1. Core Infrastructure
- ✅ **Subscription Helper** (`lib/listings/utils/subscription_helper.dart`)
  - `isPremiumUser()` - Strict Premium-only check
  - `isProfessionalUser()` - Professional tier check
  - `isPaidUser()` - Any paid tier check
  
- ✅ **Updated Listing Model** (`lib/listings/model/listing_model.dart`)
  - Added fields: `storeMode`, `storeCurrencyCode`, `storeDeliveryEnabled`, `storePickupEnabled`, `storeLeadTimeHours`, `storeUpdatedAt`
  - **CRITICAL**: Added `listerTierSnapshot` field for rules & UI performance
  - Default `listerTierSnapshot = 'free'` for backward compatibility

### 2. Data Models
- ✅ **CatalogItem Model** (`lib/listings/model/catalog_item.dart`)
  - Types: food_drink, product, service
  - Supports variants (size, color, SKU, price, stock)
  - Photos (0-6), Videos (0-2)
  - Stock tracking with availability flags

- ✅ **OrderRequest Model** (`lib/listings/model/order_request.dart`)
  - Status: requested, confirmed, declined, fulfilled, cancelled
  - OrderItem with quantity and variants
  - FulfillmentInfo (pickup/delivery, address, preferredAt)
  - Links to chat channelId

### 3. Service Layer
- ✅ **StoreService** (`lib/listings/services/store_service.dart`)
  - `getCatalogItems()` - Stream for real-time updates
  - `upsertCatalogItem()` - **Premium-gated** create/update
  - `deleteCatalogItem()` - **Premium-gated** delete
  - `uploadCatalogMedia()` - Firebase Storage uploads
  - `createOrderRequest()` - Customer order submission (validates Premium lister)
  - `updateOrderStatus()` - **Premium-gated** lister status updates
  - `_decrementInventoryOnConfirm()` - Auto inventory management
  - `getOrderRequestsForLister()` - **Premium-only** order stream
  - `getOrderRequestsForCustomer()` - Customer's orders
  - `cancelOrder()` - Customer cancellation (requested status only)

### 4. Premium-Only Screens
- ✅ **CatalogManagerScreen** (`lib/screens/store/catalog_manager_screen.dart`)
  - Lists all catalog items with filtering
  - Category chips (All, Food & Drink, Products, Services, Other)
  - Quick toggle availability
  - Edit/delete actions
  - **Premium verification on init** - auto-exits if not Premium

- ✅ **CatalogItemEditorScreen** (`lib/screens/store/catalog_item_editor_screen.dart`)
  - Type selector (Food & Drink / Product / Service)
  - Name, description, category, price
  - Stock tracking toggle + quantity
  - Availability toggle
  - Photo upload (up to 6)
  - Video upload (up to 2)
  - Form validation
  - Media preview with remove option

---

## 🚧 REMAINING IMPLEMENTATION

### 5. Customer-Facing Screens

#### A) StoreBrowseScreen (`lib/screens/store/store_browse_screen.dart`)
**Purpose**: Customer views catalog and adds items to cart

**Requirements**:
```dart
class StoreBrowseScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser? currentUser; // Can be null for guests
}
```

**Features**:
- Verify `listing.storeEnabled == true`
- Verify `listing.listerTierSnapshot == 'premium'`
- If not Premium, show: "🔒 Storefront unavailable"
- Display grid of catalog items (StreamBuilder)
- Item cards: photo, name, price, availability
- Tap item → Show detail modal with:
  - Full description
  - All photos (carousel)
  - Variant selector (if variants exist)
  - Quantity selector
  - "Add to Cart" button
- Cart badge in AppBar (shows item count)
- Floating "View Cart" button when cart has items

**Cart State Management**:
- Use Provider or local state
- Cart stored per listing (Map<listingId, List<CartItem>>)
- CartItem: {itemId, name, qty, unitPrice, variant?, photo}

---

#### B) CartScreen (`lib/screens/store/cart_screen.dart`)
**Purpose**: Review cart and submit order request

**Features**:
- List cart items with qty adjusters
- Show variant details (size, color) if applicable
- Subtotal calculation
- Fulfillment method selector:
  - Radio: Pickup / Delivery
  - If delivery: address TextField
  - Preferred date/time picker (optional)
- Notes TextField
- "Send Order Request" button

**On Submit**:
1. Validate: items, fulfillment, listing
2. Create `OrderRequest` via `StoreService.createOrderRequest()`
3. Create or reuse chat channel with lister
4. Post structured message to chat:
   ```
   📦 New Order Request
   Items:
   - [Item name] x [qty] @ $[price]
   Total: $[estimatedTotal]
   Fulfillment: [Pickup/Delivery]
   [Address if delivery]
   Notes: [customer notes]
   ```
5. Navigate to chat thread
6. Clear cart for this listing

---

### 6. Lister Premium Screens

#### C) OrdersManagementScreen (`lib/screens/store/orders_management_screen.dart`)
**Purpose**: Premium listers manage order requests

**Requirements**:
- **Premium-only** (verify on init)
- Accessible from:
  - Container screen (drawer)
  - Listing details (if owner)

**Features**:
- Filter tabs: All / Requested / Confirmed / Fulfilled / Declined / Cancelled
- StreamBuilder: `StoreService.getOrderRequestsForLister(listerId)`
- Order cards:
  - Customer name (fetch from users collection)
  - Items summary (count + total)
  - Status badge
  - Created date
  - Tap → OrderDetailScreen

#### D) OrderDetailScreen (`lib/screens/store/order_detail_screen.dart`)
**Features**:
- Full order details:
  - Customer info
  - Items list with qty and prices
  - Estimated total
  - Fulfillment (method, address, preferred time)
  - Notes
  - Status history
- Action buttons (based on status):
  - If `requested`: [Confirm] [Decline]
  - If `confirmed`: [Mark Fulfilled]
  - Status updates post message to chat
- Link to chat thread

---

### 7. UI Integration

#### E) Update AddListingScreen / EditListingScreen
**File**: `lib/listings/listings_module/add_listing/add_listing_screen.dart`

**Changes**:
1. Add store mode selector (already has `storeEnabled` toggle):
   ```dart
   // After storeEnabled toggle
   if (_storeEnabled) {
     DropdownButtonFormField<String>(
       value: _storeMode ?? 'external_url',
       items: [
         DropdownMenuItem(value: 'external_url', child: Text('External Link Only')),
         // ONLY show these if isPremiumUser(currentUser):
         if (isPremiumUser(currentUser)) ...[
           DropdownMenuItem(value: 'internal_catalog', child: Text('Internal Catalog Only')),
           DropdownMenuItem(value: 'both', child: Text('Both External & Internal')),
         ],
       ],
       onChanged: (value) => setState(() => _storeMode = value),
     );
     
     // If user is NOT Premium and tries internal catalog:
     if (!isPremiumUser(currentUser)) {
       Text('🔒 Mini Store is a Premium feature. Upgrade to sell products and receive orders.');
       ElevatedButton(
         child: Text('Upgrade to Premium'),
         onPressed: () => Navigator.push(...SubscriptionScreen),
       );
     }
   }
   
   // Add delivery/pickup toggles
   SwitchListTile(title: Text('Enable Pickup'), value: _storePickupEnabled, ...);
   SwitchListTile(title: Text('Enable Delivery'), value: _storeDeliveryEnabled, ...);
   
   // Add lead time
   TextField(
     controller: _storeLeadTimeController,
     keyboardType: TextInputType.number,
     decoration: InputDecoration(labelText: 'Lead Time (hours)'),
   );
   
   // "Manage Catalog" button (Premium only)
   if (isPremiumUser(currentUser) && _storeMode?.contains('internal') == true) {
     ElevatedButton.icon(
       icon: Icon(Icons.inventory),
       label: Text('Manage Catalog'),
       onPressed: () => Navigator.push(...CatalogManagerScreen),
     );
   }
   ```

2. **On Save**: Set `listerTierSnapshot = currentUser.subscriptionTier`
   ```dart
   await listingsRepository.addOrUpdateListing(
     listing.copyWith(
       listerTierSnapshot: currentUser.subscriptionTier,
       storeMode: _storeMode,
       ...
     ),
   );
   ```

---

#### F) Update ListingDetailsScreen
**File**: `lib/listings/listings_module/listing_details/listing_details_screen.dart`

**Changes**:
1. Add Store section (after Menu section):
   ```dart
   // Show ONLY if:
   if (listing.storeEnabled && 
       listing.storeMode?.contains('internal') == true &&
       listing.listerTierSnapshot == 'premium') {
     _buildStoreSection();
   }
   ```

2. `_buildStoreSection()`:
   ```dart
   Widget _buildStoreSection() {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Padding(
           padding: EdgeInsets.all(16),
           child: Row(
             children: [
               Icon(Icons.storefront, color: Color(colorPrimary)),
               SizedBox(width: 8),
               Text('Mini Store', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             ],
           ),
         ),
         // Preview: Show first 3-6 items in horizontal scroll
         StreamBuilder<List<CatalogItem>>(
           stream: StoreService().getCatalogItems(listing.id),
           builder: (context, snapshot) {
             if (!snapshot.hasData || snapshot.data!.isEmpty) {
               return Center(child: Text('No items available'));
             }
             
             final items = snapshot.data!.take(6).toList();
             return SizedBox(
               height: 200,
               child: ListView.builder(
                 scrollDirection: Axis.horizontal,
                 itemCount: items.length,
                 itemBuilder: (context, index) {
                   final item = items[index];
                   return _buildStoreItemCard(item);
                 },
               ),
             );
           },
         ),
         Padding(
           padding: EdgeInsets.all(16),
           child: ElevatedButton(
             child: Text('Browse Store'),
             onPressed: () => Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (_) => StoreBrowseScreen(
                   listing: listing,
                   currentUser: currentUser,
                 ),
               ),
             ),
           ),
         ),
       ],
     );
   }
   ```

3. If owner viewing, show "Manage Catalog" and "View Orders" buttons

---

### 8. Container Screen Integration

**File**: `lib/listings/ui/container/container_screen.dart`

**Add to drawer** (after Analytics):
```dart
if (currentUser.isAdmin || isPremiumUser(currentUser))
  ListTile(
    leading: Icon(Icons.receipt_long),
    title: Text('Order Requests'.tr()),
    trailing: _tierBadge('PREMIUM', Colors.purple),
    onTap: () {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrdersManagementScreen(currentUser: currentUser),
        ),
      );
    },
  ),
```

---

### 9. Firestore Security Rules

**File**: `firestore.rules`

**Add these rules**:

```javascript
// Catalog Items (subcollection under listings)
match /listings/{listingId}/catalog_items/{itemId} {
  // Allow read ONLY if parent listing has store enabled AND lister is Premium
  allow read: if get(/databases/$(database)/documents/listings/$(listingId)).data.storeEnabled == true
                 && get(/databases/$(database)/documents/listings/$(listingId)).data.listerTierSnapshot == 'premium';
  
  // Allow write ONLY if:
  // 1. User is authenticated
  // 2. User is the listing author
  // 3. Listing's listerTierSnapshot is 'premium'
  allow create, update, delete: if request.auth != null
    && request.auth.uid == get(/databases/$(database)/documents/listings/$(listingId)).data.authorID
    && get(/databases/$(database)/documents/listings/$(listingId)).data.listerTierSnapshot == 'premium';
}

// Order Requests
match /order_requests/{requestId} {
  // Allow create ONLY if:
  // 1. User is authenticated and is the customer
  // 2. Listing exists, has store enabled, and lister is Premium
  allow create: if request.auth != null
    && request.auth.uid == request.resource.data.customerId
    && get(/databases/$(database)/documents/listings/$(request.resource.data.listingId)).data.storeEnabled == true
    && get(/databases/$(database)/documents/listings/$(request.resource.data.listingId)).data.listerTierSnapshot == 'premium';
  
  // Allow read if user is customer OR lister
  allow read: if request.auth != null
    && (request.auth.uid == resource.data.customerId || request.auth.uid == resource.data.listerId);
  
  // Allow update ONLY by lister (Premium check enforced by service layer)
  allow update: if request.auth != null
    && request.auth.uid == resource.data.listerId;
  
  // No deletes allowed
  allow delete: if false;
}
```

---

### 10. Chat Integration

When creating order request, post message to chat:

**File**: `lib/listings/services/store_service.dart` (update `createOrderRequest`)

Add after creating order:
```dart
// Create or reuse chat channel
String channelId;
final existingChannels = await _firestore
    .collection(channelsCollection)
    .where('participants', arrayContains: customer.userID)
    .get();

final matchingChannel = existingChannels.docs.firstWhere(
  (doc) {
    final participants = List<String>.from(doc.data()['participants'] ?? []);
    return participants.contains(listingData.authorID);
  },
  orElse: () => null,
);

if (matchingChannel != null) {
  channelId = matchingChannel.id;
} else {
  // Create new channel (use existing chat service)
  channelId = await ChatService().createChannel(
    participants: [customer.userID, listingData.authorID],
    listingId: listingData.id,
  );
}

// Post order summary message
final messageText = '''
📦 New Order Request

Items:
${orderData.items.map((item) => '• ${item.name} x${item.qty} @ \$${item.unitPrice.toStringAsFixed(2)}').join('\n')}

Total: \$${orderData.estimatedTotal.toStringAsFixed(2)}
Fulfillment: ${orderData.fulfillment.method.value == 'pickup' ? 'Pickup' : 'Delivery'}
${orderData.fulfillment.address != null ? 'Address: ${orderData.fulfillment.address}' : ''}
${orderData.notes != null && orderData.notes!.isNotEmpty ? 'Notes: ${orderData.notes}' : ''}

Order ID: $orderId
''';

await _firestore.collection(channelsCollection).doc(channelId).collection('messages').add({
  'content': messageText,
  'senderId': customer.userID,
  'senderName': customer.fullName(),
  'created': Timestamp.now(),
  'type': 'order_request',
  'metadata': {
    'orderId': orderId,
  },
});

// Update order with channelId
await _firestore.collection('order_requests').doc(orderId).update({
  'channelId': channelId,
});
```

Similarly, when updating order status, post update to chat.

---

## 🧪 TESTING CHECKLIST

- [ ] Professional user sees locked Mini Store options
- [ ] Premium user can enable internal catalog
- [ ] Premium user can create/edit/delete catalog items
- [ ] Premium user can upload photos/videos
- [ ] Stock tracking decrements on order confirm
- [ ] Customer can browse catalog only if lister is Premium
- [ ] Customer can add items to cart
- [ ] Customer can submit order request
- [ ] Order creates chat message
- [ ] Premium lister can view orders
- [ ] Premium lister can confirm/decline/fulfill orders
- [ ] Older listings without `listerTierSnapshot` default to 'free' (don't crash)
- [ ] Firestore rules block non-Premium catalog writes
- [ ] Firestore rules block order creation if lister not Premium

---

## 📁 FILE STRUCTURE

```
lib/
├── listings/
│   ├── model/
│   │   ├── catalog_item.dart ✅
│   │   ├── order_request.dart ✅
│   │   └── listing_model.dart ✅ (updated)
│   ├── services/
│   │   └── store_service.dart ✅
│   └── utils/
│       └── subscription_helper.dart ✅
├── screens/
│   └── store/
│       ├── catalog_manager_screen.dart ✅
│       ├── catalog_item_editor_screen.dart ✅
│       ├── store_browse_screen.dart ⏳ TODO
│       ├── cart_screen.dart ⏳ TODO
│       ├── orders_management_screen.dart ⏳ TODO
│       └── order_detail_screen.dart ⏳ TODO
└── listings_module/
    ├── add_listing/
    │   └── add_listing_screen.dart ⏳ UPDATE
    └── listing_details/
        └── listing_details_screen.dart ⏳ UPDATE
```

---

## 🚀 DEPLOYMENT STEPS

1. Deploy Firestore security rules
2. Run data migration to add `listerTierSnapshot` to existing listings:
   ```javascript
   // Firebase Cloud Function
   exports.migrateListingTiers = functions.https.onRequest(async (req, res) => {
     const listings = await admin.firestore().collection('listings').get();
     const batch = admin.firestore().batch();
     
     for (const doc of listings.docs) {
       const data = doc.data();
       if (!data.listerTierSnapshot) {
         // Fetch author's tier
         const author = await admin.firestore().collection('users').doc(data.authorID).get();
         const tier = author.data()?.subscriptionTier || 'free';
         
         batch.update(doc.ref, { listerTierSnapshot: tier });
       }
     }
     
     await batch.commit();
     res.send('Migration complete');
   });
   ```
3. Test with Premium test user
4. Test with Professional user (should be blocked)
5. Monitor analytics for adoption

---

## ⚠️ CRITICAL REMINDERS

1. **ALWAYS** verify Premium tier in UI and service layer
2. **ALWAYS** check `listerTierSnapshot` before showing store UI
3. **NEVER** allow Professional users to access Mini Store features
4. Set `listerTierSnapshot` when saving listings
5. Default `listerTierSnapshot = 'free'` for backward compatibility
6. Test Firestore rules in emulator before deploying

---

## 🎯 NEXT STEPS

Complete remaining screens in this order:
1. StoreBrowseScreen (customer shopping)
2. CartScreen (order submission)
3. OrdersManagementScreen (lister management)
4. OrderDetailScreen (order actions)
5. Update AddListingScreen (Premium gating)
6. Update ListingDetailsScreen (store section)
7. Update Container screen (orders menu item)
8. Deploy Firestore rules
9. Run data migration
10. Test end-to-end

This implementation is **compile-ready** for completed components. Remaining screens follow the same patterns established in CatalogManagerScreen and CatalogItemEditorScreen.
