part of 'all_reviews_bloc.dart';

abstract class AllReviewsState {}

class AllReviewsInitial extends AllReviewsState {}

class AllReviewsLoading extends AllReviewsState {}

class AllReviewsLoaded extends AllReviewsState {
  final List<ListingReviewModel> reviews;
  final bool hasMore;
  final int? cursorCreatedAt;
  final bool isLoadingMore;
  final String? error;

  AllReviewsLoaded({
    required this.reviews,
    required this.hasMore,
    this.cursorCreatedAt,
    this.isLoadingMore = false,
    this.error,
  });

  AllReviewsLoaded copyWith({
    List<ListingReviewModel>? reviews,
    bool? hasMore,
    int? cursorCreatedAt,
    bool? isLoadingMore,
    String? error,
  }) {
    return AllReviewsLoaded(
      reviews: reviews ?? this.reviews,
      hasMore: hasMore ?? this.hasMore,
      cursorCreatedAt: cursorCreatedAt ?? this.cursorCreatedAt,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
    );
  }
}

class AllReviewsError extends AllReviewsState {
  final String error;

  AllReviewsError({required this.error});
}
