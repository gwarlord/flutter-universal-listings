import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/order_request.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';
import 'package:caribtap/listings/ui/table_mode/staff_table_sessions_screen.dart';
import 'package:caribtap/screens/store/order_detail_screen.dart';
import 'package:caribtap/screens/store/shipping_tracking_display.dart';

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
    with TickerProviderStateMixin {
  final StoreService _storeService = StoreService();
  final EntitlementService _entitlementService = EntitlementService();
  late TabController _tabController;
  final Map<String, ListingsUser> _customerCache = {};
  final Map<String, ListingModel> _listingCache = {};
  final TextEditingController _orderSearchController = TextEditingController();
  String _orderSearchQuery = '';

  // Toggle between food and general orders
  bool _isShowingFoodOrders = true;

  // Use a special marker for active orders (both pending and confirmed)
  static const String _activeOrdersMarker = 'ACTIVE';
  static const String _allOrdersMarker = 'ALL';
  
  // Food order statuses (with detailed kitchen workflow)
  final List<dynamic> _foodStatusFilters = [
    _activeOrdersMarker, // Active Orders (Pending + Confirmed + Preparing + Ready + Served)
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.served,
    OrderStatus.fulfilled,
    OrderStatus.declined,
    OrderStatus.cancelled,
    _allOrdersMarker, // All orders including history
  ];

  // General order statuses (simpler workflow)
  final List<dynamic> _generalStatusFilters = [
    _activeOrdersMarker, // Active Orders (Pending + Confirmed)
    OrderStatus.fulfilled,
    OrderStatus.declined,
    OrderStatus.cancelled,
    _allOrdersMarker, // All orders including history
  ];

  List<dynamic> get _statusFilters => _isShowingFoodOrders ? _foodStatusFilters : _generalStatusFilters;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Verify Premium access
    _ensurePremiumAccess();

    _tabController = TabController(length: _statusFilters.length, vsync: this, initialIndex: 0);
  }

  Future<void> _ensurePremiumAccess() async {
    final entitlement =
        await _entitlementService.fetchEntitlement(widget.currentUser.userID);
    final hasAccess = ProGate.tierAtLeast(
      entitlement,
      2,
      isAdmin: widget.currentUser.isAdmin,
    );

    if (!hasAccess && mounted) {
      showSnackBar(context, '🔒 Premium subscription required');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _orderSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _switchOrderType(bool isFoodOrders) {
    setState(() {
      if (_isShowingFoodOrders != isFoodOrders) {
        _isShowingFoodOrders = isFoodOrders;
        // Recreate TabController with new length
        _tabController.dispose();
        _tabController = TabController(length: _statusFilters.length, vsync: this, initialIndex: 0);
      }
    });
  }

  /// Check if an order should be displayed based on the current Food/General filter
  bool _shouldShowOrder(OrderRequest order) {
    if (_isShowingFoodOrders) {
      // Show food or mixed orders when viewing Food tab
      return order.orderType == OrderType.food || order.orderType == OrderType.mixed;
    } else {
      // Show general or mixed orders when viewing General tab
      return order.orderType == OrderType.general || order.orderType == OrderType.mixed;
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
          'Order Requests'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          // Toggle between Food and General orders
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _switchOrderType(true),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isShowingFoodOrders ? Color(cfg.colorPrimary) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 18,
                            color: _isShowingFoodOrders ? Colors.white : (dark ? Colors.white54 : Colors.black45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Food'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isShowingFoodOrders ? Colors.white : (dark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _switchOrderType(false),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_isShowingFoodOrders ? Color(cfg.colorPrimary) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag,
                            size: 18,
                            color: !_isShowingFoodOrders ? Colors.white : (dark ? Colors.white54 : Colors.black45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'General'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_isShowingFoodOrders ? Colors.white : (dark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_restaurant),
            tooltip: 'Table Sessions'.tr(),
            onPressed: () => _navigateToTableSessions(context, dark),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              _buildOrderSearchBar(dark),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Color(cfg.colorPrimary),
                unselectedLabelColor: dark ? Colors.white54 : Colors.black45,
                indicatorColor: Color(cfg.colorPrimary),
                tabs: _buildTabLabels(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusFilters.map((status) => _buildOrderList(status, dark)).toList(),
      ),
    );
  }

  List<Widget> _buildTabLabels() {
    if (_isShowingFoodOrders) {
      return [
        Tab(text: 'Active'.tr()),
        Tab(text: 'Preparing'.tr()),
        Tab(text: 'Ready'.tr()),
        Tab(text: 'Served'.tr()),
        Tab(text: 'Fulfilled'.tr()),
        Tab(text: 'Declined'.tr()),
        Tab(text: 'Cancelled'.tr()),
        Tab(text: 'All'.tr()),
      ];
    } else {
      return [
        Tab(text: 'Active'.tr()),
        Tab(text: 'Fulfilled'.tr()),
        Tab(text: 'Declined'.tr()),
        Tab(text: 'Cancelled'.tr()),
        Tab(text: 'All'.tr()),
      ];
    }
  }

  Widget _buildOrderSearchBar(bool dark) {
    final hintColor = dark ? Colors.white54 : Colors.black45;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _orderSearchController,
        onChanged: (value) {
          setState(() {
            _orderSearchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search order #'.tr(),
          hintStyle: TextStyle(color: hintColor),
          prefixIcon: Icon(Icons.search, color: hintColor),
          suffixIcon: _orderSearchQuery.trim().isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),
                  color: hintColor,
                  tooltip: 'Clear'.tr(),
                  onPressed: () {
                    setState(() {
                      _orderSearchController.clear();
                      _orderSearchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: dark ? Colors.grey.shade800 : Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: dark ? Colors.white : Colors.black87),
        textInputAction: TextInputAction.search,
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

        // Filter by order type (Food, General, or Mixed) based on current tab
        orders = orders.where(_shouldShowOrder).toList();

        final rawQuery = _orderSearchQuery.trim();

        // Filter for Active Orders tab - show Pending, Confirmed, and additional statuses based on type
        if (statusFilter == _activeOrdersMarker) {
          // Filter to only include active statuses based on order type
          if (_isShowingFoodOrders) {
            // Food orders: include detailed kitchen workflow
            orders = orders.where((o) => 
              o.status == OrderStatus.requested ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.ready ||
              o.status == OrderStatus.served
            ).toList();
          } else {
            // General orders: simple workflow (just pending and confirmed)
            orders = orders.where((o) => 
              o.status == OrderStatus.requested ||
              o.status == OrderStatus.confirmed
            ).toList();
          }

          if (rawQuery.isNotEmpty) {
            return FutureBuilder<List<OrderRequest>>(
              future: _filterOrdersForSearch(orders, rawQuery),
              builder: (context, searchSnapshot) {
                if (searchSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final searchedOrders = searchSnapshot.data ?? const <OrderRequest>[];
                return _buildActiveOrdersList(searchedOrders, dark);
              },
            );
          }

          return _buildActiveOrdersList(orders, dark);
        }

        // Filter orders for specific status tabs (client-side verification)
        if (statusFilter != null && 
            statusFilter != _activeOrdersMarker && 
            statusFilter != _allOrdersMarker &&
            statusFilter is OrderStatus) {
          orders = orders.where((o) => o.status == statusFilter).toList();
        }

        if (rawQuery.isNotEmpty) {
          return FutureBuilder<List<OrderRequest>>(
            future: _filterOrdersForSearch(orders, rawQuery),
            builder: (context, searchSnapshot) {
              if (searchSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final searchedOrders = searchSnapshot.data ?? const <OrderRequest>[];
              if (searchedOrders.isEmpty) {
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
                itemCount: searchedOrders.length,
                itemBuilder: (context, index) {
                  return _buildOrderCard(searchedOrders[index], dark);
                },
              );
            },
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

  Widget _buildActiveOrdersList(List<OrderRequest> orders, bool dark) {
    final pending = orders.where((o) => o.status == OrderStatus.requested).toList();
    final confirmed = orders.where((o) => o.status == OrderStatus.confirmed).toList();
    final preparing = _isShowingFoodOrders ? orders.where((o) => o.status == OrderStatus.preparing).toList() : [];
    final ready = _isShowingFoodOrders ? orders.where((o) => o.status == OrderStatus.ready).toList() : [];
    final served = _isShowingFoodOrders ? orders.where((o) => o.status == OrderStatus.served).toList() : [];

    if (pending.isEmpty && confirmed.isEmpty && preparing.isEmpty && ready.isEmpty && served.isEmpty) {
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
        if (confirmed.isNotEmpty) ...[
          if (pending.isNotEmpty) const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Confirmed'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade600,
              ),
            ),
          ),
          ...confirmed.map((order) => _buildOrderCard(order, dark)),
        ],
        if (preparing.isNotEmpty) ...[
          if (pending.isNotEmpty || confirmed.isNotEmpty) const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Preparing'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade600,
              ),
            ),
          ),
          ...preparing.map((order) => _buildOrderCard(order, dark)),
        ],
        if (ready.isNotEmpty) ...[
          if (pending.isNotEmpty || confirmed.isNotEmpty || preparing.isNotEmpty)
            const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Ready'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade600,
              ),
            ),
          ),
          ...ready.map((order) => _buildOrderCard(order, dark)),
        ],
        if (served.isNotEmpty) ...[
          if (pending.isNotEmpty || confirmed.isNotEmpty || preparing.isNotEmpty || ready.isNotEmpty)
            const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'Served'.tr(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.indigo.shade600,
              ),
            ),
          ),
          ...served.map((order) => _buildOrderCard(order, dark)),
        ],
      ],
    );
  }

  Future<List<OrderRequest>> _filterOrdersForSearch(
    List<OrderRequest> orders,
    String rawQuery,
  ) async {
    final normalizedQuery = _normalizeSearchText(rawQuery);
    if (normalizedQuery.isEmpty) return orders;

    final matches = await Future.wait(
      orders.map((order) async {
        final customer = await _getCustomer(order.customerId);
        final listing = await _getListingCached(order.listingId);

        final orderId = _normalizeSearchText(order.id);
        final shortId = _normalizeSearchText(
          order.id.length >= 8 ? order.id.substring(0, 8) : order.id,
        );
        final customerName = _normalizeSearchText(customer?.fullName() ?? '');
        final customerEmail = _normalizeSearchText(customer?.email ?? '');
        final productNames = _normalizeSearchText(
          order.items.map((item) => item.name).join(' '),
        );
        final listingTitle = _normalizeSearchText(listing?.title ?? '');

        final matched = orderId.contains(normalizedQuery) ||
            shortId.contains(normalizedQuery) ||
            customerName.contains(normalizedQuery) ||
            customerEmail.contains(normalizedQuery) ||
            productNames.contains(normalizedQuery) ||
            listingTitle.contains(normalizedQuery);

        return matched ? order : null;
      }),
    );

    return matches.whereType<OrderRequest>().toList();
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Widget _buildOrderCard(OrderRequest order, bool dark) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getOrderPreviewData(order),
      builder: (context, previewSnapshot) {
        final previewData = previewSnapshot.data ?? {};
        final firstItemImage = previewData['firstItemImage'] as String?;
        final listingTitle = previewData['listingTitle'] as String? ?? 'Order ${order.id.substring(0, 8)}';
        final isTableMode = previewData['isTableMode'] as bool? ?? false;
        final tableName = previewData['tableName'] as String?;

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
                  const SizedBox(height: 12),

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
                            Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 14, color: dark ? Colors.white54 : Colors.black54),
                                const SizedBox(width: 4),
                                Text(
                                  '${order.items.length} item${order.items.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: dark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Total and date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: dark ? Colors.white54 : Colors.black54),
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
                      Text(
                        _formatCurrency(order.estimatedTotal, order.currencyCode),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(cfg.colorPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fulfillment method and table mode indicator
                  Row(
                    children: [
                      Icon(
                        order.fulfillment.method == FulfillmentMethod.pickup
                            ? Icons.store_outlined
                            : order.fulfillment.method == FulfillmentMethod.dineIn
                                ? Icons.restaurant_outlined
                                : Icons.local_shipping_outlined,
                        size: 16,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        order.fulfillment.method == FulfillmentMethod.pickup
                            ? 'Pickup'.tr()
                            : order.fulfillment.method == FulfillmentMethod.dineIn
                                ? 'Dining In'.tr()
                                : order.fulfillment.method == FulfillmentMethod.shipping
                                    ? 'Shipping'.tr()
                                    : 'Delivery'.tr(),
                        style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                      ),
                      // Show Table Mode indicator ONLY for dine-in orders WITH table sessions
                      if (order.fulfillment.method == FulfillmentMethod.dineIn && isTableMode) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(cfg.colorPrimary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Color(cfg.colorPrimary).withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.table_restaurant,
                                size: 14,
                                color: Color(cfg.colorPrimary),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tableName ?? 'Table Mode'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(cfg.colorPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Show Mixed order indicator for orders with both food and general items
                      if (order.orderType == OrderType.mixed) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '🍽️',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                '🛍️',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mixed'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Show tracking chip if order has shipping tracking
                      if (order.fulfillment.method == FulfillmentMethod.shipping &&
                          order.shipping?.trackingNumber != null) ...[
                        const SizedBox(width: 8),
                        const ShippingTrackingChip(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      case OrderStatus.preparing:
        color = Colors.purple;
        label = 'Preparing'.tr();
        break;
      case OrderStatus.ready:
        color = Colors.teal;
        label = 'Ready'.tr();
        break;
      case OrderStatus.served:
        color = Colors.indigo;
        label = 'Served'.tr();
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

  Future<ListingModel?> _getListingCached(String listingId) async {
    if (_listingCache.containsKey(listingId)) {
      return _listingCache[listingId];
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('listings').doc(listingId).get();

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
    
    // Get listing title
    final listing = await _getListingCached(order.listingId);
    result['listingTitle'] = listing?.title ?? 'Order ${order.id.substring(0, 8)}';
    
    // Check if order has table mode data
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('order_requests')
          .doc(order.id)
          .get();
      
      if (orderDoc.exists) {
        final data = orderDoc.data();
        if (data?['tableSessionId'] != null) {
          result['isTableMode'] = true;
          result['tableName'] = data?['tableName'];
          result['tableId'] = data?['tableId'];
        }
      }
    } catch (e) {
      // Ignore error
    }
    
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
    
    return result;
  }

  void _viewOrderDetail(OrderRequest order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailScreen(
          order: order,
          currentUser: widget.currentUser,
          viewAsLister: true,
        ),
      ),
    );
  }

  Future<void> _navigateToTableSessions(BuildContext context, bool dark) async {
    // Show loading immediately
    showProgress(context, 'Loading...'.tr(), false, Color(cfg.colorPrimary));
    
    try {
      // Get user's listings
      final listingsQuery = await FirebaseFirestore.instance
          .collection('listings')
          .where('authorID', isEqualTo: widget.currentUser.userID)
          .get();

      if (listingsQuery.docs.isEmpty) {
        hideProgress();
        showSnackBar(context, 'No listings found'.tr());
        return;
      }

      // Check each listing for tables in parallel
      final tableChecks = await Future.wait(
        listingsQuery.docs.map((doc) async {
          final tablesSnap = await FirebaseFirestore.instance
              .collection('listings')
              .doc(doc.id)
              .collection('tables')
              .limit(1)
              .get();
          
          return {
            'hasTables': tablesSnap.docs.isNotEmpty,
            'doc': doc,
          };
        })
      );

      // Filter listings with tables
      final tableModeListings = tableChecks
          .where((check) => check['hasTables'] == true)
          .map((check) {
            final doc = check['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
            final data = doc.data();
            data['id'] = doc.id;
            return ListingModel.fromJson(data);
          })
          .toList();

      hideProgress();

      if (tableModeListings.isEmpty) {
        showSnackBar(context, 'No listings with tables. Create tables first from Store Settings.'.tr());
        return;
      }

      // If only one listing, navigate directly
      if (tableModeListings.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffTableSessionsScreen(
              listing: tableModeListings.first,
              currentUser: widget.currentUser,
            ),
          ),
        );
        return;
      }

      // Show selection dialog for multiple listings
      final selectedListing = await showDialog<ListingModel>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: dark ? Colors.grey[900] : Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Select Listing'.tr(),
            style: TextStyle(
              color: dark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tableModeListings.length,
              itemBuilder: (context, index) {
                final listing = tableModeListings[index];
                return ListTile(
                  leading: listing.photos.isNotEmpty
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(listing.photos.first),
                        )
                      : CircleAvatar(
                          backgroundColor: Color(cfg.colorPrimary).withOpacity(0.2),
                          child: Icon(
                            Icons.restaurant,
                            color: Color(cfg.colorPrimary),
                          ),
                        ),
                  title: Text(
                    listing.title,
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    listing.place,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () => Navigator.pop(context, listing),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel'.tr(),
                style: TextStyle(
                  color: dark ? Colors.grey[300] : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );

      if (selectedListing != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffTableSessionsScreen(
              listing: selectedListing,
              currentUser: widget.currentUser,
            ),
          ),
        );
      }
    } catch (e) {
      hideProgress();
      showSnackBar(context, 'Error loading listings: ${e.toString()}'.tr());
    }
  }
}
