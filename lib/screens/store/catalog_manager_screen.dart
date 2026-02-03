import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/catalog_item.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/store_service.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
import 'package:instaflutter/screens/store/catalog_item_editor_screen.dart';

/// Catalog Manager Screen - Premium Only
/// Allows listing owners to manage their Mini Store catalog
class CatalogManagerScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const CatalogManagerScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CatalogManagerScreen> createState() => _CatalogManagerScreenState();
}

class _CatalogManagerScreenState extends State<CatalogManagerScreen> {
  final StoreService _storeService = StoreService();
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Food & Drink', 'Products', 'Services', 'Other'];

  @override
  void initState() {
    super.initState();
    
    // CRITICAL: Verify Premium access
    if (!isPremiumUser(widget.currentUser)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(context, '🔒 Premium subscription required');
        Navigator.pop(context);
      });
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
          'Manage Catalog'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewItem,
            tooltip: 'Add Item'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category.tr()),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    selectedColor: Color(colorPrimary),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (dark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                );
              },
            ),
          ),

          // Catalog items list
          Expanded(
            child: StreamBuilder<List<CatalogItem>>(
              stream: _storeService.getCatalogItems(widget.listing.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading catalog: ${snapshot.error}',
                      style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                
                // Filter by category
                final filteredItems = _selectedCategory == 'All'
                    ? items
                    : items.where((item) {
                        if (_selectedCategory == 'Food & Drink') {
                          return item.type == CatalogItemType.foodDrink;
                        } else if (_selectedCategory == 'Products') {
                          return item.type == CatalogItemType.product;
                        } else if (_selectedCategory == 'Services') {
                          return item.type == CatalogItemType.service;
                        }
                        return item.category == _selectedCategory;
                      }).toList();

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items in catalog'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first item'.tr(),
                          style: TextStyle(
                            color: dark ? Colors.grey.shade600 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildItemCard(item, dark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(CatalogItem item, bool dark) {
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${getCurrencySymbol(item.currencyCode)}${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(colorPrimary),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          item.isAvailable ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: item.isAvailable ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.isAvailable ? 'Available'.tr() : 'Unavailable'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        if (item.trackStock) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.stockQty}',
                            style: TextStyle(
                              fontSize: 12,
                              color: dark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _editItem(item);
                  } else if (value == 'delete') {
                    _deleteItem(item);
                  } else if (value == 'toggle') {
                    _toggleAvailability(item);
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
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          item.isAvailable ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(item.isAvailable ? 'Mark Unavailable'.tr() : 'Mark Available'.tr()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Delete'.tr(), style: const TextStyle(color: Colors.red)),
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
      color: Colors.grey.shade300,
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  String getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
      case 'TTD':
      case 'JMD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '\$';
    }
  }

  void _addNewItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatalogItemEditorScreen(
          listing: widget.listing,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _editItem(CatalogItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CatalogItemEditorScreen(
          listing: widget.listing,
          currentUser: widget.currentUser,
          item: item,
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(CatalogItem item) async {
    try {
      await _storeService.upsertCatalogItem(
        listingId: widget.listing.id,
        item: item.copyWith(isAvailable: !item.isAvailable),
        currentUser: widget.currentUser,
      );
      showSnackBar(context, 'Item updated'.tr());
    } catch (e) {
      showSnackBar(context, e.toString());
    }
  }

  Future<void> _deleteItem(CatalogItem item) async {
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
        await _storeService.deleteCatalogItem(
          listingId: widget.listing.id,
          itemId: item.id,
          currentUser: widget.currentUser,
        );
        showSnackBar(context, 'Item deleted'.tr());
      } catch (e) {
        showSnackBar(context, e.toString());
      }
    }
  }
}
