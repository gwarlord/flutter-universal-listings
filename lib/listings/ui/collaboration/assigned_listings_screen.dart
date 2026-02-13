import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:instaflutter/listings/model/collaboration_model.dart';

class AssignedListingsScreen extends StatefulWidget {
  final String userId;
  final Function(String listingId) onListingSelected;

  const AssignedListingsScreen({
    Key? key,
    required this.userId,
    required this.onListingSelected,
  }) : super(key: key);

  @override
  State<AssignedListingsScreen> createState() => _AssignedListingsScreenState();
}

class _AssignedListingsScreenState extends State<AssignedListingsScreen> {
  late Stream<List<AssignedListingModel>> assignedListingsStream;

  @override
  void initState() {
    super.initState();
    assignedListingsStream = collaborationApiManager.streamAssignedListings(
      userId: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return Scaffold(
      backgroundColor: dark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Assigned Listings'),
        elevation: 0,
        backgroundColor: dark ? Colors.grey[850] : null,
        foregroundColor: dark ? Colors.white : null,
      ),
      body: StreamBuilder<List<AssignedListingModel>>(
        stream: assignedListingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: dark ? Colors.red[300] : Colors.red),
              ),
            );
          }

          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      size: 64,
                      color: dark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Assigned Listings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: dark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have not been added as a collaborator to any listings',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: dark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return AssignedListingTile(
                listing: listing,
                onTap: () => widget.onListingSelected(listing.listingId),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    collaborationApiManager.dispose();
    super.dispose();
  }
}

// ============================================================================
// ASSIGNED LISTING TILE
// ============================================================================

class AssignedListingTile extends StatelessWidget {
  final AssignedListingModel listing;
  final VoidCallback onTap;

  const AssignedListingTile({
    Key? key,
    required this.listing,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Theme.of(context).primaryColor;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: dark ? Colors.grey[850] : Colors.white,
      elevation: dark ? 2 : 1,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: dark ? primaryColor.withOpacity(0.2) : Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.store,
            color: dark ? primaryColor : Colors.blue[700],
          ),
        ),
        title: Text(
          listing.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: dark ? Colors.white : Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: listing.permissionsSummary
                  .take(3)
                  .map(
                    (p) => Chip(
                      label: Text(
                        _permissionLabel(p),
                        style: TextStyle(
                          fontSize: 10,
                          color: dark ? Colors.white : Colors.black87,
                        ),
                      ),
                      backgroundColor: dark ? Colors.grey[700] : Colors.grey[200],
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            if (listing.permissionsSummary.length > 3)
              Text(
                '+${listing.permissionsSummary.length - 3} more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: dark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: dark ? Colors.grey[400] : Colors.grey[600],
        ),
        onTap: onTap,
      ),
    );
  }

  String _permissionLabel(String permission) {
    final labels = {
      'manageOrders': 'Orders',
      'manageBookings': 'Bookings',
      'manageRentals': 'Rentals',
      'manageChats': 'Chats',
      'editListing': 'Edit',
      'changeOrderStatus': 'Status',
      'changeFulfillment': 'Fulfillment',
    };
    return labels[permission] ?? permission;
  }
}
