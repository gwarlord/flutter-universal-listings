import 'dart:io';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/filter_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';

abstract class ListingsRepository {
  // Categories / filters
  Future<List<CategoriesModel>> getCategories();
  Future<List<FilterModel>> getFilters();

  // Listings CRUD / queries
  Future<List<ListingModel>> getListings({required List<String> favListingsIDs});
  Future<List<ListingModel>> getMyListings({
    required String currentUserID,
    required List<String> favListingsIDs,
  });
  Future<ListingModel?> getListing({required String listingID});
  Future<List<ListingModel>> getFavoriteListings({required List<String> favListingsIDs});
  Future<List<ListingModel>> getListingsByCategoryID({
    required String categoryID,
    required List<String> favListingsIDs,
  });
  Future<List<ListingModel>> getPendingListings({required List<String> favListingsIDs});

  // Publishing
  Future<List<String>> uploadListingImages({required List<File> images});
  Future<List<String>> uploadListingVideos({required List<File> videos});

  Future<File?> getListingImage({required bool fromGallery});
  Future<File?> getListingVideo({required bool fromGallery});

  Future<bool> publishListing(ListingModel listingModel);

  // Places
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction);

  // Reviews
  Future<void> postReview({required ListingReviewModel reviewModel});
  Future<List<ListingReviewModel>> getReviews({required String listingID});

  // Admin / moderation
  Future<void> approveListing({required ListingModel listingModel});
  Future<void> deleteListing({required ListingModel listingModel});

  // Listing suspension
  Future<List<ListingModel>> getSuspendedListings();
  Future<void> suspendListing({required ListingModel listing});

  // Verification
  Future<List<ListingModel>> getUnverifiedListings();
  Future<void> verifyListing(String listingId, String adminId, String reason);
  Future<void> rejectListing(String listingId);
  Future<void> unsuspendListing({required ListingModel listing});

  // Legacy
  Future<void> postListing({required ListingModel newListing});
}
