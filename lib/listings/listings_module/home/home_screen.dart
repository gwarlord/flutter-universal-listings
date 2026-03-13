import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/utils/ads/ads_utils.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/category_listings/category_listings_screen.dart';
import 'package:caribtap/listings/listings_module/events/create_event_screen.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:caribtap/listings/listings_module/home/home_bloc.dart';
import 'package:caribtap/listings/listings_module/home/widgets/event_home_card.dart';
import 'package:caribtap/listings/listings_module/home/widgets/home_filter_panel.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/feed_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/home_filter_state.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/listings/utils/listing_filter_helpers.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/utils/search_utils.dart';
import 'package:caribtap/listings/utils/category_localization.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../ui/deals/deals_feed_screen.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_model.dart';
import 'package:caribtap/listings/location/ui/location_scope_floating_button.dart';
import 'package:caribtap/listings/model/event_model.dart';

// Country filter selection dialog widget
class _HomeCountrySelectionDialog extends StatefulWidget {
  final List<String> selectedCountries;
  final Function(List<String>) onConfirm;

  const _HomeCountrySelectionDialog({
    required this.selectedCountries,
    required this.onConfirm,
  });

  @override
  State<_HomeCountrySelectionDialog> createState() =>
      _HomeCountrySelectionDialogState();
}

class _HomeCountrySelectionDialogState
    extends State<_HomeCountrySelectionDialog> {
  late List<String> tempSelectedCountries;
  late TextEditingController searchController;
  String searchQuery = '';
  late final List<CaribbeanCountry> sortedCountries;

  @override
  void initState() {
    super.initState();
    tempSelectedCountries = List<String>.from(widget.selectedCountries);
    searchController = TextEditingController();
    sortedCountries = CaribbeanCountries.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<CaribbeanCountry> getFilteredCountries() {
    if (searchQuery.isEmpty) return sortedCountries;
    return sortedCountries
        .where((country) =>
            country.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Select Countries'.tr(),
        style: TextStyle(
          fontSize: 16,
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
                hintStyle:
                    TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: Icon(Icons.search, color: Color(cfg.colorPrimary)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: isDark ? Colors.white54 : Colors.black54),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: getFilteredCountries().length,
                  itemBuilder: (context, index) {
                    final country = getFilteredCountries()[index];
                    final isSelected =
                        tempSelectedCountries.contains(country.code);

                    return Theme(
                      data: ThemeData(
                        unselectedWidgetColor:
                            isDark ? Colors.white70 : Colors.black54,
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          country.name,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        activeColor: Color(cfg.colorPrimary),
                        checkColor: Colors.white,
                        value: isSelected,
                        onChanged: (bool? newValue) {
                          setState(() {
                            if (newValue == true) {
                              tempSelectedCountries.add(country.code);
                            } else if (newValue == false) {
                              tempSelectedCountries.remove(country.code);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'.tr(),
              style:
                  TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(cfg.colorPrimary),
          ),
          onPressed: () {
            widget.onConfirm(tempSelectedCountries);
            Navigator.of(context).pop();
          },
          child: Text(
            'Save'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class HomeWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;
  final GlobalKey<HomeScreenState> homeKey;

  const HomeWrapperWidget({
    super.key,
    required this.currentUser,
    required this.homeKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(
        currentUser: currentUser,
        profileRepository: profileApiManager,
        listingsRepository: listingApiManager,
      ),
      child: HomeScreen(
        currentUser: currentUser,
        key: homeKey,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<ListingModel> listings = [];
  List<FeedItem?> listingsWithAds = [];
  List<CategoriesModel> _categories = [];
  List<ListingModel> _featuredListings = [];
  List<DealAdModel> _dealAds = [];

  bool _showAll = false;
  bool loadingCategories = true;
  bool loadingListings = true;
  bool loadingFeatured = true;
  bool loadingDeals = true;

  late ListingsUser currentUser;

  // Search and filter variables
  String _searchQuery = '';
  List<String> _selectedCountryCodes = [];
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  HomeFilterState _currentFilters = HomeFilterState();

  // Cycling controllers
  late ScrollController _categoryScrollController;
  late ScrollController _dealsScrollController;
  late ScrollController _featuredScrollController;
  Timer? _categoryCycleTimer;
  Timer? _dealsCycleTimer;
  Timer? _featuredCycleTimer;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _categoryScrollController = ScrollController();
    _dealsScrollController = ScrollController();
    _featuredScrollController = ScrollController();
    context.read<HomeBloc>().add(GetCategoriesEvent());
    context.read<HomeBloc>().add(GetListingsEvent());
    _loadFeaturedListings();
    _loadDeals();
    _startCategoryCycling();
    _startDealsCycling();
    _startFeaturedCycling();
  }

  void refreshFeed() {
    if (!mounted) return;
    context.read<HomeBloc>().add(GetListingsEvent());
  }

  void _startCategoryCycling() {
    _categoryCycleTimer?.cancel();
    _categoryCycleTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_categoryScrollController.hasClients && _categories.isNotEmpty) {
        final maxScroll = _categoryScrollController.position.maxScrollExtent;
        double nextOffset = _categoryScrollController.offset + 150.0;

        if (nextOffset > maxScroll + 50) {
          nextOffset = 0.0;
        }

        _categoryScrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startDealsCycling() {
    _dealsCycleTimer?.cancel();
    _dealsCycleTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_dealsScrollController.hasClients && _dealAds.isNotEmpty) {
        final maxScroll = _dealsScrollController.position.maxScrollExtent;
        double nextOffset =
            _dealsScrollController.offset + 192.0; // 180 width + 12 margin

        if (nextOffset > maxScroll + 50) {
          nextOffset = 0.0;
        }

        _dealsScrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _startFeaturedCycling() {
    _featuredCycleTimer?.cancel();
    _featuredCycleTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_featuredScrollController.hasClients &&
          _featuredListings.isNotEmpty) {
        final maxScroll = _featuredScrollController.position.maxScrollExtent;
        double nextOffset =
            _featuredScrollController.offset + 216.0; // 200 width + 16 margin

        if (nextOffset > maxScroll + 50) {
          nextOffset = 0.0;
        }

        _featuredScrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadFeaturedListings() async {
    try {
      final featured = await listingApiManager.getFeaturedListings();
      setState(() {
        _featuredListings = featured;
        loadingFeatured = false;
      });
    } catch (e) {
      setState(() {
        loadingFeatured = false;
      });
    }
  }

  Future<void> _loadDeals() async {
    DealAdService().getApprovedAds().listen((ads) {
      if (mounted) {
        setState(() {
          // Prioritize ads based on user country and visibility settings
          final userCountry = currentUser.countryCode;

          // 1. Target User's Country
          final targetedAds = ads
              .where((ad) => ad.visibilityCountries.contains(userCountry))
              .toList()
            ..shuffle();

          // 2. Global Ads (visible to everyone)
          final globalAds = ads
              .where((ad) => ad.visibilityCountries.isEmpty)
              .toList()
            ..shuffle();

          // 3. Other Targeted Ads (fallback)
          final otherAds = ads
              .where((ad) =>
                  ad.visibilityCountries.isNotEmpty &&
                  !ad.visibilityCountries.contains(userCountry))
              .toList()
            ..shuffle();

          _dealAds = [...targetedAds, ...globalAds, ...otherAds];
          loadingDeals = false;
        });
      }
    }, onError: (e) {
      if (mounted) {
        loadingDeals = false;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _categoryScrollController.dispose();
    _dealsScrollController.dispose();
    _featuredScrollController.dispose();
    _categoryCycleTimer?.cancel();
    _dealsCycleTimer?.cancel();
    _featuredCycleTimer?.cancel();
    super.dispose();
  }

  List<FeedItem> _getFilteredFeedItems({LocationScope? locationScope}) {
    return listingsWithAds
        .where((item) => item != null)
        .cast<FeedItem>()
        .where((item) {
      final isOwnEvent = item.type == FeedItemType.event &&
          (item.event?.createdBy == currentUser.userID);

      final countryCode = item.type == FeedItemType.listing
          ? item.listing!.countryCode
          : item.event!.countryCode;

      // Filter by location scope (Caribbean mode shows all Caribbean countries, Local mode shows selected country only)
      if (locationScope != null) {
        final effectiveCountry = locationScope.getEffectiveCountry();
        if (locationScope.mode == LocationScopeMode.local &&
            effectiveCountry != null) {
          if (!isOwnEvent && countryCode != effectiveCountry) {
            return false;
          }
        } else if (locationScope.mode == LocationScopeMode.caribbean) {
          if (!isOwnEvent && !CaribbeanCountries.isAllowedCode(countryCode)) {
            return false;
          }
        }
      }

      // Filter by search query using comprehensive SearchUtils
      final matchesSearch = _searchQuery.isEmpty ||
          (item.type == FeedItemType.listing
              ? SearchUtils.fuzzyMatch(_searchQuery,
                  SearchUtils.buildListingSearchString(item.listing!))
              : SearchUtils.fuzzyMatch(_searchQuery,
                  SearchUtils.buildEventSearchString(item.event!)));

      // Filter by country (if countries are selected, listing must be in that list)
      final matchesCountry = _selectedCountryCodes.isEmpty ||
          _selectedCountryCodes.contains(countryCode);

      return matchesSearch && (matchesCountry || isOwnEvent);
    }).toList();
  }

  List<ListingModel> _getFilteredFeaturedListings(
      {LocationScope? locationScope}) {
    return _featuredListings.where((listing) {
      // Filter by location scope (Caribbean mode shows all Caribbean countries, Local mode shows selected country only)
      if (locationScope != null) {
        final effectiveCountry = locationScope.getEffectiveCountry();
        if (locationScope.mode == LocationScopeMode.local &&
            effectiveCountry != null) {
          if (listing.countryCode != effectiveCountry) {
            return false;
          }
        } else if (locationScope.mode == LocationScopeMode.caribbean) {
          if (!CaribbeanCountries.isAllowedCode(listing.countryCode)) {
            return false;
          }
        }
      }

      // Apply the same filters as regular listings
      // Filter by search query using comprehensive SearchUtils
      final matchesSearch = _searchQuery.isEmpty ||
          SearchUtils.fuzzyMatch(
              _searchQuery, SearchUtils.buildListingSearchString(listing));

      // Filter by country (if countries are selected, listing must be in that list)
      final matchesCountry = _selectedCountryCodes.isEmpty ||
          _selectedCountryCodes.contains(listing.countryCode);

      // Filter by standard filter options (open now, has mini store, etc.)
      if (_currentFilters.openNowOnly &&
          !ListingFilterHelpers.isOpenNow(listing)) {
        return false;
      }

      if (_currentFilters.hasMiniStore && !listing.storeEnabled) {
        return false;
      }

      if (_currentFilters.hasRentals && listing.rentalConfig == null) {
        return false;
      }

      if (_currentFilters.hasBooking && !listing.bookingEnabled) {
        return false;
      }

      if (_currentFilters.hasDeals &&
          !listing.menuEnabled &&
          !listing.storeEnabled) {
        return false;
      }

      if (_currentFilters.supportsDelivery && !listing.storeDeliveryEnabled) {
        return false;
      }

      if (_currentFilters.supportsPickup && !listing.storePickupEnabled) {
        return false;
      }

      if (_currentFilters.supportsDineIn && !listing.storeDineInEnabled) {
        return false;
      }

      if (_currentFilters.categoryIds.isNotEmpty &&
          !_currentFilters.categoryIds.contains(listing.categoryID)) {
        return false;
      }

      return matchesSearch && matchesCountry;
    }).toList();
  }

  List<FeedItem?> _getFilteredListingsWithAds({LocationScope? locationScope}) {
    final filtered = _getFilteredFeedItems(locationScope: locationScope);
    final result = <FeedItem?>[];

    for (int i = 0; i < filtered.length; i++) {
      if ((result.length + 1) % 5 == 0) {
        result.add(null);
        result.add(filtered[i]);
      } else {
        result.add(filtered[i]);
      }
    }

    return result;
  }

  Widget _buildSectionHeader({
    required String title,
    VoidCallback? onSeeAll,
    bool isDark = false,
    Color? titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: titleColor ?? (isDark ? Colors.white : Colors.black87),
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(cfg.colorPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCountrySelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _HomeCountrySelectionDialog(
          selectedCountries: _selectedCountryCodes,
          onConfirm: (selectedCountries) {
            setState(() {
              _selectedCountryCodes = selectedCountries;
            });
          },
        );
      },
    );
  }

  void _showFilterPanel(BuildContext context) {
    final homeBloc = context.read<HomeBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HomeFilterPanel(
        currentFilters: _currentFilters,
        categories: _categories,
        onApply: (filters) {
          setState(() {
            _currentFilters = filters;
          });
          homeBloc.add(ApplyFiltersEvent(filters: filters));
          Navigator.of(sheetContext).pop();
        },
        onClear: () {
          setState(() {
            _currentFilters = HomeFilterState();
          });
          homeBloc.add(ClearFiltersEvent());
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  Future<void> _openCreateEventScreen() async {
    final bool? created = await push(
      context,
      CreateEventScreen(currentUser: currentUser),
    );

    if (created == true && mounted) {
      context.read<HomeBloc>().add(GetListingsEvent());
      showSnackBar(context, 'Event posted successfully.'.tr());
    }
  }

  String _sortOptionLabel(HomeSortOption option) {
    switch (option) {
      case HomeSortOption.recommended:
        return 'Recommended'.tr();
      case HomeSortOption.mostVouched:
        return 'Most Vouched'.tr();
      case HomeSortOption.nearest:
        return 'Nearest'.tr();
      case HomeSortOption.newest:
        return 'Newest'.tr();
      case HomeSortOption.aToZ:
        return 'A-Z'.tr();
      case HomeSortOption.vouchCount:
        return 'Vouch count'.tr();
    }
  }

  Widget _buildSortControl(bool isDark) {
    final primaryColor = Color(cfg.colorPrimary);
    const options = [
      HomeSortOption.recommended,
      HomeSortOption.mostVouched,
      HomeSortOption.nearest,
      HomeSortOption.newest,
      HomeSortOption.aToZ,
      HomeSortOption.vouchCount,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(cfg.colorPrimary).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(
            'Sort by'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HomeSortOption>(
                value: _currentFilters.sortOption,
                isExpanded: true,
                dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                iconEnabledColor: primaryColor,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: options
                    .map((option) => DropdownMenuItem<HomeSortOption>(
                          value: option,
                          child: Text(_sortOptionLabel(option)),
                        ))
                    .toList(),
                onChanged: (option) {
                  if (option == null) return;
                  final updatedFilters =
                      _currentFilters.copyWith(sortOption: option);
                  setState(() => _currentFilters = updatedFilters);
                  context
                      .read<HomeBloc>()
                      .add(ApplyFiltersEvent(filters: updatedFilters));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);

    return BlocListener<LocationScopeCubit, LocationScopeState>(
      listener: (context, locationState) {
        // When location scope changes, refresh listings
        context.read<HomeBloc>().add(GetListingsEvent());
      },
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.grey[50],
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                context.read<HomeBloc>().add(LoadingEvent());
                context.read<HomeBloc>().add(GetCategoriesEvent());
                context.read<HomeBloc>().add(GetListingsEvent());
                await _loadFeaturedListings();
                await _loadDeals();
              },
              child: BlocConsumer<HomeBloc, HomeState>(
                listener: (context, state) {
                  if (state is CategoriesListState) {
                    loadingCategories = false;
                    _categories = state.categories;
                  } else if (state is ListingsListState) {
                    context.read<LoadingCubit>().hideLoading();
                    loadingListings = false;

                    listingsWithAds = state.listingsWithAds;
                    listings = listingsWithAds
                        .where((e) => e?.type == FeedItemType.listing)
                        .map((e) => e!.listing!)
                        .toList();
                  } else if (state is FiltersAppliedState) {
                    context.read<LoadingCubit>().hideLoading();
                    loadingListings = false;

                    listingsWithAds = state.listingsWithAds;
                    listings = listingsWithAds
                        .where((e) => e?.type == FeedItemType.listing)
                        .map((e) => e!.listing!)
                        .toList();

                    setState(() {
                      _currentFilters = state.filters;
                    });
                  } else if (state is LoadingCategoriesState) {
                    loadingCategories = true;
                  } else if (state is LoadingListingsState) {
                    loadingListings = true;
                  } else if (state is ToggleShowAllState) {
                    _showAll = !_showAll;
                  } else if (state is ListingFavToggleState) {
                    currentUser = state.updatedUser;
                    context.read<AuthenticationBloc>().user = state.updatedUser;

                    final idx =
                        listings.indexWhere((e) => e.id == state.listing.id);
                    if (idx != -1) {
                      listings[idx].isFav = state.listing.isFav;
                    }
                    final idx2 = listingsWithAds.indexWhere(
                      (e) =>
                          e?.type == FeedItemType.listing &&
                          e?.listing?.id == state.listing.id,
                    );
                    if (idx2 != -1) {
                      final existing = listingsWithAds[idx2];
                      if (existing != null && existing.listing != null) {
                        existing.listing!.isFav = state.listing.isFav;
                      }
                    }
                  } else if (state is LoadingState) {
                    _showAll = false;
                    loadingListings = true;
                    loadingCategories = true;
                  }
                },
                builder: (context, state) {
                  if (loadingCategories && loadingListings) {
                    return const Center(
                        child: CircularProgressIndicator.adaptive());
                  }

                  final screenWidth = MediaQuery.of(context).size.width;
                  final horizontalPadding = screenWidth >= 1200 ? 24.0 : 16.0;
                  final dealsSectionHeight =
                      screenWidth >= 1200 ? 180.0 : 150.0;
                  final categoriesSectionHeight =
                      screenWidth >= 1200 ? 132.0 : 120.0;
                  final featuredSectionHeight =
                      screenWidth >= 1200 ? 300.0 : 260.0;

                  final int listingsCrossAxisCount;
                  if (screenWidth >= 1400) {
                    listingsCrossAxisCount = 5;
                  } else if (screenWidth >= 1120) {
                    listingsCrossAxisCount = 4;
                  } else if (screenWidth >= 820) {
                    listingsCrossAxisCount = 3;
                  } else {
                    listingsCrossAxisCount = 2;
                  }

                  return Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),

                        // 1. Deals & Promotions Section
                        if (_dealAds.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6.0),
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 12.0),
                              decoration: BoxDecoration(
                                color: dark ? Colors.grey[850] : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0),
                                    child: _buildSectionHeader(
                                      title: 'Deals & Promotions'.tr(),
                                      onSeeAll: () => push(
                                          context,
                                          DealsFeedScreen(
                                              currentUser: currentUser)),
                                      isDark: dark,
                                    ),
                                  ),
                                  SizedBox(
                                    height: dealsSectionHeight,
                                    child: ListView.builder(
                                      controller: _dealsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _dealAds.length,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      itemBuilder: (context, index) {
                                        final ad = _dealAds[index];
                                        return DealAdCarouselItem(
                                            ad: ad,
                                            index: index,
                                            isDark: dark,
                                            currentUser: currentUser);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 2. Categories Section
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            padding:
                                const EdgeInsets.only(top: 8.0, bottom: 12.0),
                            decoration: BoxDecoration(
                              color: dark ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  child: _buildSectionHeader(
                                    title: 'Categories'.tr(),
                                    isDark: dark,
                                    titleColor: Color(cfg.colorPrimary),
                                  ),
                                ),
                                if (loadingCategories)
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                        child: CircularProgressIndicator
                                            .adaptive()),
                                  )
                                else if (_categories.isEmpty)
                                  showEmptyState(
                                    'No Categories'.tr(),
                                    'All Categories will be shown here here once added by the admin.'
                                        .tr(),
                                  )
                                else
                                  SizedBox(
                                    height: categoriesSectionHeight,
                                    child: ListView.builder(
                                      controller: _categoryScrollController,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _categories.length,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      itemBuilder: (context, index) =>
                                          CategoryHomeCardWidget(
                                        currentUser: currentUser,
                                        category: _categories[index],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // 3. Search & Filter Block
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: dark ? Colors.grey[900] : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Find what you need'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: dark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onTapOutside: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  style: TextStyle(
                                      color:
                                          dark ? Colors.white : Colors.black),
                                  onChanged: (value) => setState(
                                      () => _searchQuery = value.toLowerCase()),
                                  decoration: InputDecoration(
                                    hintText: 'Search listings...'.tr(),
                                    hintStyle: TextStyle(
                                        color: dark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
                                    prefixIcon: Icon(Icons.search,
                                        color: dark
                                            ? Colors.grey[400]
                                            : Colors.grey[600]),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchQuery = '');
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor:
                                        dark ? Colors.black : Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showCountrySelectionDialog(
                                                context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: dark
                                                ? Colors.black
                                                : Colors.grey[50],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Color(cfg.colorPrimary)
                                                    .withOpacity(0.1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _selectedCountryCodes.isEmpty
                                                      ? 'Filter by Country'.tr()
                                                      : '${_selectedCountryCodes.length} Countries Selected'
                                                          .tr(),
                                                  style: TextStyle(
                                                    color: _selectedCountryCodes
                                                            .isEmpty
                                                        ? Colors.grey
                                                        : (dark
                                                            ? Colors.white
                                                            : Colors.black),
                                                  ),
                                                ),
                                              ),
                                              Icon(Icons.public,
                                                  color:
                                                      Color(cfg.colorPrimary),
                                                  size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _showFilterPanel(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _currentFilters
                                                      .activeFilterCount >
                                                  0
                                              ? Color(cfg.colorPrimary)
                                              : (dark
                                                  ? Colors.black
                                                  : Colors.grey[50]),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Color(cfg.colorPrimary)
                                                  .withOpacity(0.1)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tune,
                                              color: _currentFilters
                                                          .activeFilterCount >
                                                      0
                                                  ? Colors.white
                                                  : Color(cfg.colorPrimary),
                                              size: 20,
                                            ),
                                            if (_currentFilters
                                                    .activeFilterCount >
                                                0) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${_currentFilters.activeFilterCount}',
                                                  style: TextStyle(
                                                    color:
                                                        Color(cfg.colorPrimary),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildSortControl(dark),
                                if (_selectedCountryCodes.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _selectedCountryCodes.map((code) {
                                      final country =
                                          CaribbeanCountries.all.firstWhere(
                                        (c) => c.code == code,
                                        orElse: () => CaribbeanCountry(
                                            code: code, name: code),
                                      );
                                      return Chip(
                                        label: Text(country.name,
                                            style:
                                                const TextStyle(fontSize: 12)),
                                        onDeleted: () => setState(() =>
                                            _selectedCountryCodes.remove(code)),
                                        backgroundColor: Color(cfg.colorPrimary)
                                            .withOpacity(0.1),
                                        deleteIconColor:
                                            Color(cfg.colorPrimary),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                                if (_currentFilters.activeFilterCount > 0) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Active filters'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (_currentFilters.openNowOnly)
                                        Chip(
                                          label: Text('Open Now'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    openNowOnly: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.hasMiniStore)
                                        Chip(
                                          label: Text('Has Mini Store'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    hasMiniStore: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.hasRentals)
                                        Chip(
                                          label: Text('Has Rentals'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    hasRentals: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.hasBooking)
                                        Chip(
                                          label: Text('Has Booking'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    hasBooking: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.hasDeals)
                                        Chip(
                                          label: Text('Has Deals'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    hasDeals: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.supportsDelivery)
                                        Chip(
                                          label: Text('Delivery'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    supportsDelivery: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.supportsPickup)
                                        Chip(
                                          label: Text('Pickup'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    supportsPickup: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters.supportsDineIn)
                                        Chip(
                                          label: Text('Dine-in'.tr(),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          onDeleted: () {
                                            final updatedFilters =
                                                _currentFilters.copyWith(
                                                    supportsDineIn: false);
                                            setState(() => _currentFilters =
                                                updatedFilters);
                                            context.read<HomeBloc>().add(
                                                ApplyFiltersEvent(
                                                    filters: updatedFilters));
                                          },
                                          backgroundColor:
                                              Color(cfg.colorPrimary)
                                                  .withOpacity(0.1),
                                          deleteIconColor:
                                              Color(cfg.colorPrimary),
                                          side: BorderSide.none,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      if (_currentFilters
                                          .categoryIds.isNotEmpty)
                                        ..._currentFilters.categoryIds
                                            .map((categoryId) {
                                          final categoryTitle = _categories
                                              .firstWhere(
                                                (c) => c.id == categoryId,
                                                orElse: () => CategoriesModel(
                                                    id: '',
                                                    title: 'Category'.tr(),
                                                    photo: '',
                                                    isActive: true,
                                                    sortOrder: 0),
                                              )
                                              .title;
                                          return Chip(
                                            label: Text(categoryTitle,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            onDeleted: () {
                                              final updatedCategories =
                                                  List<String>.from(
                                                      _currentFilters
                                                          .categoryIds)
                                                    ..remove(categoryId);
                                              final updatedFilters =
                                                  _currentFilters.copyWith(
                                                      categoryIds:
                                                          updatedCategories);
                                              setState(() => _currentFilters =
                                                  updatedFilters);
                                              context.read<HomeBloc>().add(
                                                  ApplyFiltersEvent(
                                                      filters: updatedFilters));
                                            },
                                            backgroundColor:
                                                Color(cfg.colorPrimary)
                                                    .withOpacity(0.1),
                                            deleteIconColor:
                                                Color(cfg.colorPrimary),
                                            side: BorderSide.none,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          );
                                        }),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 4. Featured Listings Section
                        Builder(
                          builder: (context) {
                            final locationScope =
                                context.read<LocationScopeCubit>().state.scope;
                            final filteredFeaturedListings =
                                _getFilteredFeaturedListings(
                                    locationScope: locationScope);
                            if (filteredFeaturedListings.isEmpty) {
                              return const SliverToBoxAdapter(
                                  child: SizedBox.shrink());
                            }
                            return SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                      title: 'Featured Listings'.tr(),
                                      isDark: dark),
                                  Container(
                                    height: featuredSectionHeight,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Color(cfg.colorPrimary)
                                          .withOpacity(dark ? 0.05 : 0.03),
                                    ),
                                    child: ListView.builder(
                                      controller: _featuredScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.all(12),
                                      itemCount:
                                          filteredFeaturedListings.length,
                                      itemBuilder: (context, index) {
                                        final listing =
                                            filteredFeaturedListings[index];
                                        return _buildFeaturedCard(
                                            listing, dark);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // 5. Main Listings Grid
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                              title: 'All Listings'.tr(), isDark: dark),
                        ),

                        if (loadingListings)
                          const SliverToBoxAdapter(
                              child: Center(
                                  child: CircularProgressIndicator.adaptive()))
                        else
                          Builder(
                            builder: (context) {
                              final locationScope = context
                                  .read<LocationScopeCubit>()
                                  .state
                                  .scope;
                              final filteredListingsWithAds =
                                  _getFilteredListingsWithAds(
                                      locationScope: locationScope);
                              if (filteredListingsWithAds.isEmpty) {
                                return SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 40.0),
                                    child: showEmptyState(
                                      'No Listings'.tr(),
                                      'No listings match your criteria.'.tr(),
                                      buttonTitle: 'Clear Filters'.tr(),
                                      isDarkMode: dark,
                                      action: () => setState(() {
                                        _searchQuery = '';
                                        _selectedCountryCodes = [];
                                        _searchController.clear();
                                      }),
                                      colorPrimary: Color(cfg.colorPrimary),
                                    ),
                                  ),
                                );
                              }

                              return SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = filteredListingsWithAds[index];
                                    if (item == null) {
                                      return AdsUtils.listingsInlineAd();
                                    }

                                    switch (item.type) {
                                      case FeedItemType.listing:
                                        return ListingHomeCardWidget(
                                          currentUser: currentUser,
                                          listing: item.listing!,
                                        );
                                      case FeedItemType.event:
                                        return EventHomeCard(
                                          event: item.event!,
                                          userLocation:
                                              _currentFilters.userLocation,
                                          onTap: () async {
                                            await push(
                                              context,
                                              EventDetailsScreen(
                                                  event: item.event!),
                                            );
                                          },
                                          onLongPress: (item.event!.createdBy ==
                                                      currentUser.userID ||
                                                  currentUser.isAdmin)
                                              ? () => _showEventOptions(
                                                  item.event!, context)
                                              : null,
                                        );
                                    }
                                  },
                                  childCount: filteredListingsWithAds.length > 4
                                      ? (_showAll
                                          ? filteredListingsWithAds.length
                                          : 4)
                                      : filteredListingsWithAds.length,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: listingsCrossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio:
                                      screenWidth >= 1120 ? 0.7 : 0.64,
                                ),
                              );
                            },
                          ),

                        // Show All Button
                        Builder(
                          builder: (context) {
                            final locationScope =
                                context.read<LocationScopeCubit>().state.scope;
                            final filteredListingsWithAds =
                                _getFilteredListingsWithAds(
                                    locationScope: locationScope);
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 32),
                                child: Visibility(
                                  visible: !_showAll &&
                                      filteredListingsWithAds.length > 4,
                                  child: Center(
                                    child: SizedBox(
                                      width: 200,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 14),
                                          side: BorderSide(
                                              color: Color(cfg.colorPrimary)),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                        ),
                                        child: Text(
                                          'Show All'.tr() +
                                              ' (${filteredListingsWithAds.length - 4})',
                                          style: TextStyle(
                                              color: Color(cfg.colorPrimary),
                                              fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => context
                                            .read<HomeBloc>()
                                            .add(ToggleShowAllEvent()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Floating location scope button
            LocationScopeFloatingButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(ListingModel listing, bool dark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth >= 1200 ? 240.0 : 200.0;
    final imageHeight = screenWidth >= 1200 ? 150.0 : 130.0;

    return GestureDetector(
      onTap: () => push(
          context,
          ListingDetailsWrappingWidget(
              listing: listing, currentUser: currentUser)),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: dark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    listing.photo,
                    height: imageHeight,
                    width: cardWidth,
                    fit: BoxFit.cover,
                    cacheWidth: (cardWidth * 3).round(),
                    cacheHeight: (imageHeight * 3).round(),
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (ctx, err, st) => Container(
                      height: imageHeight,
                      width: cardWidth,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.amber, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.star, size: 12, color: Colors.white),
                  ),
                ),
                if (listing.logo.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      height: 30,
                      width: 30,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: dark ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: displayImage(listing.logo),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.categoryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Color(cfg.colorPrimary),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(EventModel event, BuildContext blocContext) =>
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          message: Text(
            event.title,
            style: const TextStyle(fontSize: 20.0),
          ),
          actions: [
            if (event.createdBy == currentUser.userID || currentUser.isAdmin)
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  final bool? edited = await push(
                    context,
                    CreateEventScreen(
                      currentUser: currentUser,
                      eventToEdit: event,
                    ),
                  );
                  if (edited == true && mounted) {
                    blocContext.read<HomeBloc>().add(GetListingsEvent());
                  }
                },
                child: Text('Edit Event'.tr()),
              ),
            if (event.createdBy == currentUser.userID || currentUser.isAdmin)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () async {
                  Navigator.pop(context);
                  final String title = 'Delete Event?'.tr();
                  final String content =
                      'Are you sure you want to remove this event?'.tr();

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(title),
                      content: Text(content),
                      actions: [
                        TextButton(
                          child: Text('No'.tr()),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: Text('Yes'.tr(),
                              style: const TextStyle(color: Colors.red)),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    blocContext.read<LoadingCubit>().showLoading(
                          context,
                          'Deleting...'.tr(),
                          false,
                          Color(cfg.colorPrimary),
                        );
                    blocContext.read<HomeBloc>().add(
                          EventDeleteEvent(
                              event: event, isAdmin: currentUser.isAdmin),
                        );
                    blocContext.read<LoadingCubit>().hideLoading();
                  }
                },
                child: Text('Delete Event'.tr()),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
}

class DealAdCarouselItem extends StatefulWidget {
  final DealAdModel ad;
  final int index;
  final bool isDark;
  final ListingsUser currentUser;

  const DealAdCarouselItem({
    Key? key,
    required this.ad,
    required this.index,
    required this.isDark,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DealAdCarouselItem> createState() => _DealAdCarouselItemState();
}

class _DealAdCarouselItemState extends State<DealAdCarouselItem> {
  Uint8List? _generatedThumbnail;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.ad.mediaType == 'video' &&
        (widget.ad.thumbnailUrl == null || widget.ad.thumbnailUrl!.isEmpty)) {
      _generateLocalThumbnail();
    }
  }

  Future<void> _generateLocalThumbnail() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.ad.mediaUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        quality: 50,
      );
      if (mounted) setState(() => _generatedThumbnail = uint8list);
    } catch (e) {
      debugPrint('Error generating carousel thumbnail: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final thumbUrl =
        (ad.mediaType == 'image' ? ad.mediaUrl : ad.thumbnailUrl) ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth >= 1200 ? 220.0 : 180.0;

    return GestureDetector(
      onTap: () => push(
          context,
          DealsFeedScreen(
              initialIndex: widget.index, currentUser: widget.currentUser)),
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Content
              if (ad.mediaType == 'image')
                displayImage(ad.mediaUrl)
              else if (thumbUrl.isNotEmpty)
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  cacheWidth: 540,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  filterQuality: FilterQuality.low,
                )
              else if (_generatedThumbnail != null)
                Image.memory(_generatedThumbnail!, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.black87,
                  child: const Center(
                      child: Icon(Icons.videocam,
                          color: Colors.white24, size: 40)),
                ),

              // Overlay Elements
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7)
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),

              if (ad.mediaType == 'video')
                const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white70, size: 36)),

              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Text(
                  ad.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(cfg.colorPrimary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ad.adType.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold),
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

class CategoryHomeCardWidget extends StatelessWidget {
  final ListingsUser currentUser;
  final CategoriesModel category;

  const CategoryHomeCardWidget({
    super.key,
    required this.currentUser,
    required this.category,
  });

  String _localizedCategoryName(BuildContext context, String value) {
    return localizeCategoryLabel(value, context);
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth >= 1200 ? 82.0 : 70.0;
    final labelWidth = screenWidth >= 1200 ? 92.0 : 80.0;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => push(
          context,
          CategoryListingsWrapperWidget(
            categoryID: category.id,
            categoryName: _localizedCategoryName(context, category.title),
            currentUser: currentUser,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: ClipOval(
                child: displayImage(category.photo),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: labelWidth,
              child: Text(
                _localizedCategoryName(context, category.title),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingHomeCardWidget extends StatefulWidget {
  final ListingModel? listing;
  final ListingsUser currentUser;

  const ListingHomeCardWidget({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<ListingHomeCardWidget> createState() => _ListingHomeCardWidgetState();
}

class _ListingHomeCardWidgetState extends State<ListingHomeCardWidget> {
  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD':
      case 'XCD':
      case 'JMD':
      case 'TTD':
      case 'BSD':
      case 'BBD':
      case 'GYD':
      case 'DOP':
      case 'KYD':
      case 'SRD':
        return '\$';
      case 'ANG':
        return 'ƒ';
      case 'XOF':
        return 'CFA';
      case 'HTG':
        return 'G';
      default:
        return '\$';
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing == null) {
      return AdsUtils.listingsInlineAd();
    }

    final bool dark = isDarkMode(context);

    final double avgRating = (listing.reviewsCount > 0)
        ? (listing.reviewsSum / listing.reviewsCount)
        : 0.0;
    final double safeRating = avgRating.isFinite ? avgRating : 0.0;

    return GestureDetector(
      onLongPress: widget.currentUser.isAdmin
          ? () => _showAdminOptions(listing, context)
          : null,
      onTap: () async {
        final bool? isListingDeleted = await push(
          context,
          ListingDetailsWrappingWidget(
            listing: listing,
            currentUser: widget.currentUser,
          ),
        );
        if (isListingDeleted == true && mounted) {
          context
              .read<HomeBloc>()
              .add(ListingDeletedByUserEvent(listing: listing));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(dark ? 0.3 : 0.05),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  displayImage(listing.photo),
                  if (listing.logo.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        height: 35,
                        width: 35,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: dark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: displayImage(listing.logo),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.read<HomeBloc>().add(
                              ListingFavUpdated(listing: listing),
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            listing.isFav
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: listing.isFav
                                ? Color(cfg.colorPrimary)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.categoryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Color(cfg.colorPrimary),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdminOptions(ListingModel listing, BuildContext blocContext) =>
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          message: Text(
            listing.title,
            style: const TextStyle(fontSize: 20.0),
          ),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: false,
              onPressed: () async {
                Navigator.pop(context);
                await push(
                  context,
                  EditListingWrappingWidget(
                    currentUser: widget.currentUser,
                    listingToEdit: listing,
                  ),
                );
              },
              child: Text('Edit Listing'.tr()),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.pop(context);
                final String title = 'Delete Listing?'.tr();
                final String content =
                    'Are you sure you want to remove this listing?'.tr();

                if (Platform.isIOS) {
                  await showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: Text(title),
                      content: Text(content),
                      actions: [
                        TextButton(
                          child: Text(
                            'Yes'.tr(),
                            style: const TextStyle(color: Colors.red),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            blocContext.read<LoadingCubit>().showLoading(
                                  context,
                                  'Deleting...'.tr(),
                                  false,
                                  Color(cfg.colorPrimary),
                                );
                            blocContext.read<HomeBloc>().add(
                                  ListingDeleteByAdminEvent(listing: listing),
                                );
                          },
                        ),
                        TextButton(
                          child: Text('No'.tr()),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                } else {
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(title),
                      content: Text(content),
                      actions: [
                        TextButton(
                          child: Text(
                            'Yes'.tr(),
                            style: const TextStyle(color: Colors.red),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            blocContext.read<LoadingCubit>().showLoading(
                                  context,
                                  'Deleting...'.tr(),
                                  false,
                                  Color(cfg.colorPrimary),
                                );
                            blocContext.read<HomeBloc>().add(
                                  ListingDeleteByAdminEvent(listing: listing),
                                );
                          },
                        ),
                        TextButton(
                          child: Text('No'.tr()),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Text('Delete Listing'.tr()),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: Text('Cancel'.tr()),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
}
