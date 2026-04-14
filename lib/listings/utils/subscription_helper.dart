import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';

/// Subscription tier helper utilities for CaribTap
/// 
/// Business Rules:
/// - free: Basic access
/// - professional: Tier 2 access
/// - premium: Tier 3 access
/// 
/// CRITICAL: professional ≠ premium
/// Premium-only: Mini Store and Order Requests
/// Professional and above: Rentals and booking management

final TierGateService _tierGateService = TierGateService();

/// Checks if user has PREMIUM subscription tier
/// Returns true ONLY for subscriptionTier == "premium"
bool isPremiumUser(ListingsUser user) {
  return _tierGateService.hasPremiumAccess(user);
}

/// Checks if user has PROFESSIONAL subscription tier (NOT premium)
bool isProfessionalUser(ListingsUser user) {
  return _tierGateService.hasProfessionalAccess(user);
}

/// Checks if user has any paid tier (professional OR premium)
bool isPaidUser(ListingsUser user) {
  return _tierGateService.hasPaidAccess(user);
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
