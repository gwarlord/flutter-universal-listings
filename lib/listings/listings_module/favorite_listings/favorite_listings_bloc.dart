import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/api/firebase/events_firebase.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/ui/profile/api/profile_repository.dart';

part 'favorite_listings_event.dart';

part 'favorite_listings_state.dart';

class FavoriteListingsBloc
    extends Bloc<FavoriteListingsEvent, FavoriteListingsState> {
  final ListingsRepository listingsRepository;
  final EventsFirebaseUtils eventsRepository;
  final ListingsUser currentUser;
  final ProfileRepository profileRepository;
  List<ListingModel> favorites = [];
  List<EventModel> favoriteEvents = [];

  FavoriteListingsBloc({
    required this.listingsRepository,
    required this.currentUser,
    required this.profileRepository,
    EventsFirebaseUtils? eventsRepository,
  })  : eventsRepository = eventsRepository ?? EventsFirebaseUtils(),
        super(FavoriteListingsInitial()) {
    on<GetMyFavoriteListings>((event, emit) async {
      favorites = await listingsRepository.getFavoriteListings(
          favListingsIDs: currentUser.likedListingsIDs);
      favoriteEvents = await this.eventsRepository.getFavoriteEvents(
          eventIds: currentUser.likedEventsIDs);
      emit(FavoriteListingsReadyState(
        favorites: favorites,
        favoriteEvents: favoriteEvents,
      ));
    });
    on<ListingFavUpdated>((event, emit) async {
      event.listing.isFav = !event.listing.isFav;
      favorites.firstWhere((element) => element.id == event.listing.id).isFav =
          event.listing.isFav;
      if (event.listing.isFav) {
        currentUser.likedListingsIDs.add(event.listing.id);
      } else {
        currentUser.likedListingsIDs.remove(event.listing.id);
      }
      await profileRepository.updateCurrentUser(currentUser);
      emit(ListingFavToggleState(
        listing: event.listing,
        updatedUser: currentUser,
      ));
    });
    on<ListingDeletedByUserEvent>((event, emit) {
      favorites.remove(event.listing);
      emit(FavoriteListingsReadyState(
        favorites: favorites,
        favoriteEvents: favoriteEvents,
      ));
    });
    on<EventFavUpdated>((event, emit) async {
      event.event.isFav = !event.event.isFav;

      final matchIndex =
          favoriteEvents.indexWhere((element) => element.id == event.event.id);
      if (matchIndex != -1) {
        favoriteEvents[matchIndex].isFav = event.event.isFav;
      }

      if (event.event.isFav) {
        if (!currentUser.likedEventsIDs.contains(event.event.id)) {
          currentUser.likedEventsIDs.add(event.event.id);
        }
      } else {
        currentUser.likedEventsIDs.remove(event.event.id);
        favoriteEvents.removeWhere((element) => element.id == event.event.id);
      }

      await profileRepository.updateCurrentUser(currentUser);
      emit(EventFavToggleState(
        event: event.event,
        updatedUser: currentUser,
      ));
    });
    on<LoadingEvent>((event, emit) => emit(LoadingState()));
  }
}
