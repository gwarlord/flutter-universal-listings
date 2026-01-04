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
  Future<bool> publishListing(ListingModel listingModel);

  // Image picking (used by AddListingBloc)
  Future<File?> getListingImage({required bool fromGallery});

  // Places (used by AddListingBloc)
  Future<PlaceDetails?> getPlaceDetails(Prediction prediction);

  // Reviews
  Future<void> postReview({required ListingReviewModel reviewModel});
  Future<List<ListingReviewModel>> getReviews({required String listingID});

  // Admin / moderation
  Future<void> approveListing({required ListingModel listingModel});
  Future<void> deleteListing({required ListingModel listingModel});

  // Legacy (keep for compatibility if other screens still call it)
  Future<void> postListing({required ListingModel newListing});
}
