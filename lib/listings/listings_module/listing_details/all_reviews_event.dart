part of 'all_reviews_bloc.dart';

abstract class AllReviewsEvent {}

class LoadInitialReviewsEvent extends AllReviewsEvent {}

class LoadMoreReviewsEvent extends AllReviewsEvent {}

class RefreshReviewsEvent extends AllReviewsEvent {}
