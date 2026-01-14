import 'dart:io';

import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';

abstract class AddListingState {}

class AddListingInitial extends AddListingState {}

class AddListingProgressState extends AddListingState {
  final String progressMessage;
  AddListingProgressState({required this.progressMessage});
}

class AddListingErrorState extends AddListingState {
  final String errorTitle;
  final String errorMessage;
  AddListingErrorState({required this.errorTitle, required this.errorMessage});
}

class CategoriesFetchedState extends AddListingState {
  final List<CategoriesModel> categories;
  CategoriesFetchedState({required this.categories});
}

class CategorySelectedState extends AddListingState {
  final CategoriesModel? category;
  CategorySelectedState({required this.category});
}

class SetFiltersState extends AddListingState {
  final Map<String, String>? filters;
  SetFiltersState({required this.filters});
}

class PlaceDetailsState extends AddListingState {
  final PlaceDetails? placeDetails;
  PlaceDetailsState({required this.placeDetails});
}

class ListingImagesUpdatedState extends AddListingState {
  final List<File> images;
  ListingImagesUpdatedState({required this.images});
}

class ListingVideosUpdatedState extends AddListingState {
  final List<File> videos;
  ListingVideosUpdatedState({required this.videos});
}

class ListingPublishedState extends AddListingState {}

class ListingUpdatedState extends AddListingState {
  final ListingModel updatedListing;
  ListingUpdatedState({required this.updatedListing});
}
