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
    final entitlement = _entitlementService.currentEntitlement;
    return resolveTierFromEntitlement(entitlement, isAdmin: user.isAdmin);
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
}
