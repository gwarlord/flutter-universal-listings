import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/api/firebase/events_firebase.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/entitlement_service.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/listings/utils/country_search_dialog.dart';
import 'package:http/http.dart' as http;

class CreateEventScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const CreateEventScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();

  final _eventsRepository = EventsFirebaseUtils();
  final _entitlementService = EntitlementService();
  final _picker = ImagePicker();

  DateTime? _startAt;
  DateTime? _endAt;
  String? _countryCode;
  PlaceDetails? _placeDetail;
  Prediction? _prediction;
  File? _posterImage;

  bool _loading = false;
  bool _checkingEntitlement = true;
  bool _isSubscribed = false;

  String get _selectedCountryLabel {
    final selected = CaribbeanCountries.byCode(_countryCode);
    return selected?.name ?? '';
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final dark = isDarkMode(context);
    final primary = Color(cfg.colorPrimary);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black87),
      hintStyle: TextStyle(color: dark ? Colors.white54 : Colors.black45),
      prefixIcon: Icon(icon, color: dark ? Colors.white70 : primary),
      filled: true,
      fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final initialCountryCode = widget.currentUser.countryCode.trim().toUpperCase();
    _countryCode = CaribbeanCountries.isAllowedCode(initialCountryCode)
        ? initialCountryCode
        : null;
    _loadEntitlement();
  }

  Future<void> _loadEntitlement() async {
    try {
      final entitlement = await _entitlementService.fetchEntitlement(widget.currentUser.userID);
      _isSubscribed =
          entitlement?.isActive == true || widget.currentUser.hasBookingServices;
    } catch (_) {
      _isSubscribed =
          _entitlementService.currentEntitlement?.isActive == true ||
              widget.currentUser.hasBookingServices;
    } finally {
      if (mounted) {
        setState(() => _checkingEntitlement = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;

    setState(() {
      _posterImage = File(file.path);
    });
  }

  Future<void> _debugProbePlacesAutocomplete() async {
    final key = placesApiKey;
    if (key.trim().isEmpty) return;

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        <String, String>{
          'input': 'ang',
          'key': key,
          'language': 'en',
        },
      );

      final headers = <String, String>{};
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        headers['X-Android-Package'] = 'com.caribtap.instaflutter.android';
        headers['X-Android-Cert'] =
            '2edc5d5e857233914f8335c5d4ee9e09fc8f61f9';
      }

      final res = await http.get(uri, headers: headers);
      final decoded = jsonDecode(res.body);
      final status = decoded is Map<String, dynamic>
          ? (decoded['status'] ?? '').toString()
          : '<unknown>';
      final errorMessage = decoded is Map<String, dynamic>
          ? (decoded['error_message'] ?? '').toString()
          : '';

      debugPrint(
        '[PlacesProbe:CreateEvent] source=$placesApiKeySource key=${maskApiKey(key)} '
        'http=${res.statusCode} status=$status error=$errorMessage',
      );
    } catch (e) {
      debugPrint('[PlacesProbe:CreateEvent] failed: $e');
    }
  }

  Future<void> _pickLocation() async {
    final key = placesApiKey;
    debugPrint('[Places] Create Event using $placesApiKeySource: ${maskApiKey(key)}');
    await _debugProbePlacesAutocomplete();
    if (key.trim().isEmpty) {
      showSnackBar(
        context,
        'Google Places API key is missing. Please check .env configuration.'.tr(),
      );
      return;
    }

    final prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: key,
      mode: Mode.fullscreen,
      language: 'en',
    );
    if (prediction == null) return;

    setState(() {
      _prediction = prediction;
    });

    final details = await listingApiManager.getPlaceDetails(prediction);
    if (!mounted) return;

    setState(() {
      _placeDetail = details;
      if (_venueController.text.trim().isEmpty &&
          (details?.name?.trim().isNotEmpty ?? false)) {
        _venueController.text = details!.name!;
      }
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_startAt ?? now)
        : (_endAt ?? _startAt ?? now.add(const Duration(hours: 2)));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null || !mounted) return;

    final dateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startAt = dateTime;
        if (_endAt != null && _endAt!.isBefore(_startAt!)) {
          _endAt = _startAt!.add(const Duration(hours: 2));
        }
      } else {
        _endAt = dateTime;
      }
    });
  }

  Future<void> _submit() async {
    if (_checkingEntitlement) return;

    if (!_isSubscribed) {
      showSnackBar(context, 'You need an active subscription to post events.'.tr());
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final venue = _venueController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        venue.isEmpty ||
        _startAt == null ||
        _endAt == null ||
        _countryCode == null ||
        _countryCode!.trim().isEmpty ||
        _placeDetail?.geometry?.location.lat == null ||
        _placeDetail?.geometry?.location.lng == null ||
        _posterImage == null) {
      showSnackBar(context, 'Please complete all event fields.'.tr());
      return;
    }

    if (_endAt!.isBefore(_startAt!)) {
      showSnackBar(context, 'End date/time must be after start date/time.'.tr());
      return;
    }

    setState(() => _loading = true);

    try {
      final uploaded = await listingApiManager.uploadListingImages(images: [_posterImage!]);
      final posterUrl = uploaded.isEmpty ? '' : uploaded.first;

      final event = EventModel(
        title: title,
        description: description,
        createdBy: widget.currentUser.userID,
        createdAtSeconds: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        startAtSeconds: _startAt!.millisecondsSinceEpoch ~/ 1000,
        endAtSeconds: _endAt!.millisecondsSinceEpoch ~/ 1000,
        latitude: _placeDetail!.geometry!.location.lat,
        longitude: _placeDetail!.geometry!.location.lng,
        venueName: venue,
        countryCode: _countryCode!,
        posterImageUrl: posterUrl,
        status: 'active',
      );

      await _eventsRepository.createEvent(event);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to create event. Please try again.'.tr());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Create Event'.tr()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                style: TextStyle(color: dark ? Colors.white : Colors.black87),
                decoration: _inputDecoration(
                  context: context,
                  label: 'Title'.tr(),
                  hint: 'Event title'.tr(),
                  icon: Icons.title,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: dark ? Colors.white : Colors.black87),
                decoration: _inputDecoration(
                  context: context,
                  label: 'Description'.tr(),
                  hint: 'Describe your event'.tr(),
                  icon: Icons.description,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _venueController,
                style: TextStyle(color: dark ? Colors.white : Colors.black87),
                decoration: _inputDecoration(
                  context: context,
                  label: 'Venue'.tr(),
                  hint: 'Venue name'.tr(),
                  icon: Icons.storefront,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final selected = await showCountrySearchDialog(
                    context,
                    _countryCode,
                    caribbeanOnly: true,
                  );
                  if (selected == null) return;
                  setState(() => _countryCode = selected);
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: TextEditingController(text: _selectedCountryLabel),
                    style: TextStyle(color: dark ? Colors.white : Colors.black87),
                    decoration: _inputDecoration(
                      context: context,
                      label: 'Country'.tr(),
                      hint: 'Country'.tr(),
                      icon: Icons.public,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: Icon(Icons.location_on, color: Color(cfg.colorPrimary)),
                title: Text(
                  (_placeDetail?.formattedAddress?.trim().isNotEmpty ?? false)
                      ? _placeDetail!.formattedAddress!
                      : (_prediction?.description?.trim().isNotEmpty ?? false)
                          ? _prediction!.description!
                          : 'Select Location'.tr(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark ? Colors.white : Colors.black87),
                ),
                onTap: _pickLocation,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(isStart: true),
                      icon: Icon(
                        Icons.event_available,
                        color: dark ? Colors.white70 : Color(cfg.colorPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        backgroundColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                      ),
                      label: Text(
                        _startAt == null
                            ? 'Start Date/Time'.tr()
                            : DateFormat('MMM d, y • h:mm a').format(_startAt!),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: dark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateTime(isStart: false),
                      icon: Icon(
                        Icons.event_busy,
                        color: dark ? Colors.white70 : Color(cfg.colorPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark ? Colors.white : Colors.black87,
                        side: BorderSide(
                          color: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        backgroundColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                      ),
                      label: Text(
                        _endAt == null
                            ? 'End Date/Time'.tr()
                            : DateFormat('MMM d, y • h:mm a').format(_endAt!),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: dark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                tileColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: Icon(Icons.image, color: Color(cfg.colorPrimary)),
                title: Text(
                  _posterImage == null ? 'Upload Poster Image'.tr() : 'Poster selected'.tr(),
                  style: TextStyle(color: dark ? Colors.white : Colors.black87),
                ),
                trailing: _posterImage == null
                    ? null
                    : const Icon(Icons.check_circle, color: Colors.green),
                onTap: _pickPoster,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(cfg.colorPrimary),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _checkingEntitlement
                              ? 'Checking subscription...'.tr()
                              : 'Submit Event'.tr(),
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
