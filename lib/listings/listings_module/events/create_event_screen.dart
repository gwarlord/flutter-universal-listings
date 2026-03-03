import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart' as google_places;
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
  final EventModel? eventToEdit;

  const CreateEventScreen({
    super.key,
    required this.currentUser,
    this.eventToEdit,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _committeeController = TextEditingController();
  final _ticketInstructionsController = TextEditingController();
  final _ticketUrlController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();

  final _eventsRepository = EventsFirebaseUtils();
  final _entitlementService = EntitlementService();
  final _picker = ImagePicker();

  DateTime? _startAt;
  DateTime? _endAt;
  String? _countryCode;
  google_places.PlaceDetails? _placeDetail;
  google_places.Prediction? _prediction;
  File? _posterImage;
  String? _existingPosterUrl;

  List<TicketType> _ticketTypes = [];
  List<CommitteeMember> _committeeMembers = [];

  bool _loading = false;
  bool _checkingEntitlement = true;
  bool _isSubscribed = false;
  bool _showValidationErrors = false;

  bool get _titleMissing => _titleController.text.trim().isEmpty;
  bool get _descriptionMissing => _descriptionController.text.trim().isEmpty;
  bool get _venueMissing => _venueController.text.trim().isEmpty;
  bool get _countryMissing => _countryCode == null || _countryCode!.trim().isEmpty;
  bool get _startMissing => _startAt == null;
  bool get _endMissing => _endAt == null;
  bool get _posterMissing => _posterImage == null && _existingPosterUrl == null;
  bool get _locationMissing =>
      (_placeDetail?.geometry?.location.lat == null ||
      _placeDetail?.geometry?.location.lng == null) && widget.eventToEdit == null;
  bool get _endBeforeStart =>
      _startAt != null && _endAt != null && _endAt!.isBefore(_startAt!);

  bool get _hasRequiredFieldErrors {
    return _titleMissing ||
      _descriptionMissing ||
      _venueMissing ||
      _countryMissing ||
      _startMissing ||
      _endMissing ||
      (_locationMissing && widget.eventToEdit == null) ||
      _posterMissing ||
      _endBeforeStart;
  }

  String get _selectedCountryLabel {
    final selected = CaribbeanCountries.byCode(_countryCode);
    return selected?.name ?? '';
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
    String? hint,
    String? errorText,
  }) {
    final dark = isDarkMode(context);
    final primary = Color(cfg.colorPrimary);

    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black87, fontSize: 14),
      prefixIcon: Icon(icon, color: dark ? Colors.white70 : primary, size: 20),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      final e = widget.eventToEdit!;
      _titleController.text = e.title;
      _descriptionController.text = e.description;
      _venueController.text = e.venueName;
      _committeeController.text = e.committee;
      _ticketInstructionsController.text = e.ticketInstructions;
      _ticketUrlController.text = e.ticketUrl;
      _facebookController.text = e.facebookUrl;
      _instagramController.text = e.instagramUrl;
      _startAt = DateTime.fromMillisecondsSinceEpoch(e.startAtSeconds * 1000);
      _endAt = DateTime.fromMillisecondsSinceEpoch(e.endAtSeconds * 1000);
      _countryCode = e.countryCode;
      _existingPosterUrl = e.posterImageUrl;
      _ticketTypes = List.from(e.ticketTypes);
      _committeeMembers = List.from(e.committeeMembers);
    } else {
      final initialCountryCode = widget.currentUser.countryCode.trim().toUpperCase();
      _countryCode = CaribbeanCountries.isAllowedCode(initialCountryCode)
          ? initialCountryCode
          : null;
    }
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
    _committeeController.dispose();
    _ticketInstructionsController.dispose();
    _ticketUrlController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;

    setState(() {
      _posterImage = File(file.path);
    });
  }

  Future<void> _pickLocation() async {
    final key = placesApiKey;
    if (key.trim().isEmpty) {
      showSnackBar(
        context,
        'Google Places API key is missing.'.tr(),
      );
      return;
    }

    final dark = isDarkMode(context);
    final baseTheme = Theme.of(context);
    final suggestionIconColor = dark ? Colors.white : Color(cfg.colorPrimary);

    final prediction = await Navigator.of(context).push<google_places.Prediction>(
      MaterialPageRoute(
        builder: (routeContext) => Theme(
          data: Theme.of(routeContext).copyWith(
            iconTheme: baseTheme.iconTheme.copyWith(
              color: suggestionIconColor,
            ),
            listTileTheme: baseTheme.listTileTheme.copyWith(
              iconColor: suggestionIconColor,
            ),
          ),
          child: PlacesAutocompleteWidget(
            apiKey: key,
            mode: Mode.fullscreen,
            language: 'en',
            resultTextStyle: TextStyle(
              color: dark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
          ),
        ),
      ),
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

    final dark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                  ),
            dialogBackgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: primaryColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: primaryColor,
                  ),
            dialogBackgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
          ),
          child: child!,
        );
      },
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
      } else {
        _endAt = dateTime;
      }
    });
  }

  void _showTicketTypeDialog({TicketType? ticketType, int? index}) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);
    final nameCtrl = TextEditingController(text: ticketType?.name);
    final priceCtrl = TextEditingController(text: ticketType?.price.toString());
    final descCtrl = TextEditingController(text: ticketType?.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          ticketType == null ? 'Add Ticket Type'.tr() : 'Edit Ticket Type'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Ticket Name (e.g. VIP)'.tr(),
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Price'.tr(),
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)'.tr(),
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                final newTicketType = TicketType(
                  name: nameCtrl.text,
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  description: descCtrl.text,
                  currency: 'USD',
                );
                setState(() {
                  if (index != null) {
                    _ticketTypes[index] = newTicketType;
                  } else {
                    _ticketTypes.add(newTicketType);
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(ticketType == null ? 'Add'.tr() : 'Update'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCommitteeMemberDialog({CommitteeMember? member, int? index}) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);
    final nameCtrl = TextEditingController(text: member?.name);
    final phoneCtrl = TextEditingController(text: member?.contactNumber);
    bool hasWhatsapp = member?.hasWhatsapp ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            member == null ? 'Add Committee Member'.tr() : 'Edit Committee Member'.tr(),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Name'.tr(),
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Contact Number'.tr(),
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: Text('Available on WhatsApp'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14)),
                  value: hasWhatsapp,
                  activeColor: primaryColor,
                  onChanged: (val) => setStateDialog(() => hasWhatsapp = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  final newMember = CommitteeMember(
                    name: nameCtrl.text,
                    contactNumber: phoneCtrl.text,
                    hasWhatsapp: hasWhatsapp,
                  );
                  setState(() {
                    if (index != null) {
                      _committeeMembers[index] = newMember;
                    } else {
                      _committeeMembers.add(newMember);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(member == null ? 'Add'.tr() : 'Update'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_checkingEntitlement) return;
    if (!_isSubscribed) {
      showSnackBar(context, 'You need an active subscription to post events.'.tr());
      return;
    }

    setState(() => _showValidationErrors = true);
    if (_hasRequiredFieldErrors) return;

    setState(() => _loading = true);

    try {
      String posterUrl = _existingPosterUrl ?? '';
      if (_posterImage != null) {
        final uploaded = await listingApiManager.uploadListingImages(images: [_posterImage!]);
        posterUrl = uploaded.isEmpty ? posterUrl : uploaded.first;
      }

      final event = EventModel(
        id: widget.eventToEdit?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: widget.eventToEdit?.createdBy ?? widget.currentUser.userID,
        startAtSeconds: _startAt!.millisecondsSinceEpoch ~/ 1000,
        endAtSeconds: _endAt!.millisecondsSinceEpoch ~/ 1000,
        latitude: _placeDetail?.geometry?.location.lat ?? widget.eventToEdit?.latitude ?? 0,
        longitude: _placeDetail?.geometry?.location.lng ?? widget.eventToEdit?.longitude ?? 0,
        venueName: _venueController.text.trim(),
        countryCode: _countryCode!,
        posterImageUrl: posterUrl,
        ticketInstructions: _ticketInstructionsController.text.trim(),
        ticketUrl: _ticketUrlController.text.trim(),
        facebookUrl: _facebookController.text.trim(),
        instagramUrl: _instagramController.text.trim(),
        committee: _committeeController.text.trim(),
        ticketTypes: _ticketTypes,
        committeeMembers: _committeeMembers,
      );

      await _eventsRepository.createEvent(event);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to save event.'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.eventToEdit == null ? 'Create Event'.tr() : 'Edit Event'.tr())),
      body: SingleChildScrollView(
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
                icon: Icons.title,
                errorText: _showValidationErrors && _titleMissing ? 'Required'.tr() : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _committeeController,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(
                context: context,
                label: 'Committee / Organizer (Optional)'.tr(),
                icon: Icons.group_outlined,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(
                context: context,
                label: 'Description'.tr(),
                icon: Icons.description,
                errorText: _showValidationErrors && _descriptionMissing ? 'Required'.tr() : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _venueController,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(
                context: context,
                label: 'Venue Name'.tr(),
                icon: Icons.storefront,
                errorText: _showValidationErrors && _venueMissing ? 'Required'.tr() : null,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              tileColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(Icons.location_on, color: Color(cfg.colorPrimary)),
              title: Text(_placeDetail?.formattedAddress ?? widget.eventToEdit?.venueName ?? 'Select Location'.tr(),
                style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 14)),
              onTap: _pickLocation,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(isStart: true),
                    icon: const Icon(Icons.event_available, size: 18),
                    label: Text(_startAt == null ? 'Start Date'.tr() : DateFormat('MMM d, h:mm a').format(_startAt!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(isStart: false),
                    icon: const Icon(Icons.event_busy, size: 18),
                    label: Text(_endAt == null ? 'End Date'.tr() : DateFormat('MMM d, h:mm a').format(_endAt!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Committee Members'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add contact persons for the event.'.tr(), style: TextStyle(fontSize: 12, color: dark ? Colors.white54 : Colors.black54)),
                TextButton.icon(onPressed: () => _showCommitteeMemberDialog(), icon: const Icon(Icons.person_add_alt_1), label: Text('Add'.tr())),
              ],
            ),
            ...List.generate(_committeeMembers.length, (index) {
              final m = _committeeMembers[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _showCommitteeMemberDialog(member: m, index: index),
                  leading: Icon(Icons.person, color: Color(cfg.colorPrimary)),
                  title: Text(m.name, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  subtitle: Text(m.contactNumber, style: TextStyle(color: dark ? Colors.white70 : Colors.black54)),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _committeeMembers.removeAt(index))),
                ),
              );
            }),
            const SizedBox(height: 24),
            Text('Ticketing & Links'.tr(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: dark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: _ticketUrlController,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(context: context, label: 'Ticket Link (Optional)'.tr(), icon: Icons.link),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _facebookController,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(context: context, label: 'Facebook Page'.tr(), icon: Icons.facebook),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramController,
              style: TextStyle(color: dark ? Colors.white : Colors.black87),
              decoration: _inputDecoration(context: context, label: 'Instagram Username'.tr(), icon: Icons.camera_alt),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ticket Types'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: dark ? Colors.white : Colors.black87)),
                TextButton.icon(onPressed: () => _showTicketTypeDialog(), icon: const Icon(Icons.add), label: Text('Add'.tr())),
              ],
            ),
            ...List.generate(_ticketTypes.length, (index) {
              final t = _ticketTypes[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _showTicketTypeDialog(ticketType: t, index: index),
                  title: Text(t.name, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  subtitle: Text('\$${t.price}', style: TextStyle(color: dark ? Colors.white : Colors.black54)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => setState(() => _ticketTypes.removeAt(index)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            ListTile(
              tileColor: dark ? Colors.grey.shade900 : Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: SizedBox(
                width: 24,
                height: 24,
                child: _posterImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(_posterImage!, fit: BoxFit.cover),
                      )
                    : _existingPosterUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(_existingPosterUrl!, fit: BoxFit.cover),
                          )
                        : Icon(Icons.image, color: Color(cfg.colorPrimary)),
              ),
              title: Text(_posterImage == null && _existingPosterUrl == null ? 'Upload Poster'.tr() : 'Poster Selected'.tr(),
                style: TextStyle(color: dark ? Colors.white : Colors.black87)),
              onTap: _pickPoster,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Color(cfg.colorPrimary)),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('Save Event'.tr(), style: const TextStyle(color: Colors.white)),
              ),
            ),
            // Added padding for system navigation buttons
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }
}
