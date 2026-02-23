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

/// Checks if user has PREMIUM subscription tier
/// Returns true ONLY for subscriptionTier == "premium"
bool isPremiumUser(ListingsUser user) {
  if (user.isAdmin) return true; // Admins have all access
  final entitlement = EntitlementService().currentEntitlement;
  return ProGate.tierAtLeast(entitlement, 3, isAdmin: user.isAdmin);
}

/// Checks if user has PROFESSIONAL subscription tier (NOT premium)
bool isProfessionalUser(ListingsUser user) {
  if (user.isAdmin) return true;
  final entitlement = EntitlementService().currentEntitlement;
  return ProGate.tierAtLeast(entitlement, 2, isAdmin: user.isAdmin);
}

/// Checks if user has any paid tier (professional OR premium)
bool isPaidUser(ListingsUser user) {
  if (user.isAdmin) return true;
  final entitlement = EntitlementService().currentEntitlement;
  return ProGate.tierAtLeast(entitlement, 2, isAdmin: user.isAdmin);
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
    case 'business':
      return 'Business';
    default:
      return 'Free';
  }
}
