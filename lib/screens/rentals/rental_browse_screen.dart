import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/rental_config.dart';
import 'package:instaflutter/screens/rentals/rental_item_models.dart';
import 'package:instaflutter/screens/rentals/rental_browse_service.dart';
import 'package:instaflutter/screens/rentals/rental_checkout_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final List<RentalCartItem> _cart = [];
  
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'price_low', 'price_high'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search rentals...'.tr(),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Sort options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sort by'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: [
                    DropdownMenuItem(
                      value: 'name',
                      child: Text('Name'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'price_low',
                      child: Text('Price: Low to High'.tr()),
                    ),
                    DropdownMenuItem(
                      value: 'price_high',
                      child: Text('Price: High to Low'.tr()),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _sortBy = value);
                    }
                  },
                ),
              ],
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
                
                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  items = items
                      .where((item) =>
                          item.unitName.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                // Sort
                items.sort((a, b) {
                  switch (_sortBy) {
                    case 'price_low':
                      return a.basePrice.compareTo(b.basePrice);
                    case 'price_high':
                      return b.basePrice.compareTo(a.basePrice);
                    case 'name':
                    default:
                      return a.unitName.compareTo(b.unitName);
                  }
                });

                return GridView.builder(
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
    return GestureDetector(
      onTap: () => _showRentalItemDetail(context, item),
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
                    : null,
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
                    '\$${item.basePrice.toStringAsFixed(2)} / ${item.pricingUnit}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showRentalItemDetail(context, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Book Now'.tr(), style: const TextStyle(fontSize: 12)),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RentalItemDetailSheet(
        item: item,
        rentalConfig: widget.rentalConfig,
        onAddToCart: (cartItem) {
          setState(() {
            _cart.add(cartItem);
            Navigator.pop(context);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added to cart'.tr())),
          );
        },
      ),
    );
  }

  void _viewCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalCheckoutScreen(
          listing: widget.listing,
          rentalConfig: widget.rentalConfig,
          cartItems: _cart,
          currentUser: widget.currentUser,
          onCheckoutComplete: () {
            setState(() => _cart.clear());
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

/// Detail sheet for selecting dates and booking a rental item
class _RentalItemDetailSheet extends StatefulWidget {
  final RentalItemBrowse item;
  final RentalConfig rentalConfig;
  final Function(RentalCartItem) onAddToCart;

  const _RentalItemDetailSheet({
    required this.item,
    required this.rentalConfig,
    required this.onAddToCart,
  });

  @override
  State<_RentalItemDetailSheet> createState() => _RentalItemDetailSheetState();
}

class _RentalItemDetailSheetState extends State<_RentalItemDetailSheet> {
  final RentalBrowseService _rentalService = RentalBrowseService();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isChecking = false;

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

    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                widget.item.unitName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

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
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.item.vehicleDetails!['make']} ${widget.item.vehicleDetails!['model']} (${widget.item.vehicleDetails!['year']})',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],

              // Date selection
              Text(
                'Select Rental Period'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Start date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Start Date'.tr()),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),

              // End date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('End Date'.tr()),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(_endDate)),
                trailing: const Icon(Icons.calendar_today),
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
                        Text('Duration'.tr()),
                        Text('${_getDurationDays()} days'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Price per ${widget.item.pricingUnit}'.tr()),
                        Text('\$${widget.item.basePrice.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${_calculateTotal().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
            ],
          ),
        ),
      ),
    );
  }

  int _getDurationDays() {
    return _endDate.difference(_startDate).inDays + 1;
  }

  double _calculateTotal() {
    return _rentalService.calculatePrice(
      widget.item.basePrice,
      widget.rentalConfig.defaultPricingUnit,
      _startDate,
      _endDate,
    );
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
    setState(() => _isChecking = true);

    final available = await _rentalService.isAvailableForDates(
      widget.rentalConfig.isRentalEnabled ? 'listingId' : '',
      widget.item.id,
      _startDate,
      _endDate,
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not available for selected dates'.tr()),
            backgroundColor: Colors.red,
          ),
        );
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
      totalPrice: _calculateTotal(),
      currencyCode: widget.item.currencyCode,
      photoUrl: widget.item.photos.isNotEmpty ? widget.item.photos.first : null,
    );

    widget.onAddToCart(cartItem);
    setState(() => _isChecking = false);
  }
}
