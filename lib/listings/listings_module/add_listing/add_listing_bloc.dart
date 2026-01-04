import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_event.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_state.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';

class AddListingBloc extends Bloc<AddListingEvent, AddListingState> {
  final ListingsUser currentUser;
  final ListingsRepository listingsRepository;

  // New images selected during Add/Edit
  final List<File> listingImages = [];

  AddListingBloc({
    required this.currentUser,
    required this.listingsRepository,
  }) : super(AddListingInitial()) {
    on<GetCategoriesEvent>((event, emit) async {
      final categories = await listingsRepository.getCategories();
      emit(CategoriesFetchedState(categories: categories));
    });

    on<CategorySelectedEvent>((event, emit) async {
      emit(CategorySelectedState(category: event.categoriesModel));
    });

    on<SetFiltersEvent>((event, emit) async {
      emit(SetFiltersState(filters: event.filters));
    });

    on<GetPlaceDetailsEvent>((event, emit) async {
      final PlaceDetails? placeDetails =
      await listingsRepository.getPlaceDetails(event.prediction);
      emit(PlaceDetailsState(placeDetails: placeDetails));
    });

    on<AddImageToListingEvent>((event, emit) async {
      final File? image = await listingsRepository.getListingImage(
        fromGallery: event.fromGallery,
      );
      if (image != null) {
        listingImages.add(image);
        emit(ListingImagesUpdatedState(images: List<File>.from(listingImages)));
      }
    });

    on<RemoveListingImageEvent>((event, emit) async {
      // Screen manages removing existing URL images.
      // Bloc only removes NEW picked File images if passed in.
      if (event.image is File) {
        listingImages.remove(event.image as File);
        emit(ListingImagesUpdatedState(images: List<File>.from(listingImages)));
      }
    });

    on<ValidateListingInputEvent>((event, emit) {
      if (event.title.isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Title',
          errorMessage: 'You need to set a title for the listing.',
        ));
        return;
      }

      if (event.description.isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Description',
          errorMessage: 'You need a short description for the listing.',
        ));
        return;
      }

      if (event.category == null) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Category',
          errorMessage: 'You need to select a category for the listing.',
        ));
        return;
      }

      if (event.placeDetails == null) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Place',
          errorMessage: 'You need to set a place for the listing.',
        ));
        return;
      }

      // For ADD: require at least one new image
      // For EDIT: allow either existing photos OR new photos
      final int totalPhotos = event.existingPhotoUrls.length + listingImages.length;
      if (totalPhotos == 0) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Images',
          errorMessage: 'You need at least one photo for the listing.',
        ));
        return;
      }

      final model = ListingModel(
        title: event.title,
        createdAt: event.isEdit
            ? (event.listingToEdit?.createdAt ?? Timestamp.now().seconds)
            : Timestamp.now().seconds,
        authorID: event.isEdit ? (event.listingToEdit?.authorID ?? currentUser.userID) : currentUser.userID,
        authorName: event.isEdit ? (event.listingToEdit?.authorName ?? currentUser.fullName()) : currentUser.fullName(),
        authorProfilePic: event.isEdit
            ? (event.listingToEdit?.authorProfilePic ?? currentUser.profilePictureURL)
            : currentUser.profilePictureURL,
        categoryID: event.category!.id,
        categoryPhoto: event.category!.photo,
        categoryTitle: event.category!.title,
        description: event.description,
        price: event.price.trim().isEmpty ? '' : '${event.price}\$',
        latitude: event.placeDetails!.geometry!.location.lat,
        longitude: event.placeDetails!.geometry!.location.lng,
        filters: event.filters ?? {},
        place: event.placeDetails!.formattedAddress ?? '',
        phone: event.phone.trim(),
        email: event.email.trim(),
        website: event.website.trim(),
        openingHours: event.openingHours.trim(),
        reviewsCount: event.isEdit ? (event.listingToEdit?.reviewsCount ?? 0) : 0,
        reviewsSum: event.isEdit ? (event.listingToEdit?.reviewsSum ?? 0) : 0,
        isApproved: event.isEdit ? (event.listingToEdit?.isApproved ?? false) : false,
      );

      add(PublishListingEvent(
        listingModel: model,
        isEdit: event.isEdit,
        listingIdToUpdate: event.listingToEdit?.id,
        existingPhotoUrls: event.existingPhotoUrls,
      ));
    });

    on<PublishListingEvent>((event, emit) async {
      // Upload NEW images (if any)
      List<String> newUrls = [];
      if (listingImages.isNotEmpty) {
        emit(AddListingProgressState(progressMessage: 'Uploading Images...'.tr()));
        newUrls = await listingsRepository.uploadListingImages(images: listingImages);
        if (newUrls.isEmpty) {
          emit(AddListingErrorState(
            errorTitle: 'Upload Failed',
            errorMessage: 'We could not upload your images. Please try again.',
          ));
          return;
        }
      }

      final allPhotos = [...event.existingPhotoUrls, ...newUrls];
      if (allPhotos.isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Images',
          errorMessage: 'You need at least one photo for the listing.',
        ));
        return;
      }

      event.listingModel.photo = allPhotos.first;
      event.listingModel.photos = allPhotos;

      if (!event.isEdit) {
        emit(AddListingProgressState(progressMessage: 'Publishing Listing...'.tr()));
        final bool isDone = await listingsRepository.publishListing(event.listingModel);

        if (isDone) {
          listingImages.clear();
          emit(ListingPublishedState());
        } else {
          emit(AddListingErrorState(
            errorTitle: 'Publish Failed',
            errorMessage: 'We could not publish your listing. Please try again.',
          ));
        }
        return;
      }

      // EDIT: update Firestore directly (keeps your existing repository intact)
      if (event.listingIdToUpdate == null || event.listingIdToUpdate!.trim().isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Update Failed',
          errorMessage: 'Missing listing ID. Cannot update this listing.',
        ));
        return;
      }

      emit(AddListingProgressState(progressMessage: 'Updating Listing...'.tr()));
      try {
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(event.listingIdToUpdate)
            .update({
          'title': event.listingModel.title,
          'description': event.listingModel.description,
          'price': event.listingModel.price,
          'categoryID': event.listingModel.categoryID,
          'categoryPhoto': event.listingModel.categoryPhoto,
          'categoryTitle': event.listingModel.categoryTitle,
          'filters': event.listingModel.filters,
          'place': event.listingModel.place,
          'latitude': event.listingModel.latitude,
          'longitude': event.listingModel.longitude,
          'phone': event.listingModel.phone,
          'email': event.listingModel.email,
          'website': event.listingModel.website,
          'openingHours': event.listingModel.openingHours,
          'photo': event.listingModel.photo,
          'photos': event.listingModel.photos,
        });

        listingImages.clear();
        emit(ListingUpdatedState());
      } catch (_) {
        emit(AddListingErrorState(
          errorTitle: 'Update Failed',
          errorMessage: 'We could not update your listing. Please try again.',
        ));
      }
    });
  }
}
