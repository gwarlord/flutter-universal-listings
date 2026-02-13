# Lister Collaboration - Integration Guide

This guide shows exactly how to integrate the Lister Collaboration feature into your existing screens.

## Quick Overview

The Lister Collaboration feature is already implemented. This guide shows where to add UI elements to expose it in your existing screens.

**Files Modified:**
- `lib/listings/listings_module/listing_details/listing_details_screen.dart` - Add collaborators menu + team chat
- `lib/listings/listings_module/my_listings/my_listings_screen.dart` - Add assigned listings tab
- `lib/listings/ui/profile/profile/profile_screen.dart` - Add collaboration dashboard

---

## 1. Listing Details Screen Integration

### Location: `listing_details_screen.dart` - Collaborators Menu Item

The listing details screen already has a menu (hamburger menu in header). Add collaborators management option.

#### Step 1: Add to imports (near top of file)

```dart
import 'package:instaflutter/listings/ui/collaboration/collaborators_management_screen.dart';
```

#### Step 2: Add to `_buildHeaderCircleMenu()` function

Find the `_buildHeaderCircleMenu` method (around line 829) and add this code **AFTER the "Edit Listing" menu item** and BEFORE the "Manage Reviews" menu item:

```dart
            if (_canEditOrDelete)  // Owner only
              PopupMenuItem(
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group, color: Color(cfg.colorPrimary)),
                  title: Text(
                    'Manage Collaborators'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await push(
                      context,
                      CollaboratorsManagementScreen(
                        listing: listing,
                        currentUser: currentUser,
                      ),
                    );
                    // Refresh listing if changes made
                    setState(() {});
                  },
                ),
              ),
```

### Result
- ✅ Owners will see "Manage Collaborators" in the menu
- ✅ Opens full collaborator CRUD interface
- ✅ Includes premium gate (managed by the screen itself)

---

## 2. My Listings Screen Integration

### Location: `my_listings_screen.dart` - Add Assigned Listings Tab

The my listings screen currently shows the user's own listings. Add a second tab for assigned listings (for users who are collaborators).

#### Step 1: Add to imports

```dart
import 'package:instaflutter/listings/ui/collaboration/assigned_listings_screen.dart';
```

#### Step 2: Modify the state class

Find `_MyListingsScreenState` class and add these state variables:

```dart
  int _selectedTabIndex = 0;  // 0 = My Listings, 1 = Assigned Listings
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
```

#### Step 3: Modify the build method

Find the `build()` method in `_MyListingsScreenState` and locate where it builds the main content (likely a `BlocBuilder<MyListingsBloc, MyListingsState>`). 

**Replace** the entire main content column with this tabbed version:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Listings'.tr()),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() => _selectedTabIndex = index),
          tabs: [
            Tab(text: 'My Listings'.tr()),
            Tab(text: 'Assigned Listings'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: My Listings (existing content)
          _buildMyListingsTab(),
          // Tab 1: Assigned Listings (new)
          AssignedListingsScreen(currentUser: currentUser),
        ],
      ),
    );
  }

  // Extract existing build content into this method
  Widget _buildMyListingsTab() {
    return BlocProvider(
      create: (context) => MyListingsBloc(listingsAPI: listingsAPI)..add(GetMyListingsEvent()),
      child: BlocBuilder<MyListingsBloc, MyListingsState>(
        builder: (context, state) {
          // [Existing my listings content goes here]
          // Copy the existing build method content from before
          if (state is LoadingState) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is MyListingsLoadedState) {
            return ListView.builder(
              itemCount: state.myListings.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(state.myListings[index].title),
                  onTap: () {
                    push(context, ListingDetailsWrappingWidget(listing: state.myListings[index]));
                  },
                );
              },
            );
          }
          return Center(child: Text('No listings found'.tr()));
        },
      ),
    );
  }
```

### Result
- ✅ Tab 1: Current "My Listings" behavior unchanged
- ✅ Tab 2: Shows listings where user is a collaborator
- ✅ Each assigned listing shows permission indicators
- ✅ Click to view details with collaborative editing options

---

## 3. Profile Screen Integration

### Location: `profile_screen.dart` - Add Collaboration Section

Add a collaboration dashboard to the profile/account settings.

#### Step 1: Add to imports

```dart
import 'package:instaflutter/listings/ui/collaboration/activity_log_screen.dart';
import 'package:instaflutter/listings/model/collaboration_model.dart';
import 'package:instaflutter/listings/listings_module/api/collaboration_firebase.dart';
```

#### Step 2: Add to state variables

Find the `_ProfileScreenState` class and add:

```dart
  final CollaborationFirebaseImpl _collaborationApi = CollaborationFirebaseImpl();
  Stream<CollaborationState>? _collaborationStream;

  @override
  void initState() {
    super.initState();
    _collaborationStream = _collaborationApi.getCollaborationState(currentUser.userID);
  }
```

#### Step 3: Add collaboration section to build

Find where the profile screen builds its main content (likely a ListView or Column inside a BlocBuilder). Add this section **after the basic profile info** and **before settings/security sections**:

```dart
            // Collaboration Section
            if (currentUser.userID != CoreConstats().loggedInUser?.userID ?? false)
              SizedBox(height: 32),
            
            if (currentUser.userID == CoreConstats().loggedInUser?.userID ?? false)
              StreamBuilder<CollaborationState>(
                stream: _collaborationStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return SizedBox.shrink();
                  }
                  
                  final collabState = snapshot.data!;
                  final hasCollaborations = 
                    collabState.ownListings.isNotEmpty || 
                    collabState.assignedListings.isNotEmpty;
                  
                  if (!hasCollaborations) return SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Color(cfg.colorPrimary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(cfg.colorPrimary).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.group, color: Color(cfg.colorPrimary)),
                                SizedBox(width: 12),
                                Text(
                                  'Team Collaboration'.tr(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            
                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Listings Owned'.tr(),
                                    collabState.ownListings.length.toString(),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'Assigned'.tr(),
                                    collabState.assignedListings.length.toString(),
                                  ),
                                ),
                              ],
                            ),
                            
                            if (collabState.ownListings.isNotEmpty) ...[
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.manage_accounts),
                                  label: Text('Manage Collaborators'.tr()),
                                  onPressed: () {
                                    // Open collaborators management
                                    // User selects which listing to manage
                                    _showSelectListingDialog(
                                      context,
                                      collabState.ownListings,
                                    );
                                  },
                                ),
                              ),
                            ],
                            
                            if (collabState.ownListings.isNotEmpty) ...[
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.history),
                                  label: Text('View Team Activity'.tr()),
                                  onPressed: () {
                                    push(context, ActivityLogScreen(
                                      listingId: collabState.ownListings.first.id,
                                      currentUser: currentUser,
                                    ));
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
```

#### Step 4: Add helper methods to state class

Add these methods to `_ProfileScreenState`:

```dart
  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(cfg.colorPrimary),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showSelectListingDialog(
    BuildContext context,
    List<AssignedListingModel> listings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Listing'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: listings.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(listings[index].title),
                onTap: () {
                  Navigator.pop(context);
                  push(context, CollaboratorsManagementScreen(
                    listing: ListingModel(
                      id: listings[index].id,
                      title: listings[index].title,
                      // Copy other required fields from listing
                    ),
                    currentUser: currentUser,
                  ));
                },
              );
            },
          ),
        ),
      ),
    );
  }
```

### Result
- ✅ Shows collaboration stats when user has listings/collaborations
- ✅ "Manage Collaborators" button to add/edit team members
- ✅ "View Team Activity" button for audit trail
- ✅ Stats: listings owned vs assigned to user
- ✅ Premium gate handled by collaboration screens

---

## 4. Order/Booking Chat Integration (Optional)

### Location: `booking_management_screen.dart` - Add Order Chat Link

If you want to add team chat for orders, add this where you display orders:

```dart
// Add import
import 'package:instaflutter/listings/ui/collaboration/chat_scope_integration.dart';

// In order item widget
ListTile(
  title: Text(order.title),
  trailing: IconButton(
    icon: Icon(Icons.chat),
    onPressed: () {
      // Open order chat with team
      final chatScope = ChatScopeIntegration.createOrderChatScope(
        orderId: order.id,
        currentUser: currentUser,
        isCollaborator: true,  // Set based on user's role
      );
      // Navigate to chat using existing chat screen
      push(context, ChatScope(
        scope: chatScope,
      ));
    },
  ),
)
```

---

## 5. Existing Screens - No Changes Required

### ✅ Chat System
- Already compatible with order_chats collection
- Customers can see their order messages only
- Collaborators see full team messages

### ✅ Booking System  
- Activity logging automatic via Cloud Functions
- No UI changes needed for basic functionality

### ✅ Rental System
- Collaborator permissions apply automatically
- Cloud Functions enforce access control

---

## 6. Testing Integration

### Test Checklist

- [ ] **Collaborators Menu**: Owner can see "Manage Collaborators" option
- [ ] **Add Collaborator**: Can invite user with permission toggles
- [ ] **Assigned Listings Tab**: Collaborators see their assigned listings
- [ ] **Team Chat**: Messages visible to collaborators + owner only
- [ ] **Activity Log**: See all team actions timestamped
- [ ] **Premium Gate**: Non-premium users blocked from inviting
- [ ] **Permission Enforcement**: Collaborators can only do allowed actions
- [ ] **Delete Protection**: Can't delete listing even as collaborator

### Test Scenarios

1. **Owner Flow**:
   - Create listing → Invite collaborator → Grant permissions → Verify activity log

2. **Collaborator Flow**:
   - Receive invite → Accept → See in "Assigned Listings" → Edit allowed fields

3. **Permission Testing**:
   - Try all 8 permission toggles → Verify UI reflects permissions

4. **Chat Testing**:
   - Team chat visible to collaborators only
   - Order chat visible to collaborators + customer
   - Messages logged in activity trail

---

## 7. Troubleshooting

### Menu item doesn't appear
- ✅ Verify user is listing owner: `currentUser.userID == listing.authorID`
- ✅ Check import: `CollaboratorsManagementScreen`

### Assigned Listings tab empty
- ✅ Check Firebase `listings/{id}/collaborators/{uid}` collection exists
- ✅ Verify `activeCollaborations` stream initialized
- ✅ Check activity logs in Firebase

### Premium gate not working
- ✅ Verify RevenueCat integration in app
- ✅ Check Cloud Functions have valid RevenueCat API key
- ✅ User must have active premium product ID

### Chat scope issues
- ✅ Verify `listing_chats` and `order_chats` collections created
- ✅ Check Firestore rules allow access
- ✅ Verify participant IDs stored correctly

---

## 8. Quick Reference

**Imports Needed** (in each screen):
```dart
import 'package:instaflutter/listings/ui/collaboration/collaborators_management_screen.dart';
import 'package:instaflutter/listings/ui/collaboration/assigned_listings_screen.dart';
import 'package:instaflutter/listings/ui/collaboration/activity_log_screen.dart';
import 'package:instaflutter/listings/model/collaboration_model.dart';
import 'package:instaflutter/listings/listings_module/api/collaboration_firebase.dart';
```

**Key Classes**:
- `CollaboratorsManagementScreen` - Full CRUD interface
- `AssignedListingsScreen` - Shows collaborator's work
- `ActivityLogScreen` - Audit trail with timeline
- `CollaborationFirebaseImpl` - API for reading collaboration state
- `ChatScopeIntegration` - Helper for chat setup

**Firestore Collections**:
- `listings/{id}/collaborators/{uid}` - Team members + permissions
- `listings/{id}/activity/{docId}` - Audit trail  
- `listing_chats/{listingId}/messages/{docId}` - Team chat
- `order_chats/{orderId}/messages/{docId}` - Order thread chat

---

## 9. Next Steps

1. ✅ **Add collaborators menu** to listing details (2 min)
2. ✅ **Add assigned listings tab** to my listings (5 min)
3. ✅ **Add collaboration section** to profile (10 min)
4. ✅ **Test each integration** (15 min)
5. ✅ **Deploy and monitor** Cloud Functions logs

**Estimated time**: 30-45 minutes to integrate everything

---

**Need Help?**
- Check `LISTER_COLLABORATION_QUICKSTART.md` for implementation details
- See `LISTER_COLLABORATION_MANIFESTO.md` for architecture overview
- Review `lib/listings/ui/collaboration/` for screen implementations
- Check Cloud Functions logs for any RevenueCat errors
