import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:caribtap/core/ui/full_screen_video_viewer/full_screen_video_viewer.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/rental_config.dart';
import 'package:caribtap/listings/currency/currency_display_service.dart';
import 'package:caribtap/screens/rentals/rental_item_models.dart';
import 'package:caribtap/screens/rentals/rental_browse_service.dart';
import 'package:caribtap/screens/rentals/rental_cart_storage.dart';
import 'package:caribtap/screens/rentals/rental_checkout_screen.dart';
import 'package:caribtap/listings/utils/search_utils.dart';

String _formatCurrency(double amount, String currencyCode) {
  final normalizedCode = currencyCode.trim().isEmpty
      ? 'USD'
      : currencyCode.toUpperCase();
  return '$normalizedCode ${_getCurrencySymbol(normalizedCode)}${NumberFormat('#,##0.00').format(amount)}';
}

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

/// Customer-facing rental browsing screen - Browse and select rental items
class RentalBrowseScreen extends StatefulWidget {
  final ListingModel listing;
  final RentalConfig rentalConfig;
  final ListingsUser? currentUser; // Can be null for guests

  const RentalBrowseScreen({
    Key? key,
    required this.listing,
    required this.rentalConfig,
    this.currentUser,
  }) : super(key: key);

  @override
  State<RentalBrowseScreen> createState() => _RentalBrowseScreenState();
}

class _RentalBrowseScreenState extends State<RentalBrowseScreen> {
  final RentalBrowseService _rentalService = RentalBrowseService();
  final CurrencyDisplayService _currencyDisplayService = CurrencyDisplayService();
  final TextEditingController _searchController = TextEditingController();
  final List<RentalCartItem> _cart = [];
  
  String _searchQuery = '';
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadPersistedCart();
  }

  Future<void> _loadPersistedCart() async {
    final savedCart = await RentalCartStorage.getCart(widget.listing.id);
    if (!mounted) return;
    setState(() {
      _cart
        ..clear()
        ..addAll(savedCart);
    });
  }

  Future<void> _persistCart() async {
    await RentalCartStorage.saveCart(widget.listing.id, _cart);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _cartCountForRentalUnit(String rentalUnitId) {
    return _cart.where((item) => item.rentalUnitId == rentalUnitId).length;
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

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
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _cart.length.toString(),
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
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search rentals...'.tr(),
                hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
                prefixIcon: Icon(Icons.search, color: dark ? Colors.white70 : Colors.black54),
                suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
                filled: true,
                fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Rental items grid
          Expanded(
            child: StreamBuilder<List<RentalItemBrowse>>(
              stream: _rentalService.getAvailableRentalItems(widget.listing.id),
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
                          color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No rental items available'.tr(),
                          style: TextStyle(
                            color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var items = snapshot.data!;
                final categories = items
                    .map((item) => item.category.trim())
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final effectiveCategory = categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : 'all';
                
                // ✅ Refined Filtering logic using SearchUtils
                if (_searchQuery.isNotEmpty) {
                  items = items.where((item) {
                    final searchString = '${item.unitName} ${item.description ?? ''} ${item.category}'.toLowerCase();
                    return SearchUtils.fuzzyMatch(_searchQuery, searchString);
                  }).toList();
                }

                // Filter by category
                if (effectiveCategory != 'all') {
                  items = items
                      .where((item) => item.category == effectiveCategory)
                      .toList();
                }

                items.sort((a, b) => a.unitName.compareTo(b.unitName));

                if (items.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No results found for "${_searchQuery}"'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Category'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          DropdownButton<String>(
                            value: effectiveCategory,
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All Categories'.tr()),
                              ),
                              ...categories.map((category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(category),
                                  )),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCategory = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _buildRentalItemCard(
                            context,
                            item,
                            dark,
                            primaryColor,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalItemCard(
    BuildContext context,
    RentalItemBrowse item,
    bool dark,
    Color primaryColor,
  ) {
    final isRented = !item.isAvailable || item.stockQty <= 0;
    final inCartCount = _cartCountForRentalUnit(item.id);
    final atCartLimit = item.stockQty > 0 && inCartCount >= item.stockQty;
    final canBook = !isRented && !atCartLimit;

    return GestureDetector(
      onTap: canBook ? () => _showRentalItemDetail(context, item) : null,
      child: Card(
        color: dark ? Colors.grey.shade900 : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                  image: item.photos.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item.photos.first),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: item.photos.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${item.photos.length} ${'Photos'.tr()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.unitName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCurrency(item.basePrice, item.currencyCode)} / ${item.pricingUnit}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  FutureBuilder<CurrencyDisplayResult>(
                    future: _currencyDisplayService.buildDisplayResult(
                      rawAmount: item.basePrice.toStringAsFixed(2),
                      originalCurrencyCode: item.currencyCode,
                      preferenceValue:
                          widget.currentUser?.settings.displayCurrencyPreference,
                    ),
                    builder: (context, snapshot) {
                      final approx = snapshot.data?.approximateFormatted;
                      if (approx == null) return const SizedBox.shrink();
                      return Text(
                        '$approx / ${item.pricingUnit}',
                        style: TextStyle(
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: canBook ? () => _showRentalItemDetail(context, item) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isRented || atCartLimit)
                          ? (dark ? Colors.grey.shade700 : Colors.grey.shade400)
                          : primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      isRented
                          ? 'Rented'.tr()
                          : (atCartLimit ? 'Max in Cart'.tr() : 'Book Now'.tr()),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (isRented)
                    FutureBuilder<DateTime?>(
                      future: _rentalService.getNextAvailableDate(
                        listingId: item.listingId,
                        rentalUnitId: item.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Currently rented'.tr(),
                              style: TextStyle(
                                color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }

                        final nextDate = snapshot.data;
                        final label = nextDate == null
                            ? 'Currently rented'.tr()
                            : '${'Available again'.tr()}: ${DateFormat('MMM dd').format(nextDate)}';

                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRentalItemDetail(BuildContext context, RentalItemBrowse item) {
    final inCartCount = _cartCountForRentalUnit(item.id);
    if (item.stockQty > 0 && inCartCount >= item.stockQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have the maximum available quantity for this item in your cart.'.tr(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (context, scrollController) => _RentalItemDetailSheet(
          item: item,
          rentalConfig: widget.rentalConfig,
          currencyPreferenceValue:
              widget.currentUser?.settings.displayCurrencyPreference,
          sheetScrollController: scrollController,
          onAddToCart: (cartItem) {
            final latestCount = _cartCountForRentalUnit(item.id);
            if (item.stockQty > 0 && latestCount >= item.stockQty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'You already have the maximum available quantity for this item in your cart.'.tr(),
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.pop(context);
              return;
            }

            setState(() {
              _cart.add(cartItem);
            });
            Navigator.pop(context);
            _persistCart();
            _showAddedToCartSnackBar();
          },
        ),
      ),
    );
  }

  void _showAddedToCartSnackBar() {
    if (!mounted) return;

    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          elevation: 8,
          duration: const Duration(seconds: 2),
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          content: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: primaryColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Added to cart'.tr(),
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'View Cart'.tr(),
            textColor: primaryColor,
            onPressed: () {
              if (!mounted || _cart.isEmpty) return;
              _viewCart();
            },
          ),
        ),
      );
  }

  void _viewCart() {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalCheckoutScreen(
          listing: widget.listing,
          rentalConfig: widget.rentalConfig,
          cartItems: _cart,
          currentUser: widget.currentUser,
          onCheckoutComplete: () {
            if (!mounted) return;
            setState(() => _cart.clear());
            RentalCartStorage.clearCart(widget.listing.id);
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _loadPersistedCart();
    });
  }
}

/// Detail sheet for selecting dates and booking a rental item
class _RentalItemDetailSheet extends StatefulWidget {
  final RentalItemBrowse item;
  final RentalConfig rentalConfig;
  final String? currencyPreferenceValue;
  final ScrollController sheetScrollController;
  final Function(RentalCartItem) onAddToCart;

  const _RentalItemDetailSheet({
    required this.item,
    required this.rentalConfig,
    required this.currencyPreferenceValue,
    required this.sheetScrollController,
    required this.onAddToCart,
  });

  @override
  State<_RentalItemDetailSheet> createState() => _RentalItemDetailSheetState();
}

class _RentalItemDetailSheetState extends State<_RentalItemDetailSheet> {
  final RentalBrowseService _rentalService = RentalBrowseService();
  final CurrencyDisplayService _currencyDisplayService = CurrencyDisplayService();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isChecking = false;
  String? _availabilityError;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom > 0
        ? MediaQuery.of(context).viewInsets.bottom + 20
        : MediaQuery.of(context).padding.bottom + 20;

    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: widget.sheetScrollController,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dark ? Colors.grey.shade600 : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Title
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.unitName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                      tooltip: 'Close'.tr(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (widget.item.photos.isNotEmpty) ...[
                  SizedBox(
                    height: 210,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PageView.builder(
                        itemCount: widget.item.photos.length,
                        onPageChanged: (index) {
                          setState(() => _photoIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final photo = widget.item.photos[index];
                          return GestureDetector(
                            onTap: () {
                              push(
                                context,
                                FullScreenImageViewer(
                                  imageUrl: photo,
                                  galleryImagesList: widget.item.photos,
                                  index: index,
                                ),
                              );
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  photo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: dark ? Colors.grey.shade600 : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    margin: const EdgeInsets.all(10),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.zoom_in,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.item.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.item.photos.length, (dotIndex) {
                          final active = dotIndex == _photoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? primaryColor
                                  : (dark ? Colors.grey.shade600 : Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        }),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],

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
                        return _RentalVideoThumb(
                          url: widget.item.videos[index],
                          dark: dark,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Description
                if (widget.item.description != null)
                  Text(
                    widget.item.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 20),

                // Vehicle details (if applicable)
                if (widget.item.vehicleDetails != null) ...[
                  Text(
                    'Vehicle Details'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.item.vehicleDetails!['make']} ${widget.item.vehicleDetails!['model']} (${widget.item.vehicleDetails!['year']})',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.grey.shade300 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Date selection
                Text(
                  'Select Rental Period'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // Start date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Start Date'.tr(),
                    style: TextStyle(color: dark ? Colors.white : Colors.black),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(_startDate),
                    style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  trailing: Icon(Icons.calendar_today, color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                  onTap: () => _selectDate(context, true),
                ),

                // End date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'End Date'.tr(),
                    style: TextStyle(color: dark ? Colors.white : Colors.black),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(_endDate),
                    style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  trailing: Icon(Icons.calendar_today, color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
                  onTap: () => _selectDate(context, false),
                ),

                const SizedBox(height: 16),

                // Price summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Duration'.tr(),
                            style: TextStyle(color: dark ? Colors.white : Colors.black),
                          ),
                          Text(
                            '${_getDurationDays()} days',
                            style: TextStyle(color: dark ? Colors.white : Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Price per ${widget.item.pricingUnit}'.tr(),
                            style: TextStyle(color: dark ? Colors.white : Colors.black),
                          ),
                          _buildPriceWithApprox(
                            amount: widget.item.basePrice,
                            currencyCode: widget.item.currencyCode,
                            dark: dark,
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: dark ? Colors.white : Colors.black,
                            ),
                          ),
                          _buildPriceWithApprox(
                            amount: _calculateRentalSubtotal(),
                            currencyCode: widget.item.currencyCode,
                            dark: dark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ],
                      ),
                      if (_securityDeposit() > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Security Deposit'.tr(),
                              style: TextStyle(color: dark ? Colors.white : Colors.black),
                            ),
                            _buildPriceWithApprox(
                              amount: _securityDeposit(),
                              currencyCode: widget.item.currencyCode,
                              dark: dark,
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (incl. deposit)'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: dark ? Colors.white : Colors.black,
                              ),
                            ),
                            _buildPriceWithApprox(
                              amount: _calculateTotalWithDeposit(),
                              currencyCode: widget.item.currencyCode,
                              dark: dark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Add to cart button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _addToCart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text('Add to Cart'.tr()),
                  ),
                ),
                if (_availabilityError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (dark ? Colors.red.shade900 : Colors.red.shade50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: dark ? Colors.red.shade400 : Colors.red.shade300,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: dark ? Colors.red.shade200 : Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _availabilityError!,
                            style: TextStyle(
                              color: dark ? Colors.red.shade100 : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getDurationDays() {
    return _endDate.difference(_startDate).inDays + 1;
  }

  Widget _buildPriceWithApprox({
    required double amount,
    required String currencyCode,
    required bool dark,
    FontWeight? fontWeight,
    double? fontSize,
  }) {
    return FutureBuilder<CurrencyDisplayResult>(
      future: _currencyDisplayService.buildDisplayResult(
        rawAmount: amount.toStringAsFixed(2),
        originalCurrencyCode: currencyCode,
        preferenceValue: widget.currencyPreferenceValue,
      ),
      builder: (context, snapshot) {
        final display = snapshot.data;
        final original = _formatCurrency(amount, currencyCode);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              original,
              style: TextStyle(
                fontWeight: fontWeight,
                fontSize: fontSize,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            if (display?.approximateFormatted != null)
              Text(
                display!.approximateFormatted!,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
          ],
        );
      },
    );
  }

  double _calculateRentalSubtotal() {
    return _rentalService.calculatePrice(
      widget.item.basePrice,
      widget.rentalConfig.defaultPricingUnit,
      _startDate,
      _endDate,
    );
  }

  double _securityDeposit() {
    return widget.item.depositAmount ?? widget.rentalConfig.depositAmount ?? 0.0;
  }

  double _calculateTotalWithDeposit() {
    return _calculateRentalSubtotal() + _securityDeposit();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _availabilityError = null;
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          if (picked.isAfter(_startDate)) {
            _endDate = picked;
          }
        }
      });
    }
  }

  void _addToCart() async {
    setState(() {
      _isChecking = true;
      _availabilityError = null;
    });

    final available = await _rentalService.isAvailableForDates(
      widget.item.listingId,
      widget.item.id,
      _startDate,
      _endDate,
    );

    if (!available) {
      if (mounted) {
        setState(() {
          _availabilityError = 'Not available for selected dates'.tr();
        });
      }
      setState(() => _isChecking = false);
      return;
    }

    final cartItem = RentalCartItem(
      rentalUnitId: widget.item.id,
      unitName: widget.item.unitName,
      rentalType: widget.item.rentalType,
      startDate: _startDate,
      endDate: _endDate,
      pricePerDay: widget.item.basePrice,
      totalPrice: _calculateRentalSubtotal(),
      currencyCode: widget.item.currencyCode,
      photoUrl: widget.item.photos.isNotEmpty ? widget.item.photos.first : null,
      details: {
        'securityDeposit': _securityDeposit(),
      },
    );

    widget.onAddToCart(cartItem);
    setState(() => _isChecking = false);
  }
}

class _RentalVideoThumb extends StatefulWidget {
  final String url;
  final bool dark;

  const _RentalVideoThumb({required this.url, required this.dark});

  @override
  State<_RentalVideoThumb> createState() => _RentalVideoThumbState();
}

class _RentalVideoThumbState extends State<_RentalVideoThumb> {
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
              heroTag: 'rental_video_${widget.url.hashCode}',
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
