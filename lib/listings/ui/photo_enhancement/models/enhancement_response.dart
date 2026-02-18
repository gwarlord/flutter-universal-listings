/// Represents the response from an AI photo enhancement request
class EnhancementResponse {
  /// Unique identifier for this enhanced image
  final String id;

  /// The listing ID
  final String listingId;

  /// URL of the enhanced image in Cloud Storage
  final String enhancedImageUrl;

  /// URL of the original image (for comparison)
  final String originalImageUrl;

  /// Category: 'product', 'service', or 'person'
  final String category;

  /// List of enhancements that were applied
  final List<String> appliedEnhancements;

  /// Whether disclosure badge was added
  final bool hasDisclosureBadge;

  /// AI confidence score (0-1)
  final double confidenceScore;

  /// Processing time in seconds
  final double processingTimeSeconds;

  /// Optional metadata from Vision API
  final Map<String, dynamic>? metadata;

  /// Timestamp when enhancement was completed
  final DateTime enhancedAt;

  /// Whether user has approved this enhancement
  bool isApproved;

  EnhancementResponse({
    required this.id,
    required this.listingId,
    required this.enhancedImageUrl,
    required this.originalImageUrl,
    required this.category,
    required this.appliedEnhancements,
    required this.hasDisclosureBadge,
    required this.confidenceScore,
    required this.processingTimeSeconds,
    this.metadata,
    DateTime? enhancedAt,
    this.isApproved = false,
  }) : enhancedAt = enhancedAt ?? DateTime.now();

  /// Create from Cloud Function response JSON
  factory EnhancementResponse.fromJson(Map<String, dynamic> json) {
    return EnhancementResponse(
      id: json['id'] as String,
      listingId: json['listingId'] as String,
      enhancedImageUrl: json['enhancedImageUrl'] as String,
      originalImageUrl: json['originalImageUrl'] as String,
      category: json['category'] as String,
      appliedEnhancements: List<String>.from(json['appliedEnhancements'] as List),
      hasDisclosureBadge: json['hasDisclosureBadge'] as bool? ?? true,
      confidenceScore: (json['confidenceScore'] as num).toDouble(),
      processingTimeSeconds: (json['processingTimeSeconds'] as num).toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      enhancedAt: json['enhancedAt'] != null
          ? DateTime.parse(json['enhancedAt'] as String)
          : null,
      isApproved: json['isApproved'] as bool? ?? false,
    );
  }

  /// Convert to JSON for Firestore storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'enhancedImageUrl': enhancedImageUrl,
      'originalImageUrl': originalImageUrl,
      'category': category,
      'appliedEnhancements': appliedEnhancements,
      'hasDisclosureBadge': hasDisclosureBadge,
      'confidenceScore': confidenceScore,
      'processingTimeSeconds': processingTimeSeconds,
      'metadata': metadata,
      'enhancedAt': enhancedAt.toIso8601String(),
      'isApproved': isApproved,
    };
  }

  /// Create a copy with modified fields
  EnhancementResponse copyWith({
    String? id,
    String? listingId,
    String? enhancedImageUrl,
    String? originalImageUrl,
    String? category,
    List<String>? appliedEnhancements,
    bool? hasDisclosureBadge,
    double? confidenceScore,
    double? processingTimeSeconds,
    Map<String, dynamic>? metadata,
    DateTime? enhancedAt,
    bool? isApproved,
  }) {
    return EnhancementResponse(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      enhancedImageUrl: enhancedImageUrl ?? this.enhancedImageUrl,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      category: category ?? this.category,
      appliedEnhancements: appliedEnhancements ?? this.appliedEnhancements,
      hasDisclosureBadge: hasDisclosureBadge ?? this.hasDisclosureBadge,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      processingTimeSeconds: processingTimeSeconds ?? this.processingTimeSeconds,
      metadata: metadata ?? this.metadata,
      enhancedAt: enhancedAt ?? this.enhancedAt,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  @override
  String toString() => 'EnhancementResponse(id: $id, confidence: $confidenceScore)';
}
