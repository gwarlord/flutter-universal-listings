import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/core/utils/ads/ads_utils.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/category_listings/category_listings_bloc.dart';
import 'package:instaflutter/listings/listings_module/filters/filters_screen.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:instaflutter/listings/listings_module/map_view/map_view_screen.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

class CategoryListingsWrapperWidget extends StatelessWidget {
  final String categoryID;
  final String categoryName;
  final ListingsUser currentUser;

  const CategoryListingsWrapperWidget({
    super.key,
    required this.categoryID,
    required this.categoryName,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoryListingsBloc(
        listingsRepository: listingApiManager,
        currentUser: currentUser,
        categoryID: categoryID,
      ),
      child: CategoryListingsScreen(
        currentUser: currentUser,
        categoryID: categoryID,
        categoryName: categoryName,
      ),
    );
  }
}

class CategoryListingsScreen extends StatefulWidget {
  final String categoryID;
  final String categoryName;
  final ListingsUser currentUser;

  const CategoryListingsScreen({
    super.key,
    required this.categoryID,
    required this.categoryName,
    required this.currentUser,
  });

  @override
  State<CategoryListingsScreen> createState() => _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  List<ListingModel> _list = [];
  Map<String, String>? _filters = {};
  late ListingsUser currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;

    // Initial fetch
    context.read<CategoryListingsBloc>().add(GetListingsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(colorPrimary),
        tooltip: 'Filter'.tr(),
        onPressed: () async {
          _filters = await showModalBottomSheet<Map<String, String>?>(
            isScrollControlled: true,
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => FilterWrappingWidget(filtersValue: _filters),
          );

          _filters ??= {};
        },
        child: Icon(
          Icons.filter_list,
          color: isDarkMode(context) ? Colors.black : Colors.white,
        ),
      ),
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              // Ensure categoryTitle is populated for map view if needed
              if (_list.isNotEmpty && _list.first.categoryTitle.isEmpty) {
                _list.first.categoryTitle = widget.categoryName;
              }

              push(
                context,
                MapViewScreen(
                  listings: _list,
                  fromHome: false,
                  currentUser: currentUser,
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<CategoryListingsBloc>().add(LoadingEvent());
          context.read<CategoryListingsBloc>().add(GetListingsEvent());
        },
        child: BlocConsumer<CategoryListingsBloc, CategoryListingsState>(
          listener: (context, state) {
            if (state is ListingsReadyState) {
              isLoading = false;
              _list = state.listings;
            } else if (state is LoadingState) {
              isLoading = true;
            }
          },
          builder: (context, state) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (_list.isEmpty) {
              return Stack(
                children: [
                  ListView(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 16, 16, 120),
                    child: showEmptyState(
                      'No Listing'.tr(),
                      'Add a new listing to show up here once approved.'.tr(),
                      buttonTitle: 'Add Listing'.tr(),
                      isDarkMode: isDarkMode(context),
                      action: () => push(
                        context,
                        AddListingWrappingWidget(currentUser: currentUser),
                      ),
                      colorPrimary: Color(colorPrimary),
                    ),
                  ),
                ],
              );
            }

            return SafeArea(
              minimum: const EdgeInsets.only(bottom: 50),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 60),
                itemCount: _list.length,
                separatorBuilder: (context, index) {
                  return index == 0
                      ? const SizedBox.shrink()
                      : (index + 1) % 4 == 0
                      ? AdsUtils.adsContainer()
                      : const SizedBox.shrink();
                },
                itemBuilder: (context, index) {
                  return ListingRowWidget(
                    listing: _list[index],
                    currentUser: currentUser,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class ListingRowWidget extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const ListingRowWidget({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<ListingRowWidget> createState() => _ListingRowWidgetState();
}

class _ListingRowWidgetState extends State<ListingRowWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () async {
            final bool? isListingDeleted = await push(
              context,
              ListingDetailsWrappingWidget(
                listing: widget.listing,
                currentUser: widget.currentUser,
              ),
            );

            if (isListingDeleted == true) {
              if (!mounted) return;
              context.read<CategoryListingsBloc>().add(
                ListingDeletedEvent(listing: widget.listing),
              );
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 5,
                child: displayImage(widget.listing.photo),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.listing.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode(context)
                              ? Colors.grey[300]
                              : const Color(0xFF464646),
                        ),
                      ),
                      Text(
                        'Added on ${formatReviewTimestamp(widget.listing.createdAt)}'
                            .tr(),
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                widget.listing.place,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Text(
                              widget.listing.price,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode(context)
                                    ? Colors.grey[300]
                                    : const Color(0xFF464646),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
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
Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
