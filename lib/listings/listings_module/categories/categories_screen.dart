import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/categories/categories_bloc.dart';
import 'package:caribtap/listings/listings_module/category_listings/category_listings_screen.dart';
import 'package:caribtap/listings/config/category_taxonomy.dart';

class CategoriesWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const CategoriesWrapperWidget({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CategoriesBloc(listingsRepository: listingApiManager),
      child: CategoriesScreen(currentUser: currentUser),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const CategoriesScreen({super.key, required this.currentUser});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late ListingsUser currentUser;
  bool isLoading = true;
  List<CategoriesModel> categories = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isOtherCategory(CategoriesModel category) {
    final slug = _normalize(category.slug);
    final title = _normalize(category.title);
    return slug == 'other' || title == 'other' || title == 'order';
  }

  bool _matchesCategory(CategoriesModel category, String query) {
    if (query.isEmpty) return true;
    final q = _normalize(query);

    final values = <String>[
      category.title,
      category.slug,
      ...category.synonyms,
      if (category.parentSlug != null) category.parentSlug!,
    ];

    return values.any((v) => _normalize(v).contains(q));
  }

  String _resolvePrimaryTitle(
    CategoriesModel category,
    Map<String, CategoriesModel> bySlug,
  ) {
    if (category.parentSlug != null && category.parentSlug!.isNotEmpty) {
      final parent = bySlug[category.parentSlug!];
      if (parent != null && parent.title.trim().isNotEmpty) {
        return parent.title;
      }

      for (final node in CategoryTaxonomy.primary) {
        if (node.slug == category.parentSlug) {
          return node.title;
        }
      }
    }

    // If parent is unknown, keep broad grouping clean.
    return 'All Categories';
  }

  CategoriesModel _preferDisplayCategory(
    CategoriesModel left,
    CategoriesModel right,
  ) {
    int score(CategoriesModel category) {
      var result = 0;
      if (category.parentSlug?.trim().isNotEmpty == true) {
        result += 8;
      }
      if (category.photo.trim().isNotEmpty) {
        result += 4;
      }
      if (category.synonyms.isNotEmpty) {
        result += 2;
      }
      if (category.sortOrder > 0) {
        result += 1;
      }
      return result;
    }

    final leftScore = score(left);
    final rightScore = score(right);
    if (rightScore != leftScore) {
      return rightScore > leftScore ? right : left;
    }

    if (right.sortOrder != left.sortOrder) {
      return right.sortOrder < left.sortOrder ? right : left;
    }

    return right.title.trim().length > left.title.trim().length ? right : left;
  }

  List<CategoriesModel> _sanitizeCategoriesForDisplay(
    List<CategoriesModel> list,
    Map<String, CategoriesModel> bySlug,
  ) {
    final dedupedByDisplayKey = <String, CategoriesModel>{};

    for (final category in list) {
      final groupTitle = _resolvePrimaryTitle(category, bySlug);
      final normalizedTitle = _normalize(category.title);
      if (normalizedTitle.isEmpty) continue;

      final parentSlug = category.parentSlug?.trim();
      if (parentSlug != null && parentSlug.isNotEmpty) {
        final parent = bySlug[parentSlug];
        if (parent != null && _normalize(parent.title) == normalizedTitle) {
          // Drop malformed child docs that duplicate their parent's display title.
          continue;
        }
      }

      final displayKey = '${_normalize(groupTitle)}::$normalizedTitle';
      final existing = dedupedByDisplayKey[displayKey];
      if (existing == null) {
        dedupedByDisplayKey[displayKey] = category;
      } else {
        dedupedByDisplayKey[displayKey] = _preferDisplayCategory(existing, category);
      }
    }

    return dedupedByDisplayKey.values.toList();
  }

  List<CategoriesModel> _prepareFlatCategories(List<CategoriesModel> list) {
    final bySlug = <String, CategoriesModel>{};
    for (final category in list) {
      final key = category.slug.trim();
      if (key.isNotEmpty) {
        bySlug[key] = category;
      }
    }

    final sanitized = _sanitizeCategoriesForDisplay(list, bySlug);
    sanitized.sort((a, b) {
      final aIsOther = _isOtherCategory(a);
      final bIsOther = _isOtherCategory(b);
      if (aIsOther != bIsOther) {
        return aIsOther ? 1 : -1;
      }

      final titleCompare = _normalize(a.title).compareTo(_normalize(b.title));
      if (titleCompare != 0) return titleCompare;

      return a.sortOrder.compareTo(b.sortOrder);
    });

    return sanitized;
  }

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    context.read<CategoriesBloc>().add(FetchCategoriesEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<CategoriesBloc>().add(LoadingEvent());
          context.read<CategoriesBloc>().add(FetchCategoriesEvent());
        },
        child: BlocConsumer<CategoriesBloc, CategoriesState>(
          listener: (context, state) {
            if (state is CategoriesFetchedState) {
              isLoading = false;
              categories = state.categoriesList;
            } else if (state is LoadingState) {
              isLoading = true;
            }
          },
          builder: (context, state) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }
            if (categories.isEmpty) {
              return Stack(
                children: [
                  ListView(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: showEmptyState(
                      'No Categories'.tr(),
                      'All Categories will show up here once added by the admin.'
                          .tr(),
                    ),
                  ),
                ],
              );
            } else {
              final filtered = categories
                  .where((c) => _matchesCategory(c, _searchQuery))
                  .toList();
              final displayCategories = _prepareFlatCategories(filtered);
              final mediaQuery = MediaQuery.of(context);
              final devicePixelRatio =
                  mediaQuery.devicePixelRatio.clamp(1.0, 2.0).toDouble();
              final tileWidth = mediaQuery.size.width - 24;
              final imageCacheWidth = (tileWidth * devicePixelRatio).round();
              final imageCacheHeight = (160 * devicePixelRatio).round();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 30, 12, 8),
                itemCount: displayCategories.isEmpty
                    ? 3
                    : displayCategories.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search categories'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }

                  if (index == 1) {
                    return const SizedBox(height: 12);
                  }

                  if (displayCategories.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: showEmptyState(
                        'No matching categories'.tr(),
                        'Try a different search term.'.tr(),
                      ),
                    );
                  }

                  final category = displayCategories[index - 2];
                  return CategoryTile(
                    currentUser: currentUser,
                    category: category,
                    memCacheWidth: imageCacheWidth,
                    memCacheHeight: imageCacheHeight,
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  final CategoriesModel category;
  final ListingsUser currentUser;
  final int memCacheWidth;
  final int memCacheHeight;

  const CategoryTile(
      {
        super.key,
        required this.category,
        required this.currentUser,
        required this.memCacheWidth,
        required this.memCacheHeight,
      });

  String _displayCategoryName(BuildContext context, String value) {
    final raw = value.trim();
    if (raw.isEmpty) return value;

    // Keep category labels faithful to Firebase data; only translate on exact key match.
    if (trExists(raw, context: context)) {
      return raw.tr(context: context);
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: () => push(
          context,
          CategoryListingsWrapperWidget(
            categoryID: category.id,
            categoryName: _displayCategoryName(context, category.title),
            currentUser: currentUser,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 160,
            child: CachedNetworkImage(
              imageUrl: category.photo,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,
              maxWidthDiskCache: memCacheWidth,
              maxHeightDiskCache: memCacheHeight,
              imageBuilder: (context, imageProvider) => Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.5),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        _displayCategoryName(context, category.title),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                alignment: Alignment.center,
                child: const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
