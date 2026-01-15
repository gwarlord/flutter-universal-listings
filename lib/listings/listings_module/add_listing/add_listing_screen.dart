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

  Prediction? _selectedPrediction;
  bool _isFetchingPlaceDetails = false;

  final List<String> _existingPhotoUrls = [];
  List<File?> _newImages = [null];
  List<File?> _newVideos = [null];

  List<CategoriesModel> _categories = [];
  late ListingsUser currentUser;
  bool isLoadingCategories = true;

  bool get isEdit => widget.listingToEdit != null;
  String? _countryCode;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    context.read<AddListingBloc>().add(GetCategoriesEvent());

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

      _placeDetail = _fakePlaceDetailsFromExisting(
        l.title,
        l.place,
        l.latitude,
        l.longitude,
      );
    }
  }

  InputDecoration _getInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    bool isRequired = false,
  }) {
    final dark = isDarkMode(context);
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Color(colorPrimary)) : null,
      labelStyle: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[700]),
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: dark ? Colors.grey[900] : Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Color(colorPrimary), width: 2),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(colorPrimary),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

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
        } else if (state is ListingPublishedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          Navigator.pop(context, true);
        } else if (state is ListingUpdatedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          Navigator.pop(context, state.updatedListing);
        }
      },
      listenWhen: (old, current) =>
          old != current &&
          (current is AddListingErrorState ||
              current is ListingPublishedState ||
              current is ListingUpdatedState ||
              current is PlaceDetailsState),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEdit ? 'Edit Listing'.tr() : 'Add Listing'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Basic Information'.tr()),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: _getInputDecoration(
                  label: 'Title'.tr(),
                  hint: 'Start typing'.tr(),
                  icon: Icons.title,
                  isRequired: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _countryCode,
                      isExpanded: true,
                      decoration: _getInputDecoration(
                        label: 'Country'.tr(),
                        icon: Icons.public,
                        isRequired: true,
                      ),
                      dropdownColor: dark ? Colors.grey[900] : Colors.white,
                      items: CaribbeanCountries.all
                          .map((c) => DropdownMenuItem<String>(
                                value: c.code,
                                child: Text(c.name, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _countryCode = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _getInputDecoration(
                        label: 'Price'.tr(),
                        hint: 'Optional'.tr(),
                        icon: Icons.attach_money,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BlocBuilder<AddListingBloc, AddListingState>(
                buildWhen: (old, current) =>
                    old != current &&
                    (current is CategoriesFetchedState || current is CategorySelectedState),
                builder: (context, state) {
                  if (state is CategoriesFetchedState) {
                    isLoadingCategories = false;
                    _categories = state.categories;
                    if (isEdit && _categoryValue == null) {
                      final l = widget.listingToEdit!;
                      try {
                        _categoryValue = _categories.firstWhere((c) => c.id == l.categoryID);
                      } catch (_) {}
                    }
                  } else if (state is CategorySelectedState) {
                    _categoryValue = state.category;
                  }

                  return DropdownButtonFormField<CategoriesModel>(
                    isExpanded: true,
                    decoration: _getInputDecoration(
                      label: 'Category'.tr(),
                      icon: Icons.category,
                      isRequired: true,
                    ),
                    dropdownColor: dark ? Colors.grey[900] : Colors.white,
                    hint: Text('Choose Category'.tr()),
                    value: _categoryValue,
                    items: _categories
                        .map((category) => DropdownMenuItem<CategoriesModel>(
                              value: category,
                              child: Text(category.title, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: isLoadingCategories
                        ? null
                        : (CategoriesModel? model) => context
                            .read<AddListingBloc>()
                            .add(CategorySelectedEvent(categoriesModel: model)),
                  );
                },
              ),
              const SizedBox(height: 16),
              InkWell(
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
                    context.read<AddListingBloc>().add(GetPlaceDetailsEvent(prediction: prediction));
                  }
                },
                child: InputDecorator(
                  decoration: _getInputDecoration(
                    label: 'Location'.tr(),
                    icon: Icons.location_on,
                    isRequired: true,
                  ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              _buildSectionHeader('Description'.tr()),
              TextField(
                controller: _descController,
                maxLines: 5,
                decoration: _getInputDecoration(
                  label: 'About'.tr(),
                  hint: 'Describe your listing...'.tr(),
                ),
              ),

              _buildSectionHeader('Details & Hours'.tr()),
              InkWell(
                onTap: () async {
                  final result = await OpeningHoursEditorSheet.show(
                    context,
                    initialValue: _openingHoursController.text.trim(),
                  );
                  if (result != null) {
                    setState(() => _openingHoursController.text = result.trim());
                  }
                },
                child: InputDecorator(
                  decoration: _getInputDecoration(
                    label: 'Opening Hours'.tr(),
                    icon: Icons.access_time,
                  ),
                  child: Text(
                    _openingHoursController.text.trim().isEmpty
                        ? 'Tap to set opening hours'.tr()
                        : _openingHoursController.text.trim().replaceAll('\n', ' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final filters = await showModalBottomSheet<Map<String, String>>(
                    isScrollControlled: true,
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => FilterWrappingWidget(filtersValue: _filters ?? {}),
                  );
                  if (filters != null) {
                    if (!mounted) return;
                    context.read<AddListingBloc>().add(SetFiltersEvent(filters: filters));
                  }
                },
                child: InputDecorator(
                  decoration: _getInputDecoration(
                    label: 'Filters'.tr(),
                    icon: Icons.filter_list,
                  ),
                  child: BlocBuilder<AddListingBloc, AddListingState>(
                    buildWhen: (old, current) => old != current && current is SetFiltersState,
                    builder: (context, state) {
                      if (state is SetFiltersState) _filters = state.filters ?? {};
                      return Text(
                        _filters?.isEmpty ?? true ? 'Optional'.tr() : 'Edit Filters'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ),

              _buildSectionHeader('Contact & Social'.tr()),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _getInputDecoration(label: 'Phone'.tr(), icon: Icons.phone),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _getInputDecoration(label: 'Email'.tr(), icon: Icons.email),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _websiteController,
                keyboardType: TextInputType.url,
                decoration: _getInputDecoration(label: 'Website'.tr(), icon: Icons.language),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instagramController,
                decoration: _getInputDecoration(label: 'Instagram URL', icon: Icons.camera_alt),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _facebookController,
                decoration: _getInputDecoration(label: 'Facebook URL', icon: Icons.facebook),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _whatsappController,
                decoration: _getInputDecoration(label: 'WhatsApp Phone', icon: Icons.message),
              ),

              _buildSectionHeader('Photos'.tr()),
              SizedBox(
                height: 110,
                child: BlocBuilder<AddListingBloc, AddListingState>(
                  buildWhen: (old, current) => old != current && current is ListingImagesUpdatedState,
                  builder: (context, state) {
                    if (state is ListingImagesUpdatedState) _newImages = [...state.images, null];
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (isEdit)
                          ..._existingPhotoUrls.asMap().entries.map((e) => ExistingListingImageWidget(
                                imageUrl: e.value,
                                onRemove: () => setState(() => _existingPhotoUrls.removeAt(e.key)),
                              )),
                        ..._newImages.map((f) => ListingImageWidget(imageFile: f)),
                      ],
                    );
                  },
                ),
              ),

              _buildSectionHeader('Videos (max 3)'.tr()),
              SizedBox(
                height: 110,
                child: BlocBuilder<AddListingBloc, AddListingState>(
                  buildWhen: (old, current) => old != current && current is ListingVideosUpdatedState,
                  builder: (context, state) {
                    if (state is ListingVideosUpdatedState) _newVideos = [...state.videos, null];
                    final visible = _newVideos.take(4).toList();
                    return ListView(
                      scrollDirection: Axis.horizontal,
                      children: visible.map((v) => ListingVideoWidget(videoFile: v)).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Color(colorPrimary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: Color(colorPrimary).withOpacity(0.4),
                ),
                onPressed: _isFetchingPlaceDetails ? null : _postListing,
                child: Text(
                  isEdit ? 'Save Changes'.tr() : 'Post Listing'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),
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
    if (_countryCode == null || _countryCode!.trim().isEmpty) {
      showAlertDialog(context, 'Country required'.tr(), 'Please select a Caribbean country before posting.'.tr());
      return;
    }

    context.read<LoadingCubit>().showLoading(context, 'Loading...'.tr(), false, Color(colorPrimary));

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

  PlaceDetails _fakePlaceDetailsFromExisting(String name, String address, double lat, double lng) {
    final safeAddress = address.trim().isEmpty ? 'Unknown location' : address.trim();
    return PlaceDetails(
      placeId: 'manual_${lat.toStringAsFixed(6)}_${lng.toStringAsFixed(6)}',
      name: name.trim().isEmpty ? safeAddress : name.trim(),
      formattedAddress: safeAddress,
      geometry: Geometry(location: Location(lat: lat, lng: lng)),
    );
  }
}

class ExistingListingImageWidget extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onRemove;

  const ExistingListingImageWidget({super.key, required this.imageUrl, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
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
    final dark = isDarkMode(context);
    return GestureDetector(
      onTap: () => widget.imageFile == null ? _pickImage(context) : _viewOrDeleteImage(widget.imageFile!, context),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: widget.imageFile == null ? Border.all(color: Color(colorPrimary).withOpacity(0.5)) : null,
        ),
        child: widget.imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, color: Color(colorPrimary), size: 28),
                  const SizedBox(height: 4),
                  Text('Add'.tr(), style: TextStyle(fontSize: 12, color: Color(colorPrimary))),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(aspectRatio: 1, child: Image.file(widget.imageFile!, fit: BoxFit.cover)),
              ),
      ),
    );
  }

  void _viewOrDeleteImage(File imageFile, BuildContext blocContext) => showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                blocContext.read<AddListingBloc>().add(RemoveListingImageEvent(image: imageFile));
              },
              isDestructiveAction: true,
              child: Text('Remove Picture'.tr()),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                push(context, FullScreenImageViewer(imageUrl: 'preview', imageFile: imageFile));
              },
              child: Text('View Picture'.tr()),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
        ),
      );

  void _pickImage(BuildContext blocContext) => showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          message: Text('Add picture'.tr()),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                blocContext.read<AddListingBloc>().add(AddImageToListingEvent(fromGallery: true));
              },
              child: Text('Choose from gallery'.tr()),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                blocContext.read<AddListingBloc>().add(AddImageToListingEvent(fromGallery: false));
              },
              child: Text('Take a picture'.tr()),
            )
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
        ),
      );
}

class ListingVideoWidget extends StatefulWidget {
  final File? videoFile;
  const ListingVideoWidget({super.key, required this.videoFile});

  @override
  State<ListingVideoWidget> createState() => _ListingVideoWidgetState();
}

class _ListingVideoWidgetState extends State<ListingVideoWidget> {
  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return GestureDetector(
      onTap: () => widget.videoFile == null ? _pickVideo(context) : _viewOrDeleteVideo(widget.videoFile!, context),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: widget.videoFile == null ? Border.all(color: Color(colorPrimary).withOpacity(0.5)) : null,
        ),
        child: widget.videoFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_call, color: Color(colorPrimary), size: 28),
                  const SizedBox(height: 4),
                  Text('Add'.tr(), style: TextStyle(fontSize: 12, color: Color(colorPrimary))),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(color: Colors.black87)),
                  const Center(child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white)),
                ],
              ),
      ),
    );
  }

  void _viewOrDeleteVideo(File videoFile, BuildContext blocContext) => showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                blocContext.read<AddListingBloc>().add(RemoveListingVideoEvent(video: videoFile));
              },
              isDestructiveAction: true,
              child: Text('Remove Video'.tr()),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
        ),
      );

  void _pickVideo(BuildContext blocContext) => showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          message: Text('Add video'.tr()),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                blocContext.read<AddListingBloc>().add(AddVideoToListingEvent(fromGallery: true));
              },
              child: Text('Choose from gallery'.tr()),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
        ),
      );
}
