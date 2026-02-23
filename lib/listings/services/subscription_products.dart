class SubscriptionProductDefinition {
  final String productId;
  final int tier;
  final String billingPeriodLabel;
  final String displayName;
  final String description;

  const SubscriptionProductDefinition({
    required this.productId,
    required this.tier,
    required this.billingPeriodLabel,
    required this.displayName,
    required this.description,
  });
}

const List<SubscriptionProductDefinition> subscriptionProducts = [
  SubscriptionProductDefinition(
    productId: 'caribtap_pro_t2_monthly',
    tier: 2,
    billingPeriodLabel: 'Monthly',
    displayName: 'Professional',
    description: 'Advanced tools for growing teams.',
  ),
  SubscriptionProductDefinition(
    productId: 'caribtap_pro_t2_annual',
    tier: 2,
    billingPeriodLabel: 'Annual',
    displayName: 'Professional',
    description: 'Advanced tools for growing teams.',
  ),
  SubscriptionProductDefinition(
    productId: 'caribtap_pro_t3_monthly',
    tier: 3,
    billingPeriodLabel: 'Monthly',
    displayName: 'Premium',
    description: 'Full suite with premium business features.',
  ),
  SubscriptionProductDefinition(
    productId: 'caribtap_pro_t3_annual',
    tier: 3,
    billingPeriodLabel: 'Annual',
    displayName: 'Premium',
    description: 'Full suite with premium business features.',
  ),
];

final Set<String> subscriptionProductIds =
    subscriptionProducts.map((p) => p.productId).toSet();

int tierForProductId(String productId) {
  for (final product in subscriptionProducts) {
    if (product.productId == productId) {
      return product.tier;
    }
  }
  return 0;
}

SubscriptionProductDefinition? productDefinitionForId(String productId) {
  for (final product in subscriptionProducts) {
    if (product.productId == productId) {
      return product;
    }
  }
  return null;
}
