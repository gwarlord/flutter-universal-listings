import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/services/pro_gate.dart';

/// Subscription tier helper utilities for CaribTap
/// 
/// Business Rules:
/// - free: Basic access
/// - professional: Tier 2 access
/// - premium: Tier 3 access
/// 
/// CRITICAL: professional ≠ premium
/// Only Premium users get commerce features (Mini Store, Order Requests, Rentals)

bool _hasTierFromUser(ListingsUser user, Set<String> allowedTiers) {
  final tier = user.subscriptionTier.trim().toLowerCase();
  if (!allowedTiers.contains(tier)) return false;
  return user.isSubscriptionActive;
}

bool _hasTierFromEntitlement(ListingsUser user, int minimumTier) {
  final entitlement = EntitlementService().currentEntitlement;
  return ProGate.tierAtLeast(entitlement, minimumTier, isAdmin: user.isAdmin);
}

/// Checks if user has PREMIUM subscription tier
/// Returns true ONLY for subscriptionTier == "premium"
bool isPremiumUser(ListingsUser user) {
  if (user.isAdmin) return true; // Admins have all access

  // Prefer user profile state because it is available in Edit Listing flows.
  if (_hasTierFromUser(user, const {'premium'})) return true;

  // Fallback to entitlement snapshot if profile values are stale.
  return _hasTierFromEntitlement(user, 3);
}

/// Checks if user has PROFESSIONAL subscription tier (NOT premium)
bool isProfessionalUser(ListingsUser user) {
  if (user.isAdmin) return true;

  if (_hasTierFromUser(user, const {'professional', 'pro', 'premium'})) {
    return true;
  }

  return _hasTierFromEntitlement(user, 2);
}

/// Checks if user has any paid tier (professional OR premium)
bool isPaidUser(ListingsUser user) {
  if (user.isAdmin) return true;

  if (_hasTierFromUser(user, const {'professional', 'pro', 'premium'})) {
    return true;
  }

  return _hasTierFromEntitlement(user, 2);
}

/// Returns a user-friendly display name for subscription tier
String getSubscriptionTierDisplayName(String tier) {
  switch (tier.trim().toLowerCase()) {
    case 'free':
      return 'Free';
    case 'professional':
      return 'Professional';
    case 'premium':
      return 'Premium';
    default:
      return 'Free';
  }
}
