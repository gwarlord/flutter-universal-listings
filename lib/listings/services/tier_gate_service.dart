import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/entitlement_subscription.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';

enum ProTier {
  none,
  tier1,
  tier2,
  tier3,
}

class TierGateService {
  final EntitlementService _entitlementService;

  TierGateService({
    EntitlementService? entitlementService,
  }) : _entitlementService = entitlementService ?? EntitlementService();

  ProTier resolveTierFromUser(ListingsUser user) {
    if (user.isAdmin) return ProTier.tier3;

    // Prefer user profile fields because admin tools and migrations update
    // subscriptionTier/isSubscriptionActive on the main user document.
    final profileTier = _resolveTierFromProfile(user);
    if (profileTier != ProTier.none) {
      return profileTier;
    }

    // Fallback to entitlement snapshot when profile values are unavailable.
    final entitlement = _entitlementService.currentEntitlement;
    return resolveTierFromEntitlement(entitlement, isAdmin: user.isAdmin);
  }

  ProTier _resolveTierFromProfile(ListingsUser user) {
    if (!user.isSubscriptionActive) {
      return ProTier.none;
    }

    switch (user.subscriptionTier.trim().toLowerCase()) {
      case 'premium':
        return ProTier.tier3;
      case 'professional':
      case 'pro':
        return ProTier.tier2;
      default:
        return ProTier.none;
    }
  }

  ProTier resolveTierFromEntitlement(
    EntitlementSubscription? entitlement, {
    required bool isAdmin,
  }) {
    final tierValue = ProGate.resolveTier(
      entitlement: entitlement,
      isAdmin: isAdmin,
    );

    switch (tierValue) {
      case 1:
        return ProTier.tier1;
      case 2:
        return ProTier.tier2;
      case 3:
        return ProTier.tier3;
      default:
        return ProTier.none;
    }
  }

  bool canUseQuotes(ProTier tier) {
    return tier == ProTier.tier3;
  }

  bool canUseInvoices(ProTier tier) {
    return tier == ProTier.tier3;
  }

  bool canUseBranding(ProTier tier) {
    return tier == ProTier.tier3;
  }

  bool canUseSavedClients(ProTier tier) {
    return tier == ProTier.tier3;
  }

  int? quoteHistoryLimit(ProTier tier) {
    return tier == ProTier.tier1 ? 20 : null;
  }

  bool hasProfessionalAccess(ListingsUser user) {
    final tier = resolveTierFromUser(user);
    return tier == ProTier.tier2 || tier == ProTier.tier3;
  }

  bool hasPremiumAccess(ListingsUser user) {
    final tier = resolveTierFromUser(user);
    return tier == ProTier.tier3;
  }

  bool hasPaidAccess(ListingsUser user) {
    return hasProfessionalAccess(user);
  }

  bool canManageRentals(ListingsUser user) {
    return hasProfessionalAccess(user);
  }

  bool canUseAdvancedAnalytics(ListingsUser user) {
    return hasPremiumAccess(user);
  }
}
