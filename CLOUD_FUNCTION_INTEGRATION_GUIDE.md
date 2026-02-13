# Creating Brands & Linking Listings - UI Integration Guide

Step-by-step guide for integrating brand creation and listing linking into your Flutter app UI.

## Prerequisites

Ensure these are installed in `pubspec.yaml`:

```yaml
firebase_auth: ^4.0.0
cloud_firestore: ^4.0.0
cloud_functions: ^4.0.0
```

## Part 1: Wire Create Brand Dialog to Cloud Function

The `MyBrandsScreen` includes a create brand dialog. Here's how to connect it to the cloud function:

### in `lib/screens/brand/my_brands_screen.dart`

Find the `_showCreateBrandDialog()` method and update it:

```dart
void _showCreateBrandDialog(BuildContext context) {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isLoading = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Create New Brand'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Brand name',
                  labelText: 'Brand Name *',
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  hintText: 'Brand description',
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: !isLoading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () => _createBrand(
                      context: dialogContext,
                      name: nameController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      onSuccess: (brandId) {
                        Navigator.pop(dialogContext);
                        _refreshBrands();
                        // Show success snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Brand "$nameController.text" created'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onLoading: (loading) {
                        setState(() => isLoading = loading);
                      },
                    ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _createBrand({
  required BuildContext context,
  required String name,
  required String? description,
  required Function(String) onSuccess,
  required Function(bool) onLoading,
}) async {
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Brand name is required')),
    );
    return;
  }

  onLoading(true);
  try {
    final brandId = await _brandService.createBrand(
      name: name,
      logoUrl: null, // Can be added later via brand editing
      description: description,
    );
    
    onSuccess(brandId);
  } catch (e) {
    onLoading(false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create brand: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Part 2: Link Listings to Brand - Add in Listing Detail/Edit

When a lister wants to link a listing to a brand, add this feature in the listing edit or detail screen:

### Create a Brand Selector Dialog

```dart
Future<void> showBrandSelectorDialog({
  required BuildContext context,
  required String currentUserId,
  required ListingModel listing,
  required VoidCallback onBrandLinked,
}) async {
  final brandService = BrandService();
  
  // Fetch user's brands
  final userBrands = await brandService.getUserBrands(currentUserId);
  
  if (!context.mounted) return;
  
  if (userBrands.isEmpty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Brands'),
        content: const Text(
          'You haven\'t created any brands yet. Create a brand first in the "My Brands" section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Select Brand'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: userBrands.map((brand) {
            return ListTile(
              title: Text(brand.name),
              subtitle: Text(brand.description ?? ''),
              onTap: () => _linkListingToBrand(
                context: dialogContext,
                listing: listing,
                brand: brand,
                onSuccess: onBrandLinked,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

Future<void> _linkListingToBrand({
  required BuildContext context,
  required ListingModel listing,
  required BrandModel brand,
  required VoidCallback onSuccess,
}) async {
  final brandService = BrandService();
  
  try {
    // Optional: show custom location label dialog
    String? locationLabel;
    
    if (context.mounted) {
      locationLabel = await showDialog<String>(
        context: context,
        builder: (context) => _LocationLabelDialog(
          brandName: brand.name,
          currentLocation: listing.location?.address ?? '',
        ),
      );
    }

    await brandService.linkListingToBrand(
      listingId: listing.id,
      brandId: brand.id,
      locationLabel: locationLabel,
    );

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Listing linked to "${brand.name}"',
          ),
        ),
      );
      onSuccess();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link listing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Location Label Dialog

```dart
class _LocationLabelDialog extends StatefulWidget {
  final String brandName;
  final String currentLocation;

  const _LocationLabelDialog({
    required this.brandName,
    required this.currentLocation,
  });

  @override
  State<_LocationLabelDialog> createState() => _LocationLabelDialogState();
}

class _LocationLabelDialogState extends State<_LocationLabelDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: '${widget.brandName} – ${widget.currentLocation}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Display Name'),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'e.g., Subway – Port of Spain',
          labelText: 'Display Name (optional)',
          border: OutlineInputBorder(),
        ),
        maxLines: 1,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Set'),
        ),
      ],
    );
  }
}
```

## Part 3: Unlink Listing from Brand

Add an "Unlink from Brand" button in listing detail or edit screen:

```dart
Future<void> unlinkListingFromBrand({
  required BuildContext context,
  required ListingModel listing,
  required VoidCallback onSuccess,
}) async {
  // Confirm with user
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unlink from Brand'),
      content: Text(
        'Are you sure you want to remove this listing from its brand? '
        'It will no longer appear in the brand\'s location list.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Unlink'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final brandService = BrandService();
  try {
    await brandService.unlinkListingFromBrand(listing.id);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing unlinked from brand')),
      );
      onSuccess();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlink: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Part 4: Delete Brand

Add a "Delete Brand" option in `BrandDetailScreen`:

```dart
Future<void> deleteBrand({
  required BuildContext context,
  required BrandModel brand,
  required VoidCallback onDeleted,
}) async {
  // Count linked listings
  final brandService = BrandService();
  final locations = await brandService.getBrandLocations(brand.id);
  
  // Confirm deletion
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Brand'),
      content: Text(
        'Are you sure you want to delete "${brand.name}"?\n\n'
        'This brand has ${locations.length} linked location(s).\n\n'
        'You can choose to keep the listings linked or unlink them all.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  // Ask about unlinking
  if (locations.isNotEmpty && context.mounted) {
    final unlinkAll = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Listings'),
        content: const Text(
          'Do you want to unlink all listings from this brand?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Linked'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink All'),
          ),
        ],
      ),
    ) ?? false;

    if (context.mounted) {
      _performDeleteBrand(
        context,
        brand.id,
        unlinkAll,
        onDeleted,
      );
    }
  } else if (context.mounted) {
    _performDeleteBrand(context, brand.id, false, onDeleted);
  }
}

Future<void> _performDeleteBrand(
  BuildContext context,
  String brandId,
  bool unlinkListings,
  VoidCallback onDeleted,
) async {
  final brandService = BrandService();
  try {
    await brandService.deleteBrand(
      brandId: brandId,
      unlinkListings: unlinkListings,
    );

    if (context.mounted) {
      Navigator.pop(context); // Close detail screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand deleted')),
      );
      onDeleted();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete brand: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Part 5: Unlink from Brand in MyBrandsScreen

Update `BrandDetailScreen` to show an "Unlink" button for each location:

In `my_brands_screen.dart`, find the location tiles in `BrandDetailScreen` and add this:

```dart
ListTile(
  title: Text(location.title ?? 'Listing'),
  subtitle: Text(location.location?.address ?? ''),
  trailing: PopupMenuButton<String>(
    onSelected: (action) {
      if (action == 'unlink') {
        _confirmUnlinkListing(context, location);
      }
    },
    itemBuilder: (BuildContext context) => [
      const PopupMenuItem(
        value: 'unlink',
        child: Text('Unlink from Brand'),
      ),
    ],
  ),
  onTap: () {
    // Navigate to listing detail
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(
          listing: location,
        ),
      ),
    );
  },
)

Future<void> _confirmUnlinkListing(
  BuildContext context,
  ListingModel location,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unlink Listing'),
      content: Text(
        'Remove "${location.title}" from this brand?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Unlink'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  final brandService = BrandService();
  try {
    await brandService.unlinkListingFromBrand(location.id);
    
    if (context.mounted) {
      setState(() {
        // Refresh brand details
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing unlinked')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlink: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Integrating with Existing Listing Edit Screen

If you have an existing listing edit/detail screen, add brand management:

```dart
class ListingEditScreen extends StatefulWidget {
  final ListingModel listing;

  const ListingEditScreen({required this.listing});

  @override
  State<ListingEditScreen> createState() => _ListingEditScreenState();
}

class _ListingEditScreenState extends State<ListingEditScreen> {
  late ListingModel _currentListing;
  final _brandService = BrandService();

  @override
  void initState() {
    super.initState();
    _currentListing = widget.listing;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... existing listing fields ...
            
            // Brand Management Section
            if (_currentListing.brandId?.isNotEmpty ?? false)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brand Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<BrandModel?>(
                        future: _brandService.getBrand(_currentListing.brandId!),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Part of: ${snapshot.data!.name}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (_currentListing.locationLabel != null)
                                  Text(
                                    'Display Name: ${_currentListing.locationLabel}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.link_off),
                                  label: const Text('Unlink from Brand'),
                                  onPressed: () => _unlinkFromBrand(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brand Management',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Link this listing to one of your brands to group locations together.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.link),
                        label: const Text('Link to Brand'),
                        onPressed: () => showBrandSelectorDialog(
                          context: context,
                          currentUserId: _auth.currentUser!.uid,
                          listing: _currentListing,
                          onBrandLinked: () {
                            setState(() {
                              // Refresh current listing
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlinkFromBrand(BuildContext context) async {
    // Use the unlinkListingFromBrand function from Part 3
    await unlinkListingFromBrand(
      context: context,
      listing: _currentListing,
      onSuccess: () {
        setState(() {
          _currentListing = _currentListing.copyWith(brandId: null);
        });
      },
    );
  }
}
```

## Error Handling Best Practices

All cloud function calls throw exceptions. Handle them gracefully:

```dart
try {
  await _brandService.createBrand(
    name: brandName,
    description: description,
  );
} on FirebaseFunctionsException catch (e) {
  // Backend validation failed
  print('Code: ${e.code}');
  print('Message: ${e.message}');
  // e.code could be: 'already-exists', 'permission-denied', 'invalid-argument'
} catch (e) {
  // Network or other error
  print('Error: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

## Testing Checklist

- [ ] Create a new brand via dialog
- [ ] Link a listing to that brand
- [ ] View linked listings in MyBrandsScreen
- [ ] See linked listing in BrandLocationsScreen
- [ ] See "More Locations" on listing detail
- [ ] Unlink a listing from brand
- [ ] Delete a brand (with unlinking)
- [ ] Try to create brand with empty name (should fail)
- [ ] Try to link non-owned listing (should fail)
- [ ] Test with multiple brands simultaneously

