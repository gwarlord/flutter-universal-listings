import 'dart:io';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';

abstract class AddListingEvent {}

/* -------------------- Categories / Filters -------------------- */

class GetCategoriesEvent extends AddListingEvent {}

class CategorySelectedEvent extends AddListingEvent {
  final CategoriesModel? categoriesModel;
  CategorySelectedEvent({required this.categoriesModel});
}

class SetFiltersEvent extends AddListingEvent {
  final Map<String, String>? filters;
  SetFiltersEvent({required this.filters});
}

/* -------------------- Places -------------------- */

class GetPlaceDetailsEvent extends AddListingEvent {
  final Prediction prediction;
  GetPlaceDetailsEvent({required this.prediction});
}

/* -------------------- Images -------------------- */

class AddImageToListingEvent extends AddListingEvent {
  final bool fromGallery;
  AddImageToListingEvent({required this.fromGallery});
}

class RemoveListingImageEvent extends AddListingEvent {
  final File image;
  RemoveListingImageEvent({required this.image});
}

/* -------------------- Videos -------------------- */
/* NOTE:
 * Screen calls: AddVideoToListingEvent(fromGallery: true/false)
 * Bloc will pick the file by calling listingsRepository.getListingVideo(...)
 */
class AddVideoToListingEvent extends AddListingEvent {
  final bool fromGallery;
  AddVideoToListingEvent({required this.fromGallery});
}

class RemoveListingVideoEvent extends AddListingEvent {
  final File video;
  RemoveListingVideoEvent({required this.video});
}

/* -------------------- Validate & Publish -------------------- */

class ValidateListingInputEvent extends AddListingEvent {
  final String title;
  final String description;
  final String price;
  final String currencyCode;

  final String phone;
  final String email;
  final String website;
  final String openingHours;

  final bool bookingEnabled;
  final String bookingUrl;

  final String instagram;
  final String facebook;
  final String tiktok;
  final String whatsapp;
  final String youtube;
  final String x;

  final CategoriesModel? category;
  final Map<String, String>? filters;
  final PlaceDetails? placeDetails;

  final bool isEdit;
  final ListingModel? listingToEdit;

  final List<String> existingPhotoUrls;

  /// Made OPTIONAL (defaults to empty) to avoid:
  /// "Required named parameter 'existingVideoUrls' must be provided."
  final List<String> existingVideoUrls;

  final String countryCode;
  final bool verified;

  ValidateListingInputEvent({
    required this.title,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.phone,
    required this.email,
    required this.website,
    required this.openingHours,
    required this.bookingEnabled,
    required this.bookingUrl,
    required this.instagram,
    required this.facebook,
    required this.tiktok,
    required this.whatsapp,
    required this.youtube,
    required this.x,
    required this.category,
    required this.filters,
    required this.placeDetails,
    required this.isEdit,
    required this.listingToEdit,
    required this.existingPhotoUrls,
    this.existingVideoUrls = const <String>[],
    required this.countryCode,
    required this.verified,
  });
}

class PublishListingEvent extends AddListingEvent {
  final ListingModel listingModel;

  final bool isEdit;
  final String? listingIdToUpdate;

  final List<String> existingPhotoUrls;
  final List<String> existingVideoUrls;

  PublishListingEvent({
    required this.listingModel,
    required this.isEdit,
    required this.listingIdToUpdate,
    required this.existingPhotoUrls,
    this.existingVideoUrls = const <String>[],
  });
}
