import 'package:bloc/bloc.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/listings_module/api/listings_repository.dart';

part 'search_event.dart';
part 'search_state.dart';

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
      // Drop-in safe: do NOT emit a state your app doesn't define.
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
      final haystack = _buildSearchText(l);
      return haystack.contains(query);
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

  String _buildSearchText(ListingModel l) {
    // Build a single searchable string. Keep it defensive (null-safe).
    final b = StringBuffer();

    b.writeln(l.title);
    b.writeln(l.place);
    b.writeln(l.description);
    b.writeln(l.categoryTitle);
    b.writeln(l.price);

    // Optional fields: only include if they exist on your model.
    // If your ListingModel has these, they will compile and be included.
    // If not, remove the lines that don't exist.
    try {
      // ignore: unnecessary_statements
      l.phone;
      b.writeln(l.phone);
    } catch (_) {}
    try {
      // ignore: unnecessary_statements
      l.email;
      b.writeln(l.email);
    } catch (_) {}
    try {
      // ignore: unnecessary_statements
      l.website;
      b.writeln(l.website);
    } catch (_) {}
    try {
      // ignore: unnecessary_statements
      l.openingHours;
      b.writeln(l.openingHours);
    } catch (_) {}

    // filters: include keys & values if present
    try {
      final f = l.filters;
      if (f != null) {
        f.forEach((k, v) {
          b.writeln(k);
          b.writeln(v);
        });
      }
    } catch (_) {}

    return b.toString().toLowerCase();
  }
}
