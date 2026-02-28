import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Optional verification checklist for refreshing listings
/// Encourages (but doesn't require) listers to verify accuracy
class ListingRefreshDialog extends StatefulWidget {
  final ListingModel listing;
  final bool requireVerification;

  const ListingRefreshDialog({
    Key? key,
    required this.listing,
    this.requireVerification = false,
  }) : super(key: key);

  @override
  State<ListingRefreshDialog> createState() => _ListingRefreshDialogState();
}

class _ListingRefreshDialogState extends State<ListingRefreshDialog> {
  bool _priceVerified = false;
  bool _availabilityVerified = false;
  bool _contactVerified = false;
  bool _photosVerified = false;
  bool _detailsVerified = false;
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final allVerified = _priceVerified &&
        _availabilityVerified &&
        _contactVerified &&
        _photosVerified &&
        _detailsVerified;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.refresh, color: Colors.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Refresh Listing',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.listing.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.requireVerification)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Please verify your listing information is current',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_outlined, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Optional: Verifying helps keep your listing accurate',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Verify the following information:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildCheckItem(
              'Price is still accurate',
              _priceVerified,
              (val) => setState(() => _priceVerified = val ?? false),
              Icons.attach_money,
            ),
            _buildCheckItem(
              'Availability is current',
              _availabilityVerified,
              (val) => setState(() => _availabilityVerified = val ?? false),
              Icons.calendar_today,
            ),
            _buildCheckItem(
              'Contact info is correct',
              _contactVerified,
              (val) => setState(() => _contactVerified = val ?? false),
              Icons.contact_phone,
            ),
            _buildCheckItem(
              'Photos are up to date',
              _photosVerified,
              (val) => setState(() => _photosVerified = val ?? false),
              Icons.photo_camera,
            ),
            _buildCheckItem(
              'Details and description are accurate',
              _detailsVerified,
              (val) => setState(() => _detailsVerified = val ?? false),
              Icons.description,
            ),
            const SizedBox(height: 16),
            if (!widget.requireVerification && !allVerified)
              Text(
                'You can refresh without verification, but we recommend checking these items.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _refreshing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (!widget.requireVerification)
          TextButton(
            onPressed: _refreshing ? null : () => _refreshListing(false),
            child: const Text('Skip & Refresh'),
          ),
        ElevatedButton(
          onPressed: _refreshing
              ? null
              : (widget.requireVerification && !allVerified)
                  ? null
                  : () => _refreshListing(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(allVerified ? 'Verified & Refresh' : 'Refresh'),
        ),
      ],
    );
  }

  Widget _buildCheckItem(
    String label,
    bool checked,
    Function(bool?) onChanged,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: onChanged,
          ),
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: checked ? Colors.black87 : Colors.grey[700],
                fontWeight: checked ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshListing(bool verified) async {
    setState(() => _refreshing = true);

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('refreshListingFreshness').call({
        'listingId': widget.listing.id,
        'verified': verified,
        'verificationChecklist': verified
            ? {
                'price': _priceVerified,
                'availability': _availabilityVerified,
                'contact': _contactVerified,
                'photos': _photosVerified,
                'details': _detailsVerified,
              }
            : null,
      });

      if (!mounted) return;
      
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  verified
                      ? 'Listing refreshed and verified successfully!'
                      : 'Listing refreshed successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _refreshing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Simple refresh confirmation dialog (quick alternative)
class QuickRefreshDialog extends StatelessWidget {
  final ListingModel listing;

  const QuickRefreshDialog({
    Key? key,
    required this.listing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final freshness = listing.freshness;
    final daysRemaining = freshness?.daysRemaining ?? 0;

    return AlertDialog(
      title: const Text('Refresh Listing?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (daysRemaining > 0) ...[
            Text('Current freshness: $daysRemaining days remaining'),
            const SizedBox(height: 8),
          ],
          Text(
            'This will reset your listing freshness to ${freshness?.days ?? 90} days.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}

/// Bulk refresh confirmation dialog
class BulkRefreshDialog extends StatefulWidget {
  final List<ListingModel> listings;
  final bool showVerification;

  const BulkRefreshDialog({
    Key? key,
    required this.listings,
    this.showVerification = false,
  }) : super(key: key);

  @override
  State<BulkRefreshDialog> createState() => _BulkRefreshDialogState();
}

class _BulkRefreshDialogState extends State<BulkRefreshDialog> {
  bool _verified = false;
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Refresh ${widget.listings.length} Listings?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will refresh freshness for ${widget.listings.length} listings:',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.listings.length,
              itemBuilder: (context, index) {
                final listing = widget.listings[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          listing.title,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.showVerification) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _verified,
              onChanged: (val) => setState(() => _verified = val ?? false),
              title: const Text(
                'I confirm all listing information is current',
                style: TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _refreshing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _refreshing
              ? null
              : (widget.showVerification && !_verified)
                  ? null
                  : () => _performBulkRefresh(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Refresh All'),
        ),
      ],
    );
  }

  Future<void> _performBulkRefresh() async {
    setState(() => _refreshing = true);

    try {
      final functions = FirebaseFunctions.instance;
      final listingIds = widget.listings.map((l) => l.id).toList();

      await functions.httpsCallable('bulkRefreshListings').call({
        'listingIds': listingIds,
        'verified': _verified,
      });

      if (!mounted) return;
      
      Navigator.pop(context, true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${widget.listings.length} listings refreshed successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _refreshing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
