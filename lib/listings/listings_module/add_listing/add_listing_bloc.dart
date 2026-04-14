import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:caribtap/listings/listings_module/add_listing/add_listing_event.dart';
import 'package:caribtap/listings/listings_module/add_listing/add_listing_state.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';

/// Caribbean + Caribbean territories (ISO 3166-1 alpha-2)
const Set<String> kCaribbeanCountryCodes = {
  'AI', 'AG', 'AW', 'BS', 'BB', 'BZ', 'BM', 'BQ', 'VG', 'KY', 'CU', 'CW', 'DM',
  'DO', 'GD', 'GP', 'GY', 'HT', 'JM', 'MQ', 'MS', 'PR', 'BL', 'KN', 'LC', 'MF',
  'VC', 'SX', 'SR', 'TT', 'TC', 'VI',
};

const Set<String> kBookingEligibleTiers = {
  'pro',
  'professional',
  'premium',
};
const Set<String> kStoreEligibleTiers = {'premium'};

bool _hasBookingAccess({
  required String tier,
  required bool isAdmin,
  required bool hasBookingServices,
}) {
  return isAdmin || hasBookingServices || kBookingEligibleTiers.contains(tier);
}

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

    on<AddImagesToListingEvent>((event, emit) {
      listingImages.addAll(event.images);
      emit(ListingImagesUpdatedState(images: List<File>.from(listingImages)));
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

    on<ValidateListingInputEvent>((event, emit) async {
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

      // Place is now optional. Do not require placeDetails.

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

      // Subscription gating check
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.userID)
            .get();
        final String tier =
            (userDoc.data()?['subscriptionTier'] as String? ?? 'free')
                .toLowerCase();
        final bool isAdmin = userDoc.data()?['isAdmin'] as bool? ?? false;
        final bool hasBookingServices =
            userDoc.data()?['hasBookingServices'] as bool? ??
                currentUser.hasBookingServices;

        // Gating for bookings
        if (event.bookingEnabled &&
            !_hasBookingAccess(
              tier: tier,
              isAdmin: isAdmin,
              hasBookingServices: hasBookingServices,
            )) {
          emit(AddListingErrorState(
            errorTitle: 'Upgrade required'.tr(),
            errorMessage:
                'Bookings are available on paid plans. Upgrade to enable bookings.'
                    .tr(),
          ));
          return;
        }

        // Gating for store
        if (event.storeEnabled && !isAdmin) {
          if (!kStoreEligibleTiers.contains(tier)) {
            emit(AddListingErrorState(
              errorTitle: 'Premium required'.tr(),
              errorMessage: 'Store integration is available on Premium plans. Upgrade to enable.'.tr(),
            ));
            return;
          }
        }
      } catch (e) {
        // Fallback to cached data if Firestore fetch fails
        final String tier = currentUser.subscriptionTier.toLowerCase();
        if (event.bookingEnabled &&
            !_hasBookingAccess(
              tier: tier,
              isAdmin: currentUser.isAdmin,
              hasBookingServices: currentUser.hasBookingServices,
            )) {
          emit(AddListingErrorState(
            errorTitle: 'Upgrade required'.tr(),
            errorMessage:
                'Bookings are available on paid plans. Upgrade to enable bookings.'
                    .tr(),
          ));
          return;
        }
        if (event.storeEnabled && !currentUser.isAdmin && !kStoreEligibleTiers.contains(tier)) {
          emit(AddListingErrorState(
            errorTitle: 'Premium required'.tr(),
            errorMessage: 'Store integration is available on Premium plans. Upgrade to enable.'.tr(),
          ));
          return;
        }
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
        latitude: event.placeDetails?.geometry?.location.lat ?? 0.0,
        longitude: event.placeDetails?.geometry?.location.lng ?? 0.0,
        place: event.placeDetails?.formattedAddress ?? '',
        phone: event.phone.trim(),
        email: event.email.trim(),
        website: event.website.trim(),
        openingHours: event.openingHours.trim(),
        bookingEnabled: event.bookingEnabled,
        bookingUrl: event.bookingUrl.trim(),
        allowQuantitySelection: event.allowQuantitySelection,
        useTimeBlocks: event.useTimeBlocks,
        allowMultipleBookingsPerDay: event.allowMultipleBookingsPerDay,
        timeBlocks: event.timeBlocks,
        enableCustomQuestions: event.enableCustomQuestions,
        customQuestions: event.customQuestions,
        services: event.services,
        blockedDates: event.blockedDates,
        storeEnabled: event.storeEnabled,
        storeUrl: event.storeUrl.trim(),
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
        primaryCategorySlug: event.category!.parentSlug?.trim().isNotEmpty == true
          ? event.category!.parentSlug!.trim()
          : event.category!.slug.trim(),
        subcategorySlug: event.category!.parentSlug?.trim().isNotEmpty == true
          ? event.category!.slug.trim()
          : '',

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
        isApproved: true, // Auto-approve all listings
        verified: event.verified,

        // Country
        countryCode: countryCode,
      );

      add(PublishListingEvent(
        listingModel: model,
        isEdit: event.isEdit,
        listingIdToUpdate: event.listingToEdit?.id,
        existingPhotoUrls: event.existingPhotoUrls,
        existingVideoUrls: event.existingVideoUrls,
        newLogoFile: event.newLogoFile,
        existingLogoUrl: event.existingLogoUrl,
      ));
    });

    /* -------------------- Publish (Add or Edit) -------------------- */

    on<PublishListingEvent>((event, emit) async {
      print('🔧 DEBUG [PublishListingEvent handler]: isEdit=${event.isEdit}, companyRegistration="${event.listingModel.companyRegistration}", vatNumber="${event.listingModel.vatNumber}"');
      
      // Upload NEW logo
      String? logoUrl;
      if (event.newLogoFile != null) {
        emit(AddListingProgressState(progressMessage: 'Uploading Logo...'.tr()));
        final logoUrls = await listingsRepository.uploadListingImages(
          images: [event.newLogoFile!],
        );
        if (logoUrls.isNotEmpty) {
          logoUrl = logoUrls.first;
        }
      } else if (event.existingLogoUrl != null && event.existingLogoUrl!.trim().isNotEmpty) {
        logoUrl = event.existingLogoUrl;
      }

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
      event.listingModel.logo = logoUrl ?? '';

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

      // Guard: demo listings cannot be modified by non-admin users.
      if (event.listingModel.isDemo && !currentUser.isAdmin) {
        emit(AddListingErrorState(
          errorTitle: 'Read-Only'.tr(),
          errorMessage: 'Demo listings cannot be edited.'.tr(),
        ));
        return;
      }

      if (event.listingIdToUpdate == null || event.listingIdToUpdate!.trim().isEmpty) {
        emit(AddListingErrorState(
          errorTitle: 'Update Failed'.tr(),
          errorMessage: 'Missing listing ID. Cannot update this listing.'.tr(),
        ));
        return;
      }

      emit(AddListingProgressState(progressMessage: 'Updating Listing...'.tr()));
      try {
        // Resolve booking access from the latest user document so edits do not
        // clear booking data when cached user state is stale.
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.userID)
            .get();
        final userData = userDoc.data();
        final userTierLower =
            (userData?['subscriptionTier'] as String? ?? currentUser.subscriptionTier)
                .toLowerCase();
        final isAdmin = userData?['isAdmin'] as bool? ?? currentUser.isAdmin;
        final hasBookingServices =
            userData?['hasBookingServices'] as bool? ?? currentUser.hasBookingServices;
        final canUseBookings = _hasBookingAccess(
          tier: userTierLower,
          isAdmin: isAdmin,
          hasBookingServices: hasBookingServices,
        );
        
        final updateData = <String, dynamic>{
          'title': event.listingModel.title,
          'description': event.listingModel.description,
          'price': event.listingModel.price,
          'categoryID': event.listingModel.categoryID,
          'categoryPhoto': event.listingModel.categoryPhoto,
          'categoryTitle': event.listingModel.categoryTitle,
          'primaryCategorySlug': event.listingModel.primaryCategorySlug,
          'subcategorySlug': event.listingModel.subcategorySlug,
          'categoryTags': event.listingModel.categoryTags,
          'filters': event.listingModel.filters,
          'searchKeywords': event.listingModel.searchKeywords,
          'place': event.listingModel.place,
          'latitude': event.listingModel.latitude,
          'longitude': event.listingModel.longitude,
          'phone': event.listingModel.phone,
          'email': event.listingModel.email,
          'website': event.listingModel.website,
          'companyRegistration': event.listingModel.companyRegistration,
          'vatNumber': event.listingModel.vatNumber,
          'openingHours': event.listingModel.openingHours,
          // Booking fields (Professional+ only)
          'bookingEnabled': canUseBookings ? event.listingModel.bookingEnabled : false,
          'bookingUrl': canUseBookings ? event.listingModel.bookingUrl : '',
          'allowQuantitySelection': canUseBookings ? event.listingModel.allowQuantitySelection : false,
          'useTimeBlocks': canUseBookings ? event.listingModel.useTimeBlocks : false,
          'allowMultipleBookingsPerDay': canUseBookings ? event.listingModel.allowMultipleBookingsPerDay : false,
          'timeBlocks': canUseBookings ? event.listingModel.timeBlocks : [],
          'services': event.listingModel.services.map((e) => e.toJson()).toList(),
          'blockedDates': canUseBookings ? event.listingModel.blockedDates : [],
          'enableCustomQuestions': canUseBookings ? event.listingModel.enableCustomQuestions : false,
          'customQuestions': canUseBookings ? event.listingModel.customQuestions : [],
          // Store fields (Premium only - for now handled by app-side validation)
          'storeEnabled': event.listingModel.storeEnabled,
          'storeUrl': event.listingModel.storeUrl,
          'storeMode': event.listingModel.storeMode,
          'storeCurrencyCode': event.listingModel.storeCurrencyCode,
          'storeDeliveryEnabled': event.listingModel.storeDeliveryEnabled,
          'storePickupEnabled': event.listingModel.storePickupEnabled,
          'storeLeadTimeHours': event.listingModel.storeLeadTimeHours,
          'storeUpdatedAt': event.listingModel.storeUpdatedAt,
          'listerTierSnapshot': event.listingModel.listerTierSnapshot,
          'payments': event.listingModel.payments,
          'instagram': event.listingModel.instagram,
          'facebook': event.listingModel.facebook,
          'tiktok': event.listingModel.tiktok,
          'whatsapp': event.listingModel.whatsapp,
          'youtube': event.listingModel.youtube,
          'x': event.listingModel.x,
          'photo': event.listingModel.photo,
          'photos': event.listingModel.photos,
          'videos': allVideos,
          'logo': event.listingModel.logo,
          'exteriorImageUrl': event.listingModel.exteriorImageUrl,
          'interiorImageUrl': event.listingModel.interiorImageUrl,
          'locationInstructions': event.listingModel.locationInstructions,
          'currencyCode': event.listingModel.currencyCode,
          'countryCode': (event.listingModel.countryCode).toUpperCase(),
          'verified': event.listingModel.verified,
          'hidden': event.listingModel.hidden,
          // Rentals (Professional+)
          'rentalConfig': event.listingModel.rentalConfig?.toJson(),
        };

        // Include videos only if present in your model/schema
        if (allVideos.isNotEmpty) {
          updateData['videos'] = allVideos;
        } else {
          // keep existing videos in Firestore unless user removed them
          // (if you want “remove all videos” behavior, pass explicit empty list)
        }

        print('DEBUG [PublishListingEvent]: uid=${FirebaseAuth.instance.currentUser?.uid}');
        print('DEBUG [PublishListingEvent]: projectId=${FirebaseFirestore.instance.app.options.projectId}');
        print('DEBUG [PublishListingEvent]: tier=$userTierLower isAdmin=$isAdmin hasBookingServices=$hasBookingServices canUseBookings=$canUseBookings');
        print('DEBUG [PublishListingEvent]: updateData keys=${updateData.keys.toList()}');
        print('DEBUG [PublishListingEvent]: bookingEnabled=${updateData['bookingEnabled']} useTimeBlocks=${updateData['useTimeBlocks']} servicesCount=${(updateData['services'] as List).length}');

        print('DEBUG [PublishListingEvent]: reading listing doc...');
        final existingDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(event.listingIdToUpdate)
          .get();
        final existingData = existingDoc.data();
        print('DEBUG [PublishListingEvent]: listing doc read complete');
        print('DEBUG [PublishListingEvent]: listingExists=${existingDoc.exists}');
        final existingAuthorId = existingData?['authorID'];
        final existingCustomerId = existingData?['customerId'];
        print('DEBUG [PublishListingEvent]: authorID=$existingAuthorId customerId=$existingCustomerId');

        await FirebaseFirestore.instance
            .collection('listings')
            .doc(event.listingIdToUpdate)
            .update(updateData);

        print('DEBUG: Saved listing with verified=${event.listingModel.verified}');
        listingVideos.clear();

        // Set the ID for the updated listing
        event.listingModel.id = event.listingIdToUpdate!;

        // Log activity (fire-and-forget)
        collaborationApiManager.logActivity(
          listingId: event.listingIdToUpdate!,
          actorUid: currentUser.userID,
          actorName: currentUser.fullName(),
          actorRole: 'OWNER',
          actionType: 'LISTING_EDITED',
          targetType: 'LISTING',
          targetId: event.listingIdToUpdate!,
          targetName: event.listingModel.title,
        );

        emit(ListingUpdatedState(updatedListing: event.listingModel));
      } on FirebaseException catch (e, stackTrace) {
        print('ERROR [PublishListingEvent]: code=${e.code} message=${e.message}');
        print('ERROR [PublishListingEvent]: $stackTrace');
        emit(AddListingErrorState(
          errorTitle: 'Update Failed'.tr(),
          errorMessage: 'We could not update your listing. Please try again.'.tr(),
        ));
      } catch (e, stackTrace) {
        print('ERROR [PublishListingEvent]: $e');
        print('ERROR [PublishListingEvent]: $stackTrace');
        emit(AddListingErrorState(
          errorTitle: 'Update Failed'.tr(),
          errorMessage: 'We could not update your listing. Please try again.'.tr(),
        ));
      }
    });
  }
}
