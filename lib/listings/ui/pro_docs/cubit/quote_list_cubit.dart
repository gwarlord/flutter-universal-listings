import 'dart:async';

import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'quote_list_state.dart';

class QuoteListCubit extends Cubit<QuoteListState> {
  final QuoteService _quoteService;
  final TierGateService _tierGateService;
  final ListingsUser _currentUser;

  StreamSubscription<List<QuoteModel>>? _subscription;

  QuoteListCubit({
    required QuoteService quoteService,
    required TierGateService tierGateService,
    required ListingsUser currentUser,
  })  : _quoteService = quoteService,
        _tierGateService = tierGateService,
        _currentUser = currentUser,
        super(const QuoteListLoading());

  void start() {
    final tier = _tierGateService.resolveTierFromUser(_currentUser);
    if (!_tierGateService.canUseQuotes(tier)) {
      emit(const QuoteListLocked(message: 'Upgrade to Professional to use Quotes'));
      return;
    }

    final limit = _tierGateService.quoteHistoryLimit(tier);
    _subscription?.cancel();
    _subscription = _quoteService.streamQuotes(_currentUser.userID, limit: limit).listen(
      (quotes) {
        final limitReached = limit != null && quotes.length >= limit;
        emit(QuoteListLoaded(
          quotes: quotes,
          tier: tier,
          canUseInvoices: _tierGateService.canUseInvoices(tier),
          limit: limit,
          limitReached: limitReached,
        ));
      },
      onError: (error) {
        emit(QuoteListError(message: 'Failed to load quotes'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
