import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/core/ui/chat/chat/firestore_chat_screen_v2.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/order_request.dart';
import 'package:instaflutter/listings/services/store_service.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
import 'package:instaflutter/screens/store/order_chat_helper.dart';

/// Order detail screen with status management actions
class OrderDetailScreen extends StatefulWidget {
  final OrderRequest order;
  final ListingsUser currentUser;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final StoreService _storeService = StoreService();
  final OrderChatHelper _chatHelper = OrderChatHelper();
  ListingsUser? _customer;
  bool _isUpdating = false;
  late OrderRequest _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    // CRITICAL: Verify Premium access
    if (!isPremiumUser(widget.currentUser)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(context, '🔒 Premium subscription required');
        Navigator.pop(context);
      });
    }

    _loadOrderDetails();
    _loadCustomer();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('order_requests')
          .doc(widget.order.id)
          .get();
      if (doc.exists && mounted) {
        final updatedOrder = OrderRequest.fromJson(doc.data()!);
        setState(() {
          _currentOrder = updatedOrder;
        });
      }
    } catch (e) {
      // Ignore error - use local order data
    }
  }

  Future<void> _loadCustomer() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.order.customerId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _customer = ListingsUser.fromJson(doc.data()!);
        });
      }
    } catch (e) {
      // Ignore error
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
          'Order Details'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          if (_currentOrder.channelId != null)
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: _openChat,
              tooltip: 'Open Chat'.tr(),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order ID
          Text(
            'Order #${_currentOrder.id.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),

          // Status
          _buildStatusChip(_currentOrder.status, dark),
          const SizedBox(height: 24),

          // Customer info
          _buildSectionTitle('Customer'.tr(), dark),
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: _customer?.profilePictureURL != null &&
                        _customer!.profilePictureURL.isNotEmpty
                    ? NetworkImage(_customer!.profilePictureURL)
                    : null,
                child: _customer?.profilePictureURL == null ||
                        _customer!.profilePictureURL.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(
                _customer?.fullName() ?? 'Loading...'.tr(),
                style: TextStyle(color: dark ? Colors.white : Colors.black),
              ),
              subtitle: Text(
                _customer?.email ?? '',
                style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          _buildSectionTitle('Items'.tr(), dark),
          ..._currentOrder.items.map((item) => _buildItemCard(item, dark)),
          const SizedBox(height: 16),

          // Total
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total'.tr(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    _formatCurrency(widget.order.estimatedTotal),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(cfg.colorPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fulfillment
          _buildSectionTitle('Fulfillment'.tr(), dark),
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.order.fulfillment.method == FulfillmentMethod.pickup
                            ? Icons.store_outlined
                            : Icons.local_shipping_outlined,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.order.fulfillment.method == FulfillmentMethod.pickup
                            ? 'Pickup'.tr()
                            : 'Delivery'.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (_currentOrder.fulfillment.address != null) ...[
                    const SizedBox(height: 12),
                    // Tappable address with navigation
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canNavigate()
                            ? () => _navigateToDelivery()
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: _canNavigate()
                                        ? Color(cfg.colorPrimary)
                                        : (dark ? Colors.white70 : Colors.black54),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentOrder.fulfillment.address!,
                                      style: TextStyle(
                                        color: _canNavigate()
                                            ? Color(cfg.colorPrimary)
                                            : (dark ? Colors.white70 : Colors.black54),
                                        fontWeight: _canNavigate() ? FontWeight.w600 : FontWeight.normal,
                                        decoration: _canNavigate() ? TextDecoration.underline : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_canNavigate())
                                Padding(
                                  padding: const EdgeInsets.only(left: 24, top: 4),
                                  child: Text(
                                    'Tap to navigate'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(cfg.colorPrimary),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_currentOrder.fulfillment.preferredAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: dark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          'Preferred: ${DateFormat('MMM d, y • h:mm a').format(_currentOrder.fulfillment.preferredAt!)}',
                          style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                  // Order action section for lister
                  const SizedBox(height: 12),
                  Divider(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  if (_currentOrder.status == OrderStatus.requested)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'This order is pending your response'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Share buttons
                  const SizedBox(height: 12),
                  Divider(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildShareButton(
                          icon: Icons.mail,
                          label: 'Email'.tr(),
                          onPressed: _shareViaEmail,
                          dark: dark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildShareButton(
                          icon: Icons.chat,
                          label: 'WhatsApp'.tr(),
                          onPressed: _shareViaWhatsApp,
                          dark: dark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildShareButton(
                          icon: Icons.share,
                          label: 'Share'.tr(),
                          onPressed: _shareOrder,
                          dark: dark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Notes
          if (_currentOrder.notes != null && _currentOrder.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Notes'.tr(), dark),
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _currentOrder.notes!,
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ],

          // Date
          const SizedBox(height: 16),
          Text(
            'Created: ${_currentOrder.createdAt != null ? DateFormat('MMM d, y • h:mm a').format(_currentOrder.createdAt!.toDate()) : 'N/A'}',,
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(dark),
    );
  }

  Widget _buildSectionTitle(String title, bool dark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: dark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  bool _canNavigate() {
    return _currentOrder.fulfillment.method == FulfillmentMethod.delivery &&
        _currentOrder.fulfillment.latitude != null &&
        _currentOrder.fulfillment.longitude != null;
  }

  Future<void> _navigateToDelivery() async {
    final lat = _currentOrder.fulfillment.latitude;
    final lng = _currentOrder.fulfillment.longitude;
    
    if (lat == null || lng == null) {
      showSnackBar(context, 'Location coordinates not available'.tr());
      return;
    }

    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';

    try {
      // Try Google Maps first
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
        // Fallback to Apple Maps
        await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
      } else {
        showSnackBar(context, 'No maps app available'.tr());
      }
    } catch (e) {
      showSnackBar(context, 'Error opening maps: $e');
    }
  }

  String _generateOrderSummary() {
    final buffer = StringBuffer();
    buffer.writeln('ORDER #${_currentOrder.id.substring(0, 8).toUpperCase()}');
    buffer.writeln('Status: ${_currentOrder.status.value}');
    buffer.writeln('');
    buffer.writeln('ITEMS:');
    for (var item in _currentOrder.items) {
      buffer.writeln('  • ${item.name} x${item.qty} @ ${_formatCurrency(item.unitPrice)}');
    }
    buffer.writeln('');
    buffer.writeln('Total: ${_formatCurrency(_currentOrder.estimatedTotal)}');
    buffer.writeln('');
    buffer.writeln('FULFILLMENT:');
    buffer.writeln('Method: ${_currentOrder.fulfillment.method.value}');
    if (_currentOrder.fulfillment.address != null) {
      buffer.writeln('Address: ${_currentOrder.fulfillment.address}');
    }
    if (_currentOrder.fulfillment.latitude != null && _currentOrder.fulfillment.longitude != null) {
      buffer.writeln('Coordinates: ${_currentOrder.fulfillment.latitude}, ${_currentOrder.fulfillment.longitude}');
      buffer.writeln('Maps: https://www.google.com/maps/search/?api=1&query=${_currentOrder.fulfillment.latitude},${_currentOrder.fulfillment.longitude}');
    }
    if (_currentOrder.fulfillment.preferredAt != null) {
      buffer.writeln('Preferred: ${DateFormat('MMM d, y • h:mm a').format(_currentOrder.fulfillment.preferredAt!)}');
    }
    if (_currentOrder.notes != null) {
      buffer.writeln('');
      buffer.writeln('Notes: ${_currentOrder.notes}');
    }
    return buffer.toString();
  }

  String _formatCurrency(double amount) {
    final symbol = _getCurrencySymbol(_currentOrder.currencyCode);
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

  Future<void> _shareViaEmail() async {
    final summary = _generateOrderSummary();
    final subject = 'Order #${_currentOrder.id.substring(0, 8).toUpperCase()} - ${_currentOrder.status.value}';
    
    try {
      final emailUrl = 'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(summary)}';
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        showSnackBar(context, 'No email app available'.tr());
      }
    } catch (e) {
      showSnackBar(context, 'Error sharing via email: $e');
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final summary = _generateOrderSummary();
    
    try {
      final whatsappUrl = 'https://wa.me/?text=${Uri.encodeComponent(summary)}';
      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(Uri.parse(whatsappUrl), mode: LaunchMode.externalApplication);
      } else {
        showSnackBar(context, 'WhatsApp not installed'.tr());
      }
    } catch (e) {
      showSnackBar(context, 'Error sharing via WhatsApp: $e');
    }
  }

  Future<void> _shareOrder() async {
    final summary = _generateOrderSummary();
    
    try {
      await Share.share(
        summary,
        subject: 'Order #${_currentOrder.id.substring(0, 8).toUpperCase()}',
      );
    } catch (e) {
      showSnackBar(context, 'Error sharing: $e');
    }
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool dark,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(cfg.colorPrimary),
        side: BorderSide(color: Color(cfg.colorPrimary)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status, bool dark) {
    late Color color;
    late String label;
    late IconData icon;

    switch (status) {
      case OrderStatus.requested:
        color = Colors.orange;
        label = 'Requested'.tr();
        icon = Icons.hourglass_empty;
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'Confirmed'.tr();
        icon = Icons.check_circle_outline;
        break;
      case OrderStatus.fulfilled:
        color = Colors.green;
        label = 'Fulfilled'.tr();
        icon = Icons.check_circle;
        break;
      case OrderStatus.declined:
        color = Colors.red;
        label = 'Declined'.tr();
        icon = Icons.cancel_outlined;
        break;
      case OrderStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled'.tr();
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (item.variant != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${item.variant!['size'] ?? ''}${item.variant!['size'] != null && item.variant!['color'] != null ? ', ' : ''}${item.variant!['color'] ?? ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              'x${item.qty}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              _formatCurrency(item.unitPrice * item.qty),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(cfg.colorPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildActionButtons(bool dark) {
    if (_currentOrder.status != OrderStatus.requested &&
        _currentOrder.status != OrderStatus.confirmed) {
      return null;
    }

    return Container(
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
      child: _currentOrder.status == OrderStatus.requested
          ? Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.declined),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Decline'.tr(),
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.confirmed),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Confirm'.tr(),
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.fulfilled),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Mark Fulfilled'.tr(),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
    );
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    setState(() => _isUpdating = true);

    try {
      // Update order status
      await _storeService.updateOrderStatus(
        requestId: widget.order.id,
        status: newStatus,
        currentUser: widget.currentUser,
      );

      // Post status update to chat if channel exists
      if (widget.order.channelId != null) {
        await _chatHelper.postOrderStatusMessage(
          channelId: widget.order.channelId!,
          order: widget.order,
          newStatus: newStatus,
          actor: widget.currentUser,
        );
      }

      if (!mounted) return;

      showSnackBar(context, 'Order updated successfully'.tr());
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showSnackBar(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
  void _openChat() {
    if (_currentOrder.channelId == null) return;

    // Load listing and lister info for the chat
    _loadListingForChat();
  }

  Future<void> _loadListingForChat() async {
    try {
      // Load the listing
      final listingDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.order.listingId)
          .get();

      if (!listingDoc.exists) {
        showSnackBar(context, 'Listing not found'.tr());
        return;
      }

      final listing = ListingModel.fromJson(listingDoc.data()!);

      // Load the lister details
      final listerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.order.listerId)
          .get();

      late List<User> otherParticipants;
      if (listerDoc.exists) {
        final listerData = listerDoc.data()!;
        otherParticipants = [
          User(
            userID: listerData['userId'] ?? _currentOrder.listerId,
            firstName: listerData['firstName'] ?? listerData['name'] ?? 'Lister',
            profilePictureURL: listerData['profilePictureURL'] ?? '',
          ),
        ];
      } else {
        otherParticipants = const [];
      }

      // Post order details summary to chat for lister reference
      await _postOrderSummaryToChat();

      if (!mounted) return;

      // Navigate to chat with listing and lister info
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FirestoreChatScreenV2(
            channelId: _currentOrder.channelId!,
            currentUserId: widget.currentUser.userID,
            listingTitle: listing.title,
            listingImage: listing.photo ?? '',
            otherParticipants: otherParticipants,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Error opening chat: $e');
      }
    }
  }

  Future<void> _postOrderSummaryToChat() async {
    try {
      final channelRef = FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(_currentOrder.channelId);

      // Check if order summary already exists in chat
      final messagesSnapshot = await channelRef
          .collection('thread')
          .where('metadata.isOrderSummary', isEqualTo: true)
          .limit(1)
          .get();

      // Only post if order summary doesn't already exist
      if (messagesSnapshot.docs.isEmpty) {
        final orderSummary = _generateOrderSummary();
        
        await channelRef.collection('thread').add({
          'content': orderSummary,
          'senderId': widget.currentUser.userID,
          'senderFirstName': widget.currentUser.firstName,
          'senderLastName': widget.currentUser.lastName,
          'senderProfilePictureURL': widget.currentUser.profilePictureURL,
          'created': Timestamp.now(),
          'type': 'order_summary',
          'metadata': {
            'isOrderSummary': true,
            'orderId': widget.order.id,
          },
        });
      }
    } catch (e) {
      // Silent fail - order summary is just a convenience
      print('Error posting order summary: $e');
    }
  }
}
