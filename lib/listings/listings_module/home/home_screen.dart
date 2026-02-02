import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/ads/ads_utils.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/category_listings/category_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/home/home_bloc.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:instaflutter/listings/model/categories_model.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:instaflutter/listings/utils/caribbean_countries.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../ui/deals/deals_feed_screen.dart';

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
  List<ListingModel?> listingsWithAds = [];
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

  // Cycling controllers
  late ScrollController _categoryScrollController;
  late ScrollController _dealsScrollController;
  Timer? _categoryCycleTimer;
  Timer? _dealsCycleTimer;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _searchController = TextEditingController();
    _categoryScrollController = ScrollController();
    _dealsScrollController = ScrollController();
    context.read<HomeBloc>().add(GetCategoriesEvent());
    context.read<HomeBloc>().add(GetListingsEvent());
    _loadFeaturedListings();
    _loadDeals();
    _startCategoryCycling();
    _startDealsCycling();
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
        double nextOffset = _dealsScrollController.offset + 192.0; // 180 width + 12 margin

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
          final targetedAds = ads.where((ad) => ad.visibilityCountries.contains(userCountry)).toList()..shuffle();
          
          // 2. Global Ads (visible to everyone)
          final globalAds = ads.where((ad) => ad.visibilityCountries.isEmpty).toList()..shuffle();
          
          // 3. Other Targeted Ads (fallback)
          final otherAds = ads.where((ad) => ad.visibilityCountries.isNotEmpty && !ad.visibilityCountries.contains(userCountry)).toList()..shuffle();

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
    _categoryScrollController.dispose();
    _dealsScrollController.dispose();
    _categoryCycleTimer?.cancel();
    _dealsCycleTimer?.cancel();
    super.dispose();
  }

  List<ListingModel> _getFilteredListings() {
    return listings.where((listing) {
      // Filter by search query
      final matchesSearch = _searchQuery.isEmpty ||
          listing.title.toLowerCase().contains(_searchQuery) ||
          listing.description.toLowerCase().contains(_searchQuery) ||
          listing.place.toLowerCase().contains(_searchQuery) ||
          listing.services.any((service) => 
            service.name.toLowerCase().contains(_searchQuery) ||
            service.duration.toLowerCase().contains(_searchQuery));

      // Filter by country (if countries are selected, listing must be in that list)
      final matchesCountry = _selectedCountryCodes.isEmpty ||
          _selectedCountryCodes.contains(listing.countryCode);

      return matchesSearch && matchesCountry;
    }).toList();
  }

  List<ListingModel?> _getFilteredListingsWithAds() {
    final filtered = _getFilteredListings();
    final result = <ListingModel?>[];
    
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
                color: isDark ? Colors.white : Colors.black87,
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
    List<String> tempSelectedCountries = [..._selectedCountryCodes];

    final sortedCountries = CaribbeanCountries.all.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = isDarkMode(context);
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Select Countries (Max 5)'.tr(),
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sortedCountries.length,
                  itemBuilder: (context, index) {
                    final country = sortedCountries[index];
                    final isSelected = tempSelectedCountries.contains(country.code);

                    return Theme(
                      data: ThemeData(
                        unselectedWidgetColor: isDark ? Colors.white70 : Colors.black54,
                      ),
                      child: CheckboxListTile(
                        title: Text(
                          country.name,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        ),
                        activeColor: Color(cfg.colorPrimary), 
                        checkColor: Colors.white,
                        value: isSelected,
                        onChanged: (bool? newValue) {
                          setDialogState(() {
                            if (newValue == true && tempSelectedCountries.length < 5) {
                              tempSelectedCountries.add(country.code);
                            } else if (newValue == false) {
                              tempSelectedCountries.remove(country.code);
                            }
                          });
                        },
                        enabled: isSelected || tempSelectedCountries.length < 5,
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
                    backgroundColor: Color(cfg.colorPrimary), 
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedCountryCodes = tempSelectedCountries;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Save'.tr(),
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

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.grey[50],
      body: RefreshIndicator(
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
              final tempList = [...listingsWithAds]..removeWhere((e) => e == null);
              listings = [...tempList.cast<ListingModel>()];
            } else if (state is LoadingCategoriesState) {
              loadingCategories = true;
            } else if (state is LoadingListingsState) {
              loadingListings = true;
            } else if (state is ToggleShowAllState) {
              _showAll = !_showAll;
            } else if (state is ListingFavToggleState) {
              currentUser = state.updatedUser;
              context.read<AuthenticationBloc>().user = state.updatedUser;

              final idx = listings.indexWhere((e) => e.id == state.listing.id);
              if (idx != -1) {
                listings[idx].isFav = state.listing.isFav;
              }
              final idx2 = listingsWithAds.indexWhere((e) => e?.id == state.listing.id);
              if (idx2 != -1) {
                listingsWithAds[idx2]?.isFav = state.listing.isFav;
              }
            } else if (state is LoadingState) {
              _showAll = false;
              loadingListings = true;
              loadingCategories = true;
            }
          },
          builder: (context, state) {
            if (loadingCategories && loadingListings) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  
                  // 1. Deals & Promotions Section
                  if (_dealAds.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: _buildSectionHeader(
                                title: 'Deals & Promotions'.tr(),
                                onSeeAll: () => push(context, DealsFeedScreen(currentUser: currentUser)),
                                isDark: dark,
                              ),
                            ),
                            SizedBox(
                              height: 150,
                              child: ListView.builder(
                                controller: _dealsScrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: _dealAds.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemBuilder: (context, index) {
                                  final ad = _dealAds[index];
                                  return DealAdCarouselItem(ad: ad, index: index, isDark: dark, currentUser: currentUser);
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
                      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildSectionHeader(title: 'Categories'.tr(), isDark: dark),
                          ),
                          if (loadingCategories)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator.adaptive()),
                            )
                          else if (_categories.isEmpty)
                            showEmptyState(
                              'No Categories'.tr(),
                              'All Categories will be shown here here once added by the admin.'.tr(),
                            )
                          else
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                controller: _categoryScrollController,
                                scrollDirection: Axis.horizontal,
                                itemCount: _categories.length,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                itemBuilder: (context, index) => CategoryHomeCardWidget(
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
                            style: TextStyle(color: dark ? Colors.white : Colors.black),
                            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'Search listings...'.tr(),
                              hintStyle: TextStyle(color: dark ? Colors.grey[400] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.search, color: dark ? Colors.grey[400] : Colors.grey[600]),
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
                              fillColor: dark ? Colors.black : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showCountrySelectionDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: dark ? Colors.black : Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(cfg.colorPrimary).withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCountryCodes.isEmpty
                                          ? 'Filter by Country'.tr()
                                          : '${_selectedCountryCodes.length} Countries Selected'.tr(),
                                      style: TextStyle(
                                        color: _selectedCountryCodes.isEmpty ? Colors.grey : (dark ? Colors.white : Colors.black),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.tune, color: Color(cfg.colorPrimary), size: 20),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedCountryCodes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _selectedCountryCodes.map((code) {
                                final country = CaribbeanCountries.all.firstWhere(
                                  (c) => c.code == code,
                                  orElse: () => CaribbeanCountry(code: code, name: code),
                                );
                                return Chip(
                                  label: Text(country.name, style: const TextStyle(fontSize: 12)),
                                  onDeleted: () => setState(() => _selectedCountryCodes.remove(code)),
                                  backgroundColor: Color(cfg.colorPrimary).withOpacity(0.1),
                                  deleteIconColor: Color(cfg.colorPrimary),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // 4. Featured Listings Section
                  if (_featuredListings.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(title: 'Featured Listings'.tr(), isDark: dark),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        height: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Color(cfg.colorPrimary).withOpacity(dark ? 0.05 : 0.03),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          itemCount: _featuredListings.length,
                          itemBuilder: (context, index) {
                            final listing = _featuredListings[index];
                            return _buildFeaturedCard(listing, dark);
                          },
                        ),
                      ),
                    ),
                  ],

                  // 5. Main Listings Grid
                  SliverToBoxAdapter(
                    child: _buildSectionHeader(title: 'All Listings'.tr(), isDark: dark),
                  ),
                  
                  if (loadingListings)
                    const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator.adaptive()))
                  else
                    Builder(
                      builder: (context) {
                        final filteredListingsWithAds = _getFilteredListingsWithAds();
                        if (filteredListingsWithAds.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
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
                              return item == null
                                  ? AdsUtils.adsContainer()
                                  : ListingHomeCardWidget(currentUser: currentUser, listing: item);
                            },
                            childCount: filteredListingsWithAds.length > 4
                                ? (_showAll ? filteredListingsWithAds.length : 4)
                                : filteredListingsWithAds.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.64, // Increased height
                          ),
                        );
                      },
                    ),

                  // Show All Button
                  Builder(
                    builder: (context) {
                      final filteredListingsWithAds = _getFilteredListingsWithAds();
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Visibility(
                            visible: !_showAll && filteredListingsWithAds.length > 4,
                            child: Center(
                              child: SizedBox(
                                width: 200,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: Color(cfg.colorPrimary)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    'Show All'.tr() + ' (${filteredListingsWithAds.length - 4})',
                                    style: TextStyle(color: Color(cfg.colorPrimary), fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => context.read<HomeBloc>().add(ToggleShowAllEvent()),
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
    );
  }

  Widget _buildFeaturedCard(ListingModel listing, bool dark) {
    return GestureDetector(
      onTap: () => push(context, ListingDetailsWrappingWidget(listing: listing, currentUser: currentUser)),
      child: Container(
        width: 200,
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    listing.photo,
                    height: 130,
                    width: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                      height: 130, width: 200, color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: const Icon(Icons.star, size: 12, color: Colors.white),
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
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.categoryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(cfg.colorPrimary), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    if (widget.ad.mediaType == 'video' && (widget.ad.thumbnailUrl == null || widget.ad.thumbnailUrl!.isEmpty)) {
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
    final thumbUrl = (ad.mediaType == 'image' ? ad.mediaUrl : ad.thumbnailUrl) ?? '';

    return GestureDetector(
      onTap: () => push(context, DealsFeedScreen(initialIndex: widget.index, currentUser: widget.currentUser)),
      child: Container(
        width: 180,
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
                Image.network(thumbUrl, fit: BoxFit.cover)
              else if (_generatedThumbnail != null)
                Image.memory(_generatedThumbnail!, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.black87,
                  child: const Center(child: Icon(Icons.videocam, color: Colors.white24, size: 40)),
                ),

              // Overlay Elements
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ),

              if (ad.mediaType == 'video')
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36)),

              Positioned(
                bottom: 8,
                left: 10,
                right: 10,
                child: Text(
                  ad.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(cfg.colorPrimary),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ad.adType.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => push(
          context,
          CategoryListingsWrapperWidget(
            categoryID: category.id,
            categoryName: category.title,
            currentUser: currentUser,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? Colors.grey[900] : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipOval(
                child: displayImage(category.photo),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 80,
              child: Text(
                category.title,
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
      return AdsUtils.adsContainer();
    }

    final bool dark = isDarkMode(context);

    final double avgRating =
    (listing.reviewsCount > 0) ? (listing.reviewsSum / listing.reviewsCount) : 0.0;
    final double safeRating = avgRating.isFinite ? avgRating : 0.0;

    return GestureDetector(
      onLongPress: widget.currentUser.isAdmin ? () => _showAdminOptions(listing, context) : null,
      onTap: () async {
        final bool? isListingDeleted = await push(
          context,
          ListingDetailsWrappingWidget(
            listing: listing,
            currentUser: widget.currentUser,
          ),
        );
        if (isListingDeleted == true && mounted) {
          context.read<HomeBloc>().add(ListingDeletedByUserEvent(listing: listing));
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
                            listing.isFav ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: listing.isFav ? Color(cfg.colorPrimary) : Colors.white,
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
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    listing.categoryTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(cfg.colorPrimary), fontSize: 10, fontWeight: FontWeight.bold),
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
                final String content = 'Are you sure you want to remove this listing?'.tr();

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
