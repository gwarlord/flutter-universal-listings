import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/listings/model/brand_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/brand_service.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;

/// My Brands management screen for listers
class MyBrandsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const MyBrandsScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<MyBrandsScreen> createState() => _MyBrandsScreenState();
}

class _MyBrandsScreenState extends State<MyBrandsScreen> {
  final BrandService _brandService = BrandService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'My Brands/Branches'.tr(),
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Color(cfg.colorPrimary), size: 28),
            onPressed: () {
              _showCreateBrandDialog();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<BrandModel>>(
        stream: _brandService.getUserBrandsStream(widget.currentUser.userID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final brands = snapshot.data ?? [];

          if (brands.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 64,
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No brands yet'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a brand to organize your locations'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateBrandDialog(),
                    icon: const Icon(Icons.add),
                    label: Text('Create Brand'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(cfg.colorPrimary),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: brands.length,
            itemBuilder: (context, index) {
              final brand = brands[index];
              return _buildBrandCard(brand, dark);
            },
          );
        },
      ),
    );
  }

  Widget _buildBrandCard(BrandModel brand, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrandDetailScreen(
                brand: brand,
                currentUser: widget.currentUser,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo
              if (brand.logoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    brand.logoUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildLogoPlaceholder(dark);
                    },
                  ),
                )
              else
                _buildLogoPlaceholder(dark),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            brand.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (brand.isVerified)
                          Icon(
                            Icons.verified,
                            size: 18,
                            color: Color(cfg.colorPrimary),
                          ),
                      ],
                    ),
                    if (brand.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        brand.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(cfg.colorPrimary),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Manage Locations'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(cfg.colorPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: dark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(bool dark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Color(cfg.colorPrimary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.store,
        color: Color(cfg.colorPrimary),
        size: 40,
      ),
    );
  }

  void _showCreateBrandDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final dark = isDarkMode(context);
        return AlertDialog(
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Create New Brand'.tr(),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Brand Name *'.tr(),
                  labelStyle: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  hintText: 'e.g., KFC, Subway',
                  hintStyle: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)'.tr(),
                  labelStyle: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  hintText: 'Describe your brand',
                  hintStyle: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  showSnackBar(context, 'Brand name is required'.tr());
                  return;
                }

                try {
                  // Save reference to LoadingCubit BEFORE closing dialog
                  final loadingCubit = context.read<LoadingCubit>();
                  
                  Navigator.pop(context); // Close the create dialog first
                  
                  // Show loading overlay using saved reference
                  if (!mounted) return;
                  loadingCubit.showLoading(
                    context,
                    'Creating brand...'.tr(),
                    false,
                    Color(cfg.colorPrimary),
                  );

                  final brandId = await _brandService.createBrand(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty 
                        ? null 
                        : descriptionController.text.trim(),
                  ).timeout(
                    const Duration(seconds: 15),
                    onTimeout: () => throw Exception('Brand creation timed out. Cloud Function may not be deployed.'),
                  );

                  // Small delay to ensure loading is visible
                  await Future.delayed(const Duration(milliseconds: 500));

                  if (mounted) {
                    loadingCubit.hideLoading();
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) {
                      showSnackBar(context, 'Brand created successfully!'.tr());
                    }
                  }
                } catch (e) {
                  print('Error creating brand: $e');
                  if (mounted) {
                    try {
                      context.read<LoadingCubit>().hideLoading();
                    } catch (_) {
                      // Ignore if context is no longer valid
                    }
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) {
                      showSnackBar(context, 'Error: ${e.toString()}');
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(cfg.colorPrimary),
                foregroundColor: Colors.white,
              ),
              child: Text('Create'.tr()),
            ),
          ],
        );
      },
    );
  }
}

/// Brand Detail/Locations Management Screen
class BrandDetailScreen extends StatefulWidget {
  final BrandModel brand;
  final ListingsUser currentUser;

  const BrandDetailScreen({
    Key? key,
    required this.brand,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<BrandDetailScreen> createState() => _BrandDetailScreenState();
}

class _BrandDetailScreenState extends State<BrandDetailScreen> {
  final BrandService _brandService = BrandService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          widget.brand.name,
          style: TextStyle(
            color: dark ? Colors.white : Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: dark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: dark ? Colors.white : Colors.black),
            onPressed: () => _showEditBrandDialog(context, dark),
            tooltip: 'Edit Brand'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.all(16),
            color: dark ? Colors.grey.shade900 : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.brand.logoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.brand.logoUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Color(cfg.colorPrimary).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.store,
                                color: Color(cfg.colorPrimary),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.brand.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          if (widget.brand.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.brand.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Locations header with add button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: dark ? Colors.grey.shade900 : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(cfg.colorPrimary).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Color(cfg.colorPrimary),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Locations'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddListingDialog(context, dark),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Add'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(cfg.colorPrimary),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),

          // Locations section
          Expanded(
            child: StreamBuilder(
              stream: _brandService.getBrandLocationsStream(widget.brand.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final locations = snapshot.data ?? [];

                if (locations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 64,
                          color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No locations linked'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return _buildLocationTile(location, dark);
                  },
                );
              },
            ),
          ),

          // Delete brand button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            color: dark ? Colors.grey.shade900 : Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteBrandConfirmation(context, dark),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Delete Brand'.tr()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteBrandConfirmation(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Delete Brand?'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your brand will be deleted.'.tr(),
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your listings will be kept'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => _deleteBrand(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBrand(BuildContext context) async {
    try {
      final loadingCubit = context.read<LoadingCubit>();
      Navigator.pop(context); // Close confirmation dialog
      
      if (!mounted) return;
      loadingCubit.showLoading(
        context,
        'Deleting brand...'.tr(),
        false,
        Colors.red.shade700,
      );

      await _brandService.deleteBrand(
        brandId: widget.brand.id,
        unlinkListings: true, // Keep listings, just remove the brand link
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Brand deletion timed out. Cloud Function may be processing many listings.'),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        loadingCubit.hideLoading();
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          showSnackBar(context, 'Brand deleted successfully!'.tr());
          Navigator.pop(context); // Go back to brands list
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          context.read<LoadingCubit>().hideLoading();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          showSnackBar(context, 'Error: ${e.toString()}');
        }
      }
    }
  }

  void _showEditBrandDialog(BuildContext context, bool dark) {
    final nameController = TextEditingController(text: widget.brand.name);
    final descController = TextEditingController(text: widget.brand.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text('Edit Brand'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: 'Brand Name'.tr(),
                labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description'.tr(),
                labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final loadingCubit = context.read<LoadingCubit>();
                Navigator.pop(context);
                loadingCubit.showLoading(
                  context,
                  'Updating brand...'.tr(),
                  false,
                  Color(cfg.colorPrimary),
                );

                await _brandService.updateBrand(
                  brandId: widget.brand.id,
                  name: nameController.text.trim(),
                  description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                );

                if (mounted) {
                  loadingCubit.hideLoading();
                  showSnackBar(context, 'Brand updated successfully!'.tr());
                }
              } catch (e) {
                if (mounted) {
                  try {
                    context.read<LoadingCubit>().hideLoading();
                  } catch (_) {}
                  showSnackBar(context, 'Error: ${e.toString()}');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(cfg.colorPrimary)),
            child: Text('Update'.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddListingDialog(BuildContext context, bool dark) {
    showDialog(
      context: context,
      builder: (context) => _AddListingDialog(
        currentUser: widget.currentUser,
        brand: widget.brand,
        brandService: _brandService,
        isDark: dark,
      ),
    );
  }

  /// Dialog for selecting and adding listings to a brand
  Widget _AddListingDialog({
    required ListingsUser currentUser,
    required BrandModel brand,
    required BrandService brandService,
    required bool isDark,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return FutureBuilder<List<ListingModel>>(
          future: _getAvailableListings(currentUser.userID, brand.id),
          builder: (context, snapshot) {
            final dark = isDark;
            
            return AlertDialog(
              backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
              title: Text(
                'Add Listing'.tr(),
                style: TextStyle(color: dark ? Colors.white : Colors.black),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                        ? Center(
                            child: Text(
                              'Error loading listings'.tr(),
                              style: TextStyle(color: Colors.red),
                            ),
                          )
                        : snapshot.data?.isEmpty ?? true
                            ? Center(
                                child: Text(
                                  'No available listings to add'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final listing = snapshot.data![index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Color(cfg.colorPrimary).withOpacity(0.2),
                                      ),
                                      child: listing.photo != null && listing.photo!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                listing.photo!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    Icon(Icons.home, color: Color(cfg.colorPrimary)),
                                              ),
                                            )
                                          : Icon(Icons.home, color: Color(cfg.colorPrimary)),
                                    ),
                                    title: Text(
                                      listing.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: dark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    subtitle: Text(
                                      listing.place,
                                      style: TextStyle(
                                        color: dark ? Colors.white70 : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Icon(
                                      Icons.add_circle_outline,
                                      color: Color(cfg.colorPrimary),
                                    ),
                                    onTap: () => _handleAddListingToBrand(
                                      context,
                                      listing,
                                      isDark,
                                    ),
                                  );
                                },
                              ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Get listings available to add to the brand (not already linked)
  Future<List<ListingModel>> _getAvailableListings(
    String uid,
    String brandId,
  ) async {
    try {
      // Get user's listings
      final userListings = await _firestore
          .collection('listings')
          .where('authorID', isEqualTo: uid)
          .get();

      // Get already linked listings
      final brandListings = await _firestore
          .collection('listings')
          .where('brandId', isEqualTo: brandId)
          .get();

      final linkedIds = brandListings.docs.map((doc) => doc.id).toSet();

      // Filter out already linked listings
      return userListings.docs
          .where((doc) => !linkedIds.contains(doc.id))
          .map((doc) => ListingModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching available listings: $e');
      return [];
    }
  }

  /// Handle adding a listing to the brand
  Future<void> _handleAddListingToBrand(
    BuildContext context,
    ListingModel listing,
    bool isDark,
  ) async {
    try {
      final loadingCubit = context.read<LoadingCubit>();
      Navigator.pop(context);
      loadingCubit.showLoading(
        context,
        'Adding listing to brand...'.tr(),
        false,
        Color(cfg.colorPrimary),
      );

      // Add timeout to prevent indefinite hanging
      await _brandService.linkListingToBrand(
        listingId: listing.id,
        brandId: widget.brand.id,
        locationLabel: listing.place,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Request timed out. Please try again.'),
      );

      if (mounted) {
        loadingCubit.hideLoading();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showSnackBar(context, '${listing.title} added to brand!'.tr());
        }
      }
    } catch (e) {
      print('Error adding listing to brand: $e');
      if (mounted) {
        try {
          context.read<LoadingCubit>().hideLoading();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          showSnackBar(context, 'Error adding listing: ${e.toString()}');
        }
      }
    }
  }

  void _showEditLocationLabelDialog(BuildContext context, dynamic location, bool dark) {
    final labelController = TextEditingController(text: location.locationLabel ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(cfg.colorPrimary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_location_outlined,
                    color: Color(cfg.colorPrimary),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Location Label'.tr(),
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Customize how this location appears in the brand listing'.tr(),
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: labelController,
              autofocus: true,
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'e.g., KFC – Port of Spain',
                hintStyle: TextStyle(
                  color: dark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
                labelText: 'Location Label'.tr(),
                labelStyle: TextStyle(
                  color: dark ? Colors.white70 : Colors.black54,
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: Color(cfg.colorPrimary).withOpacity(0.6),
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(cfg.colorPrimary),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: dark ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final loadingCubit = context.read<LoadingCubit>();
                Navigator.pop(context);
                loadingCubit.showLoading(
                  context,
                  'Updating label...'.tr(),
                  false,
                  Color(cfg.colorPrimary),
                );

                await _brandService.linkListingToBrand(
                  listingId: location.id,
                  brandId: widget.brand.id,
                  locationLabel: labelController.text.trim().isEmpty ? null : labelController.text.trim(),
                );

                if (mounted) {
                  loadingCubit.hideLoading();
                  showSnackBar(context, 'Location label updated!'.tr());
                }
              } catch (e) {
                if (mounted) {
                  try {
                    context.read<LoadingCubit>().hideLoading();
                  } catch (_) {}
                  showSnackBar(context, 'Error: ${e.toString()}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnlinkConfirmation(BuildContext context, dynamic location) {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.link_off_outlined,
                color: Colors.red.shade600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Unlink Location?'.tr(),
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The listing will be removed from this brand.'.tr(),
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The listing will not be deleted'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Keep Linked'.tr(),
              style: TextStyle(
                color: dark ? Colors.white70 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final loadingCubit = context.read<LoadingCubit>();
                Navigator.pop(context);
                loadingCubit.showLoading(
                  context,
                  'Unlinking location...'.tr(),
                  false,
                  Colors.red.shade700,
                );

                await _brandService.unlinkListingFromBrand(location.id);

                if (mounted) {
                  loadingCubit.hideLoading();
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (mounted) {
                    showSnackBar(context, 'Location unlinked!'.tr());
                  }
                }
              } catch (e) {
                if (mounted) {
                  try {
                    context.read<LoadingCubit>().hideLoading();
                  } catch (_) {}
                  showSnackBar(context, 'Error: ${e.toString()}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Unlink'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(dynamic location, bool dark) {
    // location should be a ListingModel
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: dark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : Colors.black).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Location icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(cfg.colorPrimary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: Color(cfg.colorPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                // Location info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.locationLabel ?? location.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: dark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.place,
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Actions menu
                PopupMenuButton<String>(
                  enabled: true,
                  color: dark ? Colors.grey.shade900 : Colors.white,
                  offset: const Offset(-90, 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditLocationLabelDialog(context, location, dark);
                    } else if (value == 'unlink') {
                      _showUnlinkConfirmation(context, location);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem(
                      value: 'edit',
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: Color(cfg.colorPrimary)),
                          const SizedBox(width: 12),
                          Text(
                            'Edit Label'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'unlink',
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_off_outlined,
                            size: 20,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Unlink'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (dark ? Colors.grey.shade800 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
