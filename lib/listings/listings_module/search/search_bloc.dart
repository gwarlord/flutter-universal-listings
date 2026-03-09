import 'package:bloc/bloc.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/listings_module/api/listings_repository.dart';
import 'package:caribtap/listings/utils/search_utils.dart';

abstract class SearchEvent {}

class GetListingsEvent extends SearchEvent {}

class LoadingEvent extends SearchEvent {}

class SearchListingsEvent extends SearchEvent {
  final String query;

  SearchListingsEvent({required this.query});
}

class ListingDeletedByUserEvent extends SearchEvent {
  ListingModel listing;

  ListingDeletedByUserEvent({required this.listing});
}

abstract class SearchState {}

class SearchInitial extends SearchState {}

class ListingsReadyState extends SearchState {
  List<ListingModel> listings;

  ListingsReadyState({required this.listings});
}

class ListingsFilteredState extends SearchState {
  List<ListingModel> filteredListings;

  ListingsFilteredState({required this.filteredListings});
}

class LoadingState extends SearchState {}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final ListingsRepository listingsRepository;
  final ListingsUser currentUser;

  List<ListingModel> listings = [];

  SearchBloc({
    required this.listingsRepository,
    required this.currentUser,
  }) : super(SearchInitial()) {
    on<GetListingsEvent>(_onGetListings);
    on<LoadingEvent>((event, emit) => emit(LoadingState()));
    on<SearchListingsEvent>(_onSearch);
    on<ListingDeletedByUserEvent>(_onDeleted);
  }

  Future<void> _onGetListings(
      GetListingsEvent event,
      Emitter<SearchState> emit,
      ) async {
    try {
      listings = await listingsRepository.getListings(
        favListingsIDs: currentUser.likedListingsIDs,
      );
      emit(ListingsReadyState(listings: listings));
    } catch (_) {
      listings = [];
      emit(ListingsReadyState(listings: listings));
    }
  }

  void _onSearch(
      SearchListingsEvent event,
      Emitter<SearchState> emit,
      ) {
    final query = event.query.trim().toLowerCase();

    if (query.isEmpty) {
      emit(ListingsReadyState(listings: listings));
      return;
    }

    final filtered = listings.where((l) {
      final haystack = SearchUtils.buildListingSearchString(l);
      return SearchUtils.fuzzyMatch(query, haystack);
    }).toList();

    emit(ListingsFilteredState(filteredListings: filtered));
  }

  void _onDeleted(
      ListingDeletedByUserEvent event,
      Emitter<SearchState> emit,
      ) {
    listings.removeWhere((e) => e.id == event.listing.id);
    emit(ListingsReadyState(listings: listings));
  }
}
