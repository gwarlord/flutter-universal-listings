import 'package:caribtap/listings/model/entitlement_subscription.dart';

class ProGate {
  static int resolveTier({
    required EntitlementSubscription? entitlement,
    required bool isAdmin,
  }) {
    if (isAdmin) {
      return 3;
    }
    if (entitlement == null || !entitlement.isActive) {
      return 0;
    }
    return entitlement.tier;
  }

  static bool tierAtLeast(
    EntitlementSubscription? entitlement,
    int minTier, {
    required bool isAdmin,
  }) {
    return resolveTier(entitlement: entitlement, isAdmin: isAdmin) >= minTier;
  }

  static bool canUseAIEnhanceTier1(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    return tierAtLeast(entitlement, 1, isAdmin: isAdmin);
  }

  static bool canUseAIEnhanceTier2(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    return tierAtLeast(entitlement, 2, isAdmin: isAdmin);
  }

  static bool canUseWatermarking(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    return tierAtLeast(entitlement, 2, isAdmin: isAdmin);
  }

  static bool canUseQuotes(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    return tierAtLeast(entitlement, 1, isAdmin: isAdmin);
  }

  static bool canUseInvoices(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    return tierAtLeast(entitlement, 2, isAdmin: isAdmin);
  }
}
