import 'package:instaflutter/listings/model/listings_user.dart';

/// Subscription tier helper utilities for CaribTap
/// 
/// Business Rules:
/// - free: Basic access
/// - professional: Bookings + Analytics  
/// - premium: All professional features + Mini Store, Order Requests, Commerce features
/// 
/// CRITICAL: professional ≠ premium
/// Only Premium users get commerce features (Mini Store, Order Requests, Rentals)

/// Checks if user has PREMIUM subscription tier
/// Returns true ONLY for subscriptionTier == "premium"
bool isPremiumUser(ListingsUser user) {
  if (user.isAdmin) return true; // Admins have all access
  return user.isPremium && user.isSubscriptionActive;
}

/// Checks if user has PROFESSIONAL subscription tier (NOT premium)
bool isProfessionalUser(ListingsUser user) {
  if (user.isAdmin) return true;
  return user.isProfessional && user.isSubscriptionActive;
}

/// Checks if user has any paid tier (professional OR premium)
bool isPaidUser(ListingsUser user) {
  if (user.isAdmin) return true;
  return (user.isProfessional || user.isPremium || user.isBusiness) && 
         user.isSubscriptionActive;
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
