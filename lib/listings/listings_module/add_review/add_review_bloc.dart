import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/services/listing_activity_service.dart';

part 'add_review_event.dart';

part 'add_review_state.dart';

class AddReviewBloc extends Bloc<AddReviewEvent, AddReviewState> {
  final ListingsRepository listingsRepository;

  AddReviewBloc({required this.listingsRepository})
      : super(AddReviewInitial()) {
    on<PostReviewEvent>((event, emit) async {
      await listingsRepository.postReview(reviewModel: event.reviewModel);
      
      // Record activity for listing freshness tracking
      try {
        final activityService = ListingActivityService();
        await activityService.recordReview(
          event.reviewModel.listingID,
          event.reviewModel.authorID,
          event.reviewModel.starCount,
        );
      } catch (e) {
        // Log but don't fail the review if activity tracking fails
        print('Activity tracking error: $e');
      }
      
      emit(PostReviewSuccessState());
    });
  }
}
