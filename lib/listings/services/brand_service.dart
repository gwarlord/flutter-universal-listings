import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/listings/model/brand_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';

/// Service for managing brands and multi-location operations
class BrandService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a brand logo and return a public download URL.
  Future<String> uploadBrandLogo({
    required XFile logoFile,
    required String ownerUid,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'brand_logo_$timestamp.jpg';
      final ref = _storage.ref().child('brands/$ownerUid/logos/$fileName');

      final metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask;

      if (kIsWeb) {
        final bytes = await logoFile.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        uploadTask = ref.putFile(File(logoFile.path), metadata);
      }

      final snapshot = await uploadTask;
      return snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload brand logo: $e');
    }
  }

  /// Get a brand by ID
  Future<BrandModel?> getBrand(String brandId) async {
    try {
      final doc = await _firestore.collection('brands').doc(brandId).get();
      if (!doc.exists) return null;
      return BrandModel.fromJson(doc.data()!, doc.id);
    } catch (e) {
      print('Error fetching brand: $e');
      return null;
    }
  }

  /// Get all brands owned by a user
  Future<List<BrandModel>> getUserBrands(String uid) async {
    try {
      final query = await _firestore
          .collection('brands')
          .where('ownerUid', isEqualTo: uid)
          .get();
      
      return query.docs
          .map((doc) => BrandModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error fetching user brands: $e');
      return [];
    }
  }

  /// Get all listings linked to a brand
  Future<List<ListingModel>> getBrandLocations(String brandId) async {
    try {
      final query = await _firestore
          .collection('listings')
          .where('brandId', isEqualTo: brandId)
          .get();
      
      return query.docs
          .map((doc) => ListingModel.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching brand locations: $e');
      return [];
    }
  }

  /// Get other locations for a specific listing's brand
  Future<List<ListingModel>> getOtherBrandLocations(
    String listingId,
    String brandId,
  ) async {
    try {
      final query = await _firestore
          .collection('listings')
          .where('brandId', isEqualTo: brandId)
          .get();
      
      final locations = query.docs
          .map((doc) => ListingModel.fromJson(doc.data() as Map<String, dynamic>))
          .where((listing) => listing.id != listingId) // Exclude current listing
          .toList();
      
      // Sort by distance if geo data available
      return locations;
    } catch (e) {
      print('Error fetching other brand locations: $e');
      return [];
    }
  }

  /// Stream of user's brands
  Stream<List<BrandModel>> getUserBrandsStream(String uid) {
    return _firestore
        .collection('brands')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BrandModel.fromJson(doc.data(), doc.id)).toList());
  }

  /// Stream of brand locations
  Stream<List<ListingModel>> getBrandLocationsStream(String brandId) {
    return _firestore
        .collection('listings')
        .where('brandId', isEqualTo: brandId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ListingModel.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  /// Check if a listing is part of a brand
  bool isBrandLocation(ListingModel listing) {
    return listing.brandId != null && listing.brandId!.isNotEmpty;
  }

  /// Get display name for a brand location
  String getLocationDisplayName(ListingModel listing, BrandModel? brand) {
    if (listing.locationLabel != null && listing.locationLabel!.isNotEmpty) {
      return listing.locationLabel!;
    }
    
    if (brand != null) {
      final area = listing.place.isNotEmpty ? listing.place : 'Location';
      return '${brand.name} – $area';
    }
    
    return listing.title;
  }

  /// Calculate distance between two locations (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_degreesToRadians(lat1)) *
            Math.cos(_degreesToRadians(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);
    
    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * Math.pi / 180;
  }

  // ============================================
  // Cloud Functions Integration (Callables)
  // ============================================

  /// Create a new brand via Cloud Function
  /// 
  /// Returns the created brand ID on success
  Future<String> createBrand({
    required String name,
    String? logoUrl,
    String? description,
  }) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final result = await _functions
          .httpsCallable('createBrand')
          .call({
        'name': name,
        'logoUrl': logoUrl,
        'description': description,
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Brand creation timed out'),
      );

      final brandId = result.data['brandId'] as String?;
      if (brandId == null) {
        throw Exception('No brandId in response');
      }
      return brandId;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error creating brand: ${e.message}');
    } catch (e) {
      throw Exception('Error creating brand: $e');
    }
  }

  /// Update an existing brand via Cloud Function
  /// 
  /// Only specify fields that should be updated
  Future<void> updateBrand({
    required String brandId,
    String? name,
    String? logoUrl,
    String? description,
    bool? isVerified, // Admin only
    bool? freshnessExempt, // Admin only
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (logoUrl != null) updates['logoUrl'] = logoUrl;
      if (description != null) updates['description'] = description;
      if (isVerified != null) updates['isVerified'] = isVerified;
      if (freshnessExempt != null) updates['freshnessExempt'] = freshnessExempt;

      if (updates.isEmpty) {
        throw Exception('No fields provided for update');
      }

      await _functions
          .httpsCallable('updateBrand')
          .call({
        'brandId': brandId,
        'patch': updates,
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Brand update timed out'),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error updating brand: ${e.message}');
    } catch (e) {
      throw Exception('Error updating brand: $e');
    }
  }

  /// Link a listing to a brand via Cloud Function
  /// 
  /// The current user must own the listing
  Future<void> linkListingToBrand({
    required String listingId,
    required String brandId,
    String? locationLabel,
  }) async {
    try {
      await _functions
          .httpsCallable('linkListingToBrand')
          .call({
        'listingId': listingId,
        'brandId': brandId,
        'locationLabel': locationLabel,
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Link to brand timed out'),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error linking listing: ${e.message}');
    } catch (e) {
      throw Exception('Error linking listing: $e');
    }
  }

  /// Unlink a listing from its brand via Cloud Function
  /// 
  /// The current user must own the listing
  Future<void> unlinkListingFromBrand(String listingId) async {
    try {
      await _functions
          .httpsCallable('unlinkListingFromBrand')
          .call({
        'listingId': listingId,
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Unlink from brand timed out'),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error unlinking listing: ${e.message}');
    } catch (e) {
      throw Exception('Error unlinking listing: $e');
    }
  }

  /// Delete a brand via Cloud Function
  /// 
  /// The current user must own the brand
  Future<void> deleteBrand({
    required String brandId,
    bool unlinkListings = false,
  }) async {
    try {
      await _functions
          .httpsCallable('deleteBrand')
          .call({
        'brandId': brandId,
        'unlinkListings': unlinkListings,
      }).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Delete operation timed out. The function may be processing many listings.'),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Error deleting brand: ${e.message}');
    } catch (e) {
      throw Exception('Error deleting brand: $e');
    }
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Sort locations by distance from a point
  List<ListingModel> sortLocationsByDistance(
    List<ListingModel> locations,
    double userLat,
    double userLon,
  ) {
    final withDistance = locations
        .map((listing) => (
              listing,
              distance: calculateDistance(
                userLat,
                userLon,
                listing.latitude,
                listing.longitude,
              ),
            ))
        .toList();

    withDistance.sort((a, b) => a.distance.compareTo(b.distance));
    return withDistance.map((e) => e.$1).toList();
  }
}

// Helper class for Math functions
class Math {
  static const double pi = 3.14159265359;

  static double sin(double x) {
    return (x as double).sin;
  }

  static double cos(double x) {
    return (x as double).cos;
  }

  static double sqrt(double x) {
    return (x as double).sqrt;
  }

  static double atan2(double y, double x) {
    return (y as double).atan2(x as double);
  }
}

extension DoubleExtensions on double {
  double get sin => _sin(this);
  double get cos => _cos(this);
  double get sqrt => _sqrt(this);
  
  double atan2(double x) => _atan2(this, x);

  static double _sin(double x) {
    // Taylor series approximation for sin
    double result = 0.0;
    double term = x;
    for (int i = 1; i < 20; i++) {
      result += term;
      term *= -x * x / ((2 * i) * (2 * i + 1));
    }
    return result;
  }

  static double _cos(double x) {
    // Taylor series approximation for cos
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i < 20; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _sqrt(double x) {
    if (x == 0) return 0;
    double guess = x;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double _atan2(double y, double x) {
    if (x > 0) {
      return (y / x).atan;
    } else if (x < 0 && y >= 0) {
      return (y / x).atan + 3.14159265359;
    } else if (x < 0 && y < 0) {
      return (y / x).atan - 3.14159265359;
    } else if (x == 0 && y > 0) {
      return 3.14159265359 / 2;
    } else if (x == 0 && y < 0) {
      return -3.14159265359 / 2;
    }
    return 0;
  }

  double get atan {
    // Using atan Taylor series
    double x = this;
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.14159265359 / 2 - (1 / x).atan);
    }
    double result = 0.0;
    double term = x;
    double x2 = x * x;
    for (int i = 1; i < 50; i += 2) {
      result += term;
      term *= -x2 * (i) / (i + 2);
    }
    return result;
  }
}
