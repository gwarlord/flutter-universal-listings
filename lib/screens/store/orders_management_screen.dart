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
import 'package:instaflutter/screens/store/order_detail_screen.dart';

/// Orders management screen for Premium listers
class OrdersManagementScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const OrdersManagementScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<OrdersManagementScreen> createState() => _OrdersManagementScreenState();
}

class _OrdersManagementScreenState extends State<OrdersManagementScreen>
    with SingleTickerProviderStateMixin {
  final StoreService _storeService = StoreService();
  late TabController _tabController;
  final Map<String, ListingsUser> _customerCache = {};

  // Use a special marker for active orders (both pending and confirmed)
  static const String _activeOrdersMarker = 'ACTIVE';
  static const String _allOrdersMarker = 'ALL';
  
  final List<dynamic> _statusFilters = [
    _activeOrdersMarker, // Active Orders (Pending + Confirmed with visual separation)
    OrderStatus.fulfilled,
    OrderStatus.declined,
    OrderStatus.cancelled,
    _allOrdersMarker, // All orders including history
  ];

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

    _tabController = TabController(length: _statusFilters.length, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Order Requests'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Color(cfg.colorPrimary),
          unselectedLabelColor: dark ? Colors.white54 : Colors.black45,
          indicatorColor: Color(cfg.colorPrimary),
          tabs: [
            Tab(text: 'Active Orders'.tr()),
            Tab(text: 'Fulfilled'.tr()),
            Tab(text: 'Declined'.tr()),
            Tab(text: 'Cancelled'.tr()),
            Tab(text: 'All'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusFilters.map((status) => _buildOrderList(status, dark)).toList(),
      ),
    );
  }

  Widget _buildOrderList(dynamic statusFilter, bool dark) {
    return StreamBuilder<List<OrderRequest>>(
      stream: _storeService.getOrderRequestsForLister(
        listerId: widget.currentUser.userID,
        statusFilter: statusFilter == _activeOrdersMarker ? null : 
                      statusFilter == _allOrdersMarker ? null : statusFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading orders: ${snapshot.error}',
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
            ),
          );
        }

        var orders = snapshot.data ?? [];

        // Filter for Active Orders tab - show both Pending and Confirmed with visual separation
        if (statusFilter == _activeOrdersMarker) {
          final pending = orders.where((o) => o.status == OrderStatus.requested).toList();
          final confirmed = orders.where((o) => o.status == OrderStatus.confirmed).toList();

          if (pending.isEmpty && confirmed.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active orders'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pending Orders section
              if (pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Pending'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ),
                ...pending.map((order) => _buildOrderCard(order, dark)),
              ],
              // Confirmed Orders section
              if (confirmed.isNotEmpty) ...[
                if (pending.isNotEmpty) const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    'Confirmed'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
                  ),
                ),
                ...confirmed.map((order) => _buildOrderCard(order, dark)),
              ],
            ],
          );
        }

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No orders found'.tr(),
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
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(orders[index], dark);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderRequest order, bool dark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewOrderDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Customer name and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<ListingsUser?>(
                      future: _getCustomer(order.customerId),
                      builder: (context, snapshot) {
                        final customer = snapshot.data;
                        return Text(
                          customer?.fullName() ?? 'Loading...'.tr(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        );
                      },
                    ),
                  ),
                  _buildStatusChip(order.status, dark),
                ],
              ),
              const SizedBox(height: 8),

              // Item count and total
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, size: 16, color: dark ? Colors.white70 : Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    '${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}'.tr(),
                    style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.attach_money, size: 16, color: dark ? Colors.white70 : Colors.black54),
                  Text(
                    _formatCurrency(order.estimatedTotal, order.currencyCode),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(cfg.colorPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: dark ? Colors.white70 : Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    order.createdAt != null
                        ? DateFormat('MMM d, y • h:mm a').format(order.createdAt!.toDate())
                        : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),

              // Fulfillment method
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    order.fulfillment.method == FulfillmentMethod.pickup
                        ? Icons.store_outlined
                        : Icons.local_shipping_outlined,
                    size: 16,
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    order.fulfillment.method == FulfillmentMethod.pickup ? 'Pickup'.tr() : 'Delivery'.tr(),
                    style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status, bool dark) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.requested:
        color = Colors.orange;
        label = 'Requested'.tr();
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'Confirmed'.tr();
        break;
      case OrderStatus.fulfilled:
        color = Colors.green;
        label = 'Fulfilled'.tr();
        break;
      case OrderStatus.declined:
        color = Colors.red;
        label = 'Declined'.tr();
        break;
      case OrderStatus.cancelled:
        color = Colors.grey;
        label = 'Cancelled'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
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

  Future<ListingsUser?> _getCustomer(String customerId) async {
    if (_customerCache.containsKey(customerId)) {
      return _customerCache[customerId];
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
      if (doc.exists) {
        final user = ListingsUser.fromJson(doc.data()!);
        _customerCache[customerId] = user;
        return user;
      }
    } catch (e) {
      // Ignore error
    }

    return null;
  }

  void _viewOrderDetail(OrderRequest order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          order: order,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }
}
