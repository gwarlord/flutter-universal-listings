/// Cart item model for local cart state
class CartItem {
  final String itemId;
  final String name;
  int qty;
  final double unitPrice;
  final String currencyCode;
  final String? photoUrl;
  final Map<String, dynamic>? variant; // {sku, size, color, price, stockQty}
  final String? variantLabel; // Display label like "Large, Blue"

  CartItem({
    required this.itemId,
    required this.name,
    this.qty = 1,
    required this.unitPrice,
    this.currencyCode = 'USD',
    this.photoUrl,
    this.variant,
    this.variantLabel,
  });

  double get total => qty * unitPrice;

  CartItem copyWith({
    String? itemId,
    String? name,
    int? qty,
    double? unitPrice,
    String? currencyCode,
    String? photoUrl,
    Map<String, dynamic>? variant,
    String? variantLabel,
  }) {
    return CartItem(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      photoUrl: photoUrl ?? this.photoUrl,
      variant: variant ?? this.variant,
      variantLabel: variantLabel ?? this.variantLabel,
    );
  }
}
