import 'package:firebase_analytics/firebase_analytics.dart';

/// Tracks analytics for photo enhancement feature
class EnhancementAnalytics {
  final FirebaseAnalytics _analytics;

  EnhancementAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  /// Log when enhancement feature is initialized
  Future<void> logEnhancementInitiated(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_initiated',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when image is selected for enhancement
  Future<void> logImageSelected(String listingId, String category) async {
    await _analytics.logEvent(
      name: 'ai_enhance_image_selected',
      parameters: {
        'listing_id': listingId,
        'category': category,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log successful enhancement processing
  Future<void> logEnhancementProcessed(
    String listingId,
    String subscriptionTier,
    double processingTimeSeconds,
  ) async {
    await _analytics.logEvent(
      name: 'ai_enhance_processed',
      parameters: {
        'listing_id': listingId,
        'subscription_tier': subscriptionTier,
        'processing_time_seconds': processingTimeSeconds,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when user approves enhancement
  Future<void> logEnhancementApproved(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_approved',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when variant is saved
  Future<void> logVariantSaved(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_variant_saved',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when variant is published/used
  Future<void> logVariantPublished(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_variant_published',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when variant is deleted
  Future<void> logVariantDeleted(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_variant_deleted',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when quota is exceeded
  Future<void> logQuotaExceeded(String listingId) async {
    await _analytics.logEvent(
      name: 'ai_enhance_quota_exceeded',
      parameters: {
        'listing_id': listingId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when enhancement fails
  Future<void> logEnhancementError(String errorMessage) async {
    await _analytics.logEvent(
      name: 'ai_enhance_error',
      parameters: {
        'error_message': errorMessage,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when feature is unavailable
  Future<void> logFeatureUnavailable(String reason) async {
    await _analytics.logEvent(
      name: 'ai_enhance_unavailable',
      parameters: {
        'reason': reason, // 'subscription_required', 'offline', etc
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log user rating of enhancement
  Future<void> logVariantRating(String listingId, int rating) async {
    await _analytics.logEvent(
      name: 'ai_enhance_variant_rated',
      parameters: {
        'listing_id': listingId,
        'rating': rating,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log subscription tier uplift from feature view
  Future<void> logSubscriptionUpsell(String fromTier, String toTier) async {
    await _analytics.logEvent(
      name: 'ai_enhance_upsell_conversion',
      parameters: {
        'from_tier': fromTier,
        'to_tier': toTier,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when user views enhancement feature
  Future<void> logFeatureView() async {
    await _analytics.logEvent(
      name: 'ai_enhance_feature_viewed',
      parameters: {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Log when enhancement batch is completed
  Future<void> logBatchProcessed(
    int successCount,
    int failureCount,
    double totalTimeSeconds,
  ) async {
    await _analytics.logEvent(
      name: 'ai_enhance_batch_processed',
      parameters: {
        'success_count': successCount,
        'failure_count': failureCount,
        'total_time_seconds': totalTimeSeconds,
        'success_rate': successCount / (successCount + failureCount),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Set user property for enhancement feature access
  Future<void> setEnhancementAccessProperty(bool hasAccess) async {
    await _analytics.setUserProperty(
      name: 'ai_enhance_access',
      value: hasAccess ? 'yes' : 'no',
    );
  }

  /// Set subscription tier property
  Future<void> setSubscriptionTierProperty(String tier) async {
    await _analytics.setUserProperty(
      name: 'subscription_tier',
      value: tier,
    );
  }
}
