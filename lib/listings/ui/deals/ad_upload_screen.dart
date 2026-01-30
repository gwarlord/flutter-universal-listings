
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/deals/ad_format_guidance_screen.dart';
import 'package:instaflutter/listings/ui/deals/ad_terms_and_conditions_screen.dart';
import 'package:instaflutter/listings/ui/deals/ad_pricing_selector.dart';
import 'package:instaflutter/listings/utils/caribbean_countries.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:instaflutter/listings/services/media_upload_service.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/utils/ad_seasonality_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

// Video preview widget for local file
class _VideoPreviewWidget extends StatefulWidget {
  final File? file;
  final String? url;
  const _VideoPreviewWidget({this.file, this.url});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.file != null 
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.url!));
        
    _controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.setLooping(true);
          _controller.setVolume(0); // Preview muted
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

class AdUploadScreen extends StatefulWidget {
  final VoidCallback? onAdSubmitted;
  final DealAdModel? adToEdit;
  const AdUploadScreen({Key? key, this.onAdSubmitted, this.adToEdit}) : super(key: key);

  @override
  State<AdUploadScreen> createState() => _AdUploadScreenState();
}

class _AdUploadScreenState extends State<AdUploadScreen> {
  double get _seasonalMultiplier => AdSeasonalityHelper.getSeasonalMultiplier(DateTime.now());
  String get _seasonLabel => AdSeasonalityHelper.getSeasonLabel(DateTime.now());
  
  File? _mediaFile;
  String? _existingMediaUrl;
  String? _mediaType; // 'image' or 'video'
  final TextEditingController _captionController = TextEditingController();
  int _adDays = 1;
  bool _acceptedTerms = false;
  
  // Promo Period variables
  DateTime? _promoStartDate;
  DateTime? _promoEndDate;

  // Ad Type variable
  String _adType = 'promo'; // 'advert' or 'promo'

  // Visibility Filter variables
  List<String> _selectedCountryCodes = [];

  @override
  void initState() {
    super.initState();
    if (widget.adToEdit != null) {
      final ad = widget.adToEdit!;
      _captionController.text = ad.caption;
      _adDays = ad.durationDays;
      _adType = ad.adType;
      _mediaType = ad.mediaType;
      _existingMediaUrl = ad.mediaUrl;
      _promoStartDate = ad.startDate;
      _promoEndDate = ad.endDate;
      _acceptedTerms = true; // Already accepted for existing ad
      _selectedCountryCodes = List<String>.from(ad.visibilityCountries);
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: const Text('Add media'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'image'),
            child: const Text('Choose Image from Gallery'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'video'),
            child: const Text('Choose Video from Gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (result == null) return;
    if (result == 'image') {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _mediaFile = File(pickedFile.path);
          _existingMediaUrl = null;
          _mediaType = 'image';
        });
      }
    } else if (result == 'video') {
      final pickedVideo = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        setState(() {
          _mediaFile = File(pickedVideo.path);
          _existingMediaUrl = null;
          _mediaType = 'video';
        });
      }
    }
  }

  Future<void> _selectPromoDates() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _promoStartDate != null && _promoEndDate != null
          ? DateTimeRange(start: _promoStartDate!, end: _promoEndDate!)
          : null,
      builder: (context, child) {
        final dark = isDarkMode(context);
        return Theme(
          data: dark ? ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Color(colorPrimary),
              onPrimary: Colors.white,
              surface: const Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ) : ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(colorPrimary),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _promoStartDate = picked.start;
        _promoEndDate = picked.end;
        _adDays = picked.duration.inDays + 1;
      });
    }
  }

  void _showFormatGuidance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdFormatGuidanceScreen()),
    );
  }

  void _showTypeInfo() {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Ad Types', style: TextStyle(color: dark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promotion:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorPrimary))),
            const SizedBox(height: 4),
            Text('Time-limited offers. Requires a specific start and end date (e.g., 20% off for 1 week).', 
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            Text('Advert:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorPrimary))),
            const SizedBox(height: 4),
            Text('General business awareness. Runs indefinitely without a specific offer period.', 
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: Color(colorPrimary))),
          ),
        ],
      ),
    );
  }

  void _showPeriodInfo() {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Promo Period', style: TextStyle(color: dark ? Colors.white : Colors.black)),
        content: Text(
          'A promo period ensures customers know exactly when your offer begins and ends. It creates urgency and helps them plan their purchase before the deal expires.',
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: Color(colorPrimary))),
          ),
        ],
      ),
    );
  }

  void _showTermsAndConditions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdTermsAndConditionsScreen(
          onAccepted: () {
            setState(() {
              _acceptedTerms = true;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showCountrySelectionDialog() {
    final user = context.read<AuthenticationBloc>().user;
    final String? userCountryCode = user?.countryCode; 
    
    List<String> tempSelectedCountries = [..._selectedCountryCodes];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = isDarkMode(context);
            
            // Prepare countries list
            final allCountries = List<CaribbeanCountry>.from(CaribbeanCountries.all);
            allCountries.sort((a, b) => a.name.compareTo(b.name));
            
            // Bring user's country to top if it exists
            if (userCountryCode != null && userCountryCode.isNotEmpty) {
              final userIdx = allCountries.indexWhere((c) => c.code == userCountryCode);
              if (userIdx != -1) {
                final userCountry = allCountries.removeAt(userIdx);
                allCountries.insert(0, userCountry);
              }
            }

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target Countries'.tr(),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        if (tempSelectedCountries.length == allCountries.length) {
                          tempSelectedCountries.clear();
                        } else {
                          tempSelectedCountries = allCountries.map((c) => c.code).toList();
                        }
                      });
                    },
                    child: Text(
                      tempSelectedCountries.length == allCountries.length ? 'Deselect All'.tr() : 'Select All'.tr(),
                      style: TextStyle(color: Color(colorPrimary), fontSize: 12),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allCountries.length,
                  itemBuilder: (context, index) {
                    final country = allCountries[index];
                    final isSelected = tempSelectedCountries.contains(country.code);

                    return Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: isDark ? Colors.white : null,
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          country.name,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
                        ),
                        activeColor: Color(colorPrimary),
                        checkColor: Colors.white,
                        // No fillColor, use default
                        side: isDark ? BorderSide(color: Colors.white, width: 2) : null,
                        value: isSelected,
                        onChanged: (bool? newValue) {
                          setDialogState(() {
                            if (newValue == true) {
                              tempSelectedCountries.add(country.code);
                            } else {
                              tempSelectedCountries.remove(country.code);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCountryCodes = tempSelectedCountries;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isSubmitting = false;

  Future<void> _submitAd() async {
    if ((_mediaFile == null && _existingMediaUrl == null) || !_acceptedTerms) return;
    setState(() => _isSubmitting = true);
    try {
      final listerId = widget.adToEdit?.listerId ?? context.read<AuthenticationBloc>().user?.userID ?? 'demoListerId';
      final listingId = widget.adToEdit?.listingId ?? 'demoListingId';
      final adId = widget.adToEdit?.id ?? const Uuid().v4();
      final mediaService = MediaUploadService();
      
      String? mediaUrl = _existingMediaUrl;
      String? thumbnailUrl = widget.adToEdit?.thumbnailUrl;

      // Handle new media upload
      if (_mediaFile != null) {
        if (_mediaType == 'video') {
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: _mediaFile!.path,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 300,
            quality: 75,
          );
          if (thumbPath != null) {
            thumbnailUrl = await mediaService.uploadAdThumbnail(File(thumbPath), listerId, adId);
          }
        }
        mediaUrl = await mediaService.uploadAdMedia(_mediaFile!, listerId, adId);
      }

      final now = DateTime.now();
      final pricePerDay = 10.0;
      
      final startDate = _adType == 'promo' && _promoStartDate != null ? _promoStartDate! : now;
      final endDate = _adType == 'promo' && _promoEndDate != null ? _promoEndDate! : now.add(Duration(days: _adDays));

      final ad = DealAdModel(
        id: adId,
        listerId: listerId,
        listingId: listingId,
        mediaUrl: mediaUrl!,
        mediaType: _mediaType ?? 'image',
        thumbnailUrl: thumbnailUrl,
        caption: _captionController.text.trim(),
        durationDays: _adDays,
        pricePaid: pricePerDay * _adDays * _seasonalMultiplier,
        startDate: startDate,
        endDate: endDate,
        status: widget.adToEdit?.status ?? 'pending',
        createdAt: widget.adToEdit?.createdAt ?? now,
        approvedAt: widget.adToEdit?.approvedAt,
        reviewerId: widget.adToEdit?.reviewerId,
        authorID: listerId,
        adType: _adType,
        visibilityCountries: _selectedCountryCodes,
      );
      
      await DealAdService().submitAd(ad);
      if (widget.onAdSubmitted != null) widget.onAdSubmitted!();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.adToEdit != null ? 'Ad updated successfully!' : 'Ad submitted for review!')),
      );
      Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Failed to submit ad: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit ad: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final adaptiveTextColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(widget.adToEdit != null ? 'Edit Promotion' : 'Upload Promotion', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: adaptiveTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showFormatGuidance,
            tooltip: 'Format Guidance',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Picker Section
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: primaryColor.withOpacity(0.1)),
                ),
                child: (_mediaFile == null && _existingMediaUrl == null)
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 48, color: primaryColor),
                          const SizedBox(height: 12),
                          Text('Add Image or Video', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('High quality media gets more engagement', 
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                        ],
                      )
                    : _mediaType == 'image'
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _mediaFile != null 
                                ? Image.file(_mediaFile!, fit: BoxFit.cover)
                                : Image.network(_existingMediaUrl!, fit: BoxFit.cover),
                          )
                        : _VideoPreviewWidget(file: _mediaFile, url: _existingMediaUrl),
              ),
            ),
            
            const SizedBox(height: 24),

            // Ad Type Toggle
            Row(
              children: [
                Text('Type', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showTypeInfo,
                  child: Icon(Icons.info_outline, size: 18, color: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _adType = 'promo';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _adType == 'promo' ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Promotion',
                            style: TextStyle(
                              color: _adType == 'promo' ? Colors.white : adaptiveTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _adType = 'advert';
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _adType == 'advert' ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Advert',
                            style: TextStyle(
                              color: _adType == 'advert' ? Colors.white : adaptiveTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Visibility Filter Section
            Text('Visibility', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showCountrySelectionDialog,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Countries', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCountryCodes.isEmpty 
                                ? 'All Countries (Default)'.tr() 
                                : '${_selectedCountryCodes.length} Countries Selected'.tr(),
                            style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.public, color: primaryColor),
                  ],
                ),
              ),
            ),
            if (_selectedCountryCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedCountryCodes.map((code) {
                  final country = CaribbeanCountries.byCode(code);
                  return Chip(
                    label: Text(country?.name ?? code, style: const TextStyle(fontSize: 12)),
                    backgroundColor: primaryColor.withOpacity(0.1),
                    deleteIconColor: primaryColor,
                    onDeleted: () => setState(() => _selectedCountryCodes.remove(code)),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            
            // Caption Section
            Text('Describe your deal', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              style: TextStyle(color: adaptiveTextColor),
              decoration: InputDecoration(
                hintText: 'Ex: 20% off all summer items...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 24),
            
            // Promo Period Section (Only shown for Promotion type)
            if (_adType == 'promo')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: primaryColor, size: 20),
                            const SizedBox(width: 12),
                            Text('Set Promo Period', style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showPeriodInfo,
                              child: Icon(Icons.info_outline, size: 18, color: primaryColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    GestureDetector(
                      onTap: _selectPromoDates,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Starts', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_promoStartDate != null ? DateFormat('MMM dd, yyyy').format(_promoStartDate!) : 'Select Date',
                                    style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward, size: 16, color: isDark ? Colors.white24 : Colors.black26),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Ends', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_promoEndDate != null ? DateFormat('MMM dd, yyyy').format(_promoEndDate!) : 'Select Date',
                                    style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Pricing Section
            AdPricingSelector(
              selectedDays: _adDays,
              // Logic already implemented to disable interaction
              onDaysChanged: (days) => setState(() => _adDays = days),
              pricePerDay: 10.0,
              seasonalMultiplier: _seasonalMultiplier,
            ),
            
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$_seasonLabel Pricing Active',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Terms and Conditions
            Row(
              children: [
                Theme(
                  data: ThemeData(
                    unselectedWidgetColor: isDark ? Colors.white : Colors.grey,
                  ),
                  child: Checkbox(
                    value: _acceptedTerms,
                    activeColor: primaryColor,
                    checkColor: Colors.white,
                    onChanged: (val) {
                      if (!_acceptedTerms) {
                        _showTermsAndConditions();
                      } else {
                        setState(() => _acceptedTerms = false);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTermsAndConditions,
                    child: RichText(
                      text: TextSpan(
                        text: 'I accept the ',
                        style: TextStyle(color: adaptiveTextColor),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting || (_mediaFile == null && _existingMediaUrl == null) || !_acceptedTerms ? null : _submitAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(widget.adToEdit != null ? 'Save Changes' : 'Submit for Review', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
