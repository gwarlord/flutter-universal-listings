
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/deals/ad_format_guidance_screen.dart';
import 'package:caribtap/listings/ui/deals/ad_terms_and_conditions_screen.dart';
import 'package:caribtap/listings/ui/deals/ad_pricing_selector.dart';
import 'package:caribtap/listings/ui/deals/ad_review_screen.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/listings/model/ad_targeting_model.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/deal_ad_quota.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:caribtap/listings/services/media_upload_service.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/utils/ad_seasonality_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';

// Country selection dialog widget
class _CountrySelectionDialog extends StatefulWidget {
  final List<String> selectedCountries;
  final String? userCountryCode;
  final Function(List<String>) onConfirm;

  const _CountrySelectionDialog({
    required this.selectedCountries,
    this.userCountryCode,
    required this.onConfirm,
  });

  @override
  State<_CountrySelectionDialog> createState() => _CountrySelectionDialogState();
}

class _CountrySelectionDialogState extends State<_CountrySelectionDialog> {
  late List<String> tempSelectedCountries;
  late TextEditingController searchController;
  String searchFilter = '';

  @override
  void initState() {
    super.initState();
    tempSelectedCountries = List<String>.from(widget.selectedCountries);
    searchController = TextEditingController();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    // Prepare countries list
    final allCountries = List<CaribbeanCountry>.from(CaribbeanCountries.all);
    allCountries.sort((a, b) => a.name.compareTo(b.name));
    
    // Bring user's country to top if it exists
    if (widget.userCountryCode != null && widget.userCountryCode!.isNotEmpty) {
      final userIdx = allCountries.indexWhere((c) => c.code == widget.userCountryCode);
      if (userIdx != -1) {
        final userCountry = allCountries.removeAt(userIdx);
        allCountries.insert(0, userCountry);
      }
    }

    final filteredCountries = allCountries
        .where((country) => country.name.toLowerCase().contains(searchFilter.toLowerCase()))
        .toList();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Target Countries'.tr(),
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              controller: searchController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Search countries...'.tr(),
                hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black54),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            searchFilter = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(colorPrimary)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(colorPrimary), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onChanged: (value) {
                setState(() {
                  searchFilter = value;
                });
              },
            ),
            SizedBox(height: 12),
            // Filter countries based on search
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCountries.length + 1, // +1 for "All" option
                itemBuilder: (context, index) {
                  // First item is "All" option
                  if (index == 0) {
                    final isAllSelected = tempSelectedCountries.length == allCountries.length;
                    return Theme(
                      data: Theme.of(context).copyWith(
                        unselectedWidgetColor: isDark ? Colors.white : null,
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          'All Countries'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        activeColor: Color(colorPrimary),
                        checkColor: Colors.white,
                        side: isDark ? BorderSide(color: Colors.white, width: 2) : null,
                        value: isAllSelected,
                        onChanged: (bool? newValue) {
                          setState(() {
                            if (newValue == true) {
                              tempSelectedCountries = allCountries.map((c) => c.code).toList();
                            } else {
                              tempSelectedCountries.clear();
                            }
                            searchController.clear();
                            searchFilter = '';
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    );
                  }
                  
                  // Other items are filtered countries
                  final country = filteredCountries[index - 1];
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
                      side: isDark ? BorderSide(color: Colors.white, width: 2) : null,
                      value: isSelected,
                      onChanged: (bool? newValue) {
                        setState(() {
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
          ],
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
            widget.onConfirm(tempSelectedCountries);
            Navigator.of(context).pop();
          },
          child: Text(
            'Confirm'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

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

  // Targeting variables
  List<String> _selectedLocations = [];
  List<String> _selectedCategories = [];
  List<String> _selectedAudience = ['ALL'];
  List<CategoriesModel> _availableCategories = [];
  bool _loadingCategories = false;
  
  // Listing selection variables
  List<ListingModel> _userActiveListings = [];
  String? _selectedListingId;
  bool _loadingListings = false;
  
  // Deal Settings (Redemption) variables - REMOVED, but keeping defaults
  final String _redemptionType = 'IN_APP_CLAIM';
  final String? _promoCode = null;
  final int? _redemptionLimitTotal = null;
  final int? _redemptionLimitPerUser = null;
  DateTime? _scheduleAt;
  late DateTime _expireAt;
  
  // Scroll tracking for AppBar color change
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _expireAt = DateTime.now().add(const Duration(days: 30));
    _loadCategories();
    _loadUserListings();
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
      _selectedLocations = List<String>.from(ad.targeting.locations);
      _selectedCategories = List<String>.from(ad.targeting.categories);
      _selectedAudience = List<String>.from(ad.targeting.audience);
      _scheduleAt = ad.scheduleAt;
      _expireAt = ad.expireAt;
      _selectedListingId = ad.listingId; // Pre-select the listing for edit mode
    }
  }
  
  void _onScroll() {
    setState(() {
      _isScrolled = _scrollController.offset > 0;
    });
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await listingApiManager.getCategories();
      setState(() {
        _availableCategories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadUserListings() async {
    setState(() => _loadingListings = true);
    try {
      final authBloc = context.read<AuthenticationBloc>();
      final user = authBloc.user;
      if (user == null) {
        setState(() {
          _loadingListings = false;
        });
        return;
      }

      final allListings = await listingApiManager.getMyListings(
        currentUserID: user.userID,
        favListingsIDs: [],
      );

      // Filter to only active (non-hidden) listings
      final activeListings = allListings.where((listing) {
        // Check if listing is not hidden
        final freshness = listing.freshness;
        if (freshness != null && freshness.status == 'HIDDEN') {
          return false;
        }
        return true;
      }).toList();

      // DropdownButton requires exactly one item per selected value.
      // Keep first occurrence for each listing id to avoid duplicate values.
      final uniqueById = <String, ListingModel>{};
      for (final listing in activeListings) {
        if (listing.id.isEmpty) continue;
        uniqueById.putIfAbsent(listing.id, () => listing);
      }
      final uniqueActiveListings = uniqueById.values.toList();

      setState(() {
        _userActiveListings = uniqueActiveListings;
        _loadingListings = false;

        // If edit mode points to a missing listing, fall back safely.
        if (_selectedListingId != null &&
            !_userActiveListings.any((listing) => listing.id == _selectedListingId)) {
          _selectedListingId = _userActiveListings.isNotEmpty
              ? _userActiveListings.first.id
              : null;
        }

        // Auto-select first listing if only one exists
        if (_selectedListingId == null && _userActiveListings.length == 1) {
          _selectedListingId = _userActiveListings.first.id;
        }
      });
    } catch (e) {
      debugPrint('Failed to load user listings: $e');
      setState(() => _loadingListings = false);
    }
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: Text('Add media'.tr()),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'image'),
            child: Text('Choose Image from Gallery'.tr()),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'video'),
            child: Text('Choose Video from Gallery'.tr()),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.tr()),
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
    final authBloc = context.read<AuthenticationBloc>();
    final user = authBloc.user;
    final tier = DealAdQuota.normalizeTier(user?.subscriptionTier);
    final maxDays = tier == 'professional' ? 7 : (tier == 'premium' ? 30 : 7);
    final today = DateTime.now();
    
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(Duration(days: maxDays)),
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
      final duration = picked.end.difference(picked.start).inDays + 1;
      if (duration > maxDays) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('users_can_set_max_promo_period'.tr(args: [
                (tier == 'premium' ? 'Premium' : 'Professional').tr(),
                maxDays.toString(),
              ]),
                style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      setState(() {
        _promoStartDate = picked.start;
        _promoEndDate = picked.end;
        _adDays = duration;
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
        title: Text('Ad Types'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Promotion:'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorPrimary))),
            const SizedBox(height: 4),
            Text('Time-limited offers. Requires a specific start and end date (e.g., 20% off for 1 week).'.tr(), 
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            Text('Advert:'.tr(), style: TextStyle(fontWeight: FontWeight.bold, color: Color(colorPrimary))),
            const SizedBox(height: 4),
            Text('General business awareness. Runs indefinitely without a specific offer period.'.tr(), 
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'.tr(), style: TextStyle(color: Color(colorPrimary))),
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
        title: Text('Promo Period'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
        content: Text(
          'A promo period ensures customers know exactly when your offer begins and ends. It creates urgency and helps them plan their purchase before the deal expires.'.tr(),
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'.tr(), style: TextStyle(color: Color(colorPrimary))),
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
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _CountrySelectionDialog(
          selectedCountries: _selectedCountryCodes,
          userCountryCode: user?.countryCode,
          onConfirm: (selectedCountries) {
            setState(() {
              _selectedCountryCodes = selectedCountries;
            });
          },
        );
      },
    );
  }

  void _showCountriesInfoDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Row(
            children: [
              Icon(Icons.info, color: Color(colorPrimary), size: 24),
              const SizedBox(width: 8),
              Text(
                  'About Country Selection'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'This setting controls which countries can see your ad. When you select specific countries, only users from those locations will be able to view your promotion. If you leave it set to "All Countries", your ad will be visible to users everywhere.'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(colorPrimary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it'.tr(),
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isSubmitting = false;

  void _showCategorySelectionDialog() {
    List<String> tempSelectedCategories = [..._selectedCategories];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = isDarkMode(context);
            
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Select Categories'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _loadingCategories
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableCategories.length,
                        itemBuilder: (context, index) {
                          final category = _availableCategories[index];
                          final isSelected = tempSelectedCategories.contains(category.id);

                          return CheckboxListTile(
                            title: Text(
                              category.title,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                            activeColor: Color(colorPrimary),
                            checkColor: Colors.white,
                            side: isDark ? BorderSide(color: Colors.white, width: 2) : null,
                            value: isSelected,
                            onChanged: (bool? newValue) {
                              setDialogState(() {
                                if (newValue == true) {
                                  tempSelectedCategories.add(category.id);
                                } else {
                                  tempSelectedCategories.remove(category.id);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel'.tr(),
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorPrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCategories = tempSelectedCategories;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Confirm'.tr(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAudienceChip(String label, String value, Color primaryColor, bool isDark) {
    final isSelected = _selectedAudience.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (value == 'ALL') {
            // ALL is exclusive
            if (isSelected) {
              // Can't deselect ALL if it's the only one
              return;
            } else {
              _selectedAudience = ['ALL'];
            }
          } else {
            // Remove ALL if selecting specific audience
            _selectedAudience.remove('ALL');
            if (isSelected) {
              _selectedAudience.remove(value);
              // If nothing left, default to ALL
              if (_selectedAudience.isEmpty) {
                _selectedAudience = ['ALL'];
              }
            } else {
              _selectedAudience.add(value);
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : (isDark ? Colors.black26 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : (isDark ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _navigateToReview() {
    if ((_mediaFile == null && _existingMediaUrl == null) || !_acceptedTerms) return;
    
    final listerId = widget.adToEdit?.listerId ?? context.read<AuthenticationBloc>().user?.userID ?? 'demoListerId';
    final listingId = widget.adToEdit?.listingId ?? _selectedListingId;
    
    // Validate listing selection
    if (listingId == null || listingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a listing for your deal'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final pricePerDay = 0.0;
    final pricePaid = pricePerDay * _adDays * _seasonalMultiplier;
    
    final targeting = AdTargeting(
      locations: _selectedLocations,
      categories: _selectedCategories,
      audienceTypes: _selectedAudience,
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdReviewScreen(
          mediaFile: _mediaFile,
          existingMediaUrl: _existingMediaUrl,
          existingThumbnailUrl: widget.adToEdit?.thumbnailUrl,
          mediaType: _mediaType ?? 'image',
          caption: _captionController.text.trim(),
          adDays: _adDays,
          promoStartDate: _promoStartDate,
          promoEndDate: _promoEndDate,
          adType: _adType,
          selectedCountryCodes: _selectedCountryCodes,
          targeting: targeting,
          pricePaid: pricePaid,
          redemptionType: _redemptionType,
          promoCode: _promoCode,
          redemptionLimitTotal: _redemptionLimitTotal,
          redemptionLimitPerUser: _redemptionLimitPerUser,
          expireAt: _expireAt,
          scheduleAt: _scheduleAt,
          listerId: listerId,
          listingId: listingId,
          adToEdit: widget.adToEdit,
          availableCategories: _availableCategories,
        ),
      ),
    );
  }

  Future<void> _submitAd() async {
    // This method now navigates to review instead of directly submitting
    _navigateToReview();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final adaptiveTextColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: _isScrolled ? 4 : 0,
        backgroundColor: _isScrolled ? primaryColor : Colors.transparent,
        title: Text(widget.adToEdit != null ? 'Edit Promotion'.tr() : 'Upload Promotion'.tr(), style: TextStyle(color: _isScrolled ? Colors.white : adaptiveTextColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: _isScrolled ? Colors.white : adaptiveTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showFormatGuidance,
            tooltip: 'Format Guidance'.tr(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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
                          Text('Add Image or Video'.tr(), style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('High quality media gets more engagement'.tr(), 
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
                Text('Type'.tr(), style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
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
                            'Promotion'.tr(),
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
                            'Advert'.tr(),
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
            
            // Listing Selection Section
            Text('Select Listing'.tr(), style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Choose which listing this deal is for'.tr(), style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12)),
            const SizedBox(height: 12),
            _loadingListings
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: CircularProgressIndicator(color: primaryColor)),
                  )
                : _userActiveListings.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You need an active listing to post a deal. Please create a listing first.'.tr(),
                                style: TextStyle(color: adaptiveTextColor, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedListingId == null ? Colors.red.withOpacity(0.5) : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedListingId,
                            hint: Text(
                              'Select a listing...'.tr(),
                              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            ),
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: TextStyle(color: adaptiveTextColor, fontSize: 14),
                            icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                            items: _userActiveListings.map((listing) {
                              return DropdownMenuItem<String>(
                                value: listing.id,
                                child: Text(
                                  listing.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: adaptiveTextColor),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedListingId = value;
                              });
                            },
                          ),
                        ),
                      ),
            
            const SizedBox(height: 24),
            
            // Caption Section
            Text('Describe your deal'.tr(), style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              style: TextStyle(color: adaptiveTextColor),
              decoration: InputDecoration(
                hintText: 'Ex: 20% off all summer items...'.tr(),
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
            
            // Ad Duration Section (before promo period)
            AdPricingSelector(
              selectedDays: _adDays,
              onDaysChanged: (days) => setState(() => _adDays = days),
              pricePerDay: 0.0,
              seasonalMultiplier: _seasonalMultiplier,
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
                            Text('Set Promo Period'.tr(), style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.w600)),
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
                                  Text('Starts'.tr(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_promoStartDate != null ? DateFormat('MMM dd, yyyy').format(_promoStartDate!) : 'Select Date'.tr(),
                                    style: TextStyle(color: adaptiveTextColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward, size: 16, color: isDark ? Colors.white24 : Colors.black26),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Ends'.tr(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_promoEndDate != null ? DateFormat('MMM dd, yyyy').format(_promoEndDate!) : 'Select Date'.tr(),
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
            
            // Targeting Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Targeting Options'.tr(),
                        style: TextStyle(
                          color: adaptiveTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose who can see your ad'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Target Countries
                  Row(
                    children: [
                      Text(
                        'Countries'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _showCountriesInfoDialog(isDark),
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showCountrySelectionDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCountryCodes.isEmpty
                                  ? 'All Countries (Default)'.tr()
                                  : 'x_selected'.tr(args: [_selectedCountryCodes.length.toString()]),
                              style: TextStyle(
                                color: _selectedCountryCodes.isEmpty
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : adaptiveTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: adaptiveTextColor),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedCountryCodes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedCountryCodes.map((code) {
                        final country = CaribbeanCountries.byCode(code);
                        return Chip(
                          label: Text(country?.name ?? code, style: const TextStyle(fontSize: 11)),
                          backgroundColor: primaryColor.withOpacity(0.1),
                          deleteIconColor: primaryColor,
                          onDeleted: () => setState(() => _selectedCountryCodes.remove(code)),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Categories
                  Text(
                    'Target Categories'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _loadingCategories ? null : () => _showCategorySelectionDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCategories.isEmpty
                                  ? 'Select categories'.tr()
                                  : 'x_selected'.tr(args: [_selectedCategories.length.toString()]),
                              style: TextStyle(
                                color: _selectedCategories.isEmpty
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : adaptiveTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: adaptiveTextColor),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedCategories.map((catId) {
                        final cat = _availableCategories.firstWhere((c) => c.id == catId, orElse: () => CategoriesModel(id: catId, title: catId, photo: '', isActive: true, sortOrder: 0));
                        return Chip(
                          label: Text(cat.title, style: const TextStyle(fontSize: 11)),
                          backgroundColor: primaryColor.withOpacity(0.1),
                          deleteIconColor: primaryColor,
                          onDeleted: () => setState(() => _selectedCategories.remove(catId)),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Audience Type
                  Text(
                    'Audience Type'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildAudienceChip('All Users'.tr(), 'ALL', primaryColor, isDark),
                      _buildAudienceChip('Viewed Similar'.tr(), 'VIEWED_SIMILAR', primaryColor, isDark),
                      _buildAudienceChip('Favorited'.tr(), 'FAVORITED', primaryColor, isDark),
                      _buildAudienceChip('Near Location'.tr(), 'NEAR_ME', primaryColor, isDark),
                    ],
                  ),
                ],
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
                        text: '${'I accept the'.tr()} ',
                        style: TextStyle(color: adaptiveTextColor),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions'.tr(),
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
                onPressed: _isSubmitting || 
                    (_mediaFile == null && _existingMediaUrl == null) || 
                    !_acceptedTerms || 
                    (_selectedListingId == null && widget.adToEdit == null) || 
                    _userActiveListings.isEmpty
                    ? null 
                    : _navigateToReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text('Continue to Review'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
