# Activity Log Integration Sites

This document identifies all key "action" sites in the Flutter app where `ActivityLogEntry` records should be written to `listings/{listingId}/activity`.

**Model Reference:**
```dart
ActivityLogEntry {
  actorUid: String,
  actorName: String,
  actionType: String (e.g., 'LISTING_EDITED', 'ORDER_STATUS_CHANGED'),
  targetType: 'LISTING'|'ORDER'|'RENTAL'|'BOOKING'|'CHAT'|'COLLABORATOR',
  targetId: String,
  targetName: String,
  metadata: Map<String, dynamic>,
  createdAt: Timestamp,
}
```

---

## 1. LISTING EDITING / SAVING

### Site 1.1: Listing Creation/Update via AddListingBloc
**File:** [lib/listings/listings_module/add_listing/add_listing_bloc.dart](lib/listings/listings_module/add_listing/add_listing_bloc.dart#L303)

**Line:** ~303-530 (PublishListingEvent handler)

**Action:** Lister creates or updates a listing (publish/save)

**Key Variables:**
- `listingId`: Available in `event.listingModel.id`
- `actorUid`: `currentUser.userID` (from AddListingBloc)
- `actorName`: `currentUser.firstName` + `currentUser.lastName`
- `isEdit`: `event.isEdit` (boolean)

**Context Available:**
- `listing`: `event.listingModel` (ListingModel) - has title, description, etc.
- `userTier`: User subscription tier available in code
- `newImageUrls`: List of uploaded image URLs
- `logoUrl`: If logo was updated

**Activity Log Entry Should Record:**
- **actionType:** `'LISTING_EDITED'` or `'LISTING_CREATED'`
- **targetType:** `'LISTING'`
- **targetId:** `listingModel.id`
- **targetName:** `listingModel.title`
- **metadata:** 
  ```dart
  {
    'isEdit': event.isEdit,
    'previousTitle': (if editing),
    'newTitle': event.listingModel.title,
    'category': event.listingModel.category,
    'price': event.listingModel.price,
    'hasPhotos': newImageUrls.isNotEmpty,
    'photoCount': newImageUrls.length,
    'bookingEnabled': event.listingModel.bookingEnabled,
    'storeEnabled': event.listingModel.storeEnabled,
  }
  ```

**Integration Point:** After successful publish at line 525 in the PublishListingEvent handler, before the state emission.

---

## 2. COLLABORATOR MANAGEMENT

### Site 2.1: Add Collaborator
**File:** [lib/listings/ui/collaboration/collaborators_management_screen.dart](lib/listings/ui/collaboration/collaborators_management_screen.dart#L74)

**Line:** ~74-88 (onAddCollaborator callback)

**Action:** Lister adds a new collaborator to their listing

**Key Variables:**
- `listingId`: `widget.listingId`
- `actorUid`: `currentUser.uid` (available from context via provider/bloc)
- `collaboratorUid`: `uid` (returned from `addListingCollaborator()`)
- `collaboratorEmail`: `email` (from dialog)
- `permissions`: `permissions` (CollaboratorPermissions object)

**Context Available:**
- `email`: Collaborator's email address
- `permissions`: Object with `editListing`, `changeOrderStatus`, `manageBookings`, etc.

**Activity Log Entry Should Record:**
- **actionType:** `'COLLABORATOR_ADDED'`
- **targetType:** `'COLLABORATOR'`
- **targetId:** `uid` (the new collaborator's UID)
- **targetName:** `email`
- **metadata:**
  ```dart
  {
    'collaboratorEmail': email,
    'permissions': {
      'editListing': permissions.editListing,
      'changeOrderStatus': permissions.changeOrderStatus,
      'manageBookings': permissions.manageBookings,
      'manageChats': permissions.manageChats,
      'manageRentals': permissions.manageRentals,
    }
  }
  ```

**Integration Point:** After successful callback at line ~85, show snackbar.

---

### Site 2.2: Remove Collaborator
**File:** [lib/listings/ui/collaboration/collaborators_management_screen.dart](lib/listings/ui/collaboration/collaborators_management_screen.dart#L166)

**Line:** ~166-180 (removeListingCollaborator call)

**Action:** Lister removes a collaborator from their listing

**Key Variables:**
- `listingId`: `widget.listingId`
- `actorUid`: Current user's UID
- `collaboratorUid`: `collaborator.uid`
- `collaboratorName`: `collaborator.displayName` or `collaborator.uid`

**Context Available:**
- `collaborator`: CollaboratorModel object with uid, displayName, email
- All permissions they had before removal

**Activity Log Entry Should Record:**
- **actionType:** `'COLLABORATOR_REMOVED'`
- **targetType:** `'COLLABORATOR'`
- **targetId:** `collaborator.uid`
- **targetName:** `collaborator.displayName ?? collaborator.uid`
- **metadata:**
  ```dart
  {
    'collaboratorEmail': collaborator.email,
    'removedPermissions': {
      'editListing': (previous permissions),
      'changeOrderStatus': (previous permissions),
      ...
    }
  }
  ```

**Integration Point:** After successful removal at line ~170, before snackbar.

---

### Site 2.3: Update Collaborator Permissions
**File:** [lib/listings/ui/collaboration/collaborators_management_screen.dart](lib/listings/ui/collaboration/collaborators_management_screen.dart#L104)

**Line:** ~104-116 (updateListingCollaboratorPermissions call)

**Action:** Lister changes permissions for an existing collaborator

**Key Variables:**
- `listingId`: `widget.listingId`
- `actorUid`: Current user's UID
- `collaboratorUid`: `collaborator.uid`
- `oldPermissions`: Previous permissions (need to store before update)
- `newPermissions`: `newPermissions` (CollaboratorPermissions)

**Context Available:**
- `collaborator`: CollaboratorModel with previous permissions
- `newPermissions`: Updated CollaboratorPermissions object

**Activity Log Entry Should Record:**
- **actionType:** `'COLLABORATOR_PERMISSIONS_UPDATED'`
- **targetType:** `'COLLABORATOR'`
- **targetId:** `collaborator.uid`
- **targetName:** `collaborator.displayName ?? collaborator.uid`
- **metadata:**
  ```dart
  {
    'collaboratorEmail': collaborator.email,
    'permissionsChanged': {
      'editListing': { 'from': old, 'to': new },
      'changeOrderStatus': { 'from': old, 'to': new },
      'manageBookings': { 'from': old, 'to': new },
      ...
    }
  }
  ```

**Integration Point:** After successful update at line ~113, before snackbar.

---

## 3. ORDER STATUS CHANGES

### Site 3.1: Order Status Update
**File:** [lib/screens/store/order_detail_screen.dart](lib/screens/store/order_detail_screen.dart#L1510)

**Line:** ~1493-1530 (_updateStatus method)

**Action:** Lister or customer changes order status

**Key Variables:**
- `listingId`: `widget.order.listingId`
- `orderId`: `widget.order.id` or `requestId`
- `actorUid`: `widget.currentUser.uid`
- `actorName`: `widget.currentUser.firstName` + `widget.currentUser.lastName`
- `oldStatus`: `_currentOrder.status`
- `newStatus`: `newStatus` (OrderStatus enum)

**Context Available:**
- `isCustomer`: `!widget.viewAsLister`
- `_currentOrder`: Full Order object with all details
- `listerNotes`: Optional notes from lister
- `channelId`: `widget.order.channelId` (for chat integration)

**Activity Log Entry Should Record:**
- **actionType:** `'ORDER_STATUS_CHANGED'` or `'ORDER_CANCELLED'` (if cancelled)
- **targetType:** `'ORDER'`
- **targetId:** `widget.order.id`
- **targetName:** Order display name (item/service name)
- **metadata:**
  ```dart
  {
    'orderStatus': newStatus.toString(),
    'previousStatus': _currentOrder.status.toString(),
    'actor': isCustomer ? 'CUSTOMER' : 'LISTER',
    'listerNotes': listerNotes,
    'amount': _currentOrder.amount,
  }
  ```

**Integration Point:** After `_storeService.updateOrderStatus()` call at line 1510, before posting to chat at line 1520.

---

### Site 3.2: Order Status Message in Chat
**File:** [lib/screens/store/order_chat_helper.dart](lib/screens/store/order_chat_helper.dart#L112)

**Line:** ~112-180 (postOrderStatusMessage method)

**Action:** Automated message/notification sent to order chat when status changes

**Note:** This is automatic and records the status change event already. May not need separate logging if handled at Site 3.1.

---

## 4. BOOKING STATUS CHANGES

### Site 4.1: Booking Approval (Lister Accepts)
**File:** [lib/listings/listings_module/booking/booking_management_screen.dart](lib/listings/listings_module/booking/booking_management_screen.dart#L941)

**Line:** ~941-949 (_approveBooking method)

**Action:** Lister confirms/accepts a pending booking request

**Key Variables:**
- `listingId`: `booking.listingId`
- `bookingId`: `booking.id`
- `actorUid`: `widget.currentUser.userID`
- `actorName`: `widget.currentUser.firstName` + `widget.currentUser.lastName`
- `oldStatus`: `'pending'`
- `newStatus`: `'confirmed'`

**Context Available:**
- `booking`: Full booking object with customer info, dates, pricing
- `booking.customerId`: Customer's UID
- `booking.customerName`: Customer's display name

**Activity Log Entry Should Record:**
- **actionType:** `'BOOKING_CONFIRMED'`
- **targetType:** `'BOOKING'`
- **targetId:** `booking.id`
- **targetName:** `booking.unitName` or `booking.itemName`
- **metadata:**
  ```dart
  {
    'customerId': booking.customerId,
    'customerName': booking.customerName,
    'startDate': booking.startTime,
    'endDate': booking.endTime,
    'amount': booking.subtotal,
    'previousStatus': 'pending',
  }
  ```

**Integration Point:** After BLoC.add() call at line 945, or in the BLoC event handler.

---

### Site 4.2: Booking Rejection (Lister Rejects)
**File:** [lib/listings/listings_module/booking/booking_management_screen.dart](lib/listings/listings_module/booking/booking_management_screen.dart#L952)

**Line:** ~952-990 (_rejectBooking method)

**Action:** Lister rejects a pending booking request

**Key Variables:**
- `listingId`: `booking.listingId`
- `bookingId`: `booking.id`
- `actorUid`: `widget.currentUser.userID`
- `oldStatus`: `'pending'`
- `newStatus`: `'rejected'`

**Context Available:**
- `booking`: Full booking object
- `booking.customerId`: Customer who made the request

**Activity Log Entry Should Record:**
- **actionType:** `'BOOKING_REJECTED'`
- **targetType:** `'BOOKING'`
- **targetId:** `booking.id`
- **targetName:** `booking.unitName` or `booking.itemName`
- **metadata:**
  ```dart
  {
    'customerId': booking.customerId,
    'customerName': booking.customerName,
    'previousStatus': 'pending',
  }
  ```

**Integration Point:** After BLoC.add() at line 977.

---

### Site 4.3: Booking Cancellation
**File:** [lib/listings/listings_module/booking/booking_management_screen.dart](lib/listings/listings_module/booking/booking_management_screen.dart#L1010)

**Line:** ~1010-1053 (_cancelBooking method)

**Action:** Lister cancels a confirmed booking

**Key Variables:**
- `listingId`: `booking.listingId`
- `bookingId`: `booking.id`
- `actorUid`: `widget.currentUser.userID`
- `oldStatus`: `'confirmed'`
- `newStatus`: `'cancelled'`

**Context Available:**
- `booking`: Full booking object
- Can extract reason for cancellation from context

**Activity Log Entry Should Record:**
- **actionType:** `'BOOKING_CANCELLED'`
- **targetType:** `'BOOKING'`
- **targetId:** `booking.id`
- **targetName:** `booking.unitName` or `booking.itemName`
- **metadata:**
  ```dart
  {
    'customerId': booking.customerId,
    'customerName': booking.customerName,
    'previousStatus': 'confirmed',
    'reason': 'lister_cancelled',
  }
  ```

**Integration Point:** After BLoC.add() at line 1039.

---

### Site 4.4: Booking Creation
**File:** [lib/listings/listings_module/booking/booking_bloc.dart](lib/listings/listings_module/booking/booking_bloc.dart#L26)

**Line:** ~26-42 (_onCreateBooking event)

**Action:** Customer creates a new booking request

**Key Variables:**
- `listingId`: `event.booking.listingId`
- `bookingId`: (returned from `createBooking()`)
- `actorUid`: `event.booking.customerId`
- `actorName`: `event.booking.customerName`
- `status`: `'pending'` (initial)

**Context Available:**
- `event.booking`: Full BookingModel with all details
- Customer info in booking object

**Activity Log Entry Should Record:**
- **actionType:** `'BOOKING_CREATED'`
- **targetType:** `'BOOKING'`
- **targetId:** `bookingId`
- **targetName:** `event.booking.unitName` or `event.booking.itemName`
- **metadata:**
  ```dart
  {
    'customerId': event.booking.customerId,
    'customerName': event.booking.customerName,
    'startDate': event.booking.startTime,
    'endDate': event.booking.endTime,
    'amount': event.booking.subtotal,
    'status': 'pending',
  }
  ```

**Integration Point:** After successful `createBooking()` call at line 26, before emit.

---

## 5. RENTAL BOOKING STATUS CHANGES

### Site 5.1: Rental Booking Status Update (Detail Screen)
**File:** [lib/listings/ui/rentals/rental_booking_detail_screen.dart](lib/listings/ui/rentals/rental_booking_detail_screen.dart#L1054)

**Line:** ~1054-1070 (_updateLifecycleStatus call)

**Action:** Lister updates rental booking lifecycle status (Confirmed → Active → Completed)

**Key Variables:**
- `listingId`: `booking.listingId`
- `bookingId`: `booking.id`
- `actorUid`: Current lister's UID
- `oldStatus`: `booking.status`
- `newStatus`: `newStatus` (RentalBookingStatus enum)

**Context Available:**
- `booking`: Full RentalBooking object
- `booking.customerId`: Customer/renter info
- `returnedInGoodCondition`: Whether returned in good condition
- `returnIssueNote`: Any issues reported

**Activity Log Entry Should Record:**
- **actionType:** `'RENTAL_BOOKING_' + newStatus.name.toUpperCase()` (e.g., 'RENTAL_BOOKING_ACTIVE')
- **targetType:** `'RENTAL'`
- **targetId:** `booking.id`
- **targetName:** `booking.unitName` or rental item name
- **metadata:**
  ```dart
  {
    'customerId': booking.customerId,
    'previousStatus': booking.status.toString(),
    'newStatus': newStatus.toString(),
    'startDate': booking.startTime,
    'endDate': booking.endTime,
    'returnedInGoodCondition': returnedInGoodCondition,
    'returnIssueNote': returnIssueNote,
  }
  ```

**Integration Point:** After `_rentalService.updateBookingStatus()` call at line 1054.

---

### Site 5.2: Rental Booking Status Update (Management Screen)
**File:** [lib/listings/ui/rentals/rentals_management_screen.dart](lib/listings/ui/rentals/rentals_management_screen.dart#L334)

**Line:** ~334-360 (_updateBookingStatus calls)

**Action:** Lister updates rental booking status from management screen

**Similar to Site 5.1** - handles status transitions for rental bookings.

**Activity Log Entry Should Record:** Same as Site 5.1

---

### Site 5.3: Rental Booking Cancellation
**File:** [lib/listings/ui/rentals/rental_booking_detail_screen.dart](lib/listings/ui/rentals/rental_booking_detail_screen.dart#L1180)

**Line:** ~1180-1240 (_confirmCancelBooking dialog and execution)

**Action:** Lister or customer cancels a rental booking

**Key Variables:**
- Same as Site 5.1
- `reason`: Cancellation reason provided by user
- `actor`: Whether customer or lister initiated

**Activity Log Entry Should Record:**
- **actionType:** `'RENTAL_BOOKING_CANCELLED'`
- **targetType:** `'RENTAL'`
- **targetId:** `booking.id`
- **metadata:**
  ```dart
  {
    'customerId': booking.customerId,
    'previousStatus': booking.status.toString(),
    'reason': reason_text,
    'cancelledBy': 'LISTER' or 'CUSTOMER',
  }
  ```

**Integration Point:** After cancellation confirmation and status update call.

---

## 6. CHAT MESSAGES

### Site 6.1: Chat Message Sent
**File:** [lib/core/ui/chat/api/firebase/chat_firebase.dart](lib/core/ui/chat/api/firebase/chat_firebase.dart#L396)

**Line:** ~396-480 (sendMessage method in ChatFirebase)

**Action:** User sends a chat message in a channel (may be related to listing or order)

**Key Variables:**
- `listingId`: `channelDataModel.listingId` (if listing-related chat)
- `channelId`: `channelDataModel.channelID`
- `actorUid`: `message.senderID`
- `actorName`: `message.senderFirstName` + `message.senderLastName`
- `messageId`: `message.id`
- `content`: `message.content`

**Context Available:**
- `channelDataModel`: Contains listing info, participants, etc.
- `message`: Full ChatFeedContent object
- `message.chatMedia`: If media is included
- Batch write operation for atomicity

**Activity Log Entry Should Record:** (Only if `channelDataModel.listingId` is set)
- **actionType:** `'CHAT_MESSAGE_SENT'`
- **targetType:** `'CHAT'`
- **targetId:** `channelId`
- **targetName:** `channelDataModel.listingTitle` (if available)
- **metadata:**
  ```dart
  {
    'messageId': message.id,
    'contentLength': message.content.length,
    'hasMedia': message.chatMedia != null,
    'mediaType': message.chatMedia?.type,
    'participantCount': channelDataModel.participants.length,
    'listingId': channelDataModel.listingId,
  }
  ```

**Integration Point:** After batch.commit() succeeds at line ~450, before/during the activity service call.

**Note:** There's already an `activityService.recordMessage()` call at line ~454-460, so leverage that.

---

### Site 6.2: Chat Message Sent via BLoC
**File:** [lib/core/ui/chat/chat/chat_bloc.dart](lib/core/ui/chat/chat/chat_bloc.dart#L262)

**Line:** ~262-318 (_sendMessage method)

**Action:** BLoC handler for sending messages (called from various events)

**This is a wrapper around Site 6.1** - passes message to repository.

**Key Variables:**
- Same as Site 6.1
- `channelDataModel`: Full channel info
- `message`: Constructed ChatFeedContent object

**Integration Point:** The repository call at line 310 should handle activity logging.

---

## Summary Table

| Site | File | Line | actionType | targetType | When to Record |
|------|------|------|-----------|-----------|---|
| 1.1 | add_listing_bloc.dart | 303 | LISTING_EDITED / LISTING_CREATED | LISTING | After publish success |
| 2.1 | collaborators_management.dart | 74 | COLLABORATOR_ADDED | COLLABORATOR | After API call success |
| 2.2 | collaborators_management.dart | 166 | COLLABORATOR_REMOVED | COLLABORATOR | After API call success |
| 2.3 | collaborators_management.dart | 104 | COLLABORATOR_PERMISSIONS_UPDATED | COLLABORATOR | After API call success |
| 3.1 | order_detail_screen.dart | 1510 | ORDER_STATUS_CHANGED | ORDER | After status update |
| 4.1 | booking_management_screen.dart | 941 | BOOKING_CONFIRMED | BOOKING | After BLoC dispatch |
| 4.2 | booking_management_screen.dart | 952 | BOOKING_REJECTED | BOOKING | After BLoC dispatch |
| 4.3 | booking_management_screen.dart | 1010 | BOOKING_CANCELLED | BOOKING | After BLoC dispatch |
| 4.4 | booking_bloc.dart | 26 | BOOKING_CREATED | BOOKING | After create success |
| 5.1 | rental_booking_detail_screen.dart | 1054 | RENTAL_BOOKING_[STATUS] | RENTAL | After status update |
| 5.2 | rentals_management_screen.dart | 334 | RENTAL_BOOKING_[STATUS] | RENTAL | After status update |
| 5.3 | rental_booking_detail_screen.dart | 1180 | RENTAL_BOOKING_CANCELLED | RENTAL | After cancellation |
| 6.1 | chat_firebase.dart | 396 | CHAT_MESSAGE_SENT | CHAT | After batch commit |
| 6.2 | chat_bloc.dart | 262 | CHAT_MESSAGE_SENT | CHAT | Via repository layer |

---

## Implementation Notes

1. **User Context:** Most sites have access to `currentUser` or `widget.currentUser` containing `userID`, `firstName`, `lastName`.

2. **ListingId Availability:** 
   - Always available in listing contexts (`widget.listingId` or `booking.listingId`)
   - For chat, use `channelDataModel.listingId` if set

3. **Activity Service:** Reference the existing `ListingActivityService` in:
   - [booking_bloc.dart](lib/listings/listings_module/booking/booking_bloc.dart#L33) (line 33 shows usage pattern)
   - [chat_firebase.dart](lib/core/ui/chat/api/firebase/chat_firebase.dart#L454) (line 454)

4. **Batch Operations:** Sites 3.1, 5.1-5.3 use API calls that should complete before logging.

5. **Error Handling:** Activity logging should not fail the main action. Use try-catch and log errors without breaking functionality.
