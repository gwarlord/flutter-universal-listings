import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/revenue_cat_service.dart';

enum ProTier {
  none,
  tier1,
  tier2,
  tier3,
}

class TierGateService {
  final RevenueCatService _revenueCatService;

  TierGateService({
    RevenueCatService? revenueCatService,
  }) : _revenueCatService = revenueCatService ?? RevenueCatService();

  ProTier resolveTierFromUser(ListingsUser user) {
    if (user.isAdmin) return ProTier.tier3;
    if (!user.isSubscriptionActive) return ProTier.none;

    final tier = user.subscriptionTier.trim().toLowerCase();
    switch (tier) {
      case 'professional':
        return ProTier.tier1;
      case 'premium':
        return ProTier.tier2;
      case 'business':
        return ProTier.tier3;
      default:
        return ProTier.none;
    }
  }

  Future<ProTier> refreshTierFromRevenueCat() async {
    final tier = await _revenueCatService.getSubscriptionTier();
    switch (tier) {
      case 'professional':
        return ProTier.tier1;
      case 'premium':
        return ProTier.tier2;
      default:
        return ProTier.none;
    }
  }

  bool canUseQuotes(ProTier tier) {
    return tier == ProTier.tier1 || tier == ProTier.tier2 || tier == ProTier.tier3;
  }

  bool canUseInvoices(ProTier tier) {
    return tier == ProTier.tier2 || tier == ProTier.tier3;
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
