import 'dart:io';

/// Represents a request to enhance a photo using AI
class EnhancementRequest {
  /// Unique identifier for this enhancement request
  final String id;

  /// The listing ID being enhanced
  final String listingId;

  /// The image file to be enhanced
  final File imageFile;

  /// Original image URL (for reference)
  final String? originalImageUrl;

  /// Category: 'product', 'service', or 'person'
  final String category;

  /// User's subscription tier: 'professional', 'professional_plus', or 'professional_pro'
  final String subscriptionTier;

  /// The enhancements to apply (determined by tier)
  final List<String> enhancements;

  /// Whether to include disclosure badge
  final bool includeDisclosure;

  /// Optional user notes about what they want enhanced
  final String? userNotes;

  /// Timestamp when request was created
  final DateTime createdAt;

  EnhancementRequest({
    required this.id,
    required this.listingId,
    required this.imageFile,
    this.originalImageUrl,
    required this.category,
    required this.subscriptionTier,
    required this.enhancements,
    this.includeDisclosure = true,
    this.userNotes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy with modified fields
  EnhancementRequest copyWith({
    String? id,
    String? listingId,
    File? imageFile,
    String? originalImageUrl,
    String? category,
    String? subscriptionTier,
    List<String>? enhancements,
    bool? includeDisclosure,
    String? userNotes,
    DateTime? createdAt,
  }) {
    return EnhancementRequest(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      imageFile: imageFile ?? this.imageFile,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      category: category ?? this.category,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      enhancements: enhancements ?? this.enhancements,
      includeDisclosure: includeDisclosure ?? this.includeDisclosure,
      userNotes: userNotes ?? this.userNotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for Cloud Function request
  Map<String, dynamic> toCloudFunctionRequest() {
    return {
      'listingId': listingId,
      'imageFileName': imageFile.path.split('/').last,
      'category': category,
      'subscriptionTier': subscriptionTier,
      'enhancements': enhancements,
      'includeDisclosure': includeDisclosure,
      'userNotes': userNotes,
      'timestamp': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'EnhancementRequest(id: $id, listingId: $listingId, category: $category)';
}
