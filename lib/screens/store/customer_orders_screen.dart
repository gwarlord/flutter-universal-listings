import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/order_request.dart';
import 'package:caribtap/listings/model/table_mode_models.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/screens/store/order_detail_screen.dart';
import 'package:caribtap/screens/store/shipping_tracking_display.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Screen for customers to view their order history
class CustomerOrdersScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const CustomerOrdersScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final Map<String, ListingModel> _listingCache = {};
  final Map<String, ListingsUser> _listerCache = {};
  bool _showHistory = false; // Toggle between active orders and all orders
  late final StoreService _storeService = StoreService();

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Column(
      children: [
        // Filter toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: dark ? Colors.grey.shade900 : Colors.grey.shade100,
            border: Border(
              bottom: BorderSide(
                color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showHistory ? 'All Orders'.tr() : 'Active Orders'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showHistory = !_showHistory;
                  });
                },
                icon: Icon(
                  _showHistory ? Icons.filter_list_off : Icons.history,
                  size: 20,
                ),
                label: Text(_showHistory ? 'Active Only'.tr() : 'Show History'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: Color(cfg.colorPrimary),
                ),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: StreamBuilder<List<OrderRequest>>(
            stream: _storeService.getOrderRequestsForCustomer(
              customerId: widget.currentUser.userID,
            ),
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
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: dark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No orders yet'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Orders you place will appear here'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: dark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                );
              }

              var allOrders = snapshot.data!;

              // Filter orders based on toggle
              final filteredOrders = _showHistory
                  ? allOrders
                  : allOrders
                      .where((o) =>
                          o.status == OrderStatus.requested ||
                          o.status == OrderStatus.confirmed ||
                          o.status == OrderStatus.preparing ||
                          o.status == OrderStatus.ready ||
                          o.status == OrderStatus.served)
                      .toList();

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: dark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showHistory ? 'No order history'.tr() : 'No active orders'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order, dark, context);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderRequest order, bool dark, BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getOrderPreviewData(order),
      builder: (context, previewSnapshot) {
        if (previewSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final previewData = previewSnapshot.data ?? {};
        final listing = previewData['listing'] as ListingModel?;
        final listingTitle =
            listing?.title ?? 'Order ${order.id.substring(0, 8)}';
        final firstItemImage = previewData['firstItemImage'] as String?;
        final isTableMode = previewData['tableSessionId'] != null;
        final tableName = previewData['tableName'] as String?;
        final assignedStaff = previewData['assignedStaff'] as List<AssignedStaff>? ?? [];
        final isOrderActive = order.status == OrderStatus.requested ||
            order.status == OrderStatus.confirmed ||
            order.status == OrderStatus.preparing ||
            order.status == OrderStatus.ready ||
            order.status == OrderStatus.served;

        final bool requiresProofOfPayment =
            listing?.payments['acceptProofOfPayment'] ?? false;
        final bool canUploadProof = order.status == OrderStatus.confirmed &&
            requiresProofOfPayment &&
            (order.payment?['proofOfPaymentUrl'] == null ||
                order.payment!['proofOfPaymentUrl'].isEmpty);

        return Card(
          color: dark ? Colors.grey.shade900 : Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailScreen(
                    order: order,
                    currentUser: widget.currentUser,
                    viewAsLister: false,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(order.status),
                      Text(
                        '${_getCurrencySymbol(order.currencyCode)}${order.estimatedTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),

                  // Assigned waiter info (only for active table mode orders)
                  if (isTableMode && isOrderActive && assignedStaff.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(assignedStaff.first.photoUrl),
                          backgroundColor: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${'Your waiter'.tr()}: ${assignedStaff.first.firstName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: dark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const Divider(height: 24),

                  // Image and order info
                  Row(
                    children: [
                      // Image thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                          child: firstItemImage != null && firstItemImage.isNotEmpty
                              ? Image.network(
                                  firstItemImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.shopping_bag,
                                      color: dark ? Colors.white38 : Colors.black38,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.shopping_bag,
                                  color: dark ? Colors.white38 : Colors.black38,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Order info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listingTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: dark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Order #${order.id.substring(0, 8).toUpperCase()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Items count and fulfillment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            // Fulfillment method icon and text
                            Icon(
                              order.fulfillment.method.value == 'pickup'
                                  ? Icons.store
                                  : order.fulfillment.method.value == 'dine_in'
                                      ? Icons.restaurant
                                      : Icons.local_shipping,
                              size: 16,
                              color: dark ? Colors.white54 : Colors.black54,
                            ),
                            Text(
                              order.fulfillment.method.value == 'pickup'
                                  ? 'Pickup'.tr()
                                  : order.fulfillment.method.value == 'dine_in'
                                      ? 'Dining In'.tr()
                                      : 'Shipping'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.white54 : Colors.black54,
                              ),
                            ),

                            // Table name chip (if applicable and active)
                            if (isTableMode && isOrderActive)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Color(cfg.colorPrimary).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tableName ?? 'Table'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(cfg.colorPrimary),
                                  ),
                                ),
                              ),

                            // Item count
                            Text(
                              '• ${order.items.length} ${'Items'.tr()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: dark ? Colors.white54 : Colors.black54,
                              ),
                            ),

                            // Show tracking chip if order has shipping tracking
                            if (order.fulfillment.method.value == 'shipping' &&
                                order.shipping?.trackingNumber != null)
                              const ShippingTrackingChip(),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(order.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),

                  // Proof of Payment section
                  if (canUploadProof) ...[
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _uploadProofOfPayment(order),
                        icon: const Icon(Icons.upload_file),
                        label: Text('Upload Proof of Payment'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(cfg.colorPrimary),
                          side: BorderSide(color: Color(cfg.colorPrimary).withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    late Color bgColor;
    late Color textColor;
    late String label;

    switch (status) {
      case OrderStatus.requested:
        bgColor = Colors.yellow.shade100;
        textColor = Colors.yellow.shade800;
        label = 'Pending'.tr();
        break;
      case OrderStatus.confirmed:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        label = 'Confirmed'.tr();
        break;
      case OrderStatus.preparing:
        bgColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
        label = 'Preparing'.tr();
        break;
      case OrderStatus.ready:
        bgColor = Colors.teal.shade100;
        textColor = Colors.teal.shade900;
        label = 'Ready'.tr();
        break;
      case OrderStatus.served:
        bgColor = Colors.indigo.shade100;
        textColor = Colors.indigo.shade900;
        label = 'Served'.tr();
        break;
      case OrderStatus.fulfilled:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        label = 'Completed'.tr();
        break;
      case OrderStatus.declined:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        label = 'Declined'.tr();
        break;
      case OrderStatus.cancelled:
        bgColor = Colors.grey.shade300;
        textColor = Colors.grey.shade800;
        label = 'Cancelled'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Future<ListingModel?> _getListingCached(String listingId) async {
    if (_listingCache.containsKey(listingId)) {
      return _listingCache[listingId];
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .get();

      if (doc.exists) {
        final listing = ListingModel.fromJson(doc.data()!);
        _listingCache[listingId] = listing;
        return listing;
      }
    } catch (e) {
      // Ignore error
    }

    return null;
  }

  Future<Map<String, dynamic>> _getOrderPreviewData(OrderRequest order) async {
    final result = <String, dynamic>{};

    // Get listing
    final listing = await _getListingCached(order.listingId);
    result['listing'] = listing;

    // Get first item image
    if (order.items.isNotEmpty) {
      try {
        final firstItemId = order.items.first.itemId;
        final itemDoc = await FirebaseFirestore.instance
            .collection('listings')
            .doc(order.listingId)
            .collection('catalog_items')
            .doc(firstItemId)
            .get();

        if (itemDoc.exists) {
          final itemData = itemDoc.data();
          final photos = itemData?['photos'] as List?;
          if (photos != null && photos.isNotEmpty) {
            result['firstItemImage'] = photos.first;
          }
        }
      } catch (e) {
        // Ignore error, will show default icon
      }
    }

    // Check if this order is associated with a table session
    try {
      final orderDoc =
          await FirebaseFirestore.instance.collection('order_requests').doc(order.id).get();

      if (orderDoc.exists) {
        final orderData = orderDoc.data();
        final tableSessionId = orderData?['tableSessionId'] as String?;
        result['tableSessionId'] = tableSessionId;
        result['tableName'] = orderData?['tableName'];
        result['tableId'] = orderData?['tableId'];

        if (tableSessionId != null) {
          final sessionDoc = await FirebaseFirestore.instance
              .collection('table_sessions')
              .doc(tableSessionId)
              .get();
          if (sessionDoc.exists) {
            final session = TableSessionModel.fromJson(sessionDoc.id, sessionDoc.data()!);
            result['assignedStaff'] = session.assignedStaff;
          }
        }
      }
    } catch (e) {
      // Ignore error
    }

    return result;
  }

  Future<void> _uploadProofOfPayment(OrderRequest order) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File imageFile = File(image.path);

      showProgress(context, 'Uploading...'.tr(), false, Color(cfg.colorPrimary));

      try {
        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref();
        final fileName =
            'proof_of_payment/${order.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final proofRef = storageRef.child(fileName);
        final uploadTask = await proofRef.putFile(imageFile);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        // Update order in Firestore
        await FirebaseFirestore.instance.collection('order_requests').doc(order.id).update({
          'payment': {
            'proofOfPaymentUrl': downloadUrl,
            'proofOfPaymentStatus': 'pending', // 'pending', 'approved', 'rejected'
            'proofSubmittedAt': FieldValue.serverTimestamp(),
          }
        });

        hideProgress();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proof of payment uploaded successfully'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        hideProgress();
        showAlertDialog(context, 'Error'.tr(), 'Failed to upload proof of payment'.tr());
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM d').format(timestamp.toDate());
  }

  String _getCurrencySymbol(String? currencyCode) {
    if (currencyCode == null || currencyCode.isEmpty) return '\$';

    final currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CAD': '\$',
      'AUD': '\$',
      'INR': '₹',
      'JMD': 'J\$',
    };

    return currencySymbols[currencyCode] ?? '\$';
  }
}
