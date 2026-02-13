import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assigned Listings'),
        elevation: 0,
      ),
      body: StreamBuilder<List<AssignedListingModel>>(
        stream: assignedListingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_center_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Assigned Listings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have not been added as a collaborator to any listings',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.store, color: Colors.blue[700]),
        ),
        title: Text(
          listing.listingId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                        style: const TextStyle(fontSize: 10),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            if (listing.permissionsSummary.length > 3)
              Text(
                '+${listing.permissionsSummary.length - 3} more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
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
