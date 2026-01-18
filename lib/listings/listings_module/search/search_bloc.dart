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
      return _fuzzyMatch(query, haystack);
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

    // services: include name, duration, price for searchability
    if (l.services.isNotEmpty) {
      for (final s in l.services) {
        b.writeln(s.name);
        b.writeln(s.duration);
        b.writeln(s.price);
      }
    }

    return b.toString().toLowerCase();
  }

  bool _fuzzyMatch(String query, String text) {
    if (query.isEmpty) return true;
    if (text.contains(query)) return true;
    // Basic typo tolerance against tokens
    final tokens = text.split(RegExp(r'[\s,.;:]+'));
    for (final token in tokens) {
      if (token.isEmpty) continue;
      if (_levenshtein(token, query) <= 1) return true;
    }
    return false;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    List<int> prev = List<int>.generate(n + 1, (j) => j);
    for (int i = 1; i <= m; i++) {
      List<int> curr = List<int>.filled(n + 1, 0);
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = _min3(
          curr[j - 1] + 1, // insertion
          prev[j] + 1, // deletion
          prev[j - 1] + cost, // substitution
        );
      }
      prev = curr;
    }
    return prev[n];
  }

  int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);
}
