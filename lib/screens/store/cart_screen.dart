import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/order_request.dart';
import 'package:instaflutter/listings/services/store_service.dart';
import 'package:instaflutter/screens/store/cart_models.dart';
import 'package:instaflutter/screens/store/order_chat_helper.dart';
import 'package:instaflutter/screens/store/customer_orders_screen.dart';
import 'package:instaflutter/listings/listings_app_config.dart';

/// Cart screen for reviewing and submitting orders
class CartScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser? currentUser;
  final List<CartItem> cartItems;
  final VoidCallback? onCartUpdated;

  const CartScreen({
    Key? key,
    required this.listing,
    this.currentUser,
    required this.cartItems,
    this.onCartUpdated,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final StoreService _storeService = StoreService();
  final OrderChatHelper _chatHelper = OrderChatHelper();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  FulfillmentMethod _fulfillmentMethod = FulfillmentMethod.pickup;
  DateTime? _preferredDate;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return widget.cartItems.fold(0, (sum, item) => sum + item.total);
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Cart'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
      ),
      body: widget.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cart is empty'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Cart items
                      ...widget.cartItems.map((item) => _buildCartItem(item, dark)),
                      const SizedBox(height: 16),

                      // Subtotal
                      _buildSubtotalRow(dark),
                      const Divider(height: 32),

                      // Fulfillment method
                      Text(
                        'Fulfillment Method'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.listing.storePickupEnabled)
                        RadioListTile<FulfillmentMethod>(
                          title: Text('Pickup'.tr()),
                          value: FulfillmentMethod.pickup,
                          groupValue: _fulfillmentMethod,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _fulfillmentMethod = value);
                            }
                          },
                        ),
                      if (widget.listing.storeDeliveryEnabled)
                        RadioListTile<FulfillmentMethod>(
                          title: Text('Delivery'.tr()),
                          value: FulfillmentMethod.delivery,
                          groupValue: _fulfillmentMethod,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _fulfillmentMethod = value);
                            }
                          },
                        ),

                      // Delivery address
                      if (_fulfillmentMethod == FulfillmentMethod.delivery) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _addressController,
                          style: TextStyle(color: dark ? Colors.white : Colors.black),
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address *'.tr(),
                            labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Location pinning button
                        _buildLocationPinButton(dark),
                      ],

                      // Preferred date/time
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text('Preferred Date/Time (Optional)'.tr()),
                        subtitle: Text(
                          _preferredDate != null
                              ? DateFormat('MMM d, y – h:mm a').format(_preferredDate!)
                              : 'Not specified'.tr(),
                        ),
                        trailing: Icon(Icons.calendar_today, color: dark ? Colors.white70 : Colors.black54),
                        onTap: _pickDateTime,
                      ),

                      // Notes
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)'.tr(),
                          labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                        ),
                      ),
                    ],
                  ),
                ),

                // Submit button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  decoration: BoxDecoration(
                    color: dark ? Colors.grey.shade900 : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(colorPrimary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Send Order Request'.tr(),
                              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCartItem(CartItem item, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            if (item.photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.photoUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image, size: 30),
                  ),
                ),
              ),
            const SizedBox(width: 12),

            // Details
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
                  ),
                  if (item.variantLabel != null)
                    Text(
                      item.variantLabel!,
                      style: TextStyle(
                        fontSize: 14,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(item.unitPrice, item.currencyCode),
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(colorPrimary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity controls
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (item.qty > 1) {
                        item.qty--;
                      } else {
                        widget.cartItems.remove(item);
                      }
                      widget.onCartUpdated?.call();
                    });
                  },
                  icon: Icon(
                    item.qty > 1 ? Icons.remove_circle_outline : Icons.delete_outline,
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  item.qty.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      item.qty++;
                      widget.onCartUpdated?.call();
                    });
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtotalRow(bool dark) {
    final currencyCode = widget.listing.storeCurrencyCode ?? widget.listing.currencyCode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Subtotal'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          _formatCurrency(_subtotal, currencyCode),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(colorPrimary),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
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

  Widget _buildLocationPinButton(bool dark) {
    final hasLocation = _deliveryLatitude != null && _deliveryLongitude != null;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: hasLocation ? Color(colorPrimary) : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
        color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          splashColor: Colors.transparent,
          leading: Icon(
            hasLocation ? Icons.location_on : Icons.location_on_outlined,
            color: hasLocation ? Color(colorPrimary) : (dark ? Colors.white70 : Colors.black54),
          ),
          title: Text(
            hasLocation ? 'Location Pinned'.tr() : 'Pin Delivery Location'.tr(),
            style: TextStyle(
              color: dark ? Colors.white : Colors.black,
              fontWeight: hasLocation ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: hasLocation
              ? Text(
                  '$_deliveryLatitude, $_deliveryLongitude',
                  style: TextStyle(
                    color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                )
              : Text(
                  'Tap to pin your delivery location on map'.tr(),
                  style: TextStyle(
                    color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
          trailing: Icon(
            Icons.chevron_right,
            color: dark ? Colors.white70 : Colors.black54,
          ),
          onTap: () => _openLocationPicker(dark),
        ),
      ),
    );
  }

  Future<void> _openLocationPicker(bool dark) async {
    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        showSnackBar(context, 'Location permission is required for delivery'.tr());
        return;
      }
    }

    if (!mounted) return;

    // Show location picker dialog
    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => LocationPickerDialog(
        initialLatitude: _deliveryLatitude,
        initialLongitude: _deliveryLongitude,
        isDarkMode: dark,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _deliveryLatitude = result['latitude'];
        _deliveryLongitude = result['longitude'];
      });
    }
  }

  Future<void> _pickDateTime() async {
    final dark = isDarkMode(context);
    
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(hours: widget.listing.storeLeadTimeHours)),
      firstDate: DateTime.now().add(Duration(hours: widget.listing.storeLeadTimeHours)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            primaryColor: Color(colorPrimary),
            colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.blue,
              brightness: dark ? Brightness.dark : Brightness.light,
            ).copyWith(
              primary: Color(colorPrimary),
              surface: dark ? Colors.grey.shade900 : Colors.white,
            ),
            textTheme: dark
                ? ThemeData.dark().textTheme
                : ThemeData.light().textTheme,
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              primaryColor: Color(colorPrimary),
              colorScheme: ColorScheme.fromSwatch(
                primarySwatch: Colors.blue,
                brightness: dark ? Brightness.dark : Brightness.light,
              ).copyWith(
                primary: Color(colorPrimary),
                surface: dark ? Colors.grey.shade900 : Colors.white,
              ),
              textTheme: dark
                  ? ThemeData.dark().textTheme
                  : ThemeData.light().textTheme,
            ),
            child: child!,
          );
        },
      );

      if (time != null && mounted) {
        setState(() {
          _preferredDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submitOrder() async {
    // Check user is logged in
    if (widget.currentUser == null) {
      showSnackBar(context, 'Please sign in to place an order'.tr());
      return;
    }

    // Validate delivery address
    if (_fulfillmentMethod == FulfillmentMethod.delivery && _addressController.text.trim().isEmpty) {
      showSnackBar(context, 'Please enter delivery address'.tr());
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Build order items
      final orderItems = widget.cartItems.map((cartItem) {
        return OrderItem(
          itemId: cartItem.itemId,
          name: cartItem.name,
          qty: cartItem.qty,
          unitPrice: cartItem.unitPrice,
          variant: cartItem.variant,
        );
      }).toList();

      // Create fulfillment info
      final fulfillment = FulfillmentInfo(
        method: _fulfillmentMethod,
        address: _fulfillmentMethod == FulfillmentMethod.delivery ? _addressController.text.trim() : null,
        latitude: _fulfillmentMethod == FulfillmentMethod.delivery ? _deliveryLatitude : null,
        longitude: _fulfillmentMethod == FulfillmentMethod.delivery ? _deliveryLongitude : null,
        preferredAt: _preferredDate,
      );

      // Create order request
      final orderRequest = OrderRequest(
        id: '', // Will be set by service
        listingId: widget.listing.id,
        listerId: widget.listing.authorID,
        customerId: widget.currentUser!.userID,
        status: OrderStatus.requested,
        items: orderItems,
        estimatedTotal: _subtotal,
        currencyCode: widget.listing.storeCurrencyCode ?? widget.listing.currencyCode,
        fulfillment: fulfillment,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Create order via service
      final orderId = await _storeService.createOrderRequest(
        orderRequest: orderRequest,
        customer: widget.currentUser!,
      );

      // Ensure chat channel and post message
      final channelId = await _chatHelper.ensureOrderChannel(
        listing: widget.listing,
        customerId: widget.currentUser!.userID,
        listerId: widget.listing.authorID,
      );

      // Update order with channelId
      await FirebaseFirestore.instance.collection('order_requests').doc(orderId).update({
        'channelId': channelId,
      });

      // Post order message to chat
      await _chatHelper.postOrderRequestMessage(
        channelId: channelId,
        order: orderRequest.copyWith(id: orderId, channelId: channelId),
        customer: widget.currentUser!,
      );

      if (!mounted) return;

      // Clear cart and refresh
      widget.cartItems.clear();
      widget.onCartUpdated?.call();

      // Get root context before popping screens
      final rootContext = context;
      
      // Close cart and return to listing detail
      Navigator.of(context).pop(); // Close cart
      Navigator.of(context).pop(); // Close store browse

      // Show success snackbar with action to view order
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Order request sent successfully!'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(colorPrimary),
          duration: const Duration(seconds: 6),
          action: widget.currentUser != null
              ? SnackBarAction(
                  label: 'View'.tr(),
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to customer orders screen using root navigator
                    Navigator.of(rootContext, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (context) => CustomerOrdersScreen(
                          currentUser: widget.currentUser!,
                        ),
                      ),
                    );
                  },
                )
              : null,
          elevation: 8,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnackBar(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Location Picker Dialog
class LocationPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool isDarkMode;

  const LocationPickerDialog({
    Key? key,
    this.initialLatitude,
    this.initialLongitude,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late double _latitude;
  late double _longitude;
  late TextEditingController _latController;
  late TextEditingController _lngController;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude ?? 0;
    _longitude = widget.initialLongitude ?? 0;
    _latController = TextEditingController(text: _latitude.toString());
    _lngController = TextEditingController(text: _longitude.toString());
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _latController.text = _latitude.toString();
        _lngController.text = _longitude.toString();
      });
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to get location: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _updateLocation() {
    try {
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);
      
      if (lat == null || lng == null) {
        showSnackBar(context, 'Invalid latitude or longitude'.tr());
        return;
      }
      
      Navigator.pop(context, {
        'latitude': lat,
        'longitude': lng,
      });
    } catch (e) {
      showSnackBar(context, 'Error parsing location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDarkMode ? Colors.grey.shade900 : Colors.white,
      title: Text(
        'Delivery Location'.tr(),
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use current location button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: _isLoadingLocation
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
                label: Text(
                  'Use Current Location'.tr(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrimary != 0 ? Color(colorPrimary) : Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Or manually enter coordinates
            Text(
              'Or enter coordinates manually:'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            
            // Latitude field
            TextField(
              controller: _latController,
              style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Latitude'.tr(),
                labelStyle: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              onChanged: (value) {
                _latitude = double.tryParse(value) ?? _latitude;
              },
            ),
            const SizedBox(height: 12),
            
            // Longitude field
            TextField(
              controller: _lngController,
              style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Longitude'.tr(),
                labelStyle: TextStyle(
                  color: widget.isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: widget.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              onChanged: (value) {
                _longitude = double.tryParse(value) ?? _longitude;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel'.tr(),
            style: TextStyle(
              color: widget.isDarkMode ? Colors.grey.shade400 : Colors.black54,
            ),
          ),
        ),
        TextButton(
          onPressed: _updateLocation,
          child: Text(
            'Confirm'.tr(),
            style: TextStyle(
              color: colorPrimary != 0 ? Color(colorPrimary) : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
