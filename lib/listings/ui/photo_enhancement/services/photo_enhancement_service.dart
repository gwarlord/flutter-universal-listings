import 'dart:io';

import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for AI photo enhancement operations
class PhotoEnhancementService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  static const String enhancePhotoFunction = 'enhancePhoto';
  static const String variantsCollection = 'image_variants';

  PhotoEnhancementService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Call Cloud Function to enhance photo
  Future<EnhancementResponse> enhancePhoto({
    required EnhancementRequest request,
    required String imagePath,
    bool usePreview = false,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Upload image to Cloud Storage
      final storageRef = _storage.ref().child(
            'listings/${request.listingId}/enhancement-input/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      final file = File(imagePath);
      final uploadTask = storageRef.putFile(file);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(0.1 + (progress * 0.2)); // 0.1 - 0.3
      });

      await uploadTask;
      final uploadedImageUrl = await storageRef.getDownloadURL();

      onProgress?.call(0.4);

      // Call Cloud Function
      final callable = _functions.httpsCallable(enhancePhotoFunction);
      final result = await callable.call({
        'listingId': request.listingId,
        'imageUrl': uploadedImageUrl,
        'category': request.category,
        'subscriptionTier': request.subscriptionTier,
        'enhancements': request.enhancements,
        'includeDisclosure': request.includeDisclosure,
        'usePreview': usePreview,
      });

      onProgress?.call(0.9);

      // Parse response
      final response = EnhancementResponse.fromJson(
        Map<String, dynamic>.from(result.data as Map),
      );

      onProgress?.call(1.0);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Save enhanced image variant to Firestore
  Future<ImageVariant> saveEnhancementVariant(ImageVariant variant) async {
    try {
      final docRef = _firestore
          .collection('listings')
          .doc(variant.listingId)
          .collection(variantsCollection)
          .doc(variant.id);

      await docRef.set(variant.toJson());

      // Also update listing's image_variants array
      await _firestore.collection('listings').doc(variant.listingId).update({
        'image_variants': FieldValue.arrayUnion([variant.toJson()])
      });

      return variant;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all variants for a listing
  Future<List<ImageVariant>> getListingVariants(String listingId) async {
    try {
      final snapshot = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection(variantsCollection)
          .get();

      return snapshot.docs
          .map((doc) => ImageVariant.fromJson(doc.data()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get a specific variant
  Future<ImageVariant?> getVariant(String listingId, String variantId) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection(variantsCollection)
          .doc(variantId)
          .get();

      if (!doc.exists) return null;

      return ImageVariant.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Update a variant (e.g., publish, rate, add feedback)
  Future<void> updateVariant(ImageVariant variant) async {
    try {
      await _firestore
          .collection('listings')
          .doc(variant.listingId)
          .collection(variantsCollection)
          .doc(variant.id)
          .update(variant.toJson());
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a variant
  Future<void> deleteVariant(String variantId, String listingId) async {
    try {
      final variant = await getVariant(listingId, variantId);
      if (variant != null) {
        // Delete from Storage
        try {
          final storageRef = FirebaseStorage.instance.refFromURL(variant.variantUrl);
          await storageRef.delete();
        } catch (e) {
          // Log but don't fail if storage delete fails
          print('Failed to delete variant from storage: $e');
        }
      }

      // Delete from Firestore
      await _firestore
          .collection('listings')
          .doc(listingId)
          .collection(variantsCollection)
          .doc(variantId)
          .delete();

      // Remove from listing's image_variants array
      if (variant != null) {
        await _firestore.collection('listings').doc(listingId).update({
          'image_variants': FieldValue.arrayRemove([variant.toJson()])
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Publish a variant (replace listing image with variant)
  Future<void> publishVariant(
    String variantId,
    String listingId,
    int imageIndex,
  ) async {
    try {
      final variant = await getVariant(listingId, variantId);
      if (variant == null) throw Exception('Variant not found');

      // Update variant as published
      await updateVariant(variant.copyWith(isPublished: true));

      // Update listing to use this image
      final listingDoc =
          await _firestore.collection('listings').doc(listingId).get();
      final images = List<String>.from(listingDoc.get('images') ?? []);

      if (imageIndex < images.length) {
        images[imageIndex] = variant.variantUrl;
        await _firestore
            .collection('listings')
            .doc(listingId)
            .update({'images': images});
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Revert to original image
  Future<void> revertToOriginal(
    String variantId,
    String listingId,
    int imageIndex,
    String originalImageUrl,
  ) async {
    try {
      final listingDoc =
          await _firestore.collection('listings').doc(listingId).get();
      final images = List<String>.from(listingDoc.get('images') ?? []);

      if (imageIndex < images.length) {
        images[imageIndex] = originalImageUrl;
        await _firestore
            .collection('listings')
            .doc(listingId)
            .update({'images': images});
      }
    } catch (e) {
      rethrow;
    }
  }
}
