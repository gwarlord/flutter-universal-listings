import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:caribtap/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:caribtap/core/ui/full_screen_video_viewer/full_screen_video_viewer.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/catalog_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/currency/currency_display_service.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/listings/utils/category_localization.dart';
import 'package:caribtap/screens/store/cart_models.dart';
import 'package:caribtap/screens/store/cart_screen.dart';
import 'package:caribtap/screens/store/store_cart_storage.dart';

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
  final CurrencyDisplayService _currencyDisplayService = CurrencyDisplayService();
  final TextEditingController _searchController = TextEditingController();
  final List<CartItem> _cart = [];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _sortBy = 'new'; // 'new', 'price_low', 'price_high'

  @override
  void initState() {
    super.initState();
    _loadPersistedCart();
  }

  Future<void> _loadPersistedCart() async {
    final savedCart = await StoreCartStorage.getCart(widget.listing.id);
    if (!mounted) return;
    setState(() {
      _cart
        ..clear()
        ..addAll(savedCart);
    });
  }

  Future<void> _persistCart() async {
    await StoreCartStorage.saveCart(widget.listing.id, _cart);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _effectiveItemPrice(CatalogItem item) {
    if (item.variants.isEmpty) return item.price;
    return item.variants
        .map((v) => v.price)
        .reduce((a, b) => a < b ? a : b);
  }

  bool get _isStoreAvailable {
    final available = widget.listing.storeEnabled &&
        (widget.listing.storeMode == 'internal_catalog' ||
            widget.listing.storeMode == 'both') &&
        widget.listing.listerTierSnapshot == 'premium';

    if (!available) {
      print(
          '❌ Store unavailable - storeEnabled: ${widget.listing.storeEnabled}, '
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
                hintStyle:
                    TextStyle(color: dark ? Colors.white54 : Colors.black45),
                prefixIcon: Icon(Icons.search,
                    color: dark ? Colors.white70 : Colors.black54),
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
              final categories = <String>{
                'All',
                ...items.map((e) => e.category).where((c) => c.isNotEmpty)
              };
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
                Text('Sort:'.tr(),
                    style: TextStyle(
                        color: dark ? Colors.white70 : Colors.black54)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  underline: Container(),
                  items: [
                    DropdownMenuItem(value: 'new', child: Text('Newest'.tr())),
                    DropdownMenuItem(
                        value: 'price_low',
                        child: Text('Price: Low to High'.tr())),
                    DropdownMenuItem(
                        value: 'price_high',
                        child: Text('Price: High to Low'.tr())),
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
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(
                      child: Text('Error loading items'.tr(),
                          style: TextStyle(
                              color: dark ? Colors.white70 : Colors.black54)));

                var items = snapshot.data ?? [];
                if (_selectedCategory != 'All')
                  items = items
                      .where((item) => item.category == _selectedCategory)
                      .toList();
                if (_searchQuery.isNotEmpty)
                  items = items
                      .where((item) =>
                          item.name.toLowerCase().contains(_searchQuery) ||
                          (item.description
                                  ?.toLowerCase()
                                  .contains(_searchQuery) ??
                              false))
                      .toList();

                items.sort((a, b) {
                  if (_sortBy == 'price_low') {
                    return _effectiveItemPrice(a).compareTo(_effectiveItemPrice(b));
                  }
                  if (_sortBy == 'price_high') {
                    return _effectiveItemPrice(b).compareTo(_effectiveItemPrice(a));
                  }
                  return (b.createdAt?.seconds ?? 0)
                      .compareTo(a.createdAt?.seconds ?? 0);
                });

                if (items.isEmpty)
                  return Center(
                      child: Text('No items found'.tr(),
                          style: TextStyle(
                              color: dark ? Colors.white70 : Colors.black54)));

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _buildItemCard(items[index], dark),
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
              label: Text('${'View Cart'.tr()} ($_cartItemCount)',
                  style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildCategoryChip(String category, bool dark) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(localizeCategoryLabel(category, context)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _selectedCategory = category);
        },
        selectedColor: Color(cfg.colorPrimary),
        labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : (dark ? Colors.white70 : Colors.black87)),
      ),
    );
  }

  Widget _buildItemCard(CatalogItem item, bool dark) {
    final displayPrice = _effectiveItemPrice(item);
    final previewImage = item.primaryDisplayImage;
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: previewImage != null
                ? Image.network(previewImage,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                      errorBuilder: (_, __, ___) => _placeholderImage())
                  : _placeholderImage(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<CurrencyDisplayResult>(
                          future: _currencyDisplayService.buildDisplayResult(
                            rawAmount: displayPrice.toStringAsFixed(2),
                            originalCurrencyCode: item.currencyCode,
                            preferenceValue: widget.currentUser?.settings.displayCurrencyPreference,
                          ),
                          builder: (context, snapshot) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatCurrency(displayPrice, item.currencyCode),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(cfg.colorPrimary),
                                  ),
                                ),
                                if (snapshot.data?.approximateFormatted != null)
                                  Text(
                                    snapshot.data!.approximateFormatted!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        if (!item.isAvailable)
                          Text('Unavailable'.tr(),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
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

  Widget _placeholderImage() => Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: const Icon(Icons.image, size: 40, color: Colors.grey));
  String _formatCurrency(double amount, String currencyCode) =>
      '${currencyCode.toUpperCase()} ${_getCurrencySymbol(currencyCode)}${NumberFormat('#,##0.00').format(amount)}';
  String _getCurrencySymbol(String code) {
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

  String _variantSkuKey(Map<String, dynamic>? variant) {
    final sku = variant?['sku']?.toString().trim();
    if (sku != null && sku.isNotEmpty) return 'sku:$sku';

    final values = [
      variant?['option1Value']?.toString().trim(),
      variant?['option2Value']?.toString().trim(),
      variant?['option3Value']?.toString().trim(),
      variant?['option4Value']?.toString().trim(),
      variant?['size']?.toString().trim(),
      variant?['color']?.toString().trim(),
      variant?['label']?.toString().trim(),
    ]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();

    if (values.isEmpty) return '__no_variant__';
    return 'vals:${values.join('|')}';
  }

  int _cartQtyForSelection(CatalogItem item, Map<String, dynamic>? variant) {
    final targetSku = _variantSkuKey(variant);
    return _cart
        .where((cartItem) =>
            cartItem.itemId == item.id &&
            _variantSkuKey(cartItem.variant) == targetSku)
        .fold<int>(0, (total, cartItem) => total + cartItem.qty);
  }

  int _maxStockForSelection(CatalogItem item, Map<String, dynamic>? variant) {
    if (!item.trackStock) return 999999;
    if (variant != null) {
      return (variant['stockQty'] as num?)?.toInt() ?? 0;
    }
    return item.stockQty;
  }

  void _showItemDetail(CatalogItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemDetailModal(
        item: item,
        currencyPreferenceValue:
          widget.currentUser?.settings.displayCurrencyPreference,
        getExistingQtyForVariant: (variant) =>
            _cartQtyForSelection(item, variant),
        onRemoveFromCart: (variant) {
          setState(() {
            _cart.removeWhere((cartItem) =>
                cartItem.itemId == item.id &&
                _variantSkuKey(cartItem.variant) == _variantSkuKey(variant));
          });
          _persistCart();
          showSnackBar(context, 'Removed from cart'.tr());
        },
        onAddToCart: (cartItem) {
          final maxStock = _maxStockForSelection(item, cartItem.variant);
          final existingQty = _cartQtyForSelection(item, cartItem.variant);
          final remaining = item.trackStock ? (maxStock - existingQty) : 999999;

          if (item.trackStock && remaining <= 0) {
            showSnackBar(context, 'No more inventory available'.tr());
            return;
          }

          final qtyToAdd = item.trackStock
              ? (cartItem.qty > remaining ? remaining : cartItem.qty)
              : cartItem.qty;

          setState(() {
            final existingIndex = _cart.indexWhere((c) =>
                c.itemId == cartItem.itemId &&
                _variantSkuKey(c.variant) == _variantSkuKey(cartItem.variant));
            if (existingIndex >= 0) {
              _cart[existingIndex].qty += qtyToAdd;
            } else {
              _cart.add(cartItem.copyWith(qty: qtyToAdd));
            }
          });
          _persistCart();
          if (item.trackStock && qtyToAdd < cartItem.qty) {
            showSnackBar(context, 'Added only available stock'.tr());
          } else {
            showSnackBar(context, 'Added to cart'.tr());
          }
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
          onCartUpdated: () {
            setState(() {});
            _persistCart();
          },
        ),
      ),
    ).then((_) => _loadPersistedCart());
  }
}

class _ItemDetailModal extends StatefulWidget {
  final CatalogItem item;
  final String? currencyPreferenceValue;
  final int Function(Map<String, dynamic>? variant) getExistingQtyForVariant;
  final void Function(Map<String, dynamic>? variant) onRemoveFromCart;
  final Function(CartItem) onAddToCart;
  const _ItemDetailModal({
    required this.item,
    required this.currencyPreferenceValue,
    required this.getExistingQtyForVariant,
    required this.onRemoveFromCart,
    required this.onAddToCart,
  });

  @override
  State<_ItemDetailModal> createState() => _ItemDetailModalState();
}

class _ItemDetailModalState extends State<_ItemDetailModal> {
  final CurrencyDisplayService _currencyDisplayService = CurrencyDisplayService();
  int _quantity = 1;
  int _selectedPhotoIndex = 0;
  CatalogVariant? _selectedVariant;
  final Map<int, String?> _selectedValues = {
    1: null,
    2: null,
    3: null,
    4: null,
  };

  @override
  void initState() {
    super.initState();
    _selectedVariant = widget.item.variants.isNotEmpty
        ? widget.item.variants.first
        : null;
    _syncSelectedValuesFromVariant(_selectedVariant);
    _enforceQuantityWithinStock();
  }

  bool _hasOption(int index) {
    switch (index) {
      case 1:
        return widget.item.hasFirstVariantOption;
      case 2:
        return widget.item.hasSecondVariantOption;
      case 3:
        return widget.item.hasThirdVariantOption;
      case 4:
        return widget.item.hasFourthVariantOption;
      default:
        return false;
    }
  }

  String _optionName(int index) {
    switch (index) {
      case 1:
        return widget.item.resolvedOption1Name;
      case 2:
        return widget.item.resolvedOption2Name;
      case 3:
        return widget.item.resolvedOption3Name;
      case 4:
        return widget.item.resolvedOption4Name;
      default:
        return 'Option';
    }
  }

  String? _optionValueForVariant(CatalogVariant variant, int index) {
    switch (index) {
      case 1:
        return variant.effectiveOption1Value;
      case 2:
        return variant.effectiveOption2Value;
      case 3:
        return variant.effectiveOption3Value;
      case 4:
        return variant.effectiveOption4Value;
      default:
        return null;
    }
  }

  void _syncSelectedValuesFromVariant(CatalogVariant? variant) {
    _selectedValues[1] = variant?.effectiveOption1Value;
    _selectedValues[2] = variant?.effectiveOption2Value;
    _selectedValues[3] = variant?.effectiveOption3Value;
    _selectedValues[4] = variant?.effectiveOption4Value;
  }

  bool _isSizeOption(int optionIndex) {
    return !widget.item.optionAffectsImage(optionIndex);
  }

  String _optionHeading(int optionIndex) {
    final name = _optionName(optionIndex).tr();
    final selected = _selectedValues[optionIndex];
    if (selected == null || selected.isEmpty) return name;
    return '$name: $selected';
  }

  int get _existingQtyInCart {
    return widget.getExistingQtyForVariant(_selectedVariant?.toSelectionMap(
          option1Name: widget.item.normalizedOption1Name,
          option2Name: widget.item.normalizedOption2Name,
          option3Name: widget.item.normalizedOption3Name,
          option4Name: widget.item.normalizedOption4Name,
        ));
  }

  int get _maxStockForCurrentSelection {
    if (!widget.item.trackStock) return 999999;
    if (_selectedVariant != null) return _selectedVariant!.stockQty;
    return widget.item.stockQty;
  }

  int get _remainingStockForAdd {
    if (!widget.item.trackStock) return 999999;
    final remaining = _maxStockForCurrentSelection - _existingQtyInCart;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _canAddMore => !widget.item.trackStock || _remainingStockForAdd > 0;

  void _enforceQuantityWithinStock() {
    if (!widget.item.trackStock) {
      if (_quantity < 1) _quantity = 1;
      return;
    }
    final maxAllowed = _remainingStockForAdd;
    if (maxAllowed <= 0) {
      _quantity = 1;
      return;
    }
    if (_quantity > maxAllowed) {
      _quantity = maxAllowed;
    }
    if (_quantity < 1) {
      _quantity = 1;
    }
  }

  List<String> get _activeGalleryImages {
    return widget.item.galleryImagesForSelection(
      _selectedValues,
      preferredVariant: _selectedVariant,
    );
  }

  List<CatalogVariant> _variantsMatchingOtherSelections(int excludeOptionIndex) {
    return widget.item.variants.where((variant) {
      for (var optionIndex = 1; optionIndex <= 4; optionIndex++) {
        if (optionIndex == excludeOptionIndex || !_hasOption(optionIndex)) {
          continue;
        }
        final selected = _selectedValues[optionIndex];
        if (selected == null || selected.isEmpty) continue;
        if (_optionValueForVariant(variant, optionIndex) != selected) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<CatalogVariant> _variantsMatchingCurrentSelections() {
    return widget.item.variants.where((variant) {
      for (var optionIndex = 1; optionIndex <= 4; optionIndex++) {
        if (!_hasOption(optionIndex)) continue;
        final selected = _selectedValues[optionIndex];
        if (selected == null || selected.isEmpty) continue;
        if (_optionValueForVariant(variant, optionIndex) != selected) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool get _isSelectionComplete {
    for (var optionIndex = 1; optionIndex <= 4; optionIndex++) {
      if (!_hasOption(optionIndex)) continue;
      final selected = _selectedValues[optionIndex];
      if (selected == null || selected.isEmpty) return false;
    }
    return true;
  }

  CatalogVariant? _findExactMatchingVariant() {
    if (!_isSelectionComplete) return null;
    for (final variant in widget.item.variants) {
      var matches = true;
      for (var optionIndex = 1; optionIndex <= 4; optionIndex++) {
        if (!_hasOption(optionIndex)) continue;
        if (_optionValueForVariant(variant, optionIndex) !=
            _selectedValues[optionIndex]) {
          matches = false;
          break;
        }
      }
      if (matches) return variant;
    }
    return null;
  }

  CatalogVariant? _resolveBestVariantForSelection() {
    final exact = _findExactMatchingVariant();
    if (exact != null) return exact;

    final candidates = _variantsMatchingCurrentSelections();
    if (candidates.isEmpty) return null;

    final currentSku = _selectedVariant?.sku;
    if (currentSku != null) {
      for (final candidate in candidates) {
        if (candidate.sku == currentSku) return candidate;
      }
    }

    return candidates.first;
  }

  List<String> _availableValuesForOption(int optionIndex) {
    final values = widget.item.variants
        .map((variant) => _optionValueForVariant(variant, optionIndex))
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList();
    values.sort();
    return values;
  }

  List<CatalogVariant> _variantsForOptionValue(int optionIndex, String value) {
    return _variantsMatchingOtherSelections(optionIndex)
        .where((variant) => _optionValueForVariant(variant, optionIndex) == value)
        .toList();
  }

  List<CatalogVariant> _variantsForOptionValueIgnoringSelections(
    int optionIndex,
    String value,
  ) {
    return widget.item.variants
        .where((variant) => _optionValueForVariant(variant, optionIndex) == value)
        .toList();
  }

  CatalogVariant? _fallbackVariantForChosenOption(int optionIndex, String value) {
    var candidates = _variantsForOptionValueIgnoringSelections(optionIndex, value);
    if (candidates.isEmpty) return null;

    if (widget.item.trackStock) {
      final inStock = candidates.where((variant) => variant.stockQty > 0).toList();
      if (inStock.isNotEmpty) {
        candidates = inStock;
      }
    }

    int score(CatalogVariant variant) {
      var matched = 0;
      for (var i = 1; i <= 4; i++) {
        if (i == optionIndex || !_hasOption(i)) continue;
        final selected = _selectedValues[i];
        if (selected == null || selected.isEmpty) continue;
        if (_optionValueForVariant(variant, i) == selected) {
          matched++;
        }
      }
      return matched;
    }

    candidates.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      if (byScore != 0) return byScore;
      if (widget.item.trackStock) {
        final byStock = b.stockQty.compareTo(a.stockQty);
        if (byStock != 0) return byStock;
      }
      return a.sku.compareTo(b.sku);
    });

    return candidates.first;
  }

  bool _isOptionValueAvailable(int optionIndex, String value) {
    final variants = _variantsForOptionValue(optionIndex, value);
    if (variants.isNotEmpty) {
      if (!widget.item.trackStock) return true;
      return variants.any((variant) => variant.stockQty > 0);
    }

    // Relaxed path: still allow switching to this value by auto-adjusting
    // other selections to a valid combination.
    final fallbackCandidates =
        _variantsForOptionValueIgnoringSelections(optionIndex, value);
    if (fallbackCandidates.isEmpty) return false;
    if (!widget.item.trackStock) return true;
    return fallbackCandidates.any((variant) => variant.stockQty > 0);
  }

  void _selectOptionValue(
    int optionIndex,
    String value, {
    bool markAsUserSelection = false,
  }) {
    setState(() {
      _selectedValues[optionIndex] = value;
      var resolvedVariant = _resolveBestVariantForSelection();
      resolvedVariant ??= _fallbackVariantForChosenOption(optionIndex, value);
      if (resolvedVariant != null) {
        _selectedVariant = resolvedVariant;
        _syncSelectedValuesFromVariant(resolvedVariant);
      }
      _enforceQuantityWithinStock();
      _selectedPhotoIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final galleryImages = _activeGalleryImages;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return Container(
          decoration: BoxDecoration(
              color: dark ? Colors.grey.shade900 : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              if (galleryImages.isNotEmpty)
                SizedBox(
                  key: ValueKey(galleryImages.join('|')),
                  height: 300,
                  child: PageView.builder(
                    onPageChanged: (index) {
                      setState(() {
                        _selectedPhotoIndex = index;
                      });
                    },
                    itemCount: galleryImages.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => push(
                        context,
                        FullScreenImageViewer(
                          imageUrl: galleryImages[index],
                          galleryImagesList: galleryImages,
                          index: index,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          galleryImages[index],
                          fit: BoxFit.cover,
                          cacheWidth: 800,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, size: 60),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (galleryImages.length > 1) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '${(_selectedPhotoIndex.clamp(0, galleryImages.length - 1)) + 1} / ${galleryImages.length}',
                    style: TextStyle(
                      color: dark ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Videos
              if (widget.item.videos.isNotEmpty) ...[
                Text(
                  'Videos'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.item.videos.length,
                    itemBuilder: (context, index) {
                      return _StoreVideoThumb(
                        url: widget.item.videos[index],
                        dark: dark,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(widget.item.name,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black))),
                  FutureBuilder<CurrencyDisplayResult>(
                    future: _currencyDisplayService.buildDisplayResult(
                      rawAmount:
                          (_selectedVariant?.price ?? widget.item.price).toStringAsFixed(2),
                      originalCurrencyCode: widget.item.currencyCode,
                      preferenceValue: widget.currencyPreferenceValue,
                    ),
                    builder: (context, snapshot) {
                      final display = snapshot.data;
                      final original = _formatCurrency(
                        _selectedVariant?.price ?? widget.item.price,
                        widget.item.currencyCode,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            original,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(cfg.colorPrimary),
                            ),
                          ),
                          if (display?.approximateFormatted != null)
                            Text(
                              display!.approximateFormatted!,
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.item.description != null &&
                  widget.item.description!.isNotEmpty)
                Text(widget.item.description!,
                    style: TextStyle(
                        fontSize: 16,
                        color: dark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 16),
              if (widget.item.variants.isNotEmpty) _buildVariantSelectors(dark),
              if (widget.item.trackStock) ...[
                const SizedBox(height: 8),
                Text(
                  _remainingStockForAdd > 0
                      ? 'Available: $_remainingStockForAdd'
                      : 'Out of stock'.tr(),
                  style: TextStyle(
                    color: _remainingStockForAdd > 0
                        ? (dark ? Colors.white70 : Colors.black54)
                        : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_existingQtyInCart > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'In cart: $_existingQtyInCart'.tr(),
                      style: TextStyle(
                        color: dark ? Colors.white54 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Quantity'.tr(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black)),
                  const Spacer(),
                  IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: Icon(Icons.remove_circle_outline,
                          color: _quantity > 1
                              ? Color(cfg.colorPrimary)
                              : (dark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400))),
                  Text(_quantity.toString(),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black)),
                  IconButton(
                      onPressed: (_canAddMore && _quantity < _remainingStockForAdd)
                          ? () => setState(() => _quantity++)
                          : null,
                      icon: Icon(Icons.add_circle_outline,
                          color: (_canAddMore && _quantity < _remainingStockForAdd)
                              ? Color(cfg.colorPrimary)
                              : (dark ? Colors.grey.shade600 : Colors.grey.shade400))),
                  if (_existingQtyInCart > 0)
                    IconButton(
                      onPressed: () {
                        widget.onRemoveFromCart(
                          _selectedVariant?.toSelectionMap(
                            option1Name: widget.item.normalizedOption1Name,
                            option2Name: widget.item.normalizedOption2Name,
                            option3Name: widget.item.normalizedOption3Name,
                            option4Name: widget.item.normalizedOption4Name,
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            _enforceQuantityWithinStock();
                          });
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.item.isAvailable &&
                      (widget.item.variants.isEmpty ||
                        (_selectedVariant != null && _isSelectionComplete)) &&
                          _canAddMore
                      ? _addToCart
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(cfg.colorPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Add to Cart'.tr(),
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVariantSelectors(bool dark) {
    final selectorWidgets = <Widget>[];
    for (var optionIndex = 1; optionIndex <= 4; optionIndex++) {
      if (!_hasOption(optionIndex)) continue;
      final availableValues = _availableValuesForOption(optionIndex);
      if (availableValues.isEmpty) continue;

      selectorWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Text(
            _optionHeading(optionIndex),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: dark ? Colors.white : Colors.black,
            ),
          ),
        ),
      );

      selectorWidgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableValues.map((value) {
            final isSelected = _selectedValues[optionIndex] == value;
            final isAvailable = _isOptionValueAvailable(optionIndex, value);

            return ChoiceChip(
              label: Text(value),
              selected: isSelected,
              onSelected: isAvailable
                  ? (_) {
                      _selectOptionValue(
                        optionIndex,
                        value,
                        markAsUserSelection: true,
                      );
                    }
                  : null,
              selectedColor: Color(cfg.colorPrimary),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (dark ? Colors.white70 : Colors.black87),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: selectorWidgets,
    );
  }

  String _formatCurrency(double amount, String currencyCode) =>
      '${currencyCode.toUpperCase()} ${_getCurrencySymbol(currencyCode)}${amount.toStringAsFixed(2)}';
  String _getCurrencySymbol(String code) {
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

  void _addToCart() {
    if (widget.item.trackStock && _remainingStockForAdd <= 0) {
      showSnackBar(context, 'No more inventory available'.tr());
      return;
    }

    final safeQty = widget.item.trackStock
        ? (_quantity > _remainingStockForAdd ? _remainingStockForAdd : _quantity)
        : _quantity;

    final variantMap = _selectedVariant?.toSelectionMap(
      option1Name:
          widget.item.normalizedOption1Name ?? widget.item.resolvedOption1Name,
      option2Name:
          widget.item.normalizedOption2Name ?? widget.item.resolvedOption2Name,
      option3Name:
          widget.item.normalizedOption3Name ?? widget.item.resolvedOption3Name,
      option4Name:
          widget.item.normalizedOption4Name ?? widget.item.resolvedOption4Name,
    );
    final selectedGalleryImages = widget.item.galleryImagesForSelection(
      _selectedValues,
      preferredVariant: _selectedVariant,
    );
    final cartPhotoUrl = selectedGalleryImages.isNotEmpty
        ? selectedGalleryImages.first
        : widget.item.primaryDisplayImage;

    widget.onAddToCart(CartItem(
      itemId: widget.item.id,
      name: widget.item.name,
      qty: safeQty,
      unitPrice: _selectedVariant?.price ?? widget.item.price,
      currencyCode: widget.item.currencyCode,
      photoUrl: cartPhotoUrl,
      variant: variantMap,
      variantLabel: _selectedVariant != null
          ? _selectedVariant!.displayLabel(separator: ', ')
          : null,
    ));
    Navigator.pop(context);
  }
}

class _StoreVideoThumb extends StatefulWidget {
  final String url;
  final bool dark;

  const _StoreVideoThumb({required this.url, required this.dark});

  @override
  State<_StoreVideoThumb> createState() => _StoreVideoThumbState();
}

class _StoreVideoThumbState extends State<_StoreVideoThumb> {
  Uint8List? _thumb;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.url,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 120,
      quality: 75,
    );
    if (mounted) setState(() { _thumb = bytes; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullScreenVideoViewer(
              videoUrl: widget.url,
              heroTag: 'store_video_${widget.url.hashCode}',
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        height: 120,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: widget.dark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _thumb != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_thumb!, fit: BoxFit.cover),
                    const Center(
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 36),
                    ),
                  ],
                )
              : Center(
                  child: _loaded
                      ? Icon(Icons.videocam,
                          size: 36, color: Colors.grey.shade500)
                      : const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                ),
        ),
      ),
    );
  }
}
