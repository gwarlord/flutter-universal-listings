import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/filter_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';

class ListingsCustomBackendUtils extends ListingsRepository {
  @override
  Future<void> approveListing({required ListingModel listingModel}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteListing({required ListingModel listingModel}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<CategoriesModel>> getCategories() async {
    throw UnimplementedError();
  }

  @override
  Future<List<FilterModel>> getFilters() async {
    throw UnimplementedError();
  }

  @override
  Future<ListingModel?> getListing({required String listingID}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingModel>> getListings({required List<String> favListingsIDs}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingModel>> getListingsByCategoryID({
    required String categoryID,
    required List<String> favListingsIDs,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingModel>> getMyListings({
    required String currentUserID,
    required List<String> favListingsIDs,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingModel>> getPendingListings({required List<String> favListingsIDs}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingModel>> getFavoriteListings({required List<String> favListingsIDs}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> uploadListingImages({required List<File> images}) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> publishListing(ListingModel listingModel) async {
    throw UnimplementedError();
  }

  @override
  Future<File?> getListingImage({required bool fromGallery}) async {
    debugPrint('ListingsCustomBackendUtils.getListingImage not implemented');
    return null;
  }

  @override
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction) async {
    debugPrint('ListingsCustomBackendUtils.getPlaceDetails not implemented');
    return null;
  }

  @override
  Future<void> postListing({required ListingModel newListing}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> postReview({required ListingReviewModel reviewModel}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ListingReviewModel>> getReviews({required String listingID}) async {
    throw UnimplementedError();
  }
}
