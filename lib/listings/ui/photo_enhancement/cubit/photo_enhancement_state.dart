part of 'photo_enhancement_cubit.dart';

/// Base state for photo enhancement
abstract class PhotoEnhancementState {
  const PhotoEnhancementState();
}

/// Initial idle state
class PhotoEnhancementInitial extends PhotoEnhancementState {
  const PhotoEnhancementInitial();
}

/// No subscription tier or user not subscribed
class SubscriptionRequired extends PhotoEnhancementState {
  final String message;
  final String requiredTier;

  const SubscriptionRequired({
    required this.message,
    this.requiredTier = 'professional',
  });
}

/// Quota has been exhausted for this month
class QuotaExhausted extends PhotoEnhancementState {
  final int usedCount;
  final DateTime resetDate;
  final String? message;
  final UserEnhancementQuota? userQuota;

  const QuotaExhausted({
    required this.usedCount,
    required this.resetDate,
    this.message,
    this.userQuota,
  });
}

/// Selecting image for enhancement
class SelectingImage extends PhotoEnhancementState {
  const SelectingImage();
}

/// Image selected, ready to enhance
class ImageSelected extends PhotoEnhancementState {
  final String imagePath;
  final String category;
  final EnhancementQuota? quota;

  const ImageSelected({
    required this.imagePath,
    required this.category,
    this.quota,
  });
}

/// Processing enhancement (uploading & waiting for Cloud Function)
class Processing extends PhotoEnhancementState {
  final double progress; // 0.0 to 1.0
  final String message;

  const Processing({
    this.progress = 0.5,
    this.message = 'Processing enhancement...',
  });
}

/// Enhancement completed successfully
class EnhancementComplete extends PhotoEnhancementState {
  final EnhancementResponse response;
  final bool approved;

  const EnhancementComplete({
    required this.response,
    this.approved = false,
  });
}

/// Showing before/after comparison for user approval
class ComparisonView extends PhotoEnhancementState {
  final EnhancementResponse enhancement;
  final String originalImagePath;
  final List<String> appliedEnhancements;
  final bool isPreview; // true if showing preview, false if full quality
  final EnhancementRequest? request; // Store for final processing
  final UserEnhancementQuota? userQuota; // User's quota status for display

  const ComparisonView({
    required this.enhancement,
    required this.originalImagePath,
    required this.appliedEnhancements,
    this.isPreview = false,
    this.request,
    this.userQuota,
  });
}

/// Enhancement approved, saving to Firestore
class SavingVariant extends PhotoEnhancementState {
  final String message;

  const SavingVariant({
    this.message = 'Saving enhanced image...',
  });
}

/// Enhancement saved successfully
class VariantSaved extends PhotoEnhancementState {
  final ImageVariant variant;

  const VariantSaved({
    required this.variant,
  });
}

/// Error occurred during enhancement process
class EnhancementError extends PhotoEnhancementState {
  final String message;
  final String? errorCode;
  final dynamic exception;

  const EnhancementError({
    required this.message,
    this.errorCode,
    this.exception,
  });
}

/// Offline - cannot process enhancement
class OfflineError extends PhotoEnhancementState {
  final String message;

  const OfflineError({
    this.message = 'No internet connection. Enhancement requires online access.',
  });
}

/// Permission denied (camera, photo library, etc)
class PermissionDenied extends PhotoEnhancementState {
  final String permission;
  final String message;

  const PermissionDenied({
    required this.permission,
    required this.message,
  });
}

/// Viewing saved variants for a listing
class ViewingVariants extends PhotoEnhancementState {
  final List<ImageVariant> variants;
  final EnhancementQuota quota;

  const ViewingVariants({
    required this.variants,
    required this.quota,
  });
}

/// Managing/editing a specific variant
class ManagingVariant extends PhotoEnhancementState {
  final ImageVariant variant;

  const ManagingVariant({
    required this.variant,
  });
}

/// Deleting a variant
class DeletingVariant extends PhotoEnhancementState {
  final String variantId;
  final String message;

  const DeletingVariant({
    required this.variantId,
    this.message = 'Deleting variant...',
  });
}

/// Variant deleted successfully
class VariantDeleted extends PhotoEnhancementState {
  final String variantId;

  const VariantDeleted({
    required this.variantId,
  });
}
