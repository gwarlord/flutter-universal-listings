import 'dart:io';

import 'package:instaflutter/listings/utils/caribbean_countries.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_bloc.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_event.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_state.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/filters/filters_screen.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/utils/opening_hours_editor.dart';

class AddListingWrappingWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const AddListingWrappingWidget({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddListingBloc(
        currentUser: currentUser,
        listingsRepository: listingApiManager,
      ),
      child: AddListingScreen(currentUser: currentUser),
    );
  }
}

class EditListingWrappingWidget extends StatelessWidget {
  final ListingsUser currentUser;
  final ListingModel listingToEdit;

  const EditListingWrappingWidget({
    super.key,
    required this.currentUser,
    required this.listingToEdit,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddListingBloc(
        currentUser: currentUser,
        listingsRepository: listingApiManager,
      ),
      child: AddListingScreen(
        currentUser: currentUser,
        listingToEdit: listingToEdit,
      ),
    );
  }
}

class AddListingScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final ListingModel? listingToEdit;

  const AddListingScreen({
    super.key,
    required this.currentUser,
    this.listingToEdit,
  });

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  CategoriesModel? _categoryValue;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _tiktokController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _xController = TextEditingController();

  final TextEditingController _openingHoursController = TextEditingController();

  Map<String, String>? _filters = {};
  PlaceDetails? _placeDetail;

  // Used to show the selected place immediately even before details come back.
  Prediction? _selectedPrediction;
  bool _isFetchingPlaceDetails = false;

  // Existing photo URLs (edit mode)
  final List<String> _existingPhotoUrls = [];

  // New local images picked this session (file list managed by bloc)
  List<File?> _newImages = [null];

  // ✅ NEW: videos picked this session (managed by bloc)
  List<File?> _newVideos = [null];

  List<CategoriesModel> _categories = [];
  late ListingsUser currentUser;
  bool isLoadingCategories = true;

  bool get isEdit => widget.listingToEdit != null;

  // ✅ Caribbean-only country selection (store country CODE)
  String? _countryCode;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    context.read<AddListingBloc>().add(GetCategoriesEvent());

    // Prefill for EDIT mode
    if (isEdit) {
      final l = widget.listingToEdit!;
      _titleController.text = l.title;
      _descController.text = l.description;
      _priceController.text = (l.price).replaceAll('\$', '').trim();

      _filters = Map<String, String>.from(l.filters ?? {});
      _existingPhotoUrls.addAll(
        List<String>.from(l.photos ?? []).where((e) => e.trim().isNotEmpty),
      );

      _phoneController.text = (l.phone ?? '').trim();
      _emailController.text = (l.email ?? '').trim();
      _websiteController.text = (l.website ?? '').trim();
      _instagramController.text = (l.instagram ?? '').trim();
      _facebookController.text = (l.facebook ?? '').trim();
      _tiktokController.text = (l.tiktok ?? '').trim();
      _whatsappController.text = (l.whatsapp ?? '').trim();
      _youtubeController.text = (l.youtube ?? '').trim();
      _xController.text = (l.x ?? '').trim();
      _openingHoursController.text = (l.openingHours ?? '').trim();

      _countryCode = (l.countryCode ?? '').trim().isEmpty ? null : l.countryCode;

      // IMPORTANT: satisfy validation without forcing user to re-pick location
      _placeDetail = _fakePlaceDetailsFromExisting(
        l.title,
        l.place,
        l.latitude,
        l.longitude,
      );

      // NOTE: Existing videos (URLs) are not handled here.
      // Step 2B should handle editing logic if you want to keep old videos.
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddListingBloc, AddListingState>(
      listener: (listenerContext, state) async {
        if (state is AddListingErrorState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          showAlertDialog(listenerContext, state.errorTitle, state.errorMessage);
        } else if (state is PlaceDetailsState) {
          setState(() {
            _isFetchingPlaceDetails = false;
            if (state.placeDetails != null) {
              _placeDetail = state.placeDetails;
            }
          });

          if (state.placeDetails == null && mounted) {
            showAlertDialog(
              context,
              'Location lookup failed'.tr(),
              'We could not fetch details for that place. Please try another result.'.tr(),
            );
          }
        } else if (state is ListingPublishedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          Navigator.pop(context, true);
          showAlertDialog(
            context,
            'Listing Added'.tr(),
            'Your listing has been added successfully'.tr(),
          );
        } else if (state is ListingUpdatedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          Navigator.pop(context, state.updatedListing);
          showAlertDialog(
            context,
            'Listing Updated'.tr(),
            'Your listing has been updated successfully'.tr(),
          );
        }
      },
      listenWhen: (old, current) =>
      old != current &&
          (current is AddListingErrorState ||
              current is ListingPublishedState ||
              current is ListingUpdatedState ||
              current is PlaceDetailsState),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(isEdit ? 'Edit Listing'.tr() : 'Add Listing'.tr()),
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Material(
                color: isDarkMode(context) ? Colors.black12 : Colors.white,
                type: MaterialType.canvas,
                elevation: 2,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Title'.tr(),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: TextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Start typing'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Material(
                  color: isDarkMode(context) ? Colors.black12 : Colors.white,
                  elevation: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Description'.tr(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: TextField(
                          keyboardType: TextInputType.multiline,
                          controller: _descController,
                          textInputAction: TextInputAction.next,
                          maxLines: 4,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Start typing'.tr(),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Details list
              Material(
                color: isDarkMode(context) ? Colors.black12 : Colors.white,
                elevation: 2,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    // Price
                    ListTile(
                      dense: true,
                      title: Text(
                        'Price'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: SizedBox(
                        width: MediaQuery.of(context).size.width / 3,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Optional'.tr(),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Country (Caribbean-only) - REQUIRED
                    ListTile(
                      dense: true,
                      title: Text(
                        'Country'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: SizedBox(
                        width: MediaQuery.of(context).size.width / 2,
                        child: DropdownButton<String>(
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          alignment: Alignment.centerRight,
                          value: _countryCode,
                          hint: Text('Select Country'.tr()),
                          items: CaribbeanCountries.all
                              .map(
                                (c) => DropdownMenuItem<String>(
                              value: c.code,
                              alignment: Alignment.centerRight,
                              child: Text(c.name),
                            ),
                          )
                              .toList(),
                          icon: const SizedBox(),
                          onChanged: (value) {
                            setState(() {
                              _countryCode = value;
                            });
                          },
                        ),
                      ),
                      subtitle: (_countryCode == null)
                          ? Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          'Required (Caribbean only)'.tr(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                          : null,
                    ),

                    // Category
                    ListTile(
                      dense: true,
                      title: Text(
                        'Category'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: SizedBox(
                        width: MediaQuery.of(context).size.width / 2,
                        child: BlocBuilder<AddListingBloc, AddListingState>(
                          buildWhen: (old, current) =>
                          old != current &&
                              (current is CategoriesFetchedState ||
                                  current is CategorySelectedState),
                          builder: (context, state) {
                            if (state is CategoriesFetchedState) {
                              isLoadingCategories = false;
                              _categories = state.categories;

                              if (isEdit && _categoryValue == null) {
                                final l = widget.listingToEdit!;
                                try {
                                  _categoryValue =
                                      _categories.firstWhere((c) => c.id == l.categoryID);
                                } catch (_) {}
                              }
                            } else if (state is CategorySelectedState) {
                              _categoryValue = state.category;
                            }

                            if (isLoadingCategories) {
                              return const Align(
                                alignment: Alignment.centerRight,
                                child: CircularProgressIndicator.adaptive(),
                              );
                            }
                            if (_categories.isEmpty) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: Text('No Categories Found'.tr()),
                              );
                            }

                            return DropdownButton<CategoriesModel>(
                              alignment: Alignment.centerRight,
                              isDense: true,
                              isExpanded: true,
                              selectedItemBuilder: (BuildContext context) =>
                                  _categories.map<Widget>((item) => Text(item.title)).toList(),
                              hint: Text('Choose Category'.tr()),
                              value: _categoryValue,
                              underline: const SizedBox(),
                              items: _categories
                                  .map(
                                    (category) => DropdownMenuItem<CategoriesModel>(
                                  value: category,
                                  alignment: Alignment.centerRight,
                                  child: Text(category.title),
                                ),
                              )
                                  .toList(),
                              icon: const SizedBox(),
                              onChanged: (CategoriesModel? model) => context
                                  .read<AddListingBloc>()
                                  .add(CategorySelectedEvent(categoriesModel: model)),
                            );
                          },
                        ),
                      ),
                    ),

                    // Filters
                    ListTile(
                      dense: true,
                      title: Text(
                        'Filters'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: BlocBuilder<AddListingBloc, AddListingState>(
                        buildWhen: (old, current) => old != current && current is SetFiltersState,
                        builder: (context, state) {
                          if (state is SetFiltersState) {
                            _filters = state.filters ?? {};
                          }
                          return Text(
                            _filters?.isEmpty ?? true ? 'Optional'.tr() : 'Edit Filters'.tr(),
                          );
                        },
                      ),
                      onTap: () async {
                        final filters = await showModalBottomSheet<Map<String, String>>(
                          isScrollControlled: true,
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) => FilterWrappingWidget(
                            filtersValue: _filters ?? {},
                          ),
                        );
                        if (filters != null) {
                          if (!mounted) return;
                          context.read<AddListingBloc>().add(SetFiltersEvent(filters: filters));
                        }
                      },
                    ),

                    // Location
                    ListTile(
                      dense: true,
                      title: Text(
                        'Location'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      trailing: SizedBox(
                        width: MediaQuery.of(context).size.width / 2,
                        child: Text(
                          _isFetchingPlaceDetails
                              ? 'Loading...'.tr()
                              : (_placeDetail?.formattedAddress?.trim().isNotEmpty ?? false)
                              ? _placeDetail!.formattedAddress!
                              : (_selectedPrediction?.description?.trim().isNotEmpty ?? false)
                              ? _selectedPrediction!.description!
                              : (isEdit
                              ? (widget.listingToEdit?.place ?? 'Select Place'.tr())
                              : 'Select Place'.tr()),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onTap: () async {
                        final prediction = await PlacesAutocomplete.show(
                          context: context,
                          apiKey: googleApiKey,
                          mode: Mode.fullscreen,
                          language: 'en',
                        );

                        if (prediction != null) {
                          setState(() {
                            _selectedPrediction = prediction;
                            _isFetchingPlaceDetails = true;
                          });

                          if (!mounted) return;
                          context.read<AddListingBloc>().add(
                            GetPlaceDetailsEvent(prediction: prediction),
                          );
                        }
                      },
                    ),

                    // Contact Info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        'Contact Info (Optional)'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _websiteController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'Website'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Social Media
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        'Social Media (Optional)'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _instagramController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'Instagram URL'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _facebookController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'Facebook URL'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _tiktokController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'TikTok URL'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'WhatsApp Phone Number'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _youtubeController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'YouTube URL'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _xController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'X (Twitter) URL'.tr(),
                          isDense: true,
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // Opening Hours
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        'Opening Hours (Optional)'.tr(),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final result = await OpeningHoursEditorSheet.show(
                            context,
                            initialValue: _openingHoursController.text.trim(),
                          );
                          if (result != null) {
                            setState(() {
                              _openingHoursController.text = result.trim();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode(context)
                                ? Colors.black.withOpacity(0.10)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _openingHoursController.text.trim().isEmpty
                                      ? 'Tap to set opening hours'.tr()
                                      : _openingHoursController.text
                                      .trim()
                                      .replaceAll('\n', ' • '),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode(context) ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit,
                                size: 18,
                                color: isDarkMode(context) ? Colors.white70 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Photos header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16.0),
                      child: Text(
                        'Add Photos'.tr(),
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),

                    // Existing photos (edit mode)
                    if (_existingPhotoUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: SizedBox(
                          height: 100,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _existingPhotoUrls.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              final url = _existingPhotoUrls[index];
                              return ExistingListingImageWidget(
                                imageUrl: url,
                                onRemove: () {
                                  setState(() {
                                    _existingPhotoUrls.removeAt(index);
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),

                    // New photos (picked now)
                    BlocBuilder<AddListingBloc, AddListingState>(
                      buildWhen: (old, current) =>
                      old != current && current is ListingImagesUpdatedState,
                      builder: (context, state) {
                        if (state is ListingImagesUpdatedState) {
                          _newImages = [...state.images, null];
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _newImages.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) => ListingImageWidget(
                                imageFile: _newImages[index],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // ✅ NEW: Videos header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16.0),
                      child: Text(
                        'Add Videos (max 3)'.tr(),
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),

                    // ✅ NEW: Videos picker list
                    BlocBuilder<AddListingBloc, AddListingState>(
                      buildWhen: (old, current) =>
                      old != current && current is ListingVideosUpdatedState,
                      builder: (context, state) {
                        if (state is ListingVideosUpdatedState) {
                          _newVideos = [...state.videos, null];
                        }

                        // hard cap UI list at 3 + add button
                        final visible = _newVideos.take(4).toList();
                        if (visible.length > 4) visible.length = 4;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: SizedBox(
                            height: 100,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: visible.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) => ListingVideoWidget(
                                videoFile: visible[index],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Post button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    backgroundColor: Color(colorPrimary),
                    shape: RoundedRectangleBorder(
                      side: BorderSide.none,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _isFetchingPlaceDetails ? null : _postListing,
                  child: Text(
                    isEdit ? 'Save Changes'.tr() : 'Post Listing'.tr(),
                    style: TextStyle(
                      color: isDarkMode(context) ? Colors.black : Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _whatsappController.dispose();
    _youtubeController.dispose();
    _xController.dispose();
    _openingHoursController.dispose();
    super.dispose();
  }

  void _postListing() {
    if (_isFetchingPlaceDetails) {
      showAlertDialog(context, 'Please wait'.tr(), 'Loading location...'.tr());
      return;
    }

    // ✅ UI only requires non-empty selection; Bloc enforces Caribbean-only codes
    if (_countryCode == null || _countryCode!.trim().isEmpty) {
      showAlertDialog(
        context,
        'Country required'.tr(),
        'Please select a Caribbean country before posting.'.tr(),
      );
      return;
    }

    context.read<LoadingCubit>().showLoading(
      context,
      'Loading...'.tr(),
      false,
      Color(colorPrimary),
    );

    final listingToEdit = widget.listingToEdit;

    context.read<AddListingBloc>().add(
      ValidateListingInputEvent(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        price: _priceController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        website: _websiteController.text.trim(),
        openingHours: _openingHoursController.text.trim(),
        instagram: _instagramController.text.trim(),
        facebook: _facebookController.text.trim(),
        tiktok: _tiktokController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        youtube: _youtubeController.text.trim(),
        x: _xController.text.trim(),
        category: _categoryValue ??
            (isEdit
                ? CategoriesModel(
              id: listingToEdit!.categoryID,
              title: listingToEdit.categoryTitle,
              photo: listingToEdit.categoryPhoto,
              isActive: true,
              sortOrder: 0,
            )
                : null),
        filters: _filters,
        placeDetails: _placeDetail ??
            (isEdit
                ? _fakePlaceDetailsFromExisting(
              listingToEdit!.title,
              listingToEdit.place,
              listingToEdit.latitude,
              listingToEdit.longitude,
            )
                : null),
        isEdit: isEdit,
        listingToEdit: listingToEdit,
        existingPhotoUrls: List<String>.from(_existingPhotoUrls),
        countryCode: _countryCode!.trim().toUpperCase(),
      ),
    );
  }

  PlaceDetails _fakePlaceDetailsFromExisting(
      String name,
      String address,
      double lat,
      double lng,
      ) {
    final safeAddress = address.trim().isEmpty ? 'Unknown location' : address.trim();

    return PlaceDetails(
      placeId: 'manual_${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}',
      name: name.trim().isEmpty ? safeAddress : name.trim(),
      formattedAddress: safeAddress,
      geometry: Geometry(
        location: Location(lat: lat, lng: lng),
      ),
    );
  }
}

// -------------------------------
// Widgets (MUST be outside State)
// -------------------------------

class ExistingListingImageWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onRemove;

  const ExistingListingImageWidget({
    super.key,
    required this.imageUrl,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onRemove();
              },
              isDestructiveAction: true,
              child: Text('Remove Picture'.tr()),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                push(
                  context,
                  FullScreenImageViewer(imageUrl: imageUrl, imageFile: null),
                );
              },
              isDefaultAction: true,
              child: Text('View Picture'.tr()),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      child: SizedBox(
        width: 100,
        child: Card(
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.black12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
      ),
    );
  }
}

class ListingImageWidget extends StatefulWidget {
  final File? imageFile;

  const ListingImageWidget({super.key, required this.imageFile});

  @override
  State<ListingImageWidget> createState() => _ListingImageWidgetState();
}

class _ListingImageWidgetState extends State<ListingImageWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.imageFile == null ? _pickImage(context) : _viewOrDeleteImage(widget.imageFile!, context);
      },
      child: SizedBox(
        width: 100,
        child: Card(
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          color: Color(colorPrimary),
          child: widget.imageFile == null
              ? Icon(
            Icons.camera_alt,
            size: 40,
            color: isDarkMode(context) ? Colors.black : Colors.white,
          )
              : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              widget.imageFile!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _viewOrDeleteImage(File imageFile, BuildContext blocContext) => showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            blocContext.read<AddListingBloc>().add(RemoveListingImageEvent(image: imageFile));
          },
          isDestructiveAction: true,
          child: Text('Remove Picture'.tr()),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            push(
              context,
              FullScreenImageViewer(
                imageUrl: 'preview',
                imageFile: imageFile,
              ),
            );
          },
          isDefaultAction: true,
          child: Text('View Picture'.tr()),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr()),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );

  void _pickImage(BuildContext blocContext) => showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      message: Text(
        'Add picture'.tr(),
        style: const TextStyle(fontSize: 15.0),
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: false,
          onPressed: () {
            Navigator.pop(context);
            blocContext.read<AddListingBloc>().add(AddImageToListingEvent(fromGallery: true));
          },
          child: Text('Choose from gallery'.tr()),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () {
            Navigator.pop(context);
            blocContext.read<AddListingBloc>().add(AddImageToListingEvent(fromGallery: false));
          },
          child: Text('Take a picture'.tr()),
        )
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr()),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );
}

/// ✅ NEW: Video picker tile (max 3) - simple UI
class ListingVideoWidget extends StatefulWidget {
  final File? videoFile;

  const ListingVideoWidget({super.key, required this.videoFile});

  @override
  State<ListingVideoWidget> createState() => _ListingVideoWidgetState();
}

class _ListingVideoWidgetState extends State<ListingVideoWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.videoFile == null ? _pickVideo(context) : _viewOrDeleteVideo(widget.videoFile!, context);
      },
      child: SizedBox(
        width: 100,
        child: Card(
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          color: Color(colorPrimary),
          child: widget.videoFile == null
              ? Icon(
            Icons.videocam,
            size: 40,
            color: isDarkMode(context) ? Colors.black : Colors.white,
          )
              : Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: Colors.black.withOpacity(0.25),
              ),
              const Center(
                child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewOrDeleteVideo(File videoFile, BuildContext blocContext) => showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            blocContext.read<AddListingBloc>().add(RemoveListingVideoEvent(video: videoFile));
          },
          isDestructiveAction: true,
          child: Text('Remove Video'.tr()),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr()),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );

  void _pickVideo(BuildContext blocContext) => showCupertinoModalPopup(
    context: context,
    builder: (context) => CupertinoActionSheet(
      message: Text(
        'Add video'.tr(),
        style: const TextStyle(fontSize: 15.0),
      ),
      actions: [
        CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
            // Step 2B should enforce: MP4 only, <=60s, compress to 720p.
            blocContext.read<AddListingBloc>().add(AddVideoToListingEvent(fromGallery: true));
          },
          child: Text('Choose from gallery'.tr()),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('Cancel'.tr()),
        onPressed: () => Navigator.pop(context),
      ),
    ),
  );
}
