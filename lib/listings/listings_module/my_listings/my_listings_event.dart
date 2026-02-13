part of 'my_listings_bloc.dart';

abstract class MyListingsEvent {}

class GetMyListingsEvent extends MyListingsEvent {}

class ListingFavUpdated extends MyListingsEvent {
  ListingModel listing;

  ListingFavUpdated({required this.listing});
}

class ListingDeletedByUserEvent extends MyListingsEvent {
  ListingModel listing;

  ListingDeletedByUserEvent({required this.listing});
}

class ListingHiddenToggled extends MyListingsEvent {
  ListingModel listing;
  bool setHidden;

  ListingHiddenToggled({required this.listing, required this.setHidden});
}

class LoadingEvent extends MyListingsEvent {}
