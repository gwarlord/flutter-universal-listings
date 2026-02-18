import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/main.dart' hide showSnackBar;
import 'package:caribtap/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/chat/chat/firestore_chat_screen_v2.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/order_request.dart';
import 'package:caribtap/listings/model/table_mode_models.dart';
import 'package:caribtap/listings/api/firebase/table_mode_firebase.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/listings/utils/subscription_helper.dart';
import 'package:caribtap/screens/store/order_chat_helper.dart';
import 'package:caribtap/screens/store/shipping_tracking_card.dart';
import 'package:caribtap/screens/store/shipping_tracking_display.dart';
import 'package:firebase_storage/firebase_storage.dart';


/// Order detail screen with status management actions
class OrderDetailScreen extends StatefulWidget {
  final OrderRequest order;
  final ListingsUser currentUser;
  final bool viewAsLister;

  const OrderDetailScreen({
    Key? key,
    required this.order,
    required this.currentUser,
    this.viewAsLister = false,
  }) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final StoreService _storeService = StoreService();
  final OrderChatHelper _chatHelper = OrderChatHelper();
  ListingsUser? _customer;
  ListingModel? _listing;
  bool _isUpdating = false;
  late OrderRequest _currentOrder;
  TableSessionModel? _tableSession;
  bool _isSummonCooldown = false;
  int _summonCooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    // CRITICAL: Verify Premium access only for listers viewing order requests
    // Customers can always view their own orders
    if (widget.viewAsLister && !isPremiumUser(widget.currentUser)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(context, '🔒 Premium subscription required');
        Navigator.pop(context);
      });
    }

    _loadListing();
    _loadCustomer();
    _loadTableSession();
  }

  Future<void> _loadListing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.order.listingId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _listing = ListingModel.fromJson(doc.data()!);
        });
      }
    } catch (e) {
      // Ignore error
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

  Future<void> _loadTableSession() async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('order_requests')
          .doc(widget.order.id)
          .get();

      if (orderDoc.exists) {
        final tableSessionId = orderDoc.data()?['tableSessionId'] as String?;

        if (tableSessionId != null) {
          final sessionDoc = await FirebaseFirestore.instance
              .collection('table_sessions')
              .doc(tableSessionId)
              .get();

          if (sessionDoc.exists && mounted) {
            final session = TableSessionModel.fromJson(sessionDoc.id, sessionDoc.data()!);
            setState(() {
              _tableSession = session;
              _isSummonCooldown = session.isSummonOnCooldown;
              _summonCooldownSeconds = session.remainingSummonCooldownSeconds;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading table session: $e');
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('order_requests')
            .doc(widget.order.id)
            .snapshots(),
        builder: (context, snapshot) {
          // Update order if snapshot has data
          if (snapshot.hasData && snapshot.data!.exists) {
            final updatedOrder = OrderRequest.fromJson(snapshot.data!.data() as Map<String, dynamic>);
            // This ensures we always have the latest order state
            _currentOrder = updatedOrder;
          }

          return _buildOrderContent(dark);
        },
      ),
      bottomNavigationBar: _buildActionButtons(dark),
    );
  }

  Widget _buildOrderContent(bool dark) {
    final bool requiresProofOfPayment = _listing?.payments['acceptProofOfPayment'] ?? false;
    final bool canUploadProof = !widget.viewAsLister &&
        _currentOrder.status == OrderStatus.confirmed &&
        requiresProofOfPayment &&
        (_currentOrder.payment?['proofOfPaymentUrl'] == null ||
            _currentOrder.payment!['proofOfPaymentUrl'].isEmpty);
    final bool hasProofOfPayment =
        _currentOrder.payment?['proofOfPaymentUrl'] != null &&
        _currentOrder.payment!['proofOfPaymentUrl'].isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Order ID
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order #${_currentOrder.id.substring(0, 8).toUpperCase()}',
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.white54 : Colors.black45,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              color: dark ? Colors.white54 : Colors.black45,
              tooltip: 'Copy order number'.tr(),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _currentOrder.id.substring(0, 8).toUpperCase()),
                );
                showSnackBar(context, 'Order number copied'.tr());
              },
            ),
          ],
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

        // Total with shipping breakdown
        Card(
          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    Text(
                      _formatCurrency(_currentOrder.items.fold(0.0, (sum, item) {
                        return sum + (item.qty * item.unitPrice);
                      })),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (_currentOrder.fulfillment.method == FulfillmentMethod.shipping && _currentOrder.shipping?.hasData == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shipping Fee'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        _formatCurrency(
                          _currentOrder.estimatedTotal -
                              _currentOrder.items.fold(0.0, (sum, item) {
                                return sum + (item.qty * item.unitPrice);
                              })
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(cfg.colorPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                  const SizedBox(height: 12),
                ],
                Row(
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
                          : widget.order.fulfillment.method == FulfillmentMethod.dineIn
                              ? Icons.restaurant_outlined
                              : widget.order.fulfillment.method == FulfillmentMethod.shipping
                                  ? Icons.local_shipping_outlined
                                  : Icons.delivery_dining_outlined,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.order.fulfillment.method == FulfillmentMethod.pickup
                          ? 'Pickup'.tr()
                          : widget.order.fulfillment.method == FulfillmentMethod.dineIn
                              ? 'Dining In'.tr()
                              : widget.order.fulfillment.method == FulfillmentMethod.shipping
                                  ? 'Shipping'.tr()
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

                // Shipping details (address, instructions)
                if (_currentOrder.fulfillment.method == FulfillmentMethod.shipping && _currentOrder.shipping != null) ...[
                  if (_currentOrder.shipping?.address != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: dark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shipping Address'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark ? Colors.white54 : Colors.black45,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentOrder.shipping!.address!,
                                style: TextStyle(
                                  color: dark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_currentOrder.shipping?.instructions != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: dark ? Colors.white70 : Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instructions'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark ? Colors.white54 : Colors.black45,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentOrder.shipping!.instructions!,
                                style: TextStyle(
                                  color: dark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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

        // Proof of Payment Section (Customer Upload)
        if (canUploadProof) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Payment'.tr(), dark),
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'This order requires proof of payment. Please upload a receipt or screenshot.'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploadProofOfPayment,
                      icon: const Icon(Icons.upload_file),
                      label: Text('Upload Proof of Payment'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(cfg.colorPrimary),
                        side: BorderSide(color: Color(cfg.colorPrimary).withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Proof of Payment Section (Lister View)
        if (widget.viewAsLister && hasProofOfPayment)
          _buildListerProofOfPaymentSection(dark),

        // Shipping Tracking Section (only for SHIPPING orders)
        if (_currentOrder.fulfillment.method == FulfillmentMethod.shipping) ...[
          const SizedBox(height: 16),

          // Show saved tracking info to everyone (lister and customer)
          if (_currentOrder.shipping?.trackingNumber != null)
            ShippingTrackingDisplay(order: _currentOrder),

          // Show editable form to lister (below the display if tracking exists)
          if (widget.viewAsLister) ...[
            if (_currentOrder.shipping?.trackingNumber != null)
              const SizedBox(height: 16),
            ShippingTrackingCard(
              order: _currentOrder,
              currentUser: widget.currentUser,
              onTrackingUpdated: () {}, // StreamBuilder handles updates
            ),
          ],
        ],

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
        if (_currentOrder.listerNotes != null && _currentOrder.listerNotes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Seller Note'.tr(), dark),
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _currentOrder.listerNotes!,
                style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ],

        // Table Mode Actions (for customers in active table sessions)
        if (!widget.viewAsLister &&
            _tableSession != null &&
            _tableSession!.status == TableSessionStatus.ACTIVE &&
            (_currentOrder.status == OrderStatus.confirmed ||
                _currentOrder.status == OrderStatus.preparing ||
                _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.served)) ...[
          const SizedBox(height: 16),
          _buildSectionTitle('Table Service'.tr(), dark),
          Card(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Waiter info
                  if (_tableSession!.assignedStaff.isNotEmpty) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(_tableSession!.assignedStaff.first.photoUrl),
                          backgroundColor: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your ${_tableSession!.assignedStaff.first.role.toLowerCase()}'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                              Text(
                                _tableSession!.assignedStaff.first.firstName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: dark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: dark ? Colors.grey.shade700 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                  ],
                  // Summon Waiter button
                  ElevatedButton.icon(
                    onPressed: _isSummonCooldown ? null : _summonWaiter,
                    icon: Icon(_isSummonCooldown ? Icons.timer : Icons.pan_tool),
                    label: Text(
                      _isSummonCooldown
                          ? 'Wait ${_summonCooldownSeconds}s'.tr()
                          : 'Summon Waiter'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSummonCooldown ? Colors.grey : Color(cfg.colorPrimary),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Request Bill button
                  OutlinedButton.icon(
                    onPressed: _requestBill,
                    icon: const Icon(Icons.receipt_long),
                    label: Text('Request Bill'.tr(), style: const TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(cfg.colorPrimary),
                      side: BorderSide(color: Color(cfg.colorPrimary), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Date
        const SizedBox(height: 16),
        Text(
          'Created: ${_currentOrder.createdAt != null ? DateFormat('MMM d, y • h:mm a').format(_currentOrder.createdAt!.toDate()) : 'N/A'}',
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildListerProofOfPaymentSection(bool dark) {
    final status = _currentOrder.payment?['proofOfPaymentStatus'] ?? 'pending';
    final imageUrl = _currentOrder.payment!['proofOfPaymentUrl'];
    final rejectionReason = _currentOrder.payment?['rejectionReason'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionTitle('Proof of Payment'.tr(), dark),
        Card(
          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Chip
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildPOPStatusChip(status, dark),
                ),
                if (rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Reason: $rejectionReason'.tr(),
                    style: TextStyle(color: Colors.red.shade300),
                  ),
                ],
                const SizedBox(height: 16),

                // Image Preview
                GestureDetector(
                  onTap: () => push(
                    context,
                    FullScreenImageViewer(imageUrl: imageUrl),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  ),
                ),

                // Action Buttons
                if (status == 'pending') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejectProofOfPayment,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: Text('Reject'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateProofOfPaymentStatus('approved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text('Approve'.tr(), style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPOPStatusChip(String status, bool dark) {
    late Color color;
    late String label;
    late IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved'.tr();
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected'.tr();
        icon = Icons.cancel;
        break;
      default: // pending
        color = Colors.orange;
        label = 'Pending Review'.tr();
        icon = Icons.hourglass_empty;
    }
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
      labelStyle: TextStyle(color: dark ? Colors.white : Colors.black),
      backgroundColor: color.withOpacity(0.2),
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
      case OrderStatus.preparing:
        color = Colors.purple;
        label = 'Preparing'.tr();
        icon = Icons.restaurant_menu;
        break;
      case OrderStatus.ready:
        color = Colors.teal;
        label = 'Ready'.tr();
        icon = Icons.done_all;
        break;
      case OrderStatus.served:
        color = Colors.indigo;
        label = 'Served'.tr();
        icon = Icons.room_service;
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
            // Item Image
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.photoUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      color: dark ? Colors.grey.shade600 : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Item Details
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
    // Use viewAsLister parameter to determine which actions to show
    // This handles cases where user might be both customer and lister
    final isLister = widget.viewAsLister;
    final isCustomer = !widget.viewAsLister;

    // Customer can only cancel requested orders
    if (isCustomer && _currentOrder.status == OrderStatus.requested) {
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
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.cancelled),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Cancel Order'.tr(),
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Lister can perform various status updates
    if (!isLister) {
      return null;
    }

    // No actions for declined, cancelled, or fulfilled orders
    if (_currentOrder.status == OrderStatus.declined ||
        _currentOrder.status == OrderStatus.cancelled ||
        _currentOrder.status == OrderStatus.fulfilled) {
      return null;
    }

    final isDineIn = _currentOrder.fulfillment.method == FulfillmentMethod.dineIn;

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
      child: _buildListerActionButtons(isDineIn, dark),
    );
  }

  Widget _buildListerActionButtons(bool isDineIn, bool dark) {
    // Requested: Decline or Confirm/Fulfill
    if (_currentOrder.status == OrderStatus.requested) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : () async {
                      final notes = await _promptDeclineNotes();
                      if (notes == null) return;
                      await _updateStatus(OrderStatus.declined, listerNotes: notes);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Decline'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : () => _updateStatus(
                        isDineIn ? OrderStatus.confirmed : OrderStatus.confirmed,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Confirm'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ],
      );
    }

    // Confirmed: Start Preparing (for dine-in) or Mark Fulfilled (for other methods)
    if (_currentOrder.status == OrderStatus.confirmed) {
      if (isDineIn) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.preparing),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start Preparing'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
          ),
        );
      } else {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.fulfilled),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Mark Fulfilled'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
          ),
        );
      }
    }

    // Preparing: Mark as Ready
    if (_currentOrder.status == OrderStatus.preparing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.ready),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Mark Ready'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      );
    }

    // Ready: Mark as Served
    if (_currentOrder.status == OrderStatus.ready) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.served),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Mark Served'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      );
    }

    // Served: Mark as Fulfilled
    if (_currentOrder.status == OrderStatus.served) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isUpdating ? null : () => _updateStatus(OrderStatus.fulfilled),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('Mark Fulfilled'.tr(), style: const TextStyle(fontSize: 16, color: Colors.white)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<String?> _promptDeclineNotes() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dark = isDarkMode(dialogContext);
        return AlertDialog(
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Decline Order'.tr(),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            style: TextStyle(color: dark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Add a note for the customer'.tr(),
              hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: dark ? Colors.white24 : Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(cfg.colorPrimary)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'.tr(), style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Decline'.tr(), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(OrderStatus newStatus, {String? listerNotes}) async {
    setState(() => _isUpdating = true);

    try {
      final isCustomer = !widget.viewAsLister;

      // Customer can only cancel their order
      if (isCustomer && newStatus == OrderStatus.cancelled) {
        await _storeService.cancelOrder(
          requestId: widget.order.id,
          currentUser: widget.currentUser,
        );
      } else if (isCustomer) {
        // Customer can't perform other actions
        throw Exception('You can only cancel your pending orders');
      } else {
        // Lister updating order status
        await _storeService.updateOrderStatus(
          requestId: widget.order.id,
          status: newStatus,
          currentUser: widget.currentUser,
          listerNotes: listerNotes,
        );
      }

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

  Future<void> _uploadProofOfPayment() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File imageFile = File(image.path);

      showProgress(context, 'Uploading...'.tr(), false, Color(cfg.colorPrimary));

      try {
        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();
        final fileName =
            'proof_of_payment/${_currentOrder.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final proofRef = storageRef.child(fileName);
        final uploadTask = await proofRef.putFile(imageFile);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        // Update order in Firestore
        await FirebaseFirestore.instance.collection('order_requests').doc(_currentOrder.id).update({
          'payment.proofOfPaymentUrl': downloadUrl,
          'payment.proofOfPaymentStatus': 'pending',
          'payment.proofSubmittedAt': FieldValue.serverTimestamp(),
        });

        hideProgress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Proof of payment uploaded successfully'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        hideProgress();
        if (mounted) {
          showAlertDialog(context, 'Error'.tr(), 'Failed to upload proof of payment'.tr());
        }
      }
    }
  }

  Future<void> _rejectProofOfPayment() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Reject Payment?'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Reason for rejection (optional)'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('Reject'.tr()),
            ),
          ],
        );
      },
    );

    if (reason != null) {
      await _updateProofOfPaymentStatus('rejected', rejectionReason: reason);
    }
  }

  Future<void> _updateProofOfPaymentStatus(String status, {String? rejectionReason}) async {
    showProgress(context, 'Updating...'.tr(), false, Color(cfg.colorPrimary));
    try {
      final Map<String, dynamic> updateData = {
        'payment.proofOfPaymentStatus': status,
      };
      if (rejectionReason != null) {
        updateData['payment.rejectionReason'] = rejectionReason;
      }
      // If rejecting, clear the URL so the user can re-upload
      if (status == 'rejected') {
        updateData['payment.proofOfPaymentUrl'] = null;
      }

      await FirebaseFirestore.instance
          .collection('order_requests')
          .doc(_currentOrder.id)
          .update(updateData);
      hideProgress();
    } catch (e) {
      hideProgress();
      showAlertDialog(context, 'Error'.tr(), 'Failed to update status'.tr());
    }
  }



  Future<void> _summonWaiter() async {
    if (_tableSession == null) return;

    final purpose = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dark = isDarkMode(dialogContext);
        return AlertDialog(
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Summon Waiter'.tr(),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.help_outline, color: Color(cfg.colorPrimary)),
                title: Text('Need Assistance'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'ASSISTANCE'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.fastfood, color: Color(cfg.colorPrimary)),
                title: Text('Ready to Order'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'ORDER'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.cleaning_services, color: Color(cfg.colorPrimary)),
                title: Text('Table Needs Cleaning'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'CLEANING'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.chat_bubble_outline, color: Color(cfg.colorPrimary)),
                title: Text('General Request'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'GENERAL'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );

    if (purpose == null) return;

    try {
      showProgress(context, 'Summoning waiter...'.tr(), false, Color(cfg.colorPrimary));

      await tableModeRepository.summonWaiter(
        sessionId: _tableSession!.sessionId,
        purpose: purpose,
      );

      hideProgress();

      // Reload table session to update cooldown
      await _loadTableSession();

      if (mounted) {
        showSnackBar(context, 'Waiter summoned successfully!'.tr());
      }
    } catch (e) {
      hideProgress();
      if (mounted) {
        showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _requestBill() async {
    if (_tableSession == null) return;

    final method = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final dark = isDarkMode(dialogContext);
        return AlertDialog(
          backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
          title: Text(
            'Request Bill'.tr(),
            style: TextStyle(color: dark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you like to pay?'.tr(),
                style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.money, color: Color(cfg.colorPrimary)),
                title: Text('Cash'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'CASH'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.credit_card, color: Color(cfg.colorPrimary)),
                title: Text('Card'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'CARD'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                leading: Icon(Icons.account_balance_wallet, color: Color(cfg.colorPrimary)),
                title: Text('Digital Payment'.tr()),
                onTap: () => Navigator.pop(dialogContext, 'DIGITAL'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        );
      },
    );

    if (method == null) return;

    try {
      showProgress(context, 'Requesting bill...'.tr(), false, Color(cfg.colorPrimary));

      await tableModeRepository.requestBill(
        sessionId: _tableSession!.sessionId,
        paymentMethod: method,
      );

      hideProgress();

      if (mounted) {
        showSnackBar(context, 'Bill requested successfully! Your waiter will be with you shortly.'.tr());
      }
    } catch (e) {
      hideProgress();
      if (mounted) {
        showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
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
