import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/ads/ads_utils.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
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

  bool _showAll = false;
  bool loadingCategories = true;
  bool loadingListings = true;

  late ListingsUser currentUser;
  
  // Search and filter variables
  String _searchQuery = '';
  List<String> _selectedCountryCodes = [];
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _searchController = TextEditingController();
    context.read<HomeBloc>().add(GetCategoriesEvent());
    context.read<HomeBloc>().add(GetListingsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ListingModel> _getFilteredListings() {
    return listings.where((listing) {
      // Filter by search query
      final matchesSearch = _searchQuery.isEmpty ||
          listing.title.toLowerCase().contains(_searchQuery) ||
          listing.description.toLowerCase().contains(_searchQuery) ||
          listing.place.toLowerCase().contains(_searchQuery);

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

  void _showCountrySelectionDialog(BuildContext context) {
    List<String> tempSelectedCountries = [..._selectedCountryCodes];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Select Countries (Max 5)'.tr(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: CaribbeanCountries.all.length,
                  itemBuilder: (context, index) {
                    final country = CaribbeanCountries.all[index];
                    final isSelected = tempSelectedCountries.contains(country.code);

                    return CheckboxListTile(
                      title: Text(country.name),
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
                      enabled: !isSelected || tempSelectedCountries.length < 5,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'.tr()),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(colorPrimary),
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<HomeBloc>().add(LoadingEvent());
          context.read<HomeBloc>().add(GetCategoriesEvent());
          context.read<HomeBloc>().add(GetListingsEvent());
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

            final bool dark = isDarkMode(context);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Text(
                      'Categories'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  if (loadingCategories)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator.adaptive()),
                      ),
                    ),

                  if (_categories.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: showEmptyState(
                          'No Categories'.tr(),
                          'All Categories will be shown here once added by the admin.'.tr(),
                        ),
                      ),
                    ),

                  if (_categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) => CategoryHomeCardWidget(
                            currentUser: currentUser,
                            category: _categories[index],
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  SliverToBoxAdapter(
                    child: Text(
                      'Listings'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search listings...'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                child: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(colorPrimary).withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(colorPrimary), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Country Filter Dropdown (Multi-select)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedCountryCodes.isNotEmpty) ...[
                          Text(
                            'Selected Countries (${_selectedCountryCodes.length}/5)'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _selectedCountryCodes.map((code) {
                              final country = CaribbeanCountries.all.firstWhere(
                                (c) => c.code == code,
                                orElse: () => CaribbeanCountry(code: code, name: code),
                              );
                              return Chip(
                                label: Text(country.name),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCountryCodes.remove(code);
                                  });
                                },
                                backgroundColor: Color(colorPrimary).withOpacity(0.2),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        GestureDetector(
                          onTap: () => _showCountrySelectionDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(colorPrimary).withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedCountryCodes.isEmpty
                                      ? 'Filter Countries'.tr()
                                      : '${_selectedCountryCodes.length} Selected'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: _selectedCountryCodes.isEmpty
                                        ? Color(colorPrimary)
                                        : (dark ? Colors.white : Colors.black),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(colorPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedCountryCodes.length >= 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Maximum 5 countries selected'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  if (loadingListings)
                    const SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    ),

                  if (!loadingListings)
                    Builder(
                      builder: (context) {
                        final filteredListingsWithAds = _getFilteredListingsWithAds();
                        if (filteredListingsWithAds.isEmpty && !loadingListings) {
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Center(
                                child: showEmptyState(
                                  'No Listings'.tr(),
                                  'No listings match your search or filter criteria.'.tr(),
                                  buttonTitle: 'Clear Filters'.tr(),
                                  isDarkMode: dark,
                                  action: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedCountryCodes = [];
                                      _searchController.clear();
                                    });
                                  },
                                  colorPrimary: Color(colorPrimary),
                                ),
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
                                  : ListingHomeCardWidget(
                                currentUser: currentUser,
                                listing: item,
                              );
                            },
                            childCount: filteredListingsWithAds.length > 4
                                ? (_showAll ? filteredListingsWithAds.length : 4)
                                : filteredListingsWithAds.length,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.72,
                          ),
                        );
                      },
                    ),

                  Builder(
                    builder: (context) {
                      final filteredListingsWithAds = _getFilteredListingsWithAds();
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 32),
                          child: Visibility(
                            visible: !_showAll && filteredListingsWithAds.length > 4,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  side: BorderSide(color: Color(colorPrimary)),
                                ),
                              ),
                              child: Text(
                                'Show All (${(filteredListingsWithAds.length - 4) < 0 ? 0 : filteredListingsWithAds.length - 4})'.tr(),
                                style: TextStyle(color: Color(colorPrimary)),
                              ),
                              onPressed: () => context.read<HomeBloc>().add(ToggleShowAllEvent()),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
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
      padding: const EdgeInsets.only(left: 2.0, right: 2),
      child: GestureDetector(
        onTap: () => push(
          context,
          CategoryListingsWrapperWidget(
            categoryID: category.id,
            categoryName: category.title,
            currentUser: currentUser,
          ),
        ),
        child: SizedBox(
          width: 120,
          height: 120,
          child: Card(
            color: dark ? Colors.grey.shade900 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide.none,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      child: displayImage(category.photo),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8),
                  child: Center(
                    child: Text(
                      category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(dark ? 0.35 : 0.10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  displayImage(listing.photo),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Text(
                        (listing.categoryTitle.isNotEmpty) ? listing.categoryTitle : 'Listing'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.read<HomeBloc>().add(
                          ListingFavUpdated(listing: listing),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.20)),
                          ),
                          child: Icon(
                            listing.isFav ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: listing.isFav ? Color(colorPrimary) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF1B1B1B),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: dark ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          listing.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Rating row + optional price (NO overflow)
                  Row(
                    children: [
                      RatingBar.builder(
                        ignoreGestures: true,
                        minRating: 0,
                        initialRating: safeRating,
                        allowHalfRating: true,
                        itemSize: 18,
                        glow: false,
                        unratedColor: Color(colorPrimary).withOpacity(0.18),
                        itemBuilder: (context, index) => Icon(
                          Icons.star,
                          color: Color(colorPrimary),
                        ),
                        itemCount: 5,
                        onRatingUpdate: (_) {},
                      ),
                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          '${safeRating > 0 ? safeRating.toStringAsFixed(1) : '0.0'} (${listing.reviewsCount})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),

                      if (listing.price.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 90, maxHeight: 28),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Color(colorPrimary).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Color(colorPrimary).withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              listing.price,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(colorPrimary),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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
                              Color(colorPrimary),
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
                              Color(colorPrimary),
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
