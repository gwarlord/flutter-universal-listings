# Lister Collaboration - Quick Start & Usage Examples

## Quick Start

### 1. Display Collaborators for a Listing

```dart
import 'package:instaflutter/listings/ui/collaboration/collaborators_management_screen.dart';

// In your listing detail/edit screen
ElevatedButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CollaboratorsManagementScreen(
        listingId: listing.id,
        listingOwnerId: listing.authorID,
        currentUserId: currentUser.userID,
        isOwner: listing.authorID == currentUser.userID,
        hasPremium: currentUser.hasPremium,
      ),
    ),
  ),
  child: const Text('Manage Collaborators'),
)
```

### 2. Show Collaborator's Assigned Listings

```dart
import 'package:instaflutter/listings/ui/collaboration/assigned_listings_screen.dart';

// In your profile or dashboard
tab: Tab(label: 'Assigned Listings'),
tabView: AssignedListingsScreen(
  userId: currentUser.userID,
  onListingSelected: (listingId) {
    // Navigate to listing details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailsScreen(listingId: listingId),
      ),
    );
  },
)
```

### 3. Show Activity Log for a Listing

```dart
import 'package:instaflutter/listings/ui/collaboration/activity_log_screen.dart';

// In your listing management screen
ElevatedButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ActivityLogScreen(
        listingId: listing.id,
      ),
    ),
  ),
  child: const Text('View Activity Log'),
)
```

### 4. Open Listing Team Chat

```dart
import 'package:instaflutter/listings/ui/collaboration/chat_scope_integration.dart';
import 'package:instaflutter/core/ui/chat/chat/chat_screen.dart';

// When owner/collaborator opens listing details
try {
  // Check if user can access
  final canAccess = await ChatScopeIntegration.canAccessListingTeamChat(
    listingId: listing.id,
    userId: currentUser.userID,
    listingOwnerId: listing.authorID,
  );

  if (!canAccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You don\'t have access to team chat')),
    );
    return;
  }

  // Get collaborators
  final collaborators = await collaborationApiManager.getListingCollaborators(
    listingId: listing.id,
  );

  // Load user data for collaborators
  final collaboratorUsers = <User>[];
  for (var collab in collaborators) {
    // You'd need to load full User objects here
    // For now, we're using the User objects you have
  }

  // Create channel
  final channel = await ChatScopeIntegration.createListingTeamChat(
    listingId: listing.id,
    ownerUid: listing.authorID,
    ownerUser: ownerUser,
    collaboratorUsers: collaboratorUsers,
  );

  if (mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(channelDataModel: channel),
      ),
    );
  }
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error opening chat: $e')),
  );
}
```

### 5. Open Order Thread Chat

```dart
import 'package:instaflutter/listings/ui/collaboration/chat_scope_integration.dart';

// When viewing an order
final channel = await ChatScopeIntegration.createOrderThreadChat(
  orderId: order.id,
  listingId: order.listingId,
  ownerUid: order.listingOwnerUid,
  ownerUser: listingOwnerUser,
  customerUid: order.customerId,
  customerUser: customerUser,
  collaboratorUsers: collaborators,
);

Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChatScreen(channelDataModel: channel),
  ),
);
```

## Code Examples by Use Case

### Use Case 1: Premium Owner adds Collaborator

```dart
// In CollaboratorsManagementScreen
void _addCollaborator(String email, CollaboratorPermissions permissions) async {
  try {
    final uid = await collaborationApiManager.addListingCollaborator(
      listingId: listingId,
      collaboratorEmailOrUid: email,
      permissions: permissions, // UI collected these
    );

    // Cloud Function will:
    // 1. Verify owner has Premium
    // 2. Resolve email to user UID
    // 3. Create collaborator doc
    // 4. Create assignedListings mapping
    // 5. Add to listing chat
    // 6. Add to all order chats for this listing
    // 7. Log activity

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collaborator added!')),
    );
    // UI will refresh via stream
  } on FireFunctionException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.message}')),
    );
  }
}
```

### Use Case 2: Collaborator changes Order Status

```dart
// In order management screen
ElevatedButton(
  onPressed: async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('setOrderStatus')
          .call({
        'orderId': order.id,
        'listingId': listing.id,
        'newStatus': 'SHIPPED',
      });

      // Cloud Function will:
      // 1. Check if caller is owner or collab with changeOrderStatus
      // 2. Update order status in Firestore
      // 3. Log activity

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated')),
      );
    } on FireFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    }
  },
  child: const Text('Mark as Shipped'),
)
```

### Use Case 3: Collaborator edits Listing

```dart
// In listing edit form
ElevatedButton(
  onPressed: () async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('updateListingEditableFields')
          .call({
        'listingId': listing.id,
        'patch': {
          'title': titleController.text,
          'description': descController.text,
          'price': priceController.text,
        },
      });

      // Cloud Function will check editListing permission
      // and log the activity

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing updated')),
      );
    } catch (e) {
      // Handle error
    }
  },
  child: const Text('Save Changes'),
)
```

### Use Case 4: View Activity Timeline

```dart
// In ActivityLogScreen, already integrated
// Just use the built-in ActivityLogTimeline widget

body: StreamBuilder<List<ActivityLogEntry>>(
  stream: collaborationApiManager.streamActivityLog(
    listingId: listingId,
  ),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ActivityLogTimeline(
        activities: snapshot.data!,
      );
    }
    // handle loading/error
  },
)
```

### Use Case 5: Prevent Collaborator from Deleting Listing

```dart
// In listing detail screen
// The delete button should check:

if (!isOwner) {
  // Collaborators can never delete
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Only the listing owner can delete this listing'),
    ),
  );
  return;
}

// Show delete dialog only for owner
```

**Additionally**, the Firestore rules enforce this:
```
allow delete: if request.auth.uid == resource.data.authorID
// Collaborators don't have a delete rule at all
```

### Use Case 6: Customer sees only their Order Chat

```dart
// When customer is viewing their orders
// Query only orders where customerId == currentUser.userID

final customerOrders = await _firestore
    .collection('listings')
    .doc(listingId)
    .collection('orders')
    .where('customerId', isEqualTo: currentUser.userID)
    .get();

// For each order, show order chat (not listing team chat)
// Order chat includes: owner + collaborators + themselves

// Customer CANNOT access listing_chats/{listingId}
// (Firestore rules block it)
```

### Use Case 7: Disable Chat for Collaborator

```dart
// Owner removes manageChats permission
final updatedPermissions = currentPermissions.copyWith(
  manageChats: false,
);

await collaborationApiManager.updateListingCollaboratorPermissions(
  listingId: listing.id,
  collaboratorUid: collaborator.uid,
  permissions: updatedPermissions,
);

// Cloud Function will:
// 1. Remove collaborator from listing_chats/{listingId}/participants
// 2. Remove collaborator from all order_chats/{orderId}/participants
// 3. Log the permission change
```

## Integration Points in Existing Screens

### In Listing Details Screen
```dart
// Add tab or button for team chat
Tab(label: 'Team Chat', icon: Icon(Icons.group_chat))
// → Leads to listing team chat

// Add collaborators button (owner only)
if (isOwner) {
  IconButton(
    icon: const Icon(Icons.people),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollaboratorsManagementScreen(...),
      ),
    ),
  )
}
```

### In Order Details Screen
```dart
// Add order thread chat option
Tab(label: 'Chat', icon: Icon(Icons.chat))
// → Leads to order thread chat with owner + collaborators + customer

// Activity button
ElevatedButton.icon(
  icon: const Icon(Icons.history),
  label: const Text('Activity'),
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ActivityLogScreen(listingId: order.listingId),
    ),
  ),
)
```

### In User Profile/Dashboard
```dart
// Add tab for assigned listings view (if user is a collaborator)
if (assignedListingsCount > 0) {
  Tab(label: 'Assigned Listings ($assignedListingsCount)'),
  // → Leads to AssignedListingsScreen
}
```

## Permission Checks in UI

```dart
// Before showing "Edit Listing" UI
bool canEditListing = isOwner ||
    (userRole == 'COLLABORATOR' &&
        permissions?.editListing == true);

// Before showing "Change Order Status" UI  
bool canChangeStatus = isOwner ||
    (userRole == 'COLLABORATOR' &&
        permissions?.changeOrderStatus == true);

// Before showing team chat
bool canAccessTeamChat = isOwner ||
    (userRole == 'COLLABORATOR' &&
        permissions?.manageChats == true);
```

These checks prevent accidental UX flow into unauthorized operations.
The server will still enforce via Cloud Functions and Firestore rules.

## Error Handling

```dart
Future<void> _performCollaborationAction() async {
  try {
    // Your action here
  } on FireFunctionsException catch (e) {
    String message = e.message ?? 'Unknown error';
    
    if (message.contains('permission-denied')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You don\'t have permission to do this'),
        ),
      );
    } else if (message.contains('unauthenticated')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in'),
        ),
      );
    } else if (message.contains('Premium')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Premium required for this action'),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () => _navigateToPaywall(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $message')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Testing Checklist

- [ ] Add non-premium owner → see upgrade CTA
- [ ] Add premium owner → see "Add Collaborator" button
- [ ] Add collaborator with limited permissions
- [ ] Verify collaborator appears in assigned listings
- [ ] Verify collaborator can/cannot access based on permissions
- [ ] Change order status as collaborator → activity log shows it
- [ ] Remove collaborator permission → verify chat access revoked
- [ ] Customer views order → sees only order chat, not team chat
- [ ] Check Firestore rules prevent unauthorized writes
- [ ] Verify RevenueCat check blocks non-premium owners

---

**Last Updated:** February 2026
