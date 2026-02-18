import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/ui/profile/api/profile_repository.dart';

part 'listing_details_event.dart';

part 'listing_details_state.dart';

class ListingDetailsBloc
    extends Bloc<ListingDetailsEvent, ListingDetailsState> {
  final ListingsRepository listingsRepository;
  final ProfileRepository profileRepository;
  final ListingsUser currentUser;
  final ListingModel listing;

  ListingDetailsBloc({
    required this.listing,
    required this.listingsRepository,
    required this.currentUser,
    required this.profileRepository,
  }) : super(ListingDetailsInitial()) {
    on<GetListingReviewsEvent>((event, emit) async {
      // Fetch only a limited number of reviews (5) for the details page
      final pagedResult = await listingsRepository.getReviewsPaged(
        listingID: listing.id,
        limit: 5,
        descending: true,
      );
      emit(ReviewsFetchedState(reviews: pagedResult.reviews));
    });
    on<ListingFavUpdatedEvent>((event, emit) async {
      listing.isFav = !listing.isFav;
      if (listing.isFav) {
        currentUser.likedListingsIDs.add(listing.id);
      } else {
        currentUser.likedListingsIDs.remove(listing.id);
      }
      await profileRepository.updateCurrentUser(currentUser);
      emit(ListingFavToggleState(
        listing: listing,
        updatedUser: currentUser,
      ));
    });
    on<DeleteListingEvent>((event, emit) async {
      await listingsRepository.deleteListing(listingModel: listing);
      emit(DeletedListingState());
    });
    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }
}
