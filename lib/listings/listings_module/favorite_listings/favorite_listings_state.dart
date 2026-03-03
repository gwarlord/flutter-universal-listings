part of 'favorite_listings_bloc.dart';

abstract class FavoriteListingsState {}

class FavoriteListingsInitial extends FavoriteListingsState {}

class FavoriteListingsReadyState extends FavoriteListingsState {
  List<ListingModel> favorites;
  List<EventModel> favoriteEvents;

  FavoriteListingsReadyState({
    required this.favorites,
    required this.favoriteEvents,
  });
}

class ListingFavToggleState extends FavoriteListingsState {
  ListingModel listing;
  ListingsUser updatedUser;

  ListingFavToggleState({required this.listing, required this.updatedUser});
}

class EventFavToggleState extends FavoriteListingsState {
  EventModel event;
  ListingsUser updatedUser;

  EventFavToggleState({required this.event, required this.updatedUser});
}

class LoadingState extends FavoriteListingsState {}
