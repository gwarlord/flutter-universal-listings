# Admin Features - Brand Management Guide

Complete guide for implementing admin controls for brand verification and freshness exemption.

## Overview

Admins can:
1. **Verify Brands** - Mark important brands as verified (shows badge to customers)
2. **Exempt from Freshness** - Keep all locations of a brand visible indefinitely
3. **Manage Brand Ownership** - Transfer brands between users
4. **View Brand Analytics** - See which brands have most locations, which are exempt, etc.

## Part 1: Add Admin Brand List in Admin Dashboard

Create a new admin screen to manage brands:

```dart
class AdminBrandsManagementScreen extends StatefulWidget {
  const AdminBrandsManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminBrandsManagementScreen> createState() => 
    _AdminBrandsManagementScreenState();
}

class _AdminBrandsManagementScreenState 
    extends State<AdminBrandsManagementScreen> {
  final _brandService = BrandService();
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('brands').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No brands found'));
          }

          final brands = snapshot.data!.docs
              .map((doc) => BrandModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              return _BrandAdminTile(
                brand: brand,
                onVerificationToggled: (verified) => 
                  _updateBrandVerification(brand.id, verified),
                onFreshnessToggled: (exempt) => 
                  _updateBrandFreshness(brand.id, exempt),
                onTap: () => _showBrandDetailsDialog(context, brand),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateBrandVerification(String brandId, bool verified) async {
    try {
      await _brandService.updateBrand(
        brandId: brandId,
        isVerified: verified,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(verified ? 'Brand verified' : 'Brand verification removed'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateBrandFreshness(String brandId, bool exempt) async {
    try {
      await _brandService.updateBrand(
        brandId: brandId,
        freshnessExempt: exempt,
      );
      
      // Get brand to show location count
      final brand = await _brandService.getBrand(brandId);
      final locations = await _brandService.getBrandLocations(brandId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              exempt 
                ? 'Brand "${brand!.name}" and ${locations.length} locations now exempt'
                : 'Brand "${brand!.name}" freshness exemption removed'
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBrandDetailsDialog(BuildContext context, BrandModel brand) {
    showDialog(
      context: context,
      builder: (context) => _BrandDetailsDialog(brand: brand),
    );
  }
}

class _BrandAdminTile extends StatelessWidget {
  final BrandModel brand;
  final Function(bool) onVerificationToggled;
  final Function(bool) onFreshnessToggled;
  final VoidCallback onTap;

  const _BrandAdminTile({
    required this.brand,
    required this.onVerificationToggled,
    required this.onFreshnessToggled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: brand.logoUrl != null
            ? CircleAvatar(
                backgroundImage: NetworkImage(brand.logoUrl!),
                backgroundColor: Colors.grey[300],
              )
            : const CircleAvatar(child: Icon(Icons.store)),
        title: Text(brand.name),
        subtitle: Text(
          brand.description ?? 'No description',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (brand.isVerified)
              const Tooltip(
                message: 'Verified Brand',
                child: Icon(Icons.verified, color: Colors.blue),
              ),
            if (brand.freshnessExempt)
              const Tooltip(
                message: 'Freshness Exempt',
                child: Icon(Icons.shield, color: Colors.green),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Verified brands are featured and trusted',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: brand.isVerified,
                      onChanged: onVerificationToggled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Freshness Exemption',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Exempt locations never auto-hide due to age',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: brand.freshnessExempt,
                      onChanged: onFreshnessToggled,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandDetailsDialog extends StatelessWidget {
  final BrandModel brand;
  final _brandService = BrandService();

  _BrandDetailsDialog({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (brand.logoUrl != null)
                    Image.network(
                      brand.logoUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.store),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (brand.isVerified)
                          const Row(
                            children: [
                              Icon(Icons.verified, size: 16, color: Colors.blue),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (brand.description != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(brand.description!),
                    const SizedBox(height: 16),
                  ],
                ),
              _OwnerInfo(brand: brand),
              const SizedBox(height: 16),
              _LocationsList(brandId: brand.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerInfo extends StatefulWidget {
  final BrandModel brand;

  const _OwnerInfo({required this.brand});

  @override
  State<_OwnerInfo> createState() => _OwnerInfoState();
}

class _OwnerInfoState extends State<_OwnerInfo> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Owner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(widget.brand.ownerUid).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final user = snapshot.data!.data() as Map<String, dynamic>;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? widget.brand.ownerUid),
                  Text(
                    user['email'] ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Change Owner'),
                    onPressed: () => _showChangeOwnerDialog(context),
                  ),
                ],
              );
            }
            return Text(widget.brand.ownerUid);
          },
        ),
      ],
    );
  }

  void _showChangeOwnerDialog(BuildContext context) {
    // Implementation for changing brand owner
    // This would require a callable function: changeChannelOwner
    // For now, just show a message that this requires custom setup
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Owner'),
        content: const Text(
          'To change the brand owner, you need to create a Cloud Function callable.\n\n'
          'For now, admins can contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LocationsList extends StatelessWidget {
  final String brandId;
  final _brandService = BrandService();

  _LocationsList({required this.brandId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Linked Locations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<ListingModel>>(
          future: _brandService.getBrandLocations(brandId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 50,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('No locations linked');
            }

            final locations = snapshot.data!;
            return Column(
              children: locations.take(5).map((location) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${location.title ?? "Listing"} - ${location.location?.area ?? ""}',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
              if (locations.length > 5)
                Text(
                  '+ ${locations.length - 5} more',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            );
          },
        ),
      ],
    );
  }
}
```

## Part 2: Add to Existing Admin Menu

Add a link in your main admin dashboard:

```dart
class AdminDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Brand Management'),
            subtitle: const Text('Verify brands, manage freshness'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminBrandsManagementScreen(),
              ),
            ),
          ),
          // ... other admin options
        ],
      ),
    );
  }
}
```

## Part 3: Advanced - Cloud Function for Ownership Transfer

If you want admins to transfer brand ownership, add this Cloud Function:

```typescript
// Firebase Cloud Function (TypeScript)
export const changeBrandOwner = functions.https.onCall(async (data, context) => {
  // Only admins can change ownership
  const adminDoc = await admin.firestore()
    .collection('admin_users')
    .doc(context.auth!.uid)
    .get();

  if (!adminDoc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can change brand ownership'
    );
  }

  const { brandId, newOwnerUid } = data;

  if (!brandId || !newOwnerUid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'brandId and newOwnerUid required'
    );
  }

  // Verify new owner exists
  const newOwner = await admin.firestore()
    .collection('users')
    .doc(newOwnerUid)
    .get();

  if (!newOwner.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'New owner user not found'
    );
  }

  // Update brand ownership
  await admin.firestore()
    .collection('brands')
    .doc(brandId)
    .update({
      ownerUid: newOwnerUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return {
    success: true,
    message: `Brand ownership transferred to ${newOwner.data()?.name}`,
  };
});
```

Then in your Flutter admin panel:

```dart
Future<void> _changeOwner(BuildContext context, String brandId) async {
  final userService = UserService(); // Your user service
  final users = await userService.getAllUsers(); // Get all users

  if (!context.mounted) return;

  final selectedUser = await showDialog<UserModel>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Select New Owner'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: users
              .where((u) => u.role == 'lister') // Only listers can own brands
              .map((user) => ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                onTap: () => Navigator.pop(context, user),
              ))
              .toList(),
        ),
      ),
    ),
  );

  if (selectedUser == null) return;

  try {
    await FirebaseFunctions.instance
        .httpsCallable('changeBrandOwner')
        .call({
      'brandId': brandId,
      'newOwnerUid': selectedUser.id,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Owner changed to ${selectedUser.name}'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Part 4: Analytics Dashboard

Optional: Add brand analytics to admin dashboard:

```dart
class BrandAnalyticsScreen extends StatelessWidget {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brand Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsCard(
            title: 'Total Brands',
            value: _getCount('brands'),
          ),
          _StatsCard(
            title: 'Verified Brands',
            value: _getCount('brands', where: {'isVerified': true}),
          ),
          _StatsCard(
            title: 'Freshness Exempt',
            value: _getCount('brands', where: {'freshnessExempt': true}),
          ),
          _StatsCard(
            title: 'Total Locations',
            value: _getCount('listings', where: {'brandId': FieldValue.gt('')}),
          ),
          const SizedBox(height: 24),
          const Text(
            'Top Brands by Locations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _TopBrandsList(),
        ],
      ),
    );
  }

  Future<int> _getCount(String collection, {Map<String, dynamic>? where}) async {
    // Implementation
    return 0;
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final Future<int> value;

  const _StatsCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            FutureBuilder<int>(
              future: value,
              builder: (context, snapshot) {
                return Text(
                  snapshot.hasData ? '${snapshot.data}' : '–',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

## Part 5: Search and Filter

Add filtering to brand list:

```dart
class AdminBrandsManagementScreen extends StatefulWidget {
  const AdminBrandsManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminBrandsManagementScreen> createState() => 
    _AdminBrandsManagementScreenState();
}

class _AdminBrandsManagementScreenState 
    extends State<AdminBrandsManagementScreen> {
  String _searchQuery = '';
  bool _showVerifiedOnly = false;
  bool _showExemptOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brand Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SearchBar(
              hintText: 'Search brands...',
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Verified'),
                  selected: _showVerifiedOnly,
                  onSelected: (value) => 
                    setState(() => _showVerifiedOnly = value),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Freshness Exempt'),
                  selected: _showExemptOnly,
                  onSelected: (value) => 
                    setState(() => _showExemptOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: _BrandsList(
              searchQuery: _searchQuery,
              verifiedOnly: _showVerifiedOnly,
              exemptOnly: _showExemptOnly,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandsList extends StatelessWidget {
  final String searchQuery;
  final bool verifiedOnly;
  final bool exemptOnly;

  const _BrandsList({
    required this.searchQuery,
    required this.verifiedOnly,
    required this.exemptOnly,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('brands').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var brands = snapshot.data!.docs
            .map((doc) => BrandModel.fromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList();

        // Apply filters
        if (searchQuery.isNotEmpty) {
          brands = brands
              .where((b) => b.name.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();
        }

        if (verifiedOnly) {
          brands = brands.where((b) => b.isVerified).toList();
        }

        if (exemptOnly) {
          brands = brands.where((b) => b.freshnessExempt).toList();
        }

        return ListView.builder(
          itemCount: brands.length,
          itemBuilder: (context, index) {
            return _BrandAdminTile(
              brand: brands[index],
              onVerificationToggled: (verified) {},
              onFreshnessToggled: (exempt) {},
              onTap: () {},
            );
          },
        );
      },
    );
  }
}
```

## Testing Admin Features

- [ ] Verify a brand - check for badge in customer UI
- [ ] Toggle freshness exemption - verify old listings stay visible
- [ ] View brand details with location count
- [ ] Transfer brand ownership (if implemented)
- [ ] Search and filter brands
- [ ] View analytics dashboard
- [ ] Test permissions - non-admin cannot access this screen

