import 'package:cloud_firestore/cloud_firestore.dart';

/// Order request status
enum OrderStatus {
  requested('requested'),
  confirmed('confirmed'),
  preparing('preparing'), // Restaurant: meal being prepared
  ready('ready'), // Restaurant: ready to serve / pickup ready
  served('served'), // Restaurant: served to table
  declined('declined'),
  fulfilled('fulfilled'),
  cancelled('cancelled');

  final String value;
  const OrderStatus(this.value);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderStatus.requested,
    );
  }
}

/// Order type (determined by items in order)
enum OrderType {
  food('food'), // All items are food/drink
  general('general'), // All items are products/services
  mixed('mixed'); // Contains both food and non-food items

  final String value;
  const OrderType(this.value);

  static OrderType fromString(String? value) {
    if (value == null) return OrderType.general;
    return OrderType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderType.general,
    );
  }
}

/// Fulfillment method
enum FulfillmentMethod {
  pickup('pickup'),
  delivery('delivery'),
  dineIn('dine_in'),
  shipping('shipping');

  final String value;
  const FulfillmentMethod(this.value);

  static FulfillmentMethod fromString(String value) {
    return FulfillmentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FulfillmentMethod.pickup,
    );
  }
}

/// Fulfillment information
class FulfillmentInfo {
  final FulfillmentMethod method;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? preferredAt;

  FulfillmentInfo({
    required this.method,
    this.address,
    this.latitude,
    this.longitude,
    this.preferredAt,
  });

  factory FulfillmentInfo.fromJson(Map<String, dynamic> json) {
    return FulfillmentInfo(
      method: FulfillmentMethod.fromString(json['method'] ?? 'pickup'),
      address: json['address'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      preferredAt: json['preferredAt'] != null
          ? (json['preferredAt'] is Timestamp
              ? (json['preferredAt'] as Timestamp).toDate()
              : DateTime.tryParse(json['preferredAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method.value,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'preferredAt': preferredAt != null ? Timestamp.fromDate(preferredAt!) : null,
    };
  }
}

/// Tracking status enum
enum TrackingStatus {
  unknown('UNKNOWN'),
  labelCreated('LABEL_CREATED'),
  inTransit('IN_TRANSIT'),
  outForDelivery('OUT_FOR_DELIVERY'),
  delivered('DELIVERED');

  final String value;
  const TrackingStatus(this.value);

  static TrackingStatus fromString(String? value) {
    if (value == null) return TrackingStatus.unknown;
    return TrackingStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TrackingStatus.unknown,
    );
  }
}

/// Shipping information (populated when fulfillmentMethod == SHIPPING)
/// Contains both customer's shipping details and lister's tracking info
class ShippingInfo {
// Customer-provided shipping details
  final String? address; // Shipping address
  final double? latitude; // Pinned location latitude
  final double? longitude; // Pinned location longitude
  final String? instructions; // Additional shipping instructions

// Lister-provided tracking information
  final String? carrierName; // e.g., "FedEx", "UPS", "DHL"
  final String? trackingNumber;
  final String? trackingUrl;
  final TrackingStatus status;
  final DateTime? updatedAt;
  final String? updatedBy; // User ID of lister who updated it

  ShippingInfo({
    this.address,
    this.latitude,
    this.longitude,
    this.instructions,
    this.carrierName,
    this.trackingNumber,
    this.trackingUrl,
    this.status = TrackingStatus.unknown,
    this.updatedAt,
    this.updatedBy,
  });

  factory ShippingInfo.fromJson(Map<String, dynamic> json) {
    return ShippingInfo(
      address: json['address'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      instructions: json['instructions'],
      carrierName: json['carrierName'],
      trackingNumber: json['trackingNumber'],
      trackingUrl: json['trackingUrl'],
      status: TrackingStatus.fromString(json['status']),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.tryParse(json['updatedAt'].toString()))
          : null,
      updatedBy: json['updatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'instructions': instructions,
      'carrierName': carrierName,
      'trackingNumber': trackingNumber,
      'trackingUrl': trackingUrl,
      'status': status.value,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
    };
  }

  /// Returns true if tracking info is complete (required fields populated)
  bool get isComplete =>
      trackingNumber != null &&
      trackingNumber!.isNotEmpty &&
      trackingUrl != null &&
      trackingUrl!.isNotEmpty;

  /// Returns true if shipping address is complete
  bool get hasDeliveryAddress => address != null && address!.isNotEmpty;

  /// Returns true if at least one shipping field is set
  bool get hasData =>
      address != null ||
      latitude != null ||
      longitude != null ||
      instructions != null ||
      carrierName != null ||
      trackingNumber != null ||
      trackingUrl != null;
}

/// Order item
class OrderItem {
  final String itemId;
  final String name;
  final int qty;
  final double unitPrice;
  final Map<String, dynamic>? variant; // SKU, size, color, etc.
  final String itemType; // 'food_drink', 'product', 'service' from CatalogItemType
  final String? photoUrl; // Product/item image

  OrderItem({
    required this.itemId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.variant,
    this.itemType = 'product', // Default to product for backwards compatibility
    this.photoUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      qty: json['qty'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      variant: json['variant'] != null ? Map<String, dynamic>.from(json['variant']) : null,
      itemType: json['itemType'] ?? 'product',
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'qty': qty,
      'unitPrice': unitPrice,
      'variant': variant,
      'itemType': itemType,
      'photoUrl': photoUrl,
    };
  }

  double get total => qty * unitPrice;
}

/// Order request model
class OrderRequest {
  final String id;
  final String listingId;
  final String listerId;
  final String customerId;
  final OrderStatus status;
  final List<OrderItem> items;
  final double estimatedTotal;
  final String currencyCode;
  final FulfillmentInfo fulfillment;
  final ShippingInfo? shipping; // Only populated when fulfillment.method == SHIPPING
  final String? notes;
  final String? listerNotes;
  final String? channelId; // Chat channel ID
  final OrderType orderType; // Food, General, or Mixed based on items
  final Map<String, dynamic>? payment;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  OrderRequest({
    required this.id,
    required this.listingId,
    required this.listerId,
    required this.customerId,
    this.status = OrderStatus.requested,
    required this.items,
    required this.estimatedTotal,
    this.currencyCode = 'USD',
    required this.fulfillment,
    this.shipping,
    this.notes,
    this.listerNotes,
    this.channelId,
    OrderType? orderType,
    this.payment,
    this.createdAt,
    this.updatedAt,
  }) : orderType = orderType ?? _determineOrderType(items);

  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return OrderRequest(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      listerId: json['listerId'] ?? '',
      customerId: json['customerId'] ?? '',
      status: OrderStatus.fromString(json['status'] ?? 'requested'),
      items: items,
      estimatedTotal: (json['estimatedTotal'] ?? 0).toDouble(),
      currencyCode: json['currencyCode'] ?? 'USD',
      fulfillment: FulfillmentInfo.fromJson(json['fulfillment'] ?? {}),
      shipping: json['shipping'] != null
          ? ShippingInfo.fromJson(json['shipping'] as Map<String, dynamic>)
          : null,
      notes: json['notes'],
      listerNotes: json['listerNotes'],
      channelId: json['channelId'],
      orderType: OrderType.fromString(json['orderType']),
      payment: json['payment'] != null ? Map<String, dynamic>.from(json['payment']) : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listerId': listerId,
      'customerId': customerId,
      'status': status.value,
      'items': items.map((e) => e.toJson()).toList(),
      'estimatedTotal': estimatedTotal,
      'currencyCode': currencyCode,
      'fulfillment': fulfillment.toJson(),
      'shipping': shipping?.toJson(),
      'notes': notes,
      'listerNotes': listerNotes,
      'channelId': channelId,
      'orderType': orderType.value,
      'payment': payment,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  OrderRequest copyWith({
    String? id,
    String? listingId,
    String? listerId,
    String? customerId,
    OrderStatus? status,
    List<OrderItem>? items,
    double? estimatedTotal,
    String? currencyCode,
    FulfillmentInfo? fulfillment,
    ShippingInfo? shipping,
    String? notes,
    String? listerNotes,
    String? channelId,
    OrderType? orderType,
    Map<String, dynamic>? payment,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return OrderRequest(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      listerId: listerId ?? this.listerId,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      items: items ?? this.items,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      currencyCode: currencyCode ?? this.currencyCode,
      fulfillment: fulfillment ?? this.fulfillment,
      shipping: shipping ?? this.shipping,
      notes: notes ?? this.notes,
      listerNotes: listerNotes ?? this.listerNotes,
      channelId: channelId ?? this.channelId,
      orderType: orderType ?? this.orderType,
      payment: payment ?? this.payment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Determine order type based on item types
  static OrderType _determineOrderType(List<OrderItem> items) {
    if (items.isEmpty) return OrderType.general;

    bool hasFood = false;
    bool hasNonFood = false;

    for (final item in items) {
      if (item.itemType == 'food_drink') {
        hasFood = true;
      } else {
        hasNonFood = true;
      }
    }

    if (hasFood && hasNonFood) {
      return OrderType.mixed;
    } else if (hasFood) {
      return OrderType.food;
    } else {
      return OrderType.general;
    }
  }
}
