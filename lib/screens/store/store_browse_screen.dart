import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/catalog_item.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/store_service.dart';
import 'package:instaflutter/screens/store/cart_models.dart';
import 'package:instaflutter/screens/store/cart_screen.dart';

/// Customer-facing store browsing screen
class StoreBrowseScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser? currentUser; // Can be null for guests

  const StoreBrowseScreen({
    Key? key,
    required this.listing,
    this.currentUser,
  }) : super(key: key);

  @override
  State<StoreBrowseScreen> createState() => _StoreBrowseScreenState();
}

class _StoreBrowseScreenState extends State<StoreBrowseScreen> {
  final StoreService _storeService = StoreService();
  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cart = [];
  
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'new'; // 'new', 'price_low', 'price_high'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isStoreAvailable {
    final available = widget.listing.storeEnabled &&
           (widget.listing.storeMode == 'internal_catalog' || widget.listing.storeMode == 'both') &&
           widget.listing.listerTierSnapshot == 'premium';
    
    if (!available) {
      print('❌ Store unavailable - storeEnabled: ${widget.listing.storeEnabled}, '
            'storeMode: ${widget.listing.storeMode}, '
            'listerTierSnapshot: ${widget.listing.listerTierSnapshot}');
    }
    
    return available;
  }

  int get _cartItemCount {
    return _cart.fold(0, (sum, item) => sum + item.qty);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    if (!_isStoreAvailable) {
      return Scaffold(
        backgroundColor: dark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Store'.tr(),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '🔒 Storefront Unavailable'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  color: dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          widget.listing.title,
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          // Cart icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _cart.isEmpty ? null : _viewCart,
              ),
              if (_cart.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Color(cfg.colorPrimary),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: dark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search items...'.tr(),
                hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
                prefixIcon: Icon(Icons.search, color: dark ? Colors.white70 : Colors.black54),
                filled: true,
                fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Category filters (dynamically generated from catalog items)
          StreamBuilder<List<CatalogItem>>(
            stream: _storeService.getCatalogItems(widget.listing.id),
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final categories = <String>{'All', ...items.map((e) => e.category).where((c) => c.isNotEmpty)};
              final categoryList = categories.toList();
              
              return SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categoryList.length,
                  itemBuilder: (context, index) {
                    return _buildCategoryChip(categoryList[index], dark);
                  },
                ),
              );
            },
          ),

          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Sort:'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  underline: Container(),
                  items: [
                    DropdownMenuItem(value: 'new', child: Text('Newest'.tr())),
                    DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High'.tr())),
                    DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortBy = value);
                  },
                ),
              ],
            ),
          ),

          // Items grid
          Expanded(
            child: StreamBuilder<List<CatalogItem>>(
              stream: _storeService.getCatalogItems(widget.listing.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error loading items'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black54)));

                var items = snapshot.data ?? [];
                if (_selectedCategory != 'All') items = items.where((item) => item.category == _selectedCategory).toList();
                if (_searchQuery.isNotEmpty) items = items.where((item) => item.name.toLowerCase().contains(_searchQuery) || (item.description?.toLowerCase().contains(_searchQuery) ?? false)).toList();
                
                items.sort((a, b) {
                  if (_sortBy == 'price_low') return a.price.compareTo(b.price);
                  if (_sortBy == 'price_high') return b.price.compareTo(a.price);
                  return (b.createdAt?.seconds ?? 0).compareTo(a.createdAt?.seconds ?? 0);
                });

                if (items.isEmpty) return Center(child: Text('No items found'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black54)));

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _buildItemCard(items[index], dark),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _viewCart,
              backgroundColor: Color(cfg.colorPrimary),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text('View Cart ($_cartItemCount)'.tr(), style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildCategoryChip(String category, bool dark) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category.tr()),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedCategory = category);
        },
        selectedColor: Color(cfg.colorPrimary),
        labelStyle: TextStyle(color: isSelected ? Colors.white : (dark ? Colors.white70 : Colors.black87)),
      ),
    );
  }

  Widget _buildItemCard(CatalogItem item, bool dark) {
    return Card(
      color: dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showItemDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: item.photos.isNotEmpty ? Image.network(item.photos.first, height: 120, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderImage()) : _placeholderImage(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatCurrency(item.price, item.currencyCode), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(cfg.colorPrimary))),
                        if (!item.isAvailable) Text('Unavailable'.tr(), style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
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

  Widget _placeholderImage() => Container(height: 120, width: double.infinity, color: Colors.grey.shade300, child: const Icon(Icons.image, size: 40, color: Colors.grey));
  String _formatCurrency(double amount, String currencyCode) => '${_getCurrencySymbol(currencyCode)}${amount.toStringAsFixed(2)}';
  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': case 'TTD': case 'JMD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return '\$';
    }
  }

  void _showItemDetail(CatalogItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemDetailModal(
        item: item,
        onAddToCart: (cartItem) {
          setState(() {
            final existingIndex = _cart.indexWhere((c) => c.itemId == cartItem.itemId && c.variant?['sku'] == cartItem.variant?['sku']);
            if (existingIndex >= 0) {
              _cart[existingIndex].qty += cartItem.qty;
            } else {
              _cart.add(cartItem);
            }
          });
          showSnackBar(context, 'Added to cart'.tr());
        },
      ),
    );
  }

  void _viewCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          listing: widget.listing,
          currentUser: widget.currentUser,
          cartItems: _cart,
          onCartUpdated: () => setState(() {}),
        ),
      ),
    );
  }
}

class _ItemDetailModal extends StatefulWidget {
  final CatalogItem item;
  final Function(CartItem) onAddToCart;
  const _ItemDetailModal({required this.item, required this.onAddToCart});

  @override
  State<_ItemDetailModal> createState() => _ItemDetailModalState();
}

class _ItemDetailModalState extends State<_ItemDetailModal> {
  int _quantity = 1;
  CatalogVariant? _selectedVariant;
  Map<String, List<CatalogVariant>> _variantsByColor = {};
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _groupVariants();
    if (widget.item.variants.isNotEmpty) {
      final firstColor = _variantsByColor.keys.first;
      final firstVariantOfColor = _variantsByColor[firstColor]?.first;
      if (firstVariantOfColor != null) {
        _selectedVariant = firstVariantOfColor;
        _selectedColor = firstVariantOfColor.color;
        _selectedSize = firstVariantOfColor.size;
      }
    }
  }

  void _groupVariants() {
    _variantsByColor = {};
    for (final variant in widget.item.variants) {
      final colorKey = variant.color ?? 'Default';
      (_variantsByColor[colorKey] ??= []).add(variant);
    }
    // Sort sizes for consistency
    _variantsByColor.forEach((_, variants) => variants.sort((a, b) => (a.size ?? '').compareTo(b.size ?? '')));
  }
  
  void _onVariantSelected(String? color, String? size) {
    setState(() {
      _selectedColor = color;
      _selectedSize = size;
      _selectedVariant = widget.item.variants.firstWhere((v) => v.color == color && v.size == size);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(color: dark ? Colors.grey.shade900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              if (widget.item.photos.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: PageView.builder(
                    itemCount: widget.item.photos.length,
                    itemBuilder: (context, index) => ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(widget.item.photos[index], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, child: const Icon(Icons.image, size: 60)))),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(widget.item.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black))),
                  Text(_formatCurrency(_selectedVariant?.price ?? widget.item.price, widget.item.currencyCode), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(cfg.colorPrimary))),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.item.description != null && widget.item.description!.isNotEmpty) Text(widget.item.description!, style: TextStyle(fontSize: 16, color: dark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),
              if (widget.item.variants.isNotEmpty) _buildVariantSelectors(dark),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Quantity'.tr(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                  const Spacer(),
                  IconButton(onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, icon: Icon(Icons.remove_circle_outline, color: _quantity > 1 ? Color(cfg.colorPrimary) : (dark ? Colors.grey.shade600 : Colors.grey.shade400))),
                  Text(_quantity.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                  IconButton(onPressed: () => setState(() => _quantity++), icon: Icon(Icons.add_circle_outline, color: Color(cfg.colorPrimary))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.item.isAvailable && (widget.item.variants.isEmpty || _selectedVariant != null) ? _addToCart : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Color(cfg.colorPrimary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Add to Cart'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildVariantSelectors(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _variantsByColor.entries.map((entry) {
        final color = entry.key;
        final variantsForColor = entry.value;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (color != 'Default')
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text('Color: $color'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: variantsForColor.map((variant) {
                final isSelected = _selectedSize == variant.size && _selectedColor == variant.color;
                final isAvailable = !widget.item.trackStock || variant.stockQty > 0;
                
                return ChoiceChip(
                  label: Text(variant.size ?? 'Default'),
                  selected: isSelected,
                  onSelected: isAvailable ? (selected) {
                    if (selected) _onVariantSelected(variant.color, variant.size);
                  } : null,
                  selectedColor: Color(cfg.colorPrimary),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : (dark ? Colors.white70 : Colors.black87)),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatCurrency(double amount, String currencyCode) => '${_getCurrencySymbol(currencyCode)}${amount.toStringAsFixed(2)}';
  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': case 'TTD': case 'JMD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return '\$';
    }
  }

  void _addToCart() {
    widget.onAddToCart(CartItem(
      itemId: widget.item.id,
      name: widget.item.name,
      qty: _quantity,
      unitPrice: _selectedVariant?.price ?? widget.item.price,
      currencyCode: widget.item.currencyCode,
      photoUrl: widget.item.photos.isNotEmpty ? widget.item.photos.first : null,
      variant: _selectedVariant != null ? {'sku': _selectedVariant!.sku, 'size': _selectedVariant!.size, 'color': _selectedVariant!.color, 'price': _selectedVariant!.price, 'stockQty': _selectedVariant!.stockQty} : null,
      variantLabel: _selectedVariant != null ? '${_selectedVariant!.size ?? ''}${_selectedVariant!.size != null && _selectedVariant!.color != null ? ', ' : ''}${_selectedVariant!.color ?? ''}' : null,
    ));
    Navigator.pop(context);
  }
}
