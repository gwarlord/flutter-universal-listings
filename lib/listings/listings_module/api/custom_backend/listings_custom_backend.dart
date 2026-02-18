import 'dart:io';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/filter_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/model/paged_reviews_result.dart';
import 'package:caribtap/listings/model/reported_listing_model.dart';
import 'package:caribtap/listings/model/suspension_info.dart';

class ListingsCustomBackendUtils extends ListingsRepository {
  @override
  Future<List<String>> uploadListingImages({required List<File> images}) async {
    return <String>[];
  }

  @override
  Future<List<File>> getListingImages() async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> uploadListingVideos({required List<File> videos}) async {
    return <String>[];
  }

  @override
  Future<File?> getListingImage({required bool fromGallery}) async {
    return null;
  }

  @override
  Future<File?> getListingVideo({required bool fromGallery}) async {
    return null;
  }

  @override
  Future<bool> publishListing(ListingModel listingModel) async {
    return true;
  }

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
  Future<List<ListingModel>> getSuspendedListings() async => [];

  @override
  Future<void> suspendListing({
    required ListingModel listing,
    SuspensionInfo? suspensionInfo,
    required String adminId,
  }) async {}

  @override
  Future<void> unsuspendListing({
    required ListingModel listing,
    required String adminId,
  }) async {}

  @override
  Future<void> requestUnsuspension({
    required ListingModel listing,
    required String requestText,
  }) async {}

  @override
  Future<void> postReview({required ListingReviewModel reviewModel}) async {}

  @override
  Future<List<ListingReviewModel>> getReviews({required String listingID}) async => [];

  @override
  Future<PagedReviewsResult> getReviewsPaged({
    required String listingID,
    int limit = 10,
    int? startAfterCreatedAt,
    bool descending = true,
  }) async {
    return PagedReviewsResult.empty();
  }

  @override
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction) async => null;

  @override
  Future<List<ListingModel>> getUnverifiedListings() async => [];

  @override
  Future<void> verifyListing(String listingID, String verifiedBy, String reason) async {}

  @override
  Future<void> rejectListing(String listingID) async {}

  @override
  Future<List<ListingModel>> getFeaturedListings() async => [];

  @override
  Future<void> featureListing(String listingID, String featuredBy, {int? durationDays}) async {}

  @override
  Future<void> unfeatureListing(String listingID) async {}

  @override
  Future<void> refreshListingFreshness({required String listingId}) async {}

  @override
  Future<List<ReportedListing>> getReportedListings() async => [];

  @override
  Future<void> dismissReport(String reportId) async {}
}
