import 'dart:io';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/filter_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';

class ListingsLocalData extends ListingsRepository {
  @override
  Future<List<String>> uploadListingImages({required List<File> images}) async => [];

  @override
  Future<List<String>> uploadListingVideos({required List<File> videos}) async => [];

  @override
  Future<File?> getListingImage({required bool fromGallery}) async => null;

  @override
  Future<File?> getListingVideo({required bool fromGallery}) async => null;

  @override
  Future<bool> publishListing(ListingModel listingModel) async => true;

  @override
  Future<void> postListing({required ListingModel newListing}) async {}

  @override
  Future<List<CategoriesModel>> getCategories() async => [];

  @override
  Future<List<FilterModel>> getFilters() async => [];

  @override
  Future<List<ListingModel>> getListings({required List<String> favListingsIDs}) async => [];

  @override
  Future<List<ListingModel>> getMyListings({
    required String currentUserID,
    required List<String> favListingsIDs,
  }) async =>
      [];

  @override
  Future<ListingModel?> getListing({required String listingID}) async => null;

  @override
  Future<List<ListingModel>> getFavoriteListings({
    required List<String> favListingsIDs,
  }) async =>
      [];

  @override
  Future<List<ListingModel>> getListingsByCategoryID({
    required String categoryID,
    required List<String> favListingsIDs,
  }) async =>
      [];

  @override
  Future<List<ListingModel>> getPendingListings({
    required List<String> favListingsIDs,
  }) async =>
      [];

  @override
  Future<void> approveListing({required ListingModel listingModel}) async {}

  @override
  Future<void> deleteListing({required ListingModel listingModel}) async {}

  @override
  Future<void> postReview({required ListingReviewModel reviewModel}) async {}

  @override
  Future<List<ListingReviewModel>> getReviews({required String listingID}) async => [];

  @override
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction) async => null;

  @override
  Future<List<ListingModel>> getSuspendedListings() async => [];

  @override
  Future<void> suspendListing({required ListingModel listing}) async {}

  @override
  Future<void> unsuspendListing({required ListingModel listing}) async {}

  @override
  Future<List<ListingModel>> getUnverifiedListings() async => [];

  @override
  Future<void> verifyListing(String listingID, String verifiedBy, String reason) async {}

  @override
  Future<void> rejectListing(String listingID) async {}
}
