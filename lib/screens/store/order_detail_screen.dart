import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
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

    _loadCustomer();
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
          if (widget.order.channelId != null)
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
            'Order #${widget.order.id.substring(0, 8).toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),

          // Status
          _buildStatusChip(widget.order.status, dark),
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
          ...widget.order.items.map((item) => _buildItemCard(item, dark)),
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
                    _formatCurrency(widget.order.estimatedTotal, widget.order.currencyCode),
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
                  if (widget.order.fulfillment.address != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.order.fulfillment.address!,
                      style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                  if (widget.order.fulfillment.preferredAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: dark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 4),
                        Text(
                          'Preferred: ${DateFormat('MMM d, y • h:mm a').format(widget.order.fulfillment.preferredAt!)}',
                          style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Notes
          if (widget.order.notes != null && widget.order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionTitle('Notes'.tr(), dark),
            Card(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.order.notes!,
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
              ),
            ),
          ],

          // Date
          const SizedBox(height: 16),
          Text(
            'Created: ${widget.order.createdAt != null ? DateFormat('MMM d, y • h:mm a').format(widget.order.createdAt!.toDate()) : 'N/A'}',
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

  Widget _buildStatusChip(OrderStatus status, bool dark) {
    Color color;
    String label;
    IconData icon;

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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
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
              _formatCurrency(item.total, widget.order.currencyCode),
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
    if (widget.order.status != OrderStatus.requested &&
        widget.order.status != OrderStatus.confirmed) {
      return null;
    }

    return Container(
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
      child: widget.order.status == OrderStatus.requested
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
    if (widget.order.channelId == null) return;

    Navigator.pushNamed(
      context,
      '/chatConversation',
      arguments: {
        'currentUser': widget.currentUser,
        'channelId': widget.order.channelId,
      },
    );
  }
}
