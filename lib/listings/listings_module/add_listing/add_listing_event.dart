import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';

abstract class AddListingEvent {}

class GetCategoriesEvent extends AddListingEvent {}

class CategorySelectedEvent extends AddListingEvent {
  final CategoriesModel? categoriesModel;
  CategorySelectedEvent({required this.categoriesModel});
}

class SetFiltersEvent extends AddListingEvent {
  final Map<String, String>? filters;
  SetFiltersEvent({required this.filters});
}

class GetPlaceDetailsEvent extends AddListingEvent {
  final Prediction prediction;
  GetPlaceDetailsEvent({required this.prediction});
}

class AddImageToListingEvent extends AddListingEvent {
  final bool fromGallery;
  AddImageToListingEvent({required this.fromGallery});
}

class RemoveListingImageEvent extends AddListingEvent {
  final dynamic image; // File OR String(url) – screen manages the removal
  RemoveListingImageEvent({required this.image});
}

class ValidateListingInputEvent extends AddListingEvent {
  final String title;
  final String description;
  final String price;
  final String phone;
  final String email;
  final String website;
  final String openingHours;

  final CategoriesModel? category;
  final Map<String, String>? filters;
  final PlaceDetails? placeDetails;

  // EDIT MODE
  final bool isEdit;
  final ListingModel? listingToEdit;
  final List<String> existingPhotoUrls;

  ValidateListingInputEvent({
    required this.title,
    required this.description,
    required this.price,
    required this.phone,
    required this.email,
    required this.website,
    required this.openingHours,
    required this.category,
    required this.filters,
    required this.placeDetails,
    this.isEdit = false,
    this.listingToEdit,
    this.existingPhotoUrls = const [],
  });
}

class PublishListingEvent extends AddListingEvent {
  final ListingModel listingModel;
  final bool isEdit;
  final String? listingIdToUpdate;
  final List<String> existingPhotoUrls;

  PublishListingEvent({
    required this.listingModel,
    this.isEdit = false,
    this.listingIdToUpdate,
    this.existingPhotoUrls = const [],
  });
}
