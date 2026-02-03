import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/order_request.dart';
import 'package:instaflutter/listings/services/store_service.dart';
import 'package:instaflutter/screens/store/cart_models.dart';
import 'package:instaflutter/screens/store/order_chat_helper.dart';
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
                  padding: const EdgeInsets.all(16),
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(hours: widget.listing.storeLeadTimeHours)),
      firstDate: DateTime.now().add(Duration(hours: widget.listing.storeLeadTimeHours)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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

      // Clear cart
      widget.cartItems.clear();
      widget.onCartUpdated?.call();

      if (!mounted) return;

      // Navigate to chat
      Navigator.of(context).pop(); // Close cart
      Navigator.of(context).pop(); // Close store browse

      // Navigate to chat screen
      Navigator.pushNamed(
        context,
        '/chatConversation',
        arguments: {
          'currentUser': widget.currentUser,
          'channelId': channelId,
        },
      );

      showSnackBar(context, 'Order request sent successfully!'.tr());
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
