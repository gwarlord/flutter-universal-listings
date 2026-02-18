import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';

part 'add_review_event.dart';

part 'add_review_state.dart';

class AddReviewBloc extends Bloc<AddReviewEvent, AddReviewState> {
  final ListingsRepository listingsRepository;

  AddReviewBloc({required this.listingsRepository})
      : super(AddReviewInitial()) {
    on<PostReviewEvent>((event, emit) async {
      await listingsRepository.postReview(reviewModel: event.reviewModel);
      emit(PostReviewSuccessState());
    });
  }
}
