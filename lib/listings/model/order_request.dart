import 'package:cloud_firestore/cloud_firestore.dart';

/// Order request status
enum OrderStatus {
  requested('requested'),
  confirmed('confirmed'),
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

/// Fulfillment method
enum FulfillmentMethod {
  pickup('pickup'),
  delivery('delivery');

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
  final DateTime? preferredAt;

  FulfillmentInfo({
    required this.method,
    this.address,
    this.preferredAt,
  });

  factory FulfillmentInfo.fromJson(Map<String, dynamic> json) {
    return FulfillmentInfo(
      method: FulfillmentMethod.fromString(json['method'] ?? 'pickup'),
      address: json['address'],
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
      'preferredAt': preferredAt != null ? Timestamp.fromDate(preferredAt!) : null,
    };
  }
}

/// Order item
class OrderItem {
  final String itemId;
  final String name;
  final int qty;
  final double unitPrice;
  final Map<String, dynamic>? variant; // SKU, size, color, etc.

  OrderItem({
    required this.itemId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.variant,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      qty: json['qty'] ?? 1,
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      variant: json['variant'] != null ? Map<String, dynamic>.from(json['variant']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'qty': qty,
      'unitPrice': unitPrice,
      'variant': variant,
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
  final String? notes;
  final String? channelId; // Chat channel ID
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
    this.notes,
    this.channelId,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      listerId: json['listerId'] ?? '',
      customerId: json['customerId'] ?? '',
      status: OrderStatus.fromString(json['status'] ?? 'requested'),
      items: (json['items'] as List?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      estimatedTotal: (json['estimatedTotal'] ?? 0).toDouble(),
      currencyCode: json['currencyCode'] ?? 'USD',
      fulfillment: FulfillmentInfo.fromJson(json['fulfillment'] ?? {}),
      notes: json['notes'],
      channelId: json['channelId'],
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
      'notes': notes,
      'channelId': channelId,
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
    String? notes,
    String? channelId,
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
      notes: notes ?? this.notes,
      channelId: channelId ?? this.channelId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
