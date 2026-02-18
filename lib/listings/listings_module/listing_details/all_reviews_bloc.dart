import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';

part 'all_reviews_event.dart';
part 'all_reviews_state.dart';

class AllReviewsBloc extends Bloc<AllReviewsEvent, AllReviewsState> {
  final ListingsRepository listingsRepository;
  final String listingId;

  AllReviewsBloc({
    required this.listingsRepository,
    required this.listingId,
  }) : super(AllReviewsInitial()) {
    on<LoadInitialReviewsEvent>((event, emit) async {
      emit(AllReviewsLoading());
      try {
        final result = await listingsRepository.getReviewsPaged(
          listingID: listingId,
          limit: 20,
          descending: true,
        );
        emit(AllReviewsLoaded(
          reviews: result.reviews,
          hasMore: result.hasMore,
          cursorCreatedAt: result.nextCursorCreatedAt,
        ));
      } catch (e) {
        emit(AllReviewsError(error: e.toString()));
      }
    });

    on<LoadMoreReviewsEvent>((event, emit) async {
      if (state is AllReviewsLoaded) {
        final currentState = state as AllReviewsLoaded;
        if (!currentState.hasMore || currentState.isLoadingMore) return;

        emit(currentState.copyWith(isLoadingMore: true));

        try {
          final result = await listingsRepository.getReviewsPaged(
            listingID: listingId,
            limit: 20,
            startAfterCreatedAt: currentState.cursorCreatedAt,
            descending: true,
          );

          emit(AllReviewsLoaded(
            reviews: [...currentState.reviews, ...result.reviews],
            hasMore: result.hasMore,
            cursorCreatedAt: result.nextCursorCreatedAt,
            isLoadingMore: false,
          ));
        } catch (e) {
          emit(currentState.copyWith(
            isLoadingMore: false,
            error: e.toString(),
          ));
        }
      }
    });

    on<RefreshReviewsEvent>((event, emit) async {
      try {
        final result = await listingsRepository.getReviewsPaged(
          listingID: listingId,
          limit: 20,
          descending: true,
        );
        emit(AllReviewsLoaded(
          reviews: result.reviews,
          hasMore: result.hasMore,
          cursorCreatedAt: result.nextCursorCreatedAt,
        ));
      } catch (e) {
        emit(AllReviewsError(error: e.toString()));
      }
    });
  }
}
