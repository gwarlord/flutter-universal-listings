import 'dart:io';

import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:caribtap/listings/ui/photo_enhancement/services/services.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'photo_enhancement_state.dart';

/// Cubit for managing photo enhancement workflow
class PhotoEnhancementCubit extends Cubit<PhotoEnhancementState> {
  final PhotoEnhancementService _enhancementService;
  final QuotaManager _quotaManager;
  final UserQuotaManager _userQuotaManager;
  final OfflineQueueManager _offlineQueue;
  final EnhancementAnalytics _analytics;

  PhotoEnhancementCubit({
    required PhotoEnhancementService enhancementService,
    required QuotaManager quotaManager,
    required UserQuotaManager userQuotaManager,
    required OfflineQueueManager offlineQueue,
    required EnhancementAnalytics analytics,
  })  : _enhancementService = enhancementService,
        _quotaManager = quotaManager,
        _userQuotaManager = userQuotaManager,
        _offlineQueue = offlineQueue,
        _analytics = analytics,
        super(const PhotoEnhancementInitial());

  bool _looksLikeNetworkIssue(Object error) {
    final raw = error.toString().toLowerCase();
    return error is SocketException ||
        raw.contains('unable to resolve host') ||
        raw.contains('unknownhostexception') ||
        raw.contains('firestore.googleapis.com') ||
        raw.contains('network') ||
        raw.contains('unavailable');
  }

        bool _looksLikePermissionIssue(Object error) {
          if (error is FirebaseFunctionsException) {
        return error.code == 'permission-denied' ||
            error.code == 'unauthenticated';
          }
          final raw = error.toString().toLowerCase();
          return raw.contains('permission-denied') ||
          raw.contains('you do not own this listing') ||
          raw.contains('not authorized') ||
          raw.contains('unauthenticated');
        }

        String _friendlyEnhancementError(Object error, {bool duringSave = false}) {
          if (_looksLikePermissionIssue(error)) {
        return duringSave
            ? 'Saving AI enhancement is not allowed for this listing.'.trim()
            : 'AI enhancement is not available for this listing.'.trim();
          }
          return duringSave
          ? 'Failed to save enhancement. Please try again.'.trim()
          : 'Enhancement failed. Please try again.'.trim();
        }

  /// Initialize enhancement for a listing
  Future<void> initializeEnhancement({
    required String listingId,
    required ListingsUser currentUser,
    required ListingModel listing,
  }) async {
    try {
      // Check subscription tier
      if (currentUser.subscriptionTier == null ||
          currentUser.subscriptionTier == 'free' ||
          currentUser.subscriptionTier == 'basic') {
        emit(SubscriptionRequired(
          message: 'Upgrade to Professional to use AI Photo Enhancement',
          requiredTier: 'professional',
        ));
        _analytics.logFeatureUnavailable('subscription_required');
        return;
      }

      // Check quota
      final quota = await _quotaManager.getQuota(listingId);
      if (quota.isQuotaExhausted()) {
        emit(QuotaExhausted(
          usedCount: quota.usedCount,
          resetDate: quota.monthResetDate,
        ));
        _analytics.logQuotaExceeded(listingId);
        return;
      }

      emit(const SelectingImage());
      _analytics.logEnhancementInitiated(listingId);
    } catch (e) {
      emit(EnhancementError(
        message: 'Failed to initialize enhancement',
        exception: e,
      ));
    }
  }

  /// Select and prepare image for enhancement
  Future<void> selectImageForEnhancement({
    required String imagePath,
    required String listingId,
    required String category,
    required String subscriptionTier,
  }) async {
    try {
      emit(ImageSelected(
        imagePath: imagePath,
        category: category,
        quota: null,
      ));
    } catch (e) {
      emit(EnhancementError(
        message: 'Failed to select image',
        exception: e,
      ));
    }
  }

  /// Start enhancement process
  Future<void> startEnhancement({
    required String listingId,
    required String imagePath,
    required String category,
    required String subscriptionTier,
    required String userId,
  }) async {
    try {
      emit(const Processing(progress: 0.0, message: 'Preparing image...'));

      // Check user preview quota
      final usePreview = category == 'product';
      if (usePreview) {
        final hasPreviewQuota = await _userQuotaManager.hasPreviewQuotaAvailable(userId);
        if (!hasPreviewQuota) {
          emit(QuotaExhausted(
            usedCount: UserEnhancementQuota.monthlyLimit,
            resetDate: (await _userQuotaManager.getQuota(userId)).monthResetDate,
            message: 'Preview quota exhausted. Upgrade your plan for more enhancements.',
          ));
          return;
        }
      }

      // Create enhancement request
      final request = EnhancementRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        listingId: listingId,
        imageFile: File(imagePath),
        category: category,
        subscriptionTier: subscriptionTier,
        enhancements: _getEnhancementsForTier(subscriptionTier),
      );

      emit(const Processing(progress: 0.3, message: 'Uploading image...'));

      // First call with preview mode (free - doesn't use API credits)
      final isPreviewMode = request.enhancements.contains('studio_background') && category == 'product';
      final response = await _enhancementService.enhancePhoto(
        request: request,
        imagePath: imagePath,
        usePreview: isPreviewMode,
        onProgress: (progress) {
          emit(Processing(
            progress: 0.3 + (progress * 0.4),
            message: isPreviewMode ? 'Generating preview...' : 'Processing with AI...',
          ));
        },
      );

      emit(Processing(progress: 0.8, message: 'Analyzing results...'));

      // Track preview usage
      if (isPreviewMode) {
        await _userQuotaManager.incrementPreviewUsage(userId);
      }

      // Get updated quota for display
      final userQuota = await _userQuotaManager.getQuota(userId);

      // Show comparison view
      emit(ComparisonView(
        enhancement: response,
        originalImagePath: imagePath,
        appliedEnhancements: response.appliedEnhancements,
        isPreview: isPreviewMode,
        request: isPreviewMode ? request : null, // Store request if preview for final processing
        userQuota: userQuota, // Add quota for display
      ));

      _analytics.logEnhancementProcessed(
        listingId,
        subscriptionTier,
        response.processingTimeSeconds,
      );
    } catch (e) {
      if (_looksLikeNetworkIssue(e)) {
        emit(const OfflineError());
        _analytics.logFeatureUnavailable('offline');
      } else {
        emit(EnhancementError(
          message: _friendlyEnhancementError(e),
          exception: e,
        ));
        _analytics.logEnhancementError(e.toString());
      }
    }
  }

  /// Approve enhancement and save as variant
  Future<void> approveAndSaveVariant({
    required EnhancementResponse enhancement,
    required String listingId,
    required String userId,
    required String originalImagePath,
    bool isPreview = false,
    EnhancementRequest? originalRequest,
  }) async {
    try {
      // Validate listingId is not empty
      if (listingId.isEmpty) {
        emit(const EnhancementError(
          message: 'Please save the listing first before enhancing photos',
          exception: 'Missing listingId',
        ));
        return;
      }

      emit(const SavingVariant());

      EnhancementResponse finalEnhancement = enhancement;

      // If this is a preview, process full quality now (this is when we use API credits)
      if (isPreview && originalRequest != null) {
        emit(const SavingVariant(message: 'Processing full quality image...'));
        
        finalEnhancement = await _enhancementService.enhancePhoto(
          request: originalRequest,
          imagePath: originalImagePath,
          usePreview: false, // Full quality
          onProgress: (progress) {
            emit(SavingVariant(
              message: 'Processing full quality: ${(progress * 100).toInt()}%',
            ));
          },
        );

        // Track enhancement usage (only for full quality, not preview)
        await _userQuotaManager.incrementEnhancementUsage(userId);
      }

      // Create image variant
      final variant = ImageVariant(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        listingId: listingId,
        originalImageId: '', // Set based on original image
        variantUrl: finalEnhancement.enhancedImageUrl,
        category: finalEnhancement.category,
        tier: '', // Will be set by service
        enhancements: finalEnhancement.appliedEnhancements,
        hasDisclosure: finalEnhancement.hasDisclosureBadge,
        createdBy: userId,
      );

      // Save to Firestore
      await _enhancementService.saveEnhancementVariant(variant);

      emit(VariantSaved(variant: variant));

      _analytics.logVariantSaved(listingId);
    } catch (e) {
      emit(EnhancementError(
        message: _friendlyEnhancementError(e, duringSave: true),
        exception: e,
      ));
    }
  }

  /// Load all variants for a listing
  Future<void> loadVariants(String listingId) async {
    try {
      final variants = await _enhancementService.getListingVariants(listingId);
      final quota = await _quotaManager.getQuota(listingId);

      emit(ViewingVariants(
        variants: variants,
        quota: quota,
      ));
    } catch (e) {
      emit(EnhancementError(
        message: 'Failed to load variants: ${e.toString()}',
        exception: e,
      ));
    }
  }

  /// Delete a variant
  Future<void> deleteVariant({
    required String variantId,
    required String listingId,
  }) async {
    try {
      emit(DeletingVariant(variantId: variantId));

      await _enhancementService.deleteVariant(variantId, listingId);

      emit(VariantDeleted(variantId: variantId));

      // Reload variants
      await loadVariants(listingId);

      _analytics.logVariantDeleted(listingId);
    } catch (e) {
      emit(EnhancementError(
        message: 'Failed to delete variant: ${e.toString()}',
        exception: e,
      ));
    }
  }

  /// Get enhancements available for tier
  List<String> _getEnhancementsForTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'professional':
      case 'premium':
      case 'basic':
        return [
          'auto_crop',
          'lighting_normalization',
          'clarity_enhancement',
          'background_blur',
          'studio_background', // Enable white background removal for products
        ];
      case 'professional_plus':
      case 'premium_plus':
      case 'plus':
        return [
          'auto_crop',
          'lighting_normalization',
          'clarity_enhancement',
          'background_blur',
          'background_cleanup',
          'subject_isolation',
          'studio_background',
        ];
      case 'professional_pro':
      case 'premium_pro':
      case 'pro':
        return [
          'auto_crop',
          'lighting_normalization',
          'clarity_enhancement',
          'background_blur',
          'background_cleanup',
          'subject_isolation',
          'studio_background',
          'logo_watermark',
          'branded_overlay',
        ];
      case 'free':
        return [];
      default:
        // For any paid tier not explicitly mapped, provide basic enhancements
        return [
          'auto_crop',
          'lighting_normalization',
          'clarity_enhancement',
          'studio_background',
        ];
    }
  }

  /// Cancel enhancement process
  void cancelEnhancement() {
    emit(const PhotoEnhancementInitial());
  }

  /// Reset to initial state
  void reset() {
    emit(const PhotoEnhancementInitial());
  }

  /// Get current user's enhancement quota (for display in UI)
  /// Returns null if quota not yet fetched
  UserEnhancementQuota? getLastUserQuota(String userId) {
    final currentState = state;
    
    if (currentState is ComparisonView && currentState.userQuota != null) {
      return currentState.userQuota;
    }
    
    return null;
  }

  /// Fetch and return current user quota in real-time
  /// Useful for displaying quota on screens without blocking
  Future<UserEnhancementQuota?> fetchUserQuota(String userId) async {
    try {
      return await _userQuotaManager.getQuota(userId);
    } catch (e) {
      print('Error fetching user quota: $e');
      return null;
    }
  }
}

