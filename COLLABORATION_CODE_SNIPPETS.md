# Lister Collaboration - Code Implementation Snippets

Copy/paste ready code to add collaboration features to your existing screens.

---

## 1. Listing Details Screen - Add Collaborators Menu

### File: `lib/listings/listings_module/listing_details/listing_details_screen.dart`

#### Import (add at top with other imports):
```dart
import 'package:instaflutter/listings/ui/collaboration/collaborators_management_screen.dart';
```

#### Add to `_buildHeaderCircleMenu()`:

**Find this method around line 829, then find the "Manage Reviews" PopupMenuItem (around line 855).**

**INSERT THIS CODE BEFORE "Manage Reviews" but AFTER "Edit Listing":**

```dart
            if (_canEditOrDelete)
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
                    setState(() {});
                  },
                ),
              ),
```

**That's all for listing details!** The collaborators screen handles:
- ✅ Premium gate check
- ✅ Add/remove collaborators
- ✅ Permission toggles
- ✅ Activity logging

---

## 2. My Listings Screen - Add Assigned Listings Tab

### File: `lib/listings/listings_module/my_listings/my_listings_screen.dart`

#### Imports (add at top):
```dart
import 'package:instaflutter/listings/ui/collaboration/assigned_listings_screen.dart';
```

#### Add State Variables:

**Find `class _MyListingsScreenState extends State<MyListingsScreen>`**

**Add these variables just after the class declaration:**

```dart
class _MyListingsScreenState extends State<MyListingsScreen> with TickerProviderStateMixin {
  // ... existing variables ...
  
  late TabController _collabTabController;

  @override
  void initState() {
    super.initState();
    _collabTabController = TabController(length: 2, vsync: this);
    // ... rest of existing initState ...
  }

  @override
  void dispose() {
    _collabTabController.dispose();
    super.dispose();
  }
```

#### Modify Build Method:

**Find the `build()` method. The current structure is likely:**

```dart
@override
Widget build(BuildContext context) {
  return BlocProvider<MyListingsBloc>(
    create: (context) => MyListingsBloc(listingsAPI: listingsAPI)..add(GetMyListingsEvent()),
    child: BlocBuilder<MyListingsBloc, MyListingsState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text('My Listings'.tr())),
          body: // ... existing content ...
        );
      },
    ),
  );
}
```

**REPLACE the entire build method with:**

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('My Listings'.tr()),
      bottom: TabBar(
        controller: _collabTabController,
        tabs: [
          Tab(text: 'My Listings'.tr()),
          Tab(text: 'Assigned'.tr()),
        ],
      ),
    ),
    body: TabBarView(
      controller: _collabTabController,
      children: [
        // Tab 0: My Listings (existing)
        BlocProvider<MyListingsBloc>(
          create: (context) => MyListingsBloc(listingsAPI: listingsAPI)..add(GetMyListingsEvent()),
          child: BlocBuilder<MyListingsBloc, MyListingsState>(
            builder: (context, state) {
              // Paste your existing build content here
              // (the body from the original build method)
              return _buildMyListingsContent(state);
            },
          ),
        ),
        // Tab 1: Assigned Listings (new)
        AssignedListingsScreen(currentUser: currentUser),
      ],
    ),
  );
}

// Extract your existing build content into this method
Widget _buildMyListingsContent(MyListingsState state) {
  if (state is LoadingState) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  } else if (state is MyListingsLoadedState) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await push(context, CreateListingWrappingWidget(currentUser: currentUser));
          if (mounted) context.read<MyListingsBloc>().add(GetMyListingsEvent());
        },
        child: const Icon(Icons.add),
      ),
      body: state.myListings.isEmpty
          ? const Center(child: Text('No listings found'))
          : ListView.builder(
              itemCount: state.myListings.length,
              itemBuilder: (context, index) {
                return ListingItemWidget(
                  listing: state.myListings[index],
                  onTap: () async {
                    final updated = await push(
                      context,
                      ListingDetailsWrappingWidget(listing: state.myListings[index]),
                    );
                    if (updated is ListingModel && mounted) {
                      context.read<MyListingsBloc>().add(GetMyListingsEvent());
                    }
                  },
                );
              },
            ),
    );
  } else if (state is ErrorState) {
    return Scaffold(
      body: Center(child: Text(state.error)),
    );
  }
  return const Scaffold(body: SizedBox.shrink());
}
```

**Note:** If your existing code structure is different, just ensure:
1. Wrap the existing content in a BlocProvider/BlocBuilder (inside Tab 0)
2. Add AssignedListingsScreen in Tab 1
3. Use TabBar/TabBarView to switch between them

---

## 3. Profile Screen - Add Collaboration Section

### File: `lib/listings/ui/profile/profile/profile_screen.dart`

#### Imports (add at top):
```dart
import 'package:instaflutter/listings/ui/collaboration/activity_log_screen.dart';
import 'package:instaflutter/listings/ui/collaboration/collaborators_management_screen.dart';
import 'package:instaflutter/listings/model/collaboration_model.dart';
import 'package:instaflutter/listings/listings_module/api/collaboration_firebase.dart';
```

#### Add State Variables:

**In `_ProfileScreenState` class, add:**

```dart
  final CollaborationFirebaseImpl _collaborationApi = CollaborationFirebaseImpl();

  Stream<CollaborationState>? _collaborationStream;

  @override
  void initState() {
    super.initState();
    _collaborationStream = _collaborationApi.getCollaborationState(currentUser.userID);
  }
```

#### Add to Build Method:

**Find where your profile content builds (likely a ListView or Column in BlocBuilder).**

**INSERT THIS SECTION after the profile header (name/avatar) but before settings:**

```dart
            // Collaboration Section
            StreamBuilder<CollaborationState>(
              stream: _collaborationStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final collabState = snapshot.data!;
                final hasListings = collabState.ownListings.isNotEmpty;
                final hasAssigned = collabState.assignedListings.isNotEmpty;

                if (!hasListings && !hasAssigned) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Team Collaboration'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(cfg.colorPrimary).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(cfg.colorPrimary).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats
                          if (hasListings) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCard(
                                  label: 'Owned Listings'.tr(),
                                  value: collabState.ownListings.length.toString(),
                                ),
                                _buildStatCard(
                                  label: 'Collaborators'.tr(),
                                  value: collabState.activeCollaborators.length.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasAssigned) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatCard(
                                  label: 'Assigned To'.tr(),
                                  value: collabState.assignedListings.length.toString(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Action Buttons
                          if (hasListings) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.manage_accounts),
                                label: Text('Manage Collaborators'.tr()),
                                onPressed: () {
                                  if (collabState.ownListings.isNotEmpty) {
                                    _showSelectListingDialog(
                                      context,
                                      collabState.ownListings,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.history),
                                label: Text('Activity Log'.tr()),
                                onPressed: () {
                                  if (collabState.ownListings.isNotEmpty) {
                                    push(
                                      context,
                                      ActivityLogScreen(
                                        listingId: collabState.ownListings.first.id,
                                        currentUser: currentUser,
                                      ),
                                    );
                                  }
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

#### Add Helper Methods:

**Add these methods to `_ProfileScreenState` class:**

```dart
  Widget _buildStatCard({
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(cfg.colorPrimary),
            ),
          ),
          const SizedBox(height: 4),
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
              final listing = listings[index];
              return ListTile(
                title: Text(listing.title),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pop(context);
                  // Create a ListingModel from AssignedListingModel
                  final listingModel = ListingModel(
                    id: listing.id,
                    title: listing.title,
                    photos: [],
                    authorID: listing.ownerId,
                    // Add other required fields with defaults
                  );
                  push(
                    context,
                    CollaboratorsManagementScreen(
                      listing: listingModel,
                      currentUser: currentUser,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
```

---

## 4. Optional: Booking Management - Add Activity Log Link

### File: `lib/listings/listings_module/booking/booking_management_screen.dart`

#### Import:
```dart
import 'package:instaflutter/listings/ui/collaboration/activity_log_screen.dart';
```

#### In booking detail/tile, add activity log button:

```dart
IconButton(
  icon: const Icon(Icons.history),
  tooltip: 'Activity Log'.tr(),
  onPressed: () {
    push(
      context,
      ActivityLogScreen(
        listingId: booking.listingId,
        currentUser: currentUser,
      ),
    );
  },
)
```

---

## 5. Complete File Paths Reference

```
✅ Created (No changes needed):
├── functions/src/collaboration.ts
├── lib/listings/model/collaboration_model.dart
├── lib/listings/listings_module/api/collaboration_repository.dart
├── lib/listings/listings_module/api/firebase/collaboration_firebase.dart
├── lib/listings/listings_module/api/collaboration_api_manager.dart
├── lib/listings/ui/collaboration/collaborators_management_screen.dart
├── lib/listings/ui/collaboration/assigned_listings_screen.dart
├── lib/listings/ui/collaboration/activity_log_screen.dart
├── lib/listings/ui/collaboration/chat_scope_integration.dart
├── firestore.rules (MODIFIED - add rules)
└── functions/src/index.ts (MODIFIED - add import)

🔧 You Need to Update:
├── lib/listings/listings_module/listing_details/listing_details_screen.dart
├── lib/listings/listings_module/my_listings/my_listings_screen.dart
├── lib/listings/ui/profile/profile/profile_screen.dart
└── (Optional) lib/listings/listings_module/booking/booking_management_screen.dart
```

---

## 6. Verification Checklist

After making changes:

```
□ listing_details_screen.dart
  □ Import added: CollaboratorsManagementScreen
  □ Menu item added: "Manage Collaborators"
  □ Menu item only shows if _canEditOrDelete (owner)
  □ onTap navigates to CollaboratorsManagementScreen

□ my_listings_screen.dart
  □ Import added: AssignedListingsScreen
  □ TabController created in initState
  □ dispose() cleans up TabController
  □ AppBar shows TabBar with 2 tabs
  □ TabBarView has 2 children (My Listings + Assigned)
  □ Assigned listings uses AssignedListingsScreen widget

□ profile_screen.dart
  □ Imports added: activity_log, collaborators, model, firebase
  □ _collaborationApi initialized
  □ _collaborationStream created in initState
  □ StreamBuilder added to build
  □ Collaboration section hidden if no listings
  □ Stats cards display counts
  □ Buttons navigate to correct screens
  □ Helper methods added: _buildStatCard, _showSelectListingDialog

□ Firestore Rules Updated
  □ collaborators collection rules added
  □ activity log rules added
  □ listing_chats rules added
  □ order_chats rules added

□ Cloud Functions Deployed
  □ collaboration.ts compiled with no errors
  □ index.ts imports collaboration module
  □ Cloud Functions deployed to Firebase
  □ RevenueCat API key configured

□ Testing
  □ Menu item appears for owner
  □ Can open collaborators management
  □ Assigned listings tab shows for collaborator
  □ Profile shows collaboration section

```

---

## 7. Common Issues & Solutions

**Issue: Menu item doesn't appear**
```dart
// Make sure _canEditOrDelete is true
// This should be: currentUser.userID == listing.authorID || currentUser.isAdmin
```

**Issue: AssignedListingsScreen widget error**
```dart
// Make sure you imported it:
import 'package:instaflutter/listings/ui/collaboration/assigned_listings_screen.dart';
```

**Issue: TabController error**
```dart
// Make sure state class has TickerProviderStateMixin:
class _MyListingsScreenState extends State<MyListingsScreen> with TickerProviderStateMixin {
```

**Issue: CollaborationState not found**
```dart
// Import the model:
import 'package:instaflutter/listings/model/collaboration_model.dart';
```

**Issue: _collaborationApi.getCollaborationState() not found**
```dart
// Make sure you have the implementation:
import 'package:instaflutter/listings/listings_module/api/collaboration_firebase.dart';
final CollaborationFirebaseImpl _collaborationApi = CollaborationFirebaseImpl();
```

---

## Estimated Time

- Listing details: **2 minutes** (1 import + 1 menu item)
- My listings: **5 minutes** (1 import + refactor with tabs)
- Profile: **10 minutes** (1 import + section + 2 helpers)
- Testing: **5 minutes** (verify each feature)

**Total: 20-30 minutes**

