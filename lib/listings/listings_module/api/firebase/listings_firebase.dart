import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:flutter_native_image_v2/flutter_native_image_v2.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/filter_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/model/paged_reviews_result.dart';
import 'package:caribtap/listings/model/reported_listing_model.dart';
import 'package:caribtap/listings/model/suspension_info.dart';
import 'package:path/path.dart' as path;

class ListingsFirebaseUtils extends ListingsRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  /// Firebase Storage root reference
  final Reference storage = FirebaseStorage.instance.ref();

  /// For picking images/videos
  final ImagePicker _picker = ImagePicker();

  /// Google Places client (package client)
  late final GoogleMapsPlaces _places = GoogleMapsPlaces(
    apiKey: cfg.googleMapsApiKey,
  );

  // ---------------------------
  // Helpers
  // ---------------------------

  /// Always trust Firestore doc.id as the true Listing id.
  ListingModel _listingFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final model = ListingModel.fromJson(doc.data());
    model.id = doc.id;
    return model;
  }

  ListingModel _listingFromDocSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) {
      // Caller should guard; returning an empty model is safer than null here.
      return ListingModel();
    }
    final model = ListingModel.fromJson(data);
    model.id = snap.id;
    return model;
  }

  // ---------------------------
  // Admin / moderation
  // ---------------------------

  @override
  Future<void> approveListing({required ListingModel listingModel}) async {
    listingModel.isApproved = true;
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingModel.id)
        .update(listingModel.toJson());
  }

  @override
  Future<void> deleteListing({required ListingModel listingModel}) async {
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingModel.id)
        .delete();

    for (final imageUrl in (listingModel.photos)) {
      await deleteImageFromStorage(imageUrl);
    }
    for (final videoUrl in (listingModel.videos ?? const <String>[])) {
      await deleteVideoFromStorage(videoUrl);
    }
  }

  @override
  Future<List<ReportedListing>> getReportedListings() async {
    final snapshot = await firestore
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => ReportedListing.fromSnapshot(doc)).toList();
  }

  @override
  Future<void> dismissReport(String reportId) async {
    // Get report to find the listing ID
    final reportDoc = await firestore.collection('reports').doc(reportId).get();
    final reportData = reportDoc.data();
    
    // Update report status
    await firestore
        .collection('reports')
        .doc(reportId)
        .update({'status': 'dismissed'});
    
    // Clear isFlagged on the listing if this was the only pending report
    if (reportData != null && reportData['listingId'] != null) {
      final listingId = reportData['listingId'] as String;
      
      // Check if there are other pending reports for this listing
      final otherReports = await firestore
          .collection('reports')
          .where('listingId', isEqualTo: listingId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      // If no other pending reports, clear the flag
      if (otherReports.docs.isEmpty) {
        await firestore
            .collection(cfg.listingsCollection)
            .doc(listingId)
            .update({'isFlagged': false});
      }
    }
  }

  @override
  Future<List<ListingModel>> getSuspendedListings() async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot = await firestore
        .collection(cfg.listingsCollection)
        .where('suspended', isEqualTo: true)
        .get();

    return querySnapshot.docs.map(_listingFromDoc).toList();
  }

  @override
  Future<void> suspendListing({
    required ListingModel listing,
    SuspensionInfo? suspensionInfo,
    required String adminId,
  }) async {
    debugPrint('[ListingsFirebase] suspendListing START: ${listing.id}');
    final info = suspensionInfo ?? SuspensionInfo(
      isSuspended: true,
      suspendedAt: DateTime.now(),
      suspendedBy: adminId,
    );

    final updatedInfo = info.copyWith(
      isSuspended: true,
      suspendedAt: info.suspendedAt ?? DateTime.now(),
      suspendedBy: adminId,
    );

    debugPrint('[ListingsFirebase] Updating Firestore doc ${listing.id} with suspended=true');
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listing.id)
        .update({
          'suspended': true,
          'suspensionInfo': updatedInfo.toJson(),
          'isFlagged': false, // Clear flag since listing is being actioned
        });
    debugPrint('[ListingsFirebase] suspendListing COMPLETE: ${listing.id}');
  }

  @override
  Future<void> unsuspendListing({
    required ListingModel listing,
    required String adminId,
  }) async {
    debugPrint('[ListingsFirebase] unsuspendListing START: ${listing.id}');
    final currentInfo = listing.suspensionInfo ?? SuspensionInfo(isSuspended: true);
    final updatedInfo = currentInfo.copyWith(
      isSuspended: false,
      unsuspendedAt: DateTime.now(),
      unsuspendedBy: adminId,
      unsuspensionRequested: false,
      unsuspensionRequestText: null,
      unsuspensionRequestedAt: null,
    );

    debugPrint('[ListingsFirebase] Updating Firestore doc ${listing.id} with suspended=false');
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listing.id)
        .update({
          'suspended': false,
          'suspensionInfo': updatedInfo.toJson(),
        });
    debugPrint('[ListingsFirebase] unsuspendListing COMPLETE: ${listing.id}');
  }

  @override
  Future<void> requestUnsuspension({
    required ListingModel listing,
    required String requestText,
  }) async {
    debugPrint('[ListingsFirebase] requestUnsuspension for listing: ${listing.id}');
    final currentInfo = listing.suspensionInfo ?? SuspensionInfo(isSuspended: true);
    final updatedInfo = currentInfo.copyWith(
      unsuspensionRequested: true,
      unsuspensionRequestText: requestText,
      unsuspensionRequestedAt: DateTime.now(),
    );

    await firestore
        .collection(cfg.listingsCollection)
        .doc(listing.id)
        .update({
          'suspensionInfo': updatedInfo.toJson(),
        });
    debugPrint('[ListingsFirebase] requestUnsuspension COMPLETE');
  }

  // ---------------------------
  // Categories / filters
  // ---------------------------

  @override
  Future<List<CategoriesModel>> getCategories() async {
    try {
      final snap = await firestore
          .collection(cfg.categoriesCollection)
          .get();

      final categories = snap.docs
          .map((d) => CategoriesModel.fromJson(d.data(), id: d.id))
          .where((c) => c.isActive)
          .toList()
        ..sort((a, b) {
          final sortCompare = a.sortOrder.compareTo(b.sortOrder);
          if (sortCompare != 0) return sortCompare;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

      debugPrint('Parsed categories length: ${categories.length}');
      return categories;
    } catch (e, st) {
      debugPrint('getCategories() ERROR: $e');
      debugPrint('$st');
      return <CategoriesModel>[];
    }
  }

  @override
  Future<List<FilterModel>> getFilters() async {
    final result = await firestore.collection(cfg.filtersCollection).get();
    final List<FilterModel> filters = [];
    for (final doc in result.docs) {
      try {
        filters.add(FilterModel.fromJson(doc.data()));
      } catch (e, s) {
        debugPrint('FireStoreUtils.getFilters failed to parse object ${doc.id} $e $s');
      }
    }
    return filters;
  }

  // ---------------------------
  // Listings reads
  // ---------------------------

  @override
  Future<ListingModel?> getListing({required String listingID}) async {
    final result =
    await firestore.collection(cfg.listingsCollection).doc(listingID).get();

    if (result.exists && result.data() != null) {
      return _listingFromDocSnap(result);
    }
    return null;
  }

  @override
  Future<List<ListingModel>> getListings({required List<String> favListingsIDs}) async {
    final result = await firestore.collection(cfg.listingsCollection).get();
    final List<ListingModel> listings = [];

    for (final doc in result.docs) {
      try {
        final model = _listingFromDoc(doc);
        // Filter out suspended and hidden listings
        if (model.suspended) continue;
        if (model.hidden) continue;
        model.isFav = favListingsIDs.contains(doc.id);
        listings.add(model);
      } catch (e, s) {
        debugPrint('FireStoreUtils.getListings failed to parse listing object ${doc.id} $e $s');
      }
    }
    return listings;
  }

  @override
  Future<List<ListingModel>> getMyListings({
    required String currentUserID,
    required List<String> favListingsIDs,
  }) async {
    final result = await firestore
        .collection(cfg.listingsCollection)
        .where('authorID', isEqualTo: currentUserID)
        .get();

    final List<ListingModel> listings = [];
    for (final doc in result.docs) {
      try {
        final model = _listingFromDoc(doc);
        // Keep suspended listings visible for owner
        model.isFav = favListingsIDs.contains(doc.id);
        listings.add(model);
      } catch (e) {
        debugPrint('FireStoreUtils.getMyListings failed to parse object ${doc.id} $e');
      }
    }
    return listings;
  }

  @override
  Future<List<ListingModel>> getListingsByCategoryID({
    required String categoryID,
    required List<String> favListingsIDs,
  }) async {
    final result = await firestore
        .collection(cfg.listingsCollection)
        .where('categoryID', isEqualTo: categoryID)
        .get();

    final List<ListingModel> listings = [];
    for (final doc in result.docs) {
      try {
        final model = _listingFromDoc(doc);
        // Filter out suspended and hidden listings
        if (model.suspended) continue;
        if (model.hidden) continue;
        model.isFav = favListingsIDs.contains(doc.id);
        listings.add(model);
      } catch (e, s) {
        debugPrint('FireStoreUtils.getListingsByCategoryID failed to parse listing object ${doc.id} $e $s');
      }
    }
    return listings;
  }

  @override
  Future<List<ListingModel>> getPendingListings({required List<String> favListingsIDs}) async {
    final result = await firestore
        .collection(cfg.listingsCollection)
        .where('isApproved', isEqualTo: false)
        .get();

    final List<ListingModel> listings = [];
    for (final doc in result.docs) {
      try {
        final model = _listingFromDoc(doc);
        model.isFav = favListingsIDs.contains(doc.id);
        listings.add(model);
      } catch (e, s) {
        debugPrint('FireStoreUtils.getPendingListings failed to parse object ${doc.id} $e $s');
      }
    }
    return listings;
  }

  @override
  Future<List<ListingModel>> getFavoriteListings({
    required List<String> favListingsIDs,
  }) async {
    final List<ListingModel> listings = [];
    for (final listingID in favListingsIDs) {
      final ListingModel? listingModel = await getListing(listingID: listingID);
      if (listingModel != null && !listingModel.suspended && !listingModel.hidden) {
        listingModel.isFav = true;
        listings.add(listingModel);
      }
    }
    return listings;
  }

  // ---------------------------
  // Reviews
  // ---------------------------

  @override
  Future<List<ListingReviewModel>> getReviews({required String listingID}) async {
    final result = await firestore
        .collection(cfg.reviewCollection)
        .where('listingID', isEqualTo: listingID)
        .orderBy('createdAt', descending: true)
        .get();

    final List<ListingReviewModel> reviews = [];
    for (final doc in result.docs) {
      try {
        final review = ListingReviewModel.fromDoc(doc);
        // Only include reviews that are not explicitly hidden
        if (!review.isHidden) {
          reviews.add(review);
        }
      } catch (e, s) {
        debugPrint('FireStoreUtils.getReviews failed to parse object ${doc.id} $e $s');
      }
    }
    return reviews;
  }

  /// Get all reviews including hidden ones (admin only)
  Future<List<ListingReviewModel>> getAllReviews({required String listingID}) async {
    final result = await firestore
        .collection(cfg.reviewCollection)
        .where('listingID', isEqualTo: listingID)
        .get();

    final List<ListingReviewModel> reviews = [];
    for (final doc in result.docs) {
      try {
        reviews.add(ListingReviewModel.fromDoc(doc));
      } catch (e, s) {
        debugPrint('FireStoreUtils.getAllReviews failed to parse object ${doc.id} $e $s');
      }
    }
    return reviews;
  }

  @override
  Future<PagedReviewsResult> getReviewsPaged({
    required String listingID,
    int limit = 10,
    int? startAfterCreatedAt,
    bool descending = true,
  }) async {
    try {
      // Build query with pagination
      Query<Map<String, dynamic>> query = firestore
          .collection(cfg.reviewCollection)
          .where('listingID', isEqualTo: listingID)
          .orderBy('createdAt', descending: descending)
          .limit(limit + 1); // Fetch one extra to check if there are more

      // Add cursor if provided
      if (startAfterCreatedAt != null) {
        query = query.startAfter([startAfterCreatedAt]);
      }

      final result = await query.get();
      
      final List<ListingReviewModel> reviews = [];
      bool hasMore = false;

      // Check if we have more than the requested limit
      if (result.docs.length > limit) {
        hasMore = true;
      }

      // Parse reviews (excluding the extra one if present)
      final docsToProcess = result.docs.take(limit);
      for (final doc in docsToProcess) {
        try {
          final review = ListingReviewModel.fromDoc(doc);
          // Only include reviews that are not explicitly hidden
          if (!review.isHidden) {
            reviews.add(review);
          }
        } catch (e, s) {
          debugPrint('FireStoreUtils.getReviewsPaged failed to parse object ${doc.id} $e $s');
        }
      }

      // Get the cursor for the next page
      int? nextCursor;
      if (hasMore && reviews.isNotEmpty) {
        nextCursor = reviews.last.createdAt;
      }

      return PagedReviewsResult(
        reviews: reviews,
        nextCursorCreatedAt: nextCursor,
        hasMore: hasMore,
      );
    } catch (e, s) {
      debugPrint('FireStoreUtils.getReviewsPaged error: $e $s');
      return PagedReviewsResult.empty();
    }
  }

  @override
  Future<void> postReview({required ListingReviewModel reviewModel}) async {
    final ListingModel? updatedListing =
    await getListing(listingID: reviewModel.listingID);
    if (updatedListing == null) return;

    await firestore.collection(cfg.reviewCollection).doc().set(reviewModel.toJson());

    updatedListing.reviewsCount += 1;
    updatedListing.reviewsSum += reviewModel.starCount;

    await firestore
        .collection(cfg.listingsCollection)
        .doc(updatedListing.id)
        .update({
          'reviewsCount': updatedListing.reviewsCount,
          'reviewsSum': updatedListing.reviewsSum,
        });
  }

  // ---------------------------
  // Publishing
  // ---------------------------

  @override
  Future<void> postListing({required ListingModel newListing}) async {
    // If listing has an ID, update existing document. Otherwise create new one.
    final DocumentReference docRef = newListing.id.isEmpty
        ? firestore.collection(cfg.listingsCollection).doc()
        : firestore.collection(cfg.listingsCollection).doc(newListing.id);
    
    if (newListing.id.isEmpty) {
      newListing.id = docRef.id;
    }
    
    await docRef.set(newListing.toJson());
  }

  @override
  Future<bool> publishListing(ListingModel listingModel) async {
    try {
      await postListing(newListing: listingModel);
      return true;
    } catch (e, st) {
      debugPrint('publishListing() ERROR: $e');
      debugPrint('$st');
      return false;
    }
  }

  @override
  Future<void> refreshListingFreshness({required String listingId}) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('refreshListingFreshness');
    await callable.call({'listingId': listingId});
  }

  // ---------------------------
  // Images
  // ---------------------------

  @override
  Future<List<String>> uploadListingImages({required List<File> images}) async {
    final List<String> imagesUrls = [];

    for (final image in images) {
      // Keep file extension consistent. Firebase Storage infers metadata better.
      final String baseName = path.basename(image.path);
      final String ext = path.extension(baseName).toLowerCase();
      final String safeExt = (ext == '.png') ? '.png' : '.jpg';

      final Reference upload =
      storage.child('listings/images/${path.basenameWithoutExtension(baseName)}$safeExt');

      final File compressedImage = await compressImage(image);
      final SettableMetadata meta = SettableMetadata(
        contentType: safeExt == '.png' ? 'image/png' : 'image/jpeg',
      );

      final UploadTask uploadTask = upload.putFile(compressedImage, meta);
      final String downloadUrl =
      await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
      imagesUrls.add(downloadUrl);
    }

    return imagesUrls;
  }

  @override
  Future<File?> getListingImage({required bool fromGallery}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        // Keep quality relatively high; we'll still downscale in compressImage().
        imageQuality: 95,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e, st) {
      debugPrint('getListingImage() ERROR: $e');
      debugPrint('$st');
      return null;
    }
  }

  @override
  Future<List<File>> getListingImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 95,
      );
      return picked.map((xFile) => File(xFile.path)).toList();
    } catch (e, st) {
      debugPrint('getListingImages() ERROR: $e');
      debugPrint('$st');
      return [];
    }
  }

  // ---------------------------
  // Videos (NEW)
  // ---------------------------

  @override
  Future<File?> getListingVideo({required bool fromGallery}) async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
      );
      if (picked == null) return null;

      final file = File(picked.path);

      // Enforce MP4 only (as requested).
      final p = file.path.toLowerCase();
      if (!p.endsWith('.mp4')) {
        debugPrint('getListingVideo(): rejected non-mp4 file=$p');
        return null;
      }

      return file;
    } catch (e, st) {
      debugPrint('getListingVideo() ERROR: $e');
      debugPrint('$st');
      return null;
    }
  }

  @override
  Future<List<String>> uploadListingVideos({required List<File> videos}) async {
    final List<String> videoUrls = [];

    for (final video in videos) {
      final String baseName = path.basename(video.path);
      final String nameNoExt = path.basenameWithoutExtension(baseName);

      final Reference upload = storage.child('listings/videos/$nameNoExt.mp4');
      final SettableMetadata meta = SettableMetadata(
        contentType: 'video/mp4',
      );

      final UploadTask uploadTask = upload.putFile(video, meta);
      final String downloadUrl =
      await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
      videoUrls.add(downloadUrl);
    }

    return videoUrls;
  }

  // ---------------------------
  // Places
  // ---------------------------

  /// Safe Places Details fetch:
  /// 1) Calls Google endpoint directly and builds PlaceDetails manually (best for debugging).
  /// 2) Falls back to plugin call, but guarded so it cannot crash your app.
  @override
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction) async {
    final placeId = prediction.placeId;
    debugPrint('*** DEBUG: getPlaceDetails called with placeId: $placeId');
    if (placeId == null || placeId.trim().isEmpty) {
      debugPrint('getPlaceDetails(): prediction.placeId is null/empty');
      return null;
    }

    // 1) RAW HTTP call (best debugging + avoids plugin JSON decode crash)
    try {
      final key = cfg.googleMapsApiKey;
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        <String, String>{
          'place_id': placeId,
          'key': key,
          'fields': 'place_id,name,formatted_address,geometry',
          'language': 'en',
        },
      );
      debugPrint('*** DEBUG: getPlaceDetails HTTP URI: $uri');
      final res = await http.get(uri);
      debugPrint('*** DEBUG: getPlaceDetails HTTP status: ${res.statusCode} body: ${res.body}');
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final status = (decoded['status'] ?? '').toString();
        debugPrint('*** DEBUG: getPlaceDetails HTTP decoded status: $status');
        if (status != 'OK') return null;

        final result = decoded['result'];
        if (result is! Map<String, dynamic>) return null;

        final formattedAddress = (result['formatted_address'] ?? '').toString();
        final name = (result['name'] ?? formattedAddress).toString();
        final pid = (result['place_id'] ?? placeId).toString();

        final geometry = result['geometry'];
        final location =
        (geometry is Map<String, dynamic>) ? geometry['location'] : null;
        final lat = (location is Map<String, dynamic>) ? location['lat'] : null;
        final lng = (location is Map<String, dynamic>) ? location['lng'] : null;

        final latD = (lat is num) ? lat.toDouble() : null;
        final lngD = (lng is num) ? lng.toDouble() : null;

        if (latD == null || lngD == null) return null;

        return PlaceDetails(
          placeId: pid,
          name: name,
          formattedAddress: formattedAddress.isEmpty
              ? (prediction.description ?? 'Unknown location')
              : formattedAddress,
          geometry: Geometry(location: Location(lat: latD, lng: lngD)),
        );
      }
    } catch (e, st) {
      debugPrint('getPlaceDetails(): RAW HTTP decode/build failed: $e');
      debugPrint('$st');
    }

    // 2) Plugin fallback (guarded so it cannot crash)
    try {
      debugPrint('*** DEBUG: getPlaceDetails plugin fallback for placeId: $placeId');
      final response = await _places.getDetailsByPlaceId(
        placeId,
        fields: const <String>['place_id', 'name', 'formatted_address', 'geometry'],
        language: 'en',
      );
      debugPrint('*** DEBUG: getPlaceDetails plugin response: status=${response.status} isOkay=${response.isOkay} errorMessage=${response.errorMessage}');
      if (response.isOkay) {
        return response.result;
      }
      debugPrint(
        'getPlaceDetails(): plugin response NOT OK: status=${response.status} message=${response.errorMessage}',
      );
      return null;
    } catch (e, st) {
      debugPrint('getPlaceDetails(): plugin call threw: $e');
      debugPrint('$st');
      return null;
    }
  }

  // ---------------------------
  // Storage helpers
  // ---------------------------

  /// Higher-quality compression with safe downscaling.
  ///
  /// Rationale:
  /// - Prior quality=25 produced visibly degraded uploads.
  /// - We downscale to a max dimension (default 1600) and keep JPEG quality high (85).
  Future<File> compressImage(File file) async {
    try {
      final props = await FlutterNativeImage.getImageProperties(file.path);
      final int w = props.width ?? 0;
      final int h = props.height ?? 0;

      // If we cannot read properties, fall back to quality-only.
      if (w <= 0 || h <= 0) {
        return FlutterNativeImage.compressImage(
          file.path,
          quality: 85,
        );
      }

      const int maxDim = 1600;
      final double scale =
      (w > h ? maxDim / w : maxDim / h).clamp(0.0, 1.0);

      final int targetW = (w * scale).round().clamp(1, w);
      final int targetH = (h * scale).round().clamp(1, h);

      return FlutterNativeImage.compressImage(
        file.path,
        quality: 85,
        targetWidth: targetW,
        targetHeight: targetH,
      );
    } catch (e, st) {
      debugPrint('compressImage() ERROR: $e');
      debugPrint('$st');
      return FlutterNativeImage.compressImage(
        file.path,
        quality: 85,
      );
    }
  }

  Future<void> deleteImageFromStorage(String imageURL) async {
    final String fileUrl =
    Uri.decodeFull(path.basename(imageURL)).replaceAll(RegExp(r'(\?alt).*'), '');
    await storage.child(fileUrl).delete();
  }

  Future<void> deleteVideoFromStorage(String videoURL) async {
    final String fileUrl =
    Uri.decodeFull(path.basename(videoURL)).replaceAll(RegExp(r'(\?alt).*'), '');
    await storage.child(fileUrl).delete();
  }

  // ---------------------------
  // Verification
  // ---------------------------

  @override
  Future<List<ListingModel>> getUnverifiedListings() async {
    final snapshot = await firestore
        .collection(cfg.listingsCollection)
        .where('suspended', isEqualTo: false)
        .limit(100)
        .get();

    final all = snapshot.docs.map((doc) {
      final model = ListingModel.fromJson(doc.data());
      model.id = doc.id;
      return model;
    }).toList();

    // Treat missing 'verified' field as false (unverified)
    return all.where((m) => m.verified != true).toList();
  }

  @override
  Future<void> verifyListing(String listingId, String adminId, String reason) async {
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingId)
        .update({
          'verified': true,
          'verificationMethod': 'manual',
          'verifiedAt': Timestamp.now().seconds,
          'verifiedBy': adminId,
          'verificationReason': reason,
        });
  }

  @override
  Future<void> rejectListing(String listingId) async {
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingId)
        .update({
          'suspended': true,
          'verificationReason': 'Rejected by admin',
        });
  }

  // ---------------------------
  // Featured
  // ---------------------------

  @override
  Future<List<ListingModel>> getFeaturedListings() async {
    final now = Timestamp.now().seconds;
    final snapshot = await firestore
        .collection(cfg.listingsCollection)
        .where('isFeatured', isEqualTo: true)
        .where('suspended', isEqualTo: false)
        .limit(20)
        .get();

    final all = snapshot.docs.map((doc) {
      final model = ListingModel.fromJson(doc.data());
      model.id = doc.id;
      return model;
    }).toList();

    // Filter expired featured listings and hidden listings
    return all.where((m) {
      if (m.hidden) return false; // Filter out hidden listings
      if (m.featuredUntil == null) return true; // No expiration
      return m.featuredUntil! > now;
    }).toList();
  }

  @override
  Future<void> featureListing(String listingID, String featuredBy, {int? durationDays}) async {
    final data = <String, dynamic>{
      'isFeatured': true,
      'featuredBy': featuredBy,
    };

    if (durationDays != null) {
      final now = Timestamp.now().seconds;
      final expiry = now + (durationDays * 24 * 60 * 60);
      data['featuredUntil'] = expiry;
    }

    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingID)
        .update(data);
  }

  @override
  Future<void> unfeatureListing(String listingID) async {
    await firestore
        .collection(cfg.listingsCollection)
        .doc(listingID)
        .update({
          'isFeatured': false,
          'featuredUntil': null,
          'featuredBy': null,
        });
  }
}
