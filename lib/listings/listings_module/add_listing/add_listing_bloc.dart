import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_event.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_state.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

/// Caribbean + Caribbean territories (ISO 3166-1 alpha-2)
const Set<String> kCaribbeanCountryCodes = {
  'AI', 'AG', 'AW', 'BS', 'BB', 'BZ', 'BM', 'BQ', 'VG', 'KY', 'CU', 'CW', 'DM',
  'DO', 'GD', 'GP', 'GY', 'HT', 'JM', 'MQ', 'MS', 'PR', 'BL', 'KN', 'LC', 'MF',
  'VC', 'SX', 'SR', 'TT', 'TC', 'VI',
};

class AddListingBloc extends Bloc<AddListingEvent, AddListingState> {
  final ListingsUser currentUser;
  final ListingsRepository listingsRepository;

  /// New media selected during Add/Edit
  final List<File> listingImages = [];
  final List<File> listingVideos = [];

  AddListingBloc({
    required this.currentUser,
    required this.listingsRepository,
  }) : super(AddListingInitial()) {
    /* -------------------- Categories / Filters -------------------- */

    on<GetCategoriesEvent>((event, emit) async {
      final categories = await listingsRepository.getCategories();
      emit(CategoriesFetchedState(categories: categories));
    });

    on<CategorySelectedEvent>((event, emit) {
      emit(CategorySelectedState(category: event.categoriesModel));
    });

    on<SetFiltersEvent>((event, emit) {
      emit(SetFiltersState(filters: event.filters));
    });

    /* -------------------- Places -------------------- */

    on<GetPlaceDetailsEvent>((event, emit) async {
      final PlaceDetails? placeDetails =
      await listingsRepository.getPlaceDetails(event.prediction);
      emit(PlaceDetailsState(placeDetails: placeDetails));
    });

    /* -------------------- Images -------------------- */

    on<AddImageToListingEvent>((event, emit) async {
      final File? image = await listingsRepository.getListingImage(
        fromGallery: event.fromGallery,
      );
      if (image != null) {
        listingImages.add(image);
        emit(ListingImagesUpdatedState(images: List<File>.from(listingImages)));
      }
    });

    on<RemoveListingImageEvent>((event, emit) {
      listingImages.remove(event.image);
      emit(ListingImagesUpdatedState(images: List<File>.from(listingImages)));
    });

    /* -------------------- Videos -------------------- */

    on<AddVideoToListingEvent>((event, emit) async {
      // Max 3 videos
      if (listingVideos.length >= 3) {
        emit(AddListingErrorState(
          errorTitle: 'Video limit reached'.tr(),
          errorMessage: 'You can upload a maximum of 3 videos.'.tr(),
        ));
        return;
      }

      // Pick video using repository (matches your screen calling fromGallery)
      File? video;
      try {
        video = await listingsRepository.getListingVideo(
          fromGallery: event.fromGallery,
        );
      } catch (_) {
        video = null;
      }

      if (video == null) return;

      // Enforce MP4-only on client side (encoding can be handled in repository)
      final pathLower = video.path.toLowerCase();
      if (!pathLower.endsWith('.mp4')) {
        emit(AddListingErrorState(
          errorTitle: 'Invalid format'.tr(),
          errorMessage: 'Only MP4 videos are allowed.'.tr(),
        ));
        return;
      }

      listingVideos.add(video);
      emit(ListingVideosUpdatedState(videos: List<File>.from(listingVideos)));
    });

    on<RemoveListingVideoEvent>((event, emit) {
      listingVideos.remove(event.video);
      emit(ListingVideosUpdatedState(videos: List<File>.from(listingVideos)));
    });

    /* -------------------- Validate -------------------- */

    on<ValidateListingInputEvent>((event, emit) {
      if (event.title.trim().isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Title'.tr(),
          errorMessage: 'You need to set a title for the listing.'.tr(),
        ));
        return;
      }

      if (event.description.trim().isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Description'.tr(),
          errorMessage: 'You need a short description for the listing.'.tr(),
        ));
        return;
      }

      if (event.category == null) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Category'.tr(),
          errorMessage: 'You need to select a category for the listing.'.tr(),
        ));
        return;
      }

      if (event.placeDetails == null) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Place'.tr(),
          errorMessage: 'You need to set a place for the listing.'.tr(),
        ));
        return;
      }

      // Caribbean-only country validation
      final String countryCode = event.countryCode.trim().toUpperCase();
      if (countryCode.isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Country'.tr(),
          errorMessage: 'Please select a country.'.tr(),
        ));
        return;
      }
      if (!kCaribbeanCountryCodes.contains(countryCode)) {
        emit(AddListingErrorState(
          errorTitle: 'Invalid Country'.tr(),
          errorMessage: 'Please choose a Caribbean country.'.tr(),
        ));
        return;
      }

      // Require at least one photo overall (existing + new)
      final int totalPhotos = event.existingPhotoUrls.length + listingImages.length;
      if (totalPhotos == 0) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Images'.tr(),
          errorMessage: 'You need at least one photo for the listing.'.tr(),
        ));
        return;
      }

      // If your ListingModel constructor differs, keep this block aligned with your model.
      final model = ListingModel(
        title: event.title.trim(),
        description: event.description.trim(),
        price: event.price.toString(),
        currencyCode: event.currencyCode,
        latitude: event.placeDetails!.geometry!.location.lat,
        longitude: event.placeDetails!.geometry!.location.lng,
        place: event.placeDetails!.formattedAddress ?? '',
        phone: event.phone.trim(),
        email: event.email.trim(),
        website: event.website.trim(),
        openingHours: event.openingHours.trim(),
        instagram: event.instagram.trim(),
        facebook: event.facebook.trim(),
        tiktok: event.tiktok.trim(),
        whatsapp: event.whatsapp.trim(),
        youtube: event.youtube.trim(),
        x: event.x.trim(),
        filters: event.filters ?? <String, String>{},

        categoryID: event.category!.id,
        categoryTitle: event.category!.title,
        categoryPhoto: event.category!.photo,

        // Author / timestamps
        authorID: event.isEdit
            ? (event.listingToEdit?.authorID ?? currentUser.userID)
            : currentUser.userID,
        authorName: event.isEdit
            ? (event.listingToEdit?.authorName ?? currentUser.fullName())
            : currentUser.fullName(),
        authorProfilePic: event.isEdit
            ? (event.listingToEdit?.authorProfilePic ?? currentUser.profilePictureURL)
            : currentUser.profilePictureURL,
        createdAt: event.isEdit
            ? (event.listingToEdit?.createdAt ?? Timestamp.now().seconds)
            : Timestamp.now().seconds,

        reviewsCount: event.isEdit ? (event.listingToEdit?.reviewsCount ?? 0) : 0,
        reviewsSum: event.isEdit ? (event.listingToEdit?.reviewsSum ?? 0) : 0,
        isApproved: event.isEdit ? (event.listingToEdit?.isApproved ?? false) : false,

        // Country
        countryCode: countryCode,
      );

      add(PublishListingEvent(
        listingModel: model,
        isEdit: event.isEdit,
        listingIdToUpdate: event.listingToEdit?.id,
        existingPhotoUrls: event.existingPhotoUrls,
        existingVideoUrls: event.existingVideoUrls,
      ));
    });

    /* -------------------- Publish (Add or Edit) -------------------- */

    on<PublishListingEvent>((event, emit) async {
      // Upload NEW images
      List<String> newImageUrls = [];
      if (listingImages.isNotEmpty) {
        emit(AddListingProgressState(progressMessage: 'Uploading Images...'.tr()));
        newImageUrls = await listingsRepository.uploadListingImages(
          images: listingImages,
        );
        if (newImageUrls.isEmpty && listingImages.isNotEmpty) {
          emit(AddListingErrorState(
            errorTitle: 'Upload Failed'.tr(),
            errorMessage: 'We could not upload your images. Please try again.'.tr(),
          ));
          return;
        }
      }

      // Upload NEW videos
      List<String> newVideoUrls = [];
      if (listingVideos.isNotEmpty) {
        emit(AddListingProgressState(progressMessage: 'Uploading Videos...'.tr()));
        newVideoUrls = await listingsRepository.uploadListingVideos(
          videos: listingVideos,
        );
        if (newVideoUrls.isEmpty && listingVideos.isNotEmpty) {
          emit(AddListingErrorState(
            errorTitle: 'Upload Failed'.tr(),
            errorMessage: 'We could not upload your videos. Please try again.'.tr(),
          ));
          return;
        }
      }

      // Merge existing + new
      final allPhotos = <String>[
        ...event.existingPhotoUrls,
        ...newImageUrls,
      ].where((e) => e.trim().isNotEmpty).toList();

      final allVideos = <String>[
        ...event.existingVideoUrls,
        ...newVideoUrls,
      ].where((e) => e.trim().isNotEmpty).toList();

      if (allPhotos.isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Missing Images'.tr(),
          errorMessage: 'You need at least one photo for the listing.'.tr(),
        ));
        return;
      }

      // These fields must exist in your ListingModel. If your model uses different names,
      // update these assignments to match.
      event.listingModel.photos = allPhotos;
      event.listingModel.photo = allPhotos.first;

      // Optional: only set if your model supports videos
      try {
        event.listingModel.videos = allVideos;
      } catch (_) {
        // If ListingModel doesn't have videos yet, ignore quietly.
      }

      // ADD flow
      if (!event.isEdit) {
        emit(AddListingProgressState(progressMessage: 'Publishing Listing...'.tr()));
        final bool isDone = await listingsRepository.publishListing(event.listingModel);

        listingImages.clear();
        listingVideos.clear();

        if (isDone) {
          emit(ListingPublishedState());
        } else {
          emit(AddListingErrorState(
            errorTitle: 'Publish Failed'.tr(),
            errorMessage: 'We could not publish your listing. Please try again.'.tr(),
          ));
        }
        return;
      }

      // EDIT flow (update Firestore directly to avoid repo refactor)
      if (event.listingIdToUpdate == null || event.listingIdToUpdate!.trim().isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Update Failed'.tr(),
          errorMessage: 'Missing listing ID. Cannot update this listing.'.tr(),
        ));
        return;
      }

      emit(AddListingProgressState(progressMessage: 'Updating Listing...'.tr()));
      try {
        final updateData = <String, dynamic>{
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
          'instagram': event.listingModel.instagram,
          'facebook': event.listingModel.facebook,
          'tiktok': event.listingModel.tiktok,
          'whatsapp': event.listingModel.whatsapp,
          'youtube': event.listingModel.youtube,
          'x': event.listingModel.x,
          'photo': event.listingModel.photo,
          'photos': event.listingModel.photos,
          'countryCode': (event.listingModel.countryCode).toUpperCase(),
        };

        // Include videos only if present in your model/schema
        if (allVideos.isNotEmpty) {
          updateData['videos'] = allVideos;
        } else {
          // keep existing videos in Firestore unless user removed them
          // (if you want “remove all videos” behavior, pass explicit empty list)
        }

        await FirebaseFirestore.instance
            .collection('listings')
            .doc(event.listingIdToUpdate)
            .update(updateData);

        listingImages.clear();
        listingVideos.clear();

        // Set the ID for the updated listing
        event.listingModel.id = event.listingIdToUpdate!;
        emit(ListingUpdatedState(updatedListing: event.listingModel));
      } catch (_) {
        emit(AddListingErrorState(
          errorTitle: 'Update Failed'.tr(),
          errorMessage: 'We could not update your listing. Please try again.'.tr(),
        ));
      }
    });
  }
}
