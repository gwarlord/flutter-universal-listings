import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/rental_catalog_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/rental_catalog_service.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/utils/category_localization.dart';
import 'package:caribtap/screens/rentals/rental_item_editor_screen.dart';

/// Rental Catalog Manager Screen - Premium Only
/// Allows listing owners to manage their rental inventory
class RentalCatalogManagerScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const RentalCatalogManagerScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<RentalCatalogManagerScreen> createState() =>
      _RentalCatalogManagerScreenState();
}

class _RentalCatalogManagerScreenState
    extends State<RentalCatalogManagerScreen> {
  final RentalCatalogService _rentalService = RentalCatalogService();
  final EntitlementService _entitlementService = EntitlementService();
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();

    // CRITICAL: Verify Premium access
    _ensurePremiumAccess();
  }

  Future<void> _ensurePremiumAccess() async {
    final entitlement =
        await _entitlementService.fetchEntitlement(widget.currentUser.userID);
    final hasAccess = ProGate.tierAtLeast(
      entitlement,
      2,
      isAdmin: widget.currentUser.isAdmin,
    );

    if (!hasAccess && mounted) {
      showSnackBar(context, '🔒 Premium subscription required');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Manage Rental Catalog'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewItem,
            tooltip: 'Add Rental Item'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          StreamBuilder<List<RentalCatalogItem>>(
            stream: _rentalService.getRentalCatalogItems(widget.listing.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final categories = <String>{'All'};
              for (final item in items) {
                if (item.category.isNotEmpty) {
                  categories.add(item.category);
                }
              }
              final categoryList = categories.toList();

              return Container(
                height: 50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryList.length,
                  itemBuilder: (context, index) {
                    final category = categoryList[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(localizeCategoryLabel(category, context)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedCategory = category);
                          }
                        },
                        selectedColor: Color(cfg.colorPrimary),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (dark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Rental items list
          Expanded(
            child: StreamBuilder<List<RentalCatalogItem>>(
              stream: _rentalService.getRentalCatalogItems(widget.listing.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rental items yet'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            color: dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first rental item'.tr(),
                          style: TextStyle(
                            color: dark
                                ? Colors.grey.shade500
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var items = snapshot.data!;

                // Filter by category
                if (_selectedCategory != 'All') {
                  items = items
                      .where((item) => item.category == _selectedCategory)
                      .toList();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildItemCard(items[index], dark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(RentalCatalogItem item, bool dark) {
    final cardColor = dark ? Colors.grey.shade900 : Colors.grey.shade50;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Item image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.photos.isNotEmpty
                    ? Image.network(
                        item.photos.first,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      )
                    : _placeholderImage(),
              ),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: dark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (item.category.isNotEmpty)
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$${item.basePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(cfg.colorPrimary),
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          ' / ${item.pricingUnit.toString().split('.').last}',
                          style: TextStyle(
                            fontSize: 12,
                            color: dark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        if (item.stockQty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.isAvailable
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.isAvailable
                                  ? 'Available (${item.stockQty})'
                                  : 'Unavailable',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: dark ? Colors.white70 : Colors.black54),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editItem(item);
                  } else if (value == 'delete') {
                    _deleteItem(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20),
                        const SizedBox(width: 8),
                        Text('Edit'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Delete'.tr(),
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade300,
      ),
      child: const Icon(Icons.image, size: 40, color: Colors.white),
    );
  }

  void _addNewItem() {
    push(
      context,
      RentalItemEditorScreen(
        listing: widget.listing,
        currentUser: widget.currentUser,
      ),
    );
  }

  void _editItem(RentalCatalogItem item) {
    push(
      context,
      RentalItemEditorScreen(
        listing: widget.listing,
        currentUser: widget.currentUser,
        item: item,
      ),
    );
  }

  void _deleteItem(RentalCatalogItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item'.tr()),
        content: Text('Are you sure you want to delete "${item.name}"?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _rentalService.deleteRentalItem(widget.listing.id, item.id);
        if (mounted) {
          showSnackBar(context, 'Item deleted successfully'.tr());
        }
      } catch (e) {
        if (mounted) {
          showSnackBar(context, 'Error deleting item: ${e.toString()}');
        }
      }
    }
  }
}
