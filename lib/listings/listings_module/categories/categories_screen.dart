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
              return ListView.builder(
                itemCount: categories.length,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                itemBuilder: (context, index) => CategoryTile(
                    currentUser: currentUser, category: categories[index]),
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

  const CategoryTile(
      {super.key, required this.category, required this.currentUser});

  String _localizedCategoryName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;

    final normalized = trimmed.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final titleCase = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');

    final normalizedLower = normalized.toLowerCase();
    final normalizedAlias = normalizedLower
        .replaceAll('&', ' and ')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final normalizedAliasCompact = normalizedAlias.replaceAll(' and ', ' ');

    const aliases = <String, String>{
      'food drink': 'Food & Drink',
      'food drinks': 'Food & Drink',
      'food beverage': 'Food & Drink',
      'food beverages': 'Food & Drink',
      'food and beverage': 'Food & Drink',
      'food and beverages': 'Food & Drink',
      'restaurants': 'Restaurants',
      'restaurant': 'Restaurant',
      'realestate': 'Real Estate',
      'real estate': 'Real Estate',
      'automobile': 'Automotive',
      'auto': 'Auto',
      'automotive': 'Automotive',
      'health beauty': 'Health & Beauty',
      'health and beauty': 'Health & Beauty',
      'beauty spa': 'Beauty & Spa',
      'beauty and spa': 'Beauty & Spa',
      'home service': 'Home Services',
      'home services': 'Home Services',
      'professional service': 'Professional Service',
      'professional services': 'Professional Services',
      'travel tourism': 'Travel & Tourism',
      'travel and tourism': 'Travel & Tourism',
      'home garden': 'Home & Garden',
      'home and garden': 'Home & Garden',
      'retail stores': 'Shopping',
      'retail and stores': 'Shopping',
      'construction': 'Home Services',
      'construction handyman services': 'Home Services',
      'construction and handyman services': 'Home Services',
      'handyman services': 'Home Services',
      'personal service': 'Professional Service',
      'personal services': 'Professional Services',
    };

    final aliasKey = aliases[normalizedLower] ??
        aliases[normalizedAlias] ??
        aliases[normalizedAliasCompact];
    if (aliasKey != null) {
      final aliasTranslated = aliasKey.tr();
      if (aliasTranslated != aliasKey) return aliasTranslated;
    }

    final keywordSource = normalizedAliasCompact
        .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final keywordHaystack = ' $keywordSource ';
    bool hasWord(String word) => keywordHaystack.contains(' $word ');
    bool hasAny(List<String> words) => words.any(hasWord);

    String? canonicalKey;
    if (hasAny(['restaurant', 'restaurants'])) {
      canonicalKey = 'Restaurants';
    } else if (hasWord('real') && hasWord('estate') || hasAny(['property', 'properties', 'realtor'])) {
      canonicalKey = 'Real Estate';
    } else if (hasAny(['retail', 'shop', 'shopping', 'store', 'stores', 'market', 'boutique'])) {
      canonicalKey = 'Shopping';
    } else if (hasAny([
      'construction',
      'handyman',
      'contractor',
      'repair',
      'plumbing',
      'electric',
      'cleaning',
      'maintenance',
      'renovation',
      'home',
      'services'
    ])) {
      canonicalKey = 'Home Services';
    } else if (hasAny(['professional', 'consulting', 'accounting', 'legal', 'agency']) ||
        ((hasWord('personal') || hasWord('concierge')) && hasAny(['service', 'services']))) {
      canonicalKey = 'Professional Services';
    } else if (hasAny(['nightlife', 'club', 'clubs', 'bar', 'bars'])) {
      canonicalKey = 'Nightlife';
    } else if (hasAny(['food', 'beverage', 'drink', 'drinks', 'dining', 'cafe', 'bakery'])) {
      canonicalKey = 'Food & Drink';
    } else if (hasAny(['auto', 'automotive', 'car', 'cars', 'vehicle', 'vehicles', 'mechanic'])) {
      canonicalKey = 'Automotive';
    } else if (hasAny(['beauty', 'spa', 'salon', 'cosmetic'])) {
      canonicalKey = 'Beauty & Spa';
    } else if (hasAny(['health', 'fitness', 'gym', 'wellness'])) {
      canonicalKey = 'Health & Fitness';
    } else if (hasAny(['electronics', 'tech', 'technology', 'computer', 'mobile', 'phone'])) {
      canonicalKey = 'Electronics';
    } else if (hasAny(['event', 'events'])) {
      canonicalKey = 'Events';
    } else if (hasAny(['entertainment', 'music', 'movie', 'cinema'])) {
      canonicalKey = 'Entertainment';
    } else if (hasAny(['education', 'school', 'tutor', 'training'])) {
      canonicalKey = 'Education';
    } else if (hasAny(['travel', 'tourism', 'tour', 'vacation'])) {
      canonicalKey = 'Travel & Tourism';
    } else if (hasAny(['pet', 'pets', 'veterinary', 'vet'])) {
      canonicalKey = 'Pets';
    } else if (hasAny(['sport', 'sports', 'athletic'])) {
      canonicalKey = 'Sports';
    } else if (hasAny(['accommodation', 'hotel', 'hostel', 'lodging'])) {
      canonicalKey = 'Accommodation';
    } else if (hasAny(['home', 'garden'])) {
      canonicalKey = 'Home & Garden';
    }

    if (canonicalKey != null) {
      final canonicalTranslated = canonicalKey.tr();
      if (canonicalTranslated != canonicalKey) return canonicalTranslated;
    }

    final candidates = <String>[
      trimmed,
      normalized,
      titleCase,
      normalizedLower,
      normalized.toUpperCase(),
    ];

    for (final key in candidates) {
      final translated = key.tr();
      if (translated != key) return translated;
    }

    return normalized;
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
            categoryName: _localizedCategoryName(category.title),
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
                        _localizedCategoryName(category.title),
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
