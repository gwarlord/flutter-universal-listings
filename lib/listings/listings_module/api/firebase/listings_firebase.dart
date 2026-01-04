import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:flutter_native_image_v2/flutter_native_image_v2.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/filter_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:path/path.dart' as path;

class ListingsFirebaseUtils extends ListingsRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final Reference storage = FirebaseStorage.instance.ref();

  // For picking images
  final ImagePicker _picker = ImagePicker();

  // For Google Places details
  late final GoogleMapsPlaces _places = GoogleMapsPlaces(
    apiKey: cfg.googleMapsApiKey,
  );

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

    for (final imageUrl in listingModel.photos) {
      await deleteImageFromStorage(imageUrl);
    }
  }

  @override
  Future<List<CategoriesModel>> getCategories() async {
    debugPrint('getCategories() called');
    debugPrint('categoriesCollection value = "${cfg.categoriesCollection}"');

    try {
      final rawSnap = await firestore.collection(cfg.categoriesCollection).get();
      debugPrint('RAW categories docs found (no filters): ${rawSnap.docs.length}');
      if (rawSnap.docs.isNotEmpty) {
        final first = rawSnap.docs.first;
        debugPrint('RAW first doc id=${first.id} data=${first.data()}');
      }

      final filteredSnap = await firestore
          .collection(cfg.categoriesCollection)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      debugPrint(
        'FILTERED categories docs found (isActive==true, orderBy sortOrder): ${filteredSnap.docs.length}',
      );

      final categories = filteredSnap.docs
          .map((d) => CategoriesModel.fromJson(d.data(), id: d.id))
          .toList();

      debugPrint('Parsed categories length: ${categories.length}');
      return categories;
    } catch (e, st) {
      debugPrint('getCategories() ERROR: $e');
      debugPrint('$st');
      return <CategoriesModel>[];
    }
  }

  @override
  Future<List<ListingModel>> getFavoriteListings({required List<String> favListingsIDs}) async {
    final List<ListingModel> listings = [];
    for (final listingID in favListingsIDs) {
      final ListingModel? listingModel = await getListing(listingID: listingID);
      if (listingModel != null) {
        listingModel.isFav = true;
        listings.add(listingModel);
      }
    }
    return listings;
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

  @override
  Future<ListingModel?> getListing({required String listingID}) async {
    final result = await firestore
        .collection(cfg.listingsCollection)
        .doc(listingID)
        .get();

    if (result.exists && result.data() != null) {
      return ListingModel.fromJson(result.data()!);
    }
    return null;
  }

  @override
  Future<List<ListingModel>> getListings({required List<String> favListingsIDs}) async {
    final result = await firestore.collection(cfg.listingsCollection).get();
    final List<ListingModel> listings = [];

    for (final doc in result.docs) {
      try {
        listings.add(
          ListingModel.fromJson(doc.data())..isFav = favListingsIDs.contains(doc.id),
        );
      } catch (e, s) {
        debugPrint('FireStoreUtils.getListings failed to parse listing object ${doc.id} $e $s');
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
        listings.add(
          ListingModel.fromJson(doc.data())..isFav = favListingsIDs.contains(doc.id),
        );
      } catch (e, s) {
        debugPrint('FireStoreUtils.getListingsByCategoryID failed to parse listing object ${doc.id} $e $s');
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
        listings.add(
          ListingModel.fromJson(doc.data())..isFav = favListingsIDs.contains(doc.id),
        );
      } catch (e) {
        debugPrint('FireStoreUtils.getMyListings failed to parse object ${doc.id} $e');
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
        listings.add(
          ListingModel.fromJson(doc.data())..isFav = favListingsIDs.contains(doc.id),
        );
      } catch (e, s) {
        debugPrint('FireStoreUtils.getPendingListings failed to parse object ${doc.id} $e $s');
      }
    }
    return listings;
  }

  @override
  Future<List<ListingReviewModel>> getReviews({required String listingID}) async {
    final result = await firestore
        .collection(cfg.reviewCollection)
        .where('listingID', isEqualTo: listingID)
        .get();

    final List<ListingReviewModel> reviews = [];
    for (final doc in result.docs) {
      try {
        reviews.add(ListingReviewModel.fromJson(doc.data()));
      } catch (e, s) {
        debugPrint('FireStoreUtils.getReviews failed to parse object ${doc.id} $e $s');
      }
    }
    return reviews;
  }

  @override
  Future<void> postListing({required ListingModel newListing}) async {
    final DocumentReference docRef = firestore.collection(cfg.listingsCollection).doc();
    newListing.id = docRef.id;
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
  Future<void> postReview({required ListingReviewModel reviewModel}) async {
    final ListingModel? updatedListing = await getListing(listingID: reviewModel.listingID);
    if (updatedListing == null) return;

    await firestore.collection(cfg.reviewCollection).doc().set(reviewModel.toJson());

    updatedListing.reviewsCount += 1;
    updatedListing.reviewsSum += reviewModel.starCount;

    await firestore
        .collection(cfg.listingsCollection)
        .doc(updatedListing.id)
        .update(updatedListing.toJson());
  }

  @override
  Future<List<String>> uploadListingImages({required List<File> images}) async {
    final List<String> imagesUrls = [];

    for (final image in images) {
      final Reference upload = storage.child('listings/images/${image.uri.pathSegments.last}.png');

      final File compressedImage = await compressImage(image);
      final UploadTask uploadTask = upload.putFile(compressedImage);

      final String downloadUrl = await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
      imagesUrls.add(downloadUrl);
    }

    return imagesUrls;
  }

  @override
  Future<File?> getListingImage({required bool fromGallery}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 85,
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
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction) async {
    try {
      final placeId = prediction.placeId;
      if (placeId == null || placeId.trim().isEmpty) {
        print('getPlaceDetails() FAILED: prediction.placeId is null/empty');
        return null;
      }

      // NOTE:
      // Google Places Details API requires `fields` (field mask) to be specified.
      // If not provided, the API may return INVALID_REQUEST.
      final response = await _places.getDetailsByPlaceId(
        placeId,
        // Keep this minimal to reduce quota usage.
        fields: <String>[
          'place_id',
          'name',
          'formatted_address',
          'geometry',
        ],
        language: 'en',
      );

      if (response.isOkay) {
        return response.result;
      } else {
        print(
          'getPlaceDetails() FAILED: status=${response.status} message=${response.errorMessage}',
        );
        return null;
      }
    } catch (error, stackTrace) {
      print('getPlaceDetails() FAILED: $error');
      print(stackTrace);
      return null;
    }
  }

  Future<File> compressImage(File file) async {
    return FlutterNativeImage.compressImage(
      file.path,
      quality: 25,
    );
  }

  Future<void> deleteImageFromStorage(String imageURL) async {
    final String fileUrl = Uri.decodeFull(path.basename(imageURL)).replaceAll(RegExp(r'(\?alt).*'), '');
    await storage.child(fileUrl).delete();
  }
}
