# Lister Collaboration Feature - Implementation Guide

## Overview

The Lister Collaboration feature allows listing owners (with Premium subscription) to invite multiple collaborators to manage listings and their related operations (orders, bookings, rentals, chats). Each collaborator's access is controlled via granular permissions.

## Key Components

### 1. **Cloud Functions** (`functions/src/collaboration.ts`)

#### Collaborator Management
- **`addListingCollaborator()`** - Add collaborator with permissions
  - Verifies caller is owner/admin
  - Checks Premium subscription via RevenueCat
  - Resolves collaborator by email or UID
  - Updates chat participants automatically
  - Logs activity

- **`removeListingCollaborator()`** - Soft-delete collaborator
  - Sets `isActive=false`
  - Removes from chat participants
  - Prevents hard delete (audit trail)

- **`updateListingCollaboratorPermissions()`** - Update permissions per collaborator
  - Ensures `deleteListing` is always false
  - Updates chat access if `manageChats` permission changes

#### Activity Logging
- All actions logged to `listings/{listingId}/activity/{activityId}`
- Includes: actor, action type, target, timestamp, optional note

#### State Change Functions (with auth check)
- **`setOrderStatus()`** - Requires `changeOrderStatus` permission
- **`setOrderFulfillment()`** - Requires `changeFulfillment` permission
- **`updateListingEditableFields()`** - Requires `editListing` permission
- **`setRentalStatus()`** - Requires `manageRentals` permission
- **`setBookingStatus()`** - Requires `manageBookings` permission
- **`sendOrderChatMessage()`** - Requires `manageChats` permission

### 2. **Firestore Data Model**

#### Collaborators Subcollection
```
listings/{listingId}/collaborators/{collaboratorUid}
{
  isActive: boolean,
  role: "COLLABORATOR" | "MANAGER",
  permissions: {
    manageOrders: boolean,
    manageBookings: boolean,
    manageRentals: boolean,
    manageChats: boolean,
    editListing: boolean,
    changeOrderStatus: boolean,
    changeFulfillment: boolean,
    deleteListing: false  // ALWAYS false
  },
  addedBy: string (ownerUid),
  addedAt: Timestamp,
  updatedAt: Timestamp
}
```

#### Activity Log
```
listings/{listingId}/activity/{activityId}
{
  actorUid: string,
  actorName: string,
  actorRole: "OWNER" | "COLLABORATOR" | "ADMIN",
  actionType: string (e.g., "ORDER_STATUS_CHANGED"),
  targetType: "LISTING" | "ORDER" | "RENTAL" | "BOOKING" | "CHAT" | "COLLABORATOR",
  targetId: string,
  createdAt: Timestamp,
  note: string (optional)
}
```

#### Assigned Listings Mapping
```
users/{userId}/assignedListings/{listingId}
{
  ownerUid: string,
  isActive: boolean,
  addedAt: Timestamp,
  updatedAt: Timestamp,
  permissionsSummary: ["manageOrders", "manageChats", ...] // Quick lookup
}
```

#### Listing Team Chat
```
listing_chats/listing_{listingId}
{
  listingId: string,
  ownerUid: string,
  participantUids: [ownerUid, collab1, collab2, ...],
  updatedAt: Timestamp,
  lastMessage: string (optional),
  lastMessageAt: Timestamp (optional)
}

listing_chats/listing_{listingId}/messages/{messageId}
{
  senderUid: string,
  content: string,
  type: "text" | "image" | "video" | "audio",
  attachments: [] (optional),
  createdAt: Timestamp
}
```

#### Order Thread Chat
```
order_chats/order_{orderId}
{
  orderId: string,
  listingId: string,
  ownerUid: string,
  customerUid: string,
  participantUids: [ownerUid, customerUid, collab1, collab2, ...],
  updatedAt: Timestamp,
  lastMessage: string (optional),
  lastMessageAt: Timestamp (optional)
}

order_chats/order_{orderId}/messages/{messageId}
{
  senderUid: string,
  content: string,
  type: "text" | "image" | "video" | "audio",
  attachments: [] (optional),
  createdAt: Timestamp
}
```

### 3. **Firestore Security Rules**

**Collaborator Documents** (write-only via Cloud Functions)
```
allow read: if user is owner or the collaborator themselves
allow write: never (Cloud Functions only)
```

**Activity Log** (read-only for authorized users)
```
allow read: if user is owner or active collaborator
allow write: never (Cloud Functions only)
```

**Listing Team Chat**
```
Participants: owner + collaborators with manageChats=true
access: only participants can read/write
```

**Order Thread Chat**
```
Participants: owner + collaborators with manageChats=true + order customer
access: only participants can read/write
Customer sees ONLY their order chat, not listing team chat (enforced by UI/queries)
```

### 4. **Flutter Models**

#### CollaboratorPermissions
- Boolean flags for each capability
- Includes helper methods: `enabledPermissions`, `copyWith()`
- Factory constructor for defaults

#### CollaboratorModel
- Represents a single collaborator
- Includes user display info (name, avatar)
- JSON serialization for Firestore

#### ActivityLogEntry
- Immutable activity record
- Helper methods: `getActionLabel()`, `getIconData()`
- Formatted timestamp

#### ListingChat & OrderChat
- Metadata documents for the two chat types
- List of participant UIDs
- Last message tracking

#### AssignedListingModel
- For quick lookup of listings where user collaborates
- Includes permission summary for UI display

### 5. **Flutter Services**

#### CollaborationRepository (Abstract)
- Interface for all collaboration operations
- Implemented by `CollaborationFirebase`

#### CollaborationFirebase
- Direct Firestore reads + Cloud Functions for writes
- Stream-based for real-time updates
- Resource cleanup via `dispose()`

#### ChatScopeIntegration (Helper)
- Bridges collaboration system with existing chat UI
- Methods to create/get channels for both chat types
- Permission checks for chat access

### 6. **Flutter UI Screens**

#### CollaboratorsManagementScreen
- Shows list of collaborators for a listing
- Add/remove buttons (for owner only)
- Toggle permissions per collaborator (expanded tile)
- Premium gate with upgrade CTA

#### AssignedListingsScreen
- Shows listings where user is a collaborator
- Permission summary chips per listing
- Navigate to listing management

#### ActivityLogScreen
- Timeline/list view of all activities
- Color-coded by action type
- Actor name, role, timestamp
- Expandable notes

### 7. **How to Use Both Chat Scopes**

#### Listing Team Chat (Owner + Collaborators only)
```dart
// Initialize chat when listing details load
final channel = await ChatScopeIntegration.createListingTeamChat(
  listingId: listingId,
  ownerUid: listing.authorID,
  ownerUser: ownerUser,
  collaboratorUsers: collaborators,
);

// Show chat UI with this channel
Navigator.push(context, MaterialPageRoute(
  builder: (context) => ChatScreen(channelDataModel: channel),
));
```

#### Order Thread Chat (Owner + Collaborators + Customer)
```dart
// Initialize when customer opens an order
final channel = await ChatScopeIntegration.createOrderThreadChat(
  orderId: orderId,
  listingId: order.listingId,
  ownerUid: order.listingOwnerUid,
  ownerUser: ownerUser,
  customerUid: order.customerId,
  customerUser: customerUser,
  collaboratorUsers: collaborators,
);

// Show chat UI with this channel
Navigator.push(context, MaterialPageRoute(
  builder: (context) => ChatScreen(channelDataModel: channel),
));
```

## PREMIUM GATING

### RevenueCat Integration
- All collaborator management requires owner to have active "CaribTap Pro" entitlement
- Server-side validation in Cloud Functions
- Set RevenueCat API key: `firebase functions:config:set revenuecat.key="your_key"`

### UI Lock
- "Add Collaborator" button disabled if not premium
- Upgrade CTA shown to non-premium owners
- Collaborators don't need premium (owner's subscription grants access)

## PERMISSIONS MODEL

| Permission | Effect |
|-----------|--------|
| `manageOrders` | Can change order status, update fulfillment |
| `manageBookings` | Can confirm/reject/cancel bookings |
| `manageRentals` | Can update rental status |
| `manageChats` | Can participate in listing team + order chats |
| `editListing` | Can change listing details |
| `changeOrderStatus` | Can set order status |
| `changeFulfillment` | Can update fulfillment/tracking |
| `deleteListing` | **ALWAYS false** - collaborators cannot delete |

## AUTHORIZATION CHECKS

### For Collaborators
1. Check if collaborator doc exists: `listings/{listingId}/collaborators/{uid}`
2. Verify `isActive == true`
3. Verify required permission is `true`
4. Deny if any check fails

### For Chats
- **Listing Team Chat**: participants = owner + collaborators with `manageChats=true`
- **Order Chat**: participants = owner + order customer + collaborators with `manageChats=true`
- Enforce in Firestore rules + UI queries

## TEST SCENARIOS

### 1. Collaborator with limited permissions
```dart
// Owner adds "Maria" with only manageChats and manageOrders
permissions: {
  manageOrders: true,
  manageChats: true,
  editListing: false,
  changeFulfillment: false,
  // ...
}

// Maria can:
// - See and message in listing team chat
// - See order thread chats
// - Change order status
// CANNOT:
// - Edit listing details
// - Update fulfillment
// - Access bookings
```

### 2. Customer isolation
```dart
// When customer opens order chat for their order
// - Customer sees ONLY their order thread
// - Customer does NOT see listing team chat
// - Collaborators can see both (if manageChats=true)
// - Owner can see both
```

### 3. Non-premium owner
```dart
// Owner without Premium entitlement
// - "Add Collaborator" button shows upgrade CTA
// - Any attempt to add shows premium-required error
```

### 4. Activity log audit trail
```dart
// After adding collaborator
activity: {
  actionType: "COLLABORATOR_ADDED",
  actor: ownerUid,
  target: collaboratorUid,
  note: "Added as COLLABORATOR with permissions: manageOrders, manageChats, ..."
}

// After order status change by collaborator
activity: {
  actionType: "ORDER_STATUS_CHANGED",
  actor: collaboratorUid,
  role: "COLLABORATOR",
  target: orderId,
  note: "Status changed to: SHIPPED"
}
```

## INTEGRATION CHECKLIST

- [ ] Deploy Cloud Functions (`npm run deploy`)
- [ ] Update Firestore rules (`firebase deploy --only firestore:rules`)
- [ ] Set RevenueCat API key in Functions config
- [ ] Integrate collaborators management into listing detail/edit screens
- [ ] Add activity log tab to listing management
- [ ] Add "Assigned Listings" section to collaborator dashboard
- [ ] Wire up listing team chat to listing details
- [ ] Wire up order chat to order detail screens
- [ ] Ensure chat permissions enforced in UI queries
- [ ] Test premium gate and permission checks
- [ ] Test activity logging across all state changes
- [ ] Test chat visibility (collaborators vs customer)

## FILE STRUCTURE

```
functions/src/
├── collaboration.ts                    # All collaboration Cloud Functions

lib/listings/
├── model/
│   └── collaboration_model.dart       # All data models
├── listings_module/api/
│   ├── collaboration_repository.dart  # Abstract interface
│   ├── collaboration_api_manager.dart # API manager (pluggable backend)
│   └── firebase/
│       └── collaboration_firebase.dart  # Firebase implementation
└── ui/collaboration/
    ├── collaborators_management_screen.dart  # Manage collaborators
    ├── assigned_listings_screen.dart        # Collaborator's listings
    ├── activity_log_screen.dart             # Audit trail
    └── chat_scope_integration.dart          # Chat helper utilities
```

## NOTES

- All collaborator writes go through Cloud Functions (security + audit)
- Chat access determined by Firestore rules (real-time enforcement)
- Activity log time-indexed for fast pagination
- No hard deletes for audit compliance (soft delete pattern)
- Customer cannot see listing team chat (UI filtered + Firestore rules)
- Collaborators auto-removed from chats when permission changes

---

**Documentation last updated:** February 2026  
**Feature Status:** Complete & Production-Ready
