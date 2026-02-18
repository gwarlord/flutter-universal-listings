/// Represents an enhanced image variant stored for a listing
class ImageVariant {
  /// Unique identifier for this variant
  final String id;

  /// The listing ID
  final String listingId;

  /// Original image ID/URL that was enhanced
  final String originalImageId;

  /// URL of the enhanced image in Cloud Storage
  final String variantUrl;

  /// Category: 'product', 'service', or 'person'
  final String category;

  /// Subscription tier used: 'professional', 'professional_plus', or 'professional_pro'
  final String tier;

  /// List of enhancements applied
  final List<String> enhancements;

  /// Whether "Enhanced for Clarity" disclosure badge was added
  final bool hasDisclosure;

  /// User ID who created this variant
  final String createdBy;

  /// When this variant was created
  final DateTime enhancedAt;

  /// Whether user has approved and published this variant
  bool isPublished;

  /// User's rating of this enhancement (1-5), if any
  int? userRating;

  /// User's feedback on this enhancement
  String? userFeedback;

  ImageVariant({
    required this.id,
    required this.listingId,
    required this.originalImageId,
    required this.variantUrl,
    required this.category,
    required this.tier,
    required this.enhancements,
    required this.hasDisclosure,
    required this.createdBy,
    DateTime? enhancedAt,
    this.isPublished = false,
    this.userRating,
    this.userFeedback,
  }) : enhancedAt = enhancedAt ?? DateTime.now();

  /// Create from Firestore document
  factory ImageVariant.fromJson(Map<String, dynamic> json) {
    return ImageVariant(
      id: json['id'] as String,
      listingId: json['listingId'] as String,
      originalImageId: json['originalImageId'] as String,
      variantUrl: json['variantUrl'] as String,
      category: json['category'] as String,
      tier: json['tier'] as String,
      enhancements: List<String>.from(json['enhancements'] as List? ?? []),
      hasDisclosure: json['hasDisclosure'] as bool? ?? true,
      createdBy: json['createdBy'] as String,
      enhancedAt: json['enhancedAt'] != null
          ? DateTime.parse(json['enhancedAt'] as String)
          : null,
      isPublished: json['isPublished'] as bool? ?? false,
      userRating: json['userRating'] as int?,
      userFeedback: json['userFeedback'] as String?,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'originalImageId': originalImageId,
      'variantUrl': variantUrl,
      'category': category,
      'tier': tier,
      'enhancements': enhancements,
      'hasDisclosure': hasDisclosure,
      'createdBy': createdBy,
      'enhancedAt': enhancedAt.toIso8601String(),
      'isPublished': isPublished,
      'userRating': userRating,
      'userFeedback': userFeedback,
    };
  }

  /// Create a copy with modified fields
  ImageVariant copyWith({
    String? id,
    String? listingId,
    String? originalImageId,
    String? variantUrl,
    String? category,
    String? tier,
    List<String>? enhancements,
    bool? hasDisclosure,
    String? createdBy,
    DateTime? enhancedAt,
    bool? isPublished,
    int? userRating,
    String? userFeedback,
  }) {
    return ImageVariant(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      originalImageId: originalImageId ?? this.originalImageId,
      variantUrl: variantUrl ?? this.variantUrl,
      category: category ?? this.category,
      tier: tier ?? this.tier,
      enhancements: enhancements ?? this.enhancements,
      hasDisclosure: hasDisclosure ?? this.hasDisclosure,
      createdBy: createdBy ?? this.createdBy,
      enhancedAt: enhancedAt ?? this.enhancedAt,
      isPublished: isPublished ?? this.isPublished,
      userRating: userRating ?? this.userRating,
      userFeedback: userFeedback ?? this.userFeedback,
    );
  }

  /// Get human-readable description of enhancements
  String getEnhancementsDescription() {
    switch (tier) {
      case 'professional':
        return 'Auto-crop, lighting, clarity, blur';
      case 'professional_plus':
        return 'Background cleanup, subject isolation, advanced enhancements';
      case 'professional_pro':
        return 'Logo watermark, branding tools, premium enhancements';
      default:
        return enhancements.join(', ');
    }
  }

  @override
  String toString() => 'ImageVariant(id: $id, tier: $tier, published: $isPublished)';
}
