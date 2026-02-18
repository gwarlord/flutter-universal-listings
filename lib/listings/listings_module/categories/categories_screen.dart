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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: GestureDetector(
        onTap: () => push(
          context,
          CategoryListingsWrapperWidget(
            categoryID: category.id,
            categoryName: category.title,
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
                        category.title,
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
