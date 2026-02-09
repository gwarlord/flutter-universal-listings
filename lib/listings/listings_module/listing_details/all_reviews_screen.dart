import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/listing_details/all_reviews_bloc.dart';

class AllReviewsScreen extends StatefulWidget {
  final String listingId;
  final String? listingTitle;

  const AllReviewsScreen({
    Key? key,
    required this.listingId,
    this.listingTitle,
  }) : super(key: key);

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<AllReviewsBloc>().add(LoadMoreReviewsEvent());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return BlocProvider(
      create: (context) => AllReviewsBloc(
        listingsRepository: listingApiManager,
        listingId: widget.listingId,
      )..add(LoadInitialReviewsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Reviews'.tr()),
          backgroundColor: isDark ? Colors.black : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 1,
        ),
        body: BlocBuilder<AllReviewsBloc, AllReviewsState>(
          builder: (context, state) {
            if (state is AllReviewsLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            if (state is AllReviewsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load reviews'.tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.error,
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.read<AllReviewsBloc>().add(RefreshReviewsEvent());
                      },
                      child: Text('Retry'.tr()),
                    ),
                  ],
                ),
              );
            }

            if (state is AllReviewsLoaded) {
              if (state.reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No reviews yet'.tr(),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<AllReviewsBloc>().add(RefreshReviewsEvent());
                  // Wait for the refresh to complete
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.reviews.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (context, index) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    if (index >= state.reviews.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }

                    final review = state.reviews[index];
                    return ReviewWidget(review: review);
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class ReviewWidget extends StatelessWidget {
  final ListingReviewModel review;

  const ReviewWidget({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (review.profilePictureURL.isNotEmpty)
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(review.profilePictureURL),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                child: Text(
                  review.firstName.isNotEmpty ? review.firstName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                review.fullName(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(
                DateTime.fromMillisecondsSinceEpoch(review.createdAt * 1000),
              ),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RatingBarIndicator(
          rating: review.starCount.toDouble(),
          itemBuilder: (context, index) => const Icon(
            Icons.star,
            color: Colors.amber,
          ),
          itemCount: 5,
          itemSize: 20.0,
          direction: Axis.horizontal,
        ),
        const SizedBox(height: 8),
        Text(
          review.content,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}
