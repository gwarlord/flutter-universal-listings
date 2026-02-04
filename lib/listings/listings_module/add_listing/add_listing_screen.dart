import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/listings/utils/caribbean_countries.dart';
import 'package:instaflutter/listings/utils/country_search_dialog.dart';
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
import 'package:instaflutter/listings/listings_module/add_listing/description_editor.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/services/gemini_ai_service.dart';
import 'package:instaflutter/listings/listings_module/filters/filters_screen.dart';
import 'package:instaflutter/widgets/menu/menu_edit_section_widget.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/utils/opening_hours_editor.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
import 'package:instaflutter/screens/store/catalog_manager_screen.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

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
    final TextEditingController _serviceDescriptionController = TextEditingController();
  // Supported currencies for Caribbean markets
  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'symbol': r'$'},
    {'code': 'XCD', 'symbol': r'$'},
    {'code': 'JMD', 'symbol': r'$'},
    {'code': 'TTD', 'symbol': r'$'},
    {'code': 'BSD', 'symbol': r'$'},
    {'code': 'BBD', 'symbol': r'$'},
    {'code': 'GYD', 'symbol': r'$'},
    {'code': 'HTG', 'symbol': 'G'},
    {'code': 'DOP', 'symbol': r'$'},
    {'code': 'KYD', 'symbol': r'$'},
    {'code': 'ANG', 'symbol': 'ƒ'},
    {'code': 'SRD', 'symbol': r'$'},
    {'code': 'XOF', 'symbol': 'CFA'},
  ];
  String _selectedCurrencyCode = 'USD';
  CategoriesModel? _categoryValue;

  final TextEditingController _titleController = TextEditingController();
  String _description = '';
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
  final TextEditingController _bookingUrlController = TextEditingController();

  // Service Menu Controllers
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDurationController = TextEditingController();

  Map<String, String>? _filters = {};
  PlaceDetails? _placeDetail;
  Prediction? _selectedPrediction;
  bool _isFetchingPlaceDetails = false;
  // *** DEBUG: Track place selection and persistence ***
  bool _placeManuallySelected = false;

  final List<String> _existingPhotoUrls = [];
  final List<String> _existingVideoUrls = [];
  List<File> _newImages = [];
  List<File> _newVideos = [];
  
  // Logo state
  String? _existingLogoUrl;
  File? _newLogo;
  
  // ✅ Service Menu State
  final List<ServiceItem> _services = [];

  List<CategoriesModel> _categories = [];
  late ListingsUser currentUser;
  bool isLoadingCategories = true;
  bool _isLoadingListing = false;

  bool get isEdit => widget.listingToEdit != null;
  String? _countryCode;
  bool _verified = false;
  bool _bookingEnabled = false;
  bool _allowQuantitySelection = false;
  bool _useTimeBlocks = false;
  bool _allowMultipleBookingsPerDay = false;
  bool _enableCustomQuestions = false;
  final List<String> _timeBlocks = [];
  final List<String> _customQuestions = [];
  final List<DateTime> _blockedDates = [];

  // Store/Ecommerce
  bool _storeEnabled = false;
  final TextEditingController _storeUrlController = TextEditingController();
  String _storeMode = 'external_url'; // "external_url" | "internal_catalog" | "both"
  int _storeLeadTimeHours = 24;

  @override
  void initState() {
    if (isEdit) {
      _selectedCurrencyCode = widget.listingToEdit?.currencyCode ?? 'USD';
      _isLoadingListing = true;
    }
    super.initState();
    currentUser = widget.currentUser;
    _refreshUserSubscription();
    context.read<AddListingBloc>().add(GetCategoriesEvent());

    if (isEdit) {
      _initializeEditListing();
    }
  }

  Future<void> _initializeEditListing() async {
    // Always reset manual selection so the address is loaded from the listing unless user picks a new one
    _placeManuallySelected = false;
    try {
      // Reload listing from Firestore to ensure we have latest changes (e.g., from booking services)
      final freshListing = await listingApiManager.getListing(listingID: widget.listingToEdit!.id);
      if (freshListing != null) {
        _populateListingData(freshListing);
      } else {
        // Fallback to passed listing if fresh data unavailable
        _populateListingData(widget.listingToEdit!);
      }
    } catch (e) {
      // Fallback to passed listing on error
      _populateListingData(widget.listingToEdit!);
    } finally {
      if (mounted) {
        setState(() => _isLoadingListing = false);
      }
    }
  }

  void _populateListingData(ListingModel l) {
    debugPrint('*** DEBUG: _populateListingData called. _placeManuallySelected=[0m$_placeManuallySelected');
    _titleController.text = l.title;
    _description = l.description;
    _priceController.text = l.price.toString();

    _filters = Map<String, String>.from(l.filters ?? {});
    _existingPhotoUrls.clear();
    _existingPhotoUrls.addAll(
      List<String>.from(l.photos ?? []).where((e) => e.trim().isNotEmpty),
    );
    _existingVideoUrls.clear();
    _existingVideoUrls.addAll(
      List<String>.from(l.videos ?? []).where((e) => e.trim().isNotEmpty),
    );
    _existingLogoUrl = (l.logo ?? '').trim().isEmpty ? null : l.logo;

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
    _bookingUrlController.text = (l.bookingUrl ?? '').trim();

    _countryCode = (l.countryCode ?? '').trim().isEmpty ? null : l.countryCode;
    _verified = l.verified;
    _bookingEnabled = l.bookingEnabled;
    _allowQuantitySelection = l.allowQuantitySelection;
    _useTimeBlocks = l.useTimeBlocks;
    _allowMultipleBookingsPerDay = l.allowMultipleBookingsPerDay;
    _enableCustomQuestions = l.enableCustomQuestions;

    // ✅ Load existing services
    _services.clear();
    _services.addAll(l.services);

    // ✅ Load existing time blocks
    _timeBlocks.clear();
    _timeBlocks.addAll(l.timeBlocks);

    // ✅ Load existing custom questions
    _customQuestions.clear();
    _customQuestions.addAll(l.customQuestions);

    // ✅ Load existing blocked dates
    _blockedDates.clear();
    _blockedDates.addAll(l.blockedDates.map((ms) => DateTime.fromMillisecondsSinceEpoch(ms)));

    if (!_placeManuallySelected) {
      _placeDetail = _fakePlaceDetailsFromExisting(
        l.title,
        l.place,
        l.latitude,
        l.longitude,
      );
    }
    // Store/Ecommerce fields
    _storeEnabled = l.storeEnabled;
    _storeUrlController.text = l.storeUrl ?? '';
    _storeMode = l.storeMode ?? 'external_url';
    _storeLeadTimeHours = l.storeLeadTimeHours;
  }

  Future<void> _refreshUserSubscription() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.userID)
          .get();
      
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null && data['subscriptionTier'] != null) {
          setState(() {
            currentUser.subscriptionTier = data['subscriptionTier'] as String;
          });
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error refreshing user subscription: $e');
    }
  }

  InputDecoration _getInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    bool isRequired = false,
    bool alwaysFloatLabel = false,
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
      floatingLabelBehavior:
          alwaysFloatLabel ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
    );
  }

  bool _canUseBooking() {
    if (currentUser.isAdmin) return true;
    const bookingTiers = {'professional', 'premium', 'business'};
    return bookingTiers.contains(currentUser.subscriptionTier.toLowerCase());
  }

  Widget _buildSectionHeader(String title, {bool isSocial = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: isSocial ? const Color(0xFFff5a66) : Color(colorPrimary),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBookingSection(bool dark, bool canUseBooking) {
    if (!canUseBooking) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bookings are available on Pro plans.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upgrade your subscription to enable booking for this listing.',
              style: TextStyle(
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: _bookingEnabled,
          onChanged: (value) => setState(() => _bookingEnabled = value),
          title: Text(
            'Require booking',
            style: TextStyle(
              color: dark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Text(
            'Show a "Book Now" button on your listing.',
            style: TextStyle(
              color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
          ),
          activeColor: Color(colorPrimary),
          activeTrackColor: Color(colorPrimary).withOpacity(0.5),
          inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
          inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        if (_bookingEnabled)
          SwitchListTile(
            value: _allowQuantitySelection,
            onChanged: (value) => setState(() => _allowQuantitySelection = value),
            title: Text(
              'Allow quantity selection',
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Customers can select quantity when booking services.',
              style: TextStyle(
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            activeColor: Color(colorPrimary),
            activeTrackColor: Color(colorPrimary).withOpacity(0.5),
            inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
            inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        if (_bookingEnabled)
          SwitchListTile(
            value: _useTimeBlocks,
            onChanged: (value) => setState(() => _useTimeBlocks = value),
            title: Text(
              'Use time blocks',
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Enable hourly time slot bookings instead of full day bookings.',
              style: TextStyle(
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            activeColor: Color(colorPrimary),
            activeTrackColor: Color(colorPrimary).withOpacity(0.5),
            inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
            inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        if (_bookingEnabled && _useTimeBlocks)
          SwitchListTile(
            value: _allowMultipleBookingsPerDay,
            onChanged: (value) => setState(() => _allowMultipleBookingsPerDay = value),
            title: Text(
              'Allow multiple bookings per day',
              style: TextStyle(
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Text(
              'Multiple customers can book different time slots on the same day.',
              style: TextStyle(
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            activeColor: Color(colorPrimary),
            activeTrackColor: Color(colorPrimary).withOpacity(0.5),
            inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
            inactiveTrackColor: dark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        if (_bookingEnabled && _useTimeBlocks)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Time Blocks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define hourly time slots (e.g., 09:00-10:00, 10:00-11:00)',
                  style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._timeBlocks.map((block) => Chip(
                      label: Text(block),
                      deleteIcon: Icon(Icons.close, size: 18),
                      onDeleted: () => setState(() => _timeBlocks.remove(block)),
                      backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      labelStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
                    )),
                    ActionChip(
                      label: Text('+ Add Time Block'),
                      onPressed: () => _showAddTimeBlockDialog(dark),
                      backgroundColor: Color(colorPrimary).withOpacity(0.1),
                      labelStyle: TextStyle(color: Color(colorPrimary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ✅ New Service Menu Widget
  Widget _buildServiceMenuEditor(bool dark) {
    // Check if user has subscription tier that unlocks booking services
    final canUseServices = widget.currentUser.hasBookingServices;
    
    if (!canUseServices) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Services are available on Professional plans.'.tr(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upgrade your subscription to enable services for this listing.'.tr(),
              style: TextStyle(
                color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_services.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _services.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
              itemBuilder: (context, index) {
                final s = _services[index];
                return ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: TextStyle(fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black)),
                      if (s.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            s.description,
                            style: TextStyle(fontSize: 13, color: dark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    s.duration.isNotEmpty && (s.price != 0.0 && s.price.toString().isNotEmpty)
                        ? '${s.duration} • ${s.price} $_selectedCurrencyCode'
                        : s.duration.isNotEmpty
                            ? s.duration
                            : (s.price != 0.0 && s.price.toString().isNotEmpty)
                                ? '${s.price} $_selectedCurrencyCode'
                                : '',
                    style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () async {
                          _serviceNameController.text = s.name;
                          _serviceDescriptionController.text = s.description;
                          _servicePriceController.text = s.price != 0.0 ? s.price.toString() : '';
                          _serviceDurationController.text = s.duration;
                          setState(() {
                            _services.removeAt(index);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => setState(() => _services.removeAt(index)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? Colors.black26 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(colorPrimary).withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              TextField(
                controller: _serviceNameController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: _getInputDecoration(label: 'Service Name', hint: 'e.g. Consultation'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _servicePriceController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: dark ? Colors.white : Colors.black),
                      decoration: _getInputDecoration(label: 'Price (optional)', hint: '0.00'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _serviceDurationController,
                      style: TextStyle(color: dark ? Colors.white : Colors.black),
                      decoration: _getInputDecoration(label: 'Duration', hint: 'e.g. 30 mins'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_serviceNameController.text.isEmpty) return;
                    setState(() {
                      _services.add(ServiceItem(
                        name: _serviceNameController.text.trim(),
                        price: double.tryParse(_servicePriceController.text.trim()) ?? 0.0,
                        duration: _serviceDurationController.text.trim(),
                      ));
                      _serviceNameController.clear();
                      _servicePriceController.clear();
                      _serviceDurationController.clear();
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Services'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(colorPrimary),
                    side: BorderSide(color: Color(colorPrimary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Blocked Dates Editor Widget
  Widget _buildBlockedDatesEditor(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_blockedDates.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _blockedDates.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final date = _blockedDates[index];
                return ListTile(
                  title: Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _blockedDates.removeAt(index)),
                  ),
                );
              },
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: Text('+ Add Blocked Dates'),
              onPressed: () async {
                final selectedDates = await showDialog<List<DateTime>>(
                  context: context,
                  builder: (context) => _MultiDatePickerDialog(
                    initialSelectedDates: _blockedDates,
                    dark: dark,
                  ),
                );
                if (selectedDates != null) {
                  setState(() {
                    for (var date in selectedDates) {
                      if (!_blockedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day)) {
                        _blockedDates.add(DateTime(date.year, date.month, date.day));
                      }
                    }
                    _blockedDates.sort();
                  });
                }
              },
              backgroundColor: Color(colorPrimary).withOpacity(0.1),
              labelStyle: TextStyle(color: Color(colorPrimary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoUpload() {
    final dark = isDarkMode(context);
    final bool hasLogo = _newLogo != null || _existingLogoUrl != null;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: hasLogo ? null : Border.all(color: Color(colorPrimary).withOpacity(0.5)),
        ),
        child: Stack(
          children: [
            if (hasLogo)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _newLogo != null
                    ? Image.file(_newLogo!, fit: BoxFit.cover, width: 100, height: 100)
                    : Image.network(_existingLogoUrl!, fit: BoxFit.cover, width: 100, height: 100),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: Color(colorPrimary), size: 28),
                    const SizedBox(height: 4),
                    Text('Logo'.tr(), style: TextStyle(fontSize: 12, color: Color(colorPrimary))),
                  ],
                ),
              ),

            // Tap target for add/replace
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showLogoUploadOptions(),
                  child: hasLogo
                      ? Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withOpacity(0.26),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 26),
                        )
                      : null,
                ),
              ),
            ),

            // Remove button (only show if logo exists)
            if (hasLogo)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _newLogo = null;
                    _existingLogoUrl = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoUploadOptions() async {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: Text('Add logo'.tr()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickLogo(fromGallery: true);
            },
            child: Text('Choose from gallery'.tr()),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickLogo(fromGallery: false);
            },
            child: Text('Take a picture'.tr()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.tr()),
        ),
      ),
    );
  }

  Future<void> _pickLogo({required bool fromGallery}) async {
    final image = await listingApiManager.getListingImage(fromGallery: fromGallery);
    if (image != null) {
      setState(() => _newLogo = image);
    }
  }

  Widget _buildPhotoGrid(bool dark) {
    final totalCount = _existingPhotoUrls.length + _newImages.length;
    const maxPhotos = 10;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing photos
        ..._existingPhotoUrls.asMap().entries.map((entry) => _buildPhotoTile(
          url: entry.value,
          dark: dark,
          onRemove: () => setState(() => _existingPhotoUrls.removeAt(entry.key)),
        )),
        
        // New photos
        ..._newImages.asMap().entries.map((entry) => _buildPhotoTile(
          file: entry.value,
          dark: dark,
          onRemove: () {
            context.read<AddListingBloc>().add(RemoveListingImageEvent(image: entry.value));
          },
        )),
        
        // Add button (only if under limit)
        if (totalCount < maxPhotos)
          _buildAddPhotoButton(dark),
      ],
    );
  }

  Widget _buildPhotoTile({
    String? url,
    File? file,
    required bool dark,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null
                ? Image.network(url, fit: BoxFit.cover)
                : (file != null ? Image.file(file, fit: BoxFit.cover) : const Icon(Icons.image)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton(bool dark) {
    return GestureDetector(
      onTap: _pickPhotosMulti,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          border: Border.all(
            color: Color(colorPrimary).withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.add_a_photo,
          size: 40,
          color: Color(colorPrimary),
        ),
      ),
    );
  }

  Future<void> _pickPhotosMulti() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      final files = pickedFiles.map((xFile) => File(xFile.path)).toList();
      context.read<AddListingBloc>().add(AddImagesToListingEvent(images: files));
    }
  }

  Widget _buildVideoGrid(bool dark) {
    final totalCount = _existingVideoUrls.length + _newVideos.length;
    const maxVideos = 3;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing videos
        ..._existingVideoUrls.asMap().entries.map((entry) => _buildVideoTile(
          url: entry.value,
          dark: dark,
          onRemove: () => setState(() => _existingVideoUrls.removeAt(entry.key)),
        )),
        
        // New videos
        ..._newVideos.asMap().entries.map((entry) => _buildVideoTile(
          file: entry.value,
          dark: dark,
          onRemove: () {
            context.read<AddListingBloc>().add(RemoveListingVideoEvent(video: entry.value));
          },
        )),
        
        // Add button (only if under limit)
        if (totalCount < maxVideos)
          _buildAddVideoButton(dark),
      ],
    );
  }

  Widget _buildVideoTile({
    String? url,
    File? file,
    required bool dark,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: file != null
                ? FutureBuilder<Uint8List?>(
                    future: _generateVideoThumbnail(file),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      }
                      return Center(
                        child: Icon(Icons.videocam, size: 40, color: Colors.grey.shade600),
                      );
                    },
                  )
                : Center(
                    child: Icon(Icons.videocam, size: 40, color: Colors.grey.shade600),
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _generateVideoThumbnail(File videoFile) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 100,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildAddVideoButton(bool dark) {
    return GestureDetector(
      onTap: _pickVideosMulti,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          border: Border.all(
            color: Color(colorPrimary).withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          Icons.videocam,
          size: 40,
          color: Color(colorPrimary),
        ),
      ),
    );
  }

  Future<void> _pickVideosMulti() async {
    final picker = ImagePicker();
    
    // Show selection modal for user to pick videos (max 3, minus existing count)
    final maxAvailable = 3 - _existingVideoUrls.length - _newVideos.length;
    
    if (maxAvailable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 3 videos allowed'.tr())),
      );
      return;
    }

    // Pick videos individually since pickMultiVideo isn't available
    // Instead, we'll allow picking one at a time through the modal
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: Text('Add video'.tr()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickSingleVideoAndAdd(fromGallery: true);
            },
            child: Text('Choose from gallery'.tr()),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickSingleVideoAndAdd(fromGallery: false);
            },
            child: Text('Record video'.tr()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.tr()),
        ),
      ),
    );
  }

  Future<void> _pickSingleVideoAndAdd({required bool fromGallery}) async {
    try {
      context.read<AddListingBloc>().add(AddVideoToListingEvent(fromGallery: fromGallery));
    } catch (_) {
      // Handle error
    }
  }

  Future<void> _showAIDescriptionDialog(BuildContext context, bool dark) async {
    final title = _titleController.text.trim();
    final category = _categoryValue?.title ?? '';
    final existingDesc = _description.trim();
    final location = _placeDetail?.formattedAddress ?? _selectedPrediction?.description ?? '';
    final services = _services.map((s) => s.name).toList();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a title first'.tr())),
      );
      return;
    }

    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a category first'.tr())),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AIDescriptionSheet(
        title: title,
        category: category,
        existingDescription: existingDesc,
        location: location,
        services: services,
        onAccept: (generatedText) {
          setState(() => _description = generatedText);
        },
        isDark: dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final tier = currentUser.subscriptionTier.toLowerCase();
    final bool canUseBooking = currentUser.isAdmin || const ['pro', 'premium', 'business'].contains(tier);

    return BlocListener<AddListingBloc, AddListingState>(
      listener: (listenerContext, state) async {
        if (state is AddListingErrorState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          showAlertDialog(listenerContext, state.errorTitle, state.errorMessage);
        } else if (state is PlaceDetailsState) {
          debugPrint('*** DEBUG: PlaceDetailsState received: '
              '${state.placeDetails?.formattedAddress ?? state.placeDetails?.toString()}');
          setState(() {
            _isFetchingPlaceDetails = false;
            if (state.placeDetails != null) {
              _placeDetail = state.placeDetails;
              _placeManuallySelected = true;
            }
          });
        } else if (state is ListingPublishedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          Navigator.pop(context, true);
        } else if (state is ListingUpdatedState) {
          context.read<LoadingCubit>().hideLoading();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Listing saved.'.tr()),
              duration: const Duration(seconds: 2),
              backgroundColor: state.updatedListing.verified ? Colors.green : Colors.orange,
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) Navigator.pop(context, state.updatedListing);
          });
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
                    child: GestureDetector(
                      onTap: () async {
                        final selected = await showCountrySearchDialog(context, _countryCode);
                        if (selected != null) setState(() => _countryCode = selected);
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: TextEditingController(
                            text: CaribbeanCountries.all.firstWhere(
                              (c) => c.code == _countryCode,
                              orElse: () => CaribbeanCountry(code: '', name: ''),
                            ).name,
                          ),
                          decoration: _getInputDecoration(
                            label: 'Country'.tr(),
                            icon: Icons.public,
                            isRequired: true,
                          ),
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _getInputDecoration(
                        label: 'Base Price'.tr(),
                        hint: 'Optional'.tr(),
                        icon: Icons.attach_money,
                        alwaysFloatLabel: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedCurrencyCode,
                      decoration: _getInputDecoration(
                        label: 'Currency'.tr(),
                        icon: Icons.money,
                      ),
                      items: _currencies
                          .map((currency) => DropdownMenuItem<String>(
                                value: currency['code'],
                                child: Text(currency['code'] ?? ''),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedCurrencyCode = value ?? 'USD'),
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
                    items: (_categories.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase())))
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
                  debugPrint('*** DEBUG: Place selected from autocomplete: '
                      '${prediction?.description ?? prediction?.toString()}');
                  if (prediction != null) {
                    setState(() {
                      _selectedPrediction = prediction;
                      _isFetchingPlaceDetails = true;
                      _placeManuallySelected = true;
                    });
                    if (!mounted) return;
                    context.read<AddListingBloc>().add(GetPlaceDetailsEvent(prediction: prediction));
                  }
                },
                child: InputDecorator(
                  decoration: _getInputDecoration(
                    label: 'Location'.tr(),
                    icon: Icons.location_on,
                    isRequired: false,
                  ),
                  child: Builder(
                    builder: (context) {
                      final displayText = _isFetchingPlaceDetails
                          ? 'Loading...'.tr()
                          : (_placeDetail?.formattedAddress?.trim().isNotEmpty ?? false)
                              ? _placeDetail!.formattedAddress!
                              : (_selectedPrediction?.description?.trim().isNotEmpty ?? false)
                                  ? _selectedPrediction!.description!
                                  : (isEdit
                                      ? (widget.listingToEdit?.place ?? 'Select Place'.tr())
                                      : 'Select Place'.tr());
                      debugPrint('*** DEBUG: Location field display: $displayText');
                      return Text(
                        displayText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DescriptionEditor(
                initialText: _description,
                onChanged: (text) {
                  setState(() => _description = text);
                },
                maxCharacters: 2000,
                draftKey: isEdit 
                    ? 'listing_description_draft_${widget.listingToEdit!.id}'
                    : 'listing_description_draft_new',
              ),
              const SizedBox(height: 8),
              // AI Enhancement Buttons
              if (GeminiAIService().isReady)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _description.trim().isEmpty ? 'Generate with AI' : 'Enhance with AI',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(colorPrimary),
                          side: BorderSide(color: Color(colorPrimary).withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _showAIDescriptionDialog(context, dark),
                      ),
                    ),
                  ],
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

              const SizedBox(height: 16),
              if (currentUser.isAdmin)
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode(context) ? Colors.grey[900] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode(context) ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Verified',
                      style: TextStyle(color: Color(colorPrimary), fontWeight: FontWeight.bold),
                    ),
                    value: _verified,
                    onChanged: (value) => setState(() => _verified = value ?? false),
                    activeColor: Color(colorPrimary),
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
              // Menu Section
              if (isEdit && widget.listingToEdit != null)
                MenuEditSectionWidget(
                  listing: widget.listingToEdit!,
                  onMenuUpdated: () {
                    if (mounted) setState(() {});
                  },
                ),
              const SizedBox(height: 24),
              _buildSectionHeader('Social Media'.tr(), isSocial: true),
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
              const SizedBox(height: 16),
              TextField(
                controller: _tiktokController,
                decoration: _getInputDecoration(label: 'TikTok URL', icon: Icons.music_note),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _youtubeController,
                decoration: _getInputDecoration(label: 'YouTube URL', icon: Icons.ondemand_video),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _xController,
                decoration: _getInputDecoration(label: 'X (Twitter) URL', icon: Icons.alternate_email),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Store / Ecommerce (Optional)'),
              SwitchListTile(
                value: _storeEnabled,
                onChanged: (value) => setState(() => _storeEnabled = value),
                title: Text('Enable Store/Ecommerce'),
                subtitle: Text(
                  'Allow users to visit your online store or shop.',
                  style: isDarkMode(context)
                      ? const TextStyle(color: Colors.white, fontSize: 14)
                      : const TextStyle(fontSize: 14),
                ),
                activeColor: Color(colorPrimary),
                activeTrackColor: Color(colorPrimary).withOpacity(0.5),
                inactiveThumbColor: isDarkMode(context) ? Colors.grey.shade600 : Colors.grey.shade400,
                inactiveTrackColor: isDarkMode(context) ? Colors.grey.shade800 : Colors.grey.shade300,
              ),
              if (_storeEnabled) ...[
                const SizedBox(height: 12),
                // Store Mode Dropdown (Premium-gated)
                DropdownButtonFormField<String>(
                  value: _storeMode,
                  decoration: _getInputDecoration(
                    label: 'Store Mode',
                    icon: Icons.storefront,
                  ),
                  dropdownColor: isDarkMode(context) ? Colors.grey.shade800 : Colors.white,
                  style: TextStyle(
                    color: isDarkMode(context) ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'external_url',
                      child: Text('External URL Only'),
                    ),
                    DropdownMenuItem(
                      value: 'internal_catalog',
                      enabled: isPremiumUser(currentUser),
                      child: Row(
                        children: [
                          Text('Internal Catalog'),
                          if (!isPremiumUser(currentUser)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'both',
                      enabled: isPremiumUser(currentUser),
                      child: Row(
                        children: [
                          Text('Both (URL + Catalog)'),
                          if (!isPremiumUser(currentUser)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFD700),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      // Block non-Premium users from selecting internal catalog options
                      if ((value == 'internal_catalog' || value == 'both') && !isPremiumUser(currentUser)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Internal Catalog requires Premium subscription'.tr()),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      setState(() => _storeMode = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // External URL field (show if mode is external_url or both)
                if (_storeMode == 'external_url' || _storeMode == 'both') ...[
                  TextField(
                    controller: _storeUrlController,
                    keyboardType: TextInputType.url,
                    decoration: _getInputDecoration(label: 'Store URL', icon: Icons.link),
                  ),
                  const SizedBox(height: 12),
                ],
                // Lead Time Hours
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: _getInputDecoration(
                    label: 'Lead Time (Hours)',
                    icon: Icons.access_time,
                    hint: 'Minimum hours needed to prepare orders',
                  ),
                  controller: TextEditingController(text: _storeLeadTimeHours.toString())
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: _storeLeadTimeHours.toString().length),
                    ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed != null && parsed >= 0) {
                      _storeLeadTimeHours = parsed;
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Manage Catalog button (Premium-only)
                if ((_storeMode == 'internal_catalog' || _storeMode == 'both') && isPremiumUser(currentUser)) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to CatalogManagerScreen (only after listing is saved)
                      if (!isEdit) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Please save the listing first, then you can manage catalog items'.tr()),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      // For edit mode, navigate to catalog manager
                      push(context, CatalogManagerScreen(
                        listing: widget.listingToEdit!,
                        currentUser: currentUser,
                      ));
                    },
                    icon: Icon(Icons.inventory_2),
                    label: Text(isEdit ? 'Manage Catalog Items' : 'Save Listing First'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEdit ? Color(colorPrimary) : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 20),

              // Services section (always available)
              _buildSectionHeader('Services'.tr()),
              const SizedBox(height: 16),
              _buildServiceMenuEditor(isDarkMode(context)),
              const SizedBox(height: 20),

              // Time Blocks Editor (only if booking with time blocks is enabled)
              if (_bookingEnabled && _useTimeBlocks) ...[
                _buildSectionHeader('Time Blocks'.tr()),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Define hourly time slots (e.g., 09:00-10:00, 10:00-11:00)',
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._timeBlocks.map((block) => Chip(
                            label: Text(block),
                            deleteIcon: Icon(Icons.close, size: 18),
                            onDeleted: () => setState(() => _timeBlocks.remove(block)),
                            backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                            labelStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
                          )),
                          ActionChip(
                            label: Text('+ Add Time Block'),
                            onPressed: () => _showAddTimeBlockDialog(dark),
                            backgroundColor: Color(colorPrimary).withOpacity(0.1),
                            labelStyle: TextStyle(color: Color(colorPrimary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Custom Booking Questions (only if booking enabled)
              if (_bookingEnabled) ...[
                _buildSectionHeader('Custom Booking Questions'.tr()),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add questions customers must answer when they book.'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_enableCustomQuestions) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._customQuestions.map((q) => Chip(
                              label: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                              deleteIcon: Icon(Icons.close, size: 18),
                              onDeleted: () => setState(() => _customQuestions.remove(q)),
                              backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                              labelStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
                            )),
                            ActionChip(
                              label: Text('+ Add Question'),
                              onPressed: () => _showAddQuestionDialog(dark),
                              backgroundColor: Color(colorPrimary).withOpacity(0.1),
                              labelStyle: TextStyle(color: Color(colorPrimary)),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Enable custom questions in Booking Services to add questions here.'.tr(),
                          style: TextStyle(
                            fontSize: 13,
                            color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Blocked dates (only if booking enabled)
              if (_bookingEnabled) ...[
                _buildSectionHeader('Block Unavailable Dates'.tr()),
                _buildBlockedDatesEditor(isDarkMode(context)),
              ],

              // Logo upload
              _buildSectionHeader('Logo (Optional)'.tr()),
              _buildLogoUpload(),
              const SizedBox(height: 12),

              _buildSectionHeader('Photos'.tr()),
              BlocBuilder<AddListingBloc, AddListingState>(
                buildWhen: (old, current) => old != current && current is ListingImagesUpdatedState,
                builder: (context, state) {
                  if (state is ListingImagesUpdatedState) _newImages = state.images;
                  return _buildPhotoGrid(isDarkMode(context));
                },
              ),

              _buildSectionHeader('Videos (max 3)'.tr()),
              BlocBuilder<AddListingBloc, AddListingState>(
                buildWhen: (old, current) => old != current && current is ListingVideosUpdatedState,
                builder: (context, state) {
                  if (state is ListingVideosUpdatedState) _newVideos = state.videos;
                  return _buildVideoGrid(isDarkMode(context));
                },
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
    _serviceDescriptionController.dispose();
    _titleController.dispose();
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
    _bookingUrlController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    _storeUrlController.dispose();
    super.dispose();
  }
  // Add missing _postListing stub if not present
  void _postListing() {
    // Validate required fields before posting
    if (_titleController.text.trim().isEmpty || _categoryValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all required fields'.tr())),
      );
      return;
    }

    // Show loading overlay
    context.read<LoadingCubit>().showLoading(
      context,
      isEdit ? 'Saving listing...'.tr() : 'Posting listing...'.tr(),
      false,
      Color(colorPrimary),
    );

    final place = _placeDetail?.formattedAddress ?? (isEdit ? widget.listingToEdit?.place ?? '' : '');
    final latitude = _placeDetail?.geometry?.location.lat ?? (isEdit ? widget.listingToEdit?.latitude ?? 0 : 0);
    final longitude = _placeDetail?.geometry?.location.lng ?? (isEdit ? widget.listingToEdit?.longitude ?? 0 : 0);
    debugPrint('*** DEBUG: _postListing called. place="$place" lat=$latitude lng=$longitude');

    final listingModel = ListingModel(
      title: _titleController.text.trim(),
      description: _description.trim(),
      categoryID: _categoryValue!.id,
      categoryTitle: _categoryValue!.title,
      categoryPhoto: _categoryValue!.photo,
      price: _priceController.text.trim(),
      currencyCode: _selectedCurrencyCode,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      website: _websiteController.text.trim(),
      openingHours: _openingHoursController.text.trim(),
      bookingEnabled: _bookingEnabled,
      bookingUrl: _bookingUrlController.text.trim(),
      allowQuantitySelection: _allowQuantitySelection,
      useTimeBlocks: _useTimeBlocks,
      allowMultipleBookingsPerDay: _allowMultipleBookingsPerDay,
      timeBlocks: _timeBlocks,
      enableCustomQuestions: _enableCustomQuestions,
      customQuestions: _customQuestions,
      services: _services,
      blockedDates: _blockedDates.map((d) => d.millisecondsSinceEpoch).toList(),
      storeEnabled: _storeEnabled,
      storeUrl: _storeUrlController.text.trim(),
      storeMode: _storeMode,
      storeLeadTimeHours: _storeLeadTimeHours,
      listerTierSnapshot: currentUser.subscriptionTier.toLowerCase(),
      instagram: _instagramController.text.trim(),
      facebook: _facebookController.text.trim(),
      tiktok: _tiktokController.text.trim(),
      whatsapp: _whatsappController.text.trim(),
      youtube: _youtubeController.text.trim(),
      x: _xController.text.trim(),
      filters: _filters ?? {},
      countryCode: _countryCode ?? '',
      verified: _verified,
      authorID: currentUser.userID,
      photo: '', // Will be set by backend
      id: '', // Will be set by backend
      createdAt: DateTime.now().millisecondsSinceEpoch,
      place: place,
      latitude: latitude,
      longitude: longitude,
    );

    context.read<AddListingBloc>().add(
      PublishListingEvent(
        listingModel: listingModel,
        isEdit: isEdit,
        listingIdToUpdate: isEdit ? widget.listingToEdit?.id : null,
        existingPhotoUrls: _existingPhotoUrls,
        existingVideoUrls: _existingVideoUrls,
        newLogoFile: _newLogo,
        existingLogoUrl: _existingLogoUrl,
      ),
    );
  }

  void _showAddTimeBlockDialog(bool dark) async {
    int startHour = 9;
    int endHour = 10;

    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
              title: Text(
                'Add Time Block',
                style: TextStyle(color: dark ? Colors.white : Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: startHour,
                          decoration: InputDecoration(
                            labelText: 'Start Hour',
                            labelStyle: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                          style: TextStyle(color: dark ? Colors.white : Colors.black),
                          items: List.generate(24, (i) => i).map((hour) {
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('${hour.toString().padLeft(2, '0')}:00'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                startHour = value;
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: endHour,
                          decoration: InputDecoration(
                            labelText: 'End Hour',
                            labelStyle: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade700),
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                          style: TextStyle(color: dark ? Colors.white : Colors.black),
                          items: List.generate(24, (i) => i).map((hour) {
                            return DropdownMenuItem(
                              value: hour,
                              child: Text('${hour.toString().padLeft(2, '0')}:00'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value > startHour) {
                              setDialogState(() => endHour = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time block:  ${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, {'start': startHour, 'end': endHour}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorPrimary),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      final start = result['start']!;
      final end = result['end']!;
      final timeBlock = '${start.toString().padLeft(2, '0')}:00-${end.toString().padLeft(2, '0')}:00';
      if (!_timeBlocks.contains(timeBlock)) {
        setState(() => _timeBlocks.add(timeBlock));
      }
    }
  }

  void _showAddQuestionDialog(bool dark) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dark ? Colors.grey[900] : Colors.white,
          title: Text('Add Booking Question'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            style: TextStyle(color: dark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Question'.tr(),
              labelStyle: TextStyle(color: dark ? Colors.grey[300] : Colors.grey[700]),
              hintText: 'e.g., Do you have any allergies?',
              hintStyle: TextStyle(color: dark ? Colors.grey[500] : Colors.grey[400]),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: dark ? Colors.grey[850] : Colors.grey[50],
              counterStyle: TextStyle(color: dark ? Colors.white : Colors.grey[700]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr(), style: TextStyle(color: dark ? Colors.grey[300] : Color(colorPrimary))),
            ),
            ElevatedButton(
              onPressed: () {
                final question = controller.text.trim();
                if (question.isNotEmpty) {
                  Navigator.pop(context, question);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(colorPrimary),
                foregroundColor: Colors.white,
              ),
              child: Text('Add'.tr()),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && !_customQuestions.contains(result)) {
      setState(() => _customQuestions.add(result));
    }
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

// <-- The class closing bracket should be here, after all methods
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

class ExistingListingVideoWidget extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onRemove;

  const ExistingListingVideoWidget({super.key, required this.videoUrl, required this.onRemove});

  @override
  State<ExistingListingVideoWidget> createState() => _ExistingListingVideoWidgetState();
}

class _ExistingListingVideoWidgetState extends State<ExistingListingVideoWidget> {
  Uint8List? _thumbnail;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    try {
      final data = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 320,
        quality: 40,
      );
      if (mounted) setState(() => _thumbnail = data);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _thumbnail != null
                ? Image.memory(_thumbnail!, fit: BoxFit.cover, width: 100, height: 100)
                : Container(
                    color: dark ? Colors.grey[900] : Colors.black87,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill, size: 44, color: Colors.white70),
                    ),
                  ),
          ),
          if (_failed)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Preview unavailable', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: widget.onRemove,
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
  final bool isAddButton;
  const ListingImageWidget({super.key, required this.imageFile, required this.isAddButton});

  @override
  State<ListingImageWidget> createState() => _ListingImageWidgetState();
}

class _ListingImageWidgetState extends State<ListingImageWidget> {
  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return GestureDetector(
      onTap: () => widget.isAddButton ? _pickImage(context) : _viewOrDeleteImage(widget.imageFile!, context),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: widget.isAddButton ? Border.all(color: Color(colorPrimary).withOpacity(0.5)) : null,
        ),
        child: widget.isAddButton
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
  final bool isAddButton;
  const ListingVideoWidget({super.key, required this.videoFile, required this.isAddButton});

  @override
  State<ListingVideoWidget> createState() => _ListingVideoWidgetState();
}

class _ListingVideoWidgetState extends State<ListingVideoWidget> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    if (widget.videoFile != null) {
      _generateThumbnail();
    }
  }

  @override
  void didUpdateWidget(ListingVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoFile != oldWidget.videoFile && widget.videoFile != null) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    final uint8list = await VideoThumbnail.thumbnailData(
      video: widget.videoFile!.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 128,
      quality: 25,
    );
    if (mounted) {
      setState(() {
        _thumbnailData = uint8list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    return GestureDetector(
      onTap: () => widget.isAddButton ? _pickVideo(context) : _viewOrDeleteVideo(widget.videoFile!, context),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey[900] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: widget.isAddButton ? Border.all(color: Color(colorPrimary).withOpacity(0.5)) : null,
        ),
        child: widget.isAddButton
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _thumbnailData != null
                        ? Image.memory(_thumbnailData!, fit: BoxFit.cover)
                        : Container(color: Colors.black87),
                  ),
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

// Multi-Date Picker Dialog
class _MultiDatePickerDialog extends StatefulWidget {
  final List<DateTime> initialSelectedDates;
  final bool dark;

  const _MultiDatePickerDialog({
    required this.initialSelectedDates,
    required this.dark,
  });

  @override
  State<_MultiDatePickerDialog> createState() => _MultiDatePickerDialogState();
}

class _MultiDatePickerDialogState extends State<_MultiDatePickerDialog> {
  final List<DateTime> _selectedDates = [];
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime.now();
  }

  bool _isDateSelected(DateTime date) {
    return _selectedDates.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  void _toggleDate(DateTime date) {
    setState(() {
      // Normalize date to remove time component
      final normalizedDate = DateTime(date.year, date.month, date.day);
      
      final existingIndex = _selectedDates.indexWhere((d) =>
          d.year == normalizedDate.year && d.month == normalizedDate.month && d.day == normalizedDate.day);
      
      if (existingIndex != -1) {
        _selectedDates.removeAt(existingIndex);
      } else {
        _selectedDates.add(normalizedDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.dark ? Colors.grey.shade900 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Dates to Block'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: widget.dark ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  },
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.dark ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: widget.dark ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCalendar(),
            const SizedBox(height: 16),
            Text(
              '${_selectedDates.length} ${_selectedDates.length == 1 ? 'date' : 'dates'} selected'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: widget.dark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.dark ? Colors.white : Colors.black,
                      side: BorderSide(color: widget.dark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    child: Text('Cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedDates.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedDates),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(colorPrimary),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Confirm'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingDayOfWeek = firstDay.weekday;
    final totalCells = startingDayOfWeek - 1 + daysInMonth;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        if (index < startingDayOfWeek - 1) {
          return const SizedBox.shrink();
        }

        final day = index - (startingDayOfWeek - 1) + 1;
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
        final today = DateTime.now();
        final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
        final isSelected = _isDateSelected(date);

        return InkWell(
          onTap: isPast ? null : () => _toggleDate(date),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Color(colorPrimary)
                  : (widget.dark ? Colors.grey.shade800 : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.dark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isPast
                      ? (widget.dark ? Colors.grey.shade600 : Colors.grey.shade400)
                      : isSelected
                          ? Colors.white
                          : (widget.dark ? Colors.white : Colors.black),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// AI Description Generation Bottom Sheet
class _AIDescriptionSheet extends StatefulWidget {
  final String title;
  final String category;
  final String? existingDescription;
  final String? location;
  final List<String> services;
  final Function(String) onAccept;
  final bool isDark;

  const _AIDescriptionSheet({
    required this.title,
    required this.category,
    this.existingDescription,
    this.location,
    this.services = const [],
    required this.onAccept,
    required this.isDark,
  });

  @override
  State<_AIDescriptionSheet> createState() => _AIDescriptionSheetState();
}

class _AIDescriptionSheetState extends State<_AIDescriptionSheet> {
  bool _isGenerating = false;
  String? _generatedText;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateDescription();
  }

  Future<void> _generateDescription() async {
    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final hasExisting = widget.existingDescription?.isNotEmpty ?? false;
      
      final result = hasExisting
          ? await GeminiAIService().enhanceDescription(
              description: widget.existingDescription!,
              category: widget.category,
            )
          : await GeminiAIService().generateListingDescription(
              title: widget.title,
              category: widget.category,
              location: widget.location,
              services: widget.services,
            );

      setState(() {
        _generatedText = result;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(colorPrimary),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Generated Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: widget.isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // Content
              Expanded(
                child: _isGenerating
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Color(colorPrimary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Generating description...',
                              style: TextStyle(
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to generate description',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try Again'),
                                    onPressed: _generateDescription,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(colorPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            controller: scrollController,
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + MediaQuery.of(context).viewPadding.bottom),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: widget.isDark ? Colors.grey[850] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: widget.isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    _generatedText ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: widget.isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Regenerate'),
                                        onPressed: _generateDescription,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Color(colorPrimary),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.check),
                                        label: const Text('Use This'),
                                        onPressed: () {
                                          widget.onAccept(_generatedText ?? '');
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(colorPrimary),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
