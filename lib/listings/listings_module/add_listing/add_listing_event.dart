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

class AddImagesToListingEvent extends AddListingEvent {
  final List<File> images;
  AddImagesToListingEvent({required this.images});
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
  final bool allowQuantitySelection; // ✅ Added
  final bool useTimeBlocks; // ✅ Added
  final bool allowMultipleBookingsPerDay; // ✅ Added
  final List<String> timeBlocks; // ✅ Added
  final bool enableCustomQuestions; // ✅ Added
  final List<String> customQuestions; // ✅ Added
  final List<ServiceItem> services; // ✅ Added
  final List<int> blockedDates; // ✅ Added (milliseconds since epoch)

  final bool storeEnabled; // ✅ Added
  final String storeUrl; // ✅ Added

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

  // Logo
  final File? newLogoFile;
  final String? existingLogoUrl;

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
    required this.allowQuantitySelection, // ✅ Added
    required this.useTimeBlocks, // ✅ Added
    required this.allowMultipleBookingsPerDay, // ✅ Added
    required this.timeBlocks, // ✅ Added
    required this.enableCustomQuestions, // ✅ Added
    required this.customQuestions, // ✅ Added
    required this.services, // ✅ Added
    required this.blockedDates, // ✅ Added
    required this.storeEnabled, // ✅ Added
    required this.storeUrl, // ✅ Added
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
    this.newLogoFile,
    this.existingLogoUrl,
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

  // Logo
  final File? newLogoFile;
  final String? existingLogoUrl;

  PublishListingEvent({
    required this.listingModel,
    required this.isEdit,
    required this.listingIdToUpdate,
    required this.existingPhotoUrls,
    this.existingVideoUrls = const <String>[],
    this.newLogoFile,
    this.existingLogoUrl,
  });
}
