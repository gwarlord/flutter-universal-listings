import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'quote_builder_state.dart';

class QuoteBuilderCubit extends Cubit<QuoteBuilderState> {
  final QuoteService _quoteService;
  final TierGateService _tierGateService;
  final ListingsUser _currentUser;

  QuoteBuilderCubit({
    required QuoteService quoteService,
    required TierGateService tierGateService,
    required ListingsUser currentUser,
    QuoteModel? initialQuote,
  })  : _quoteService = quoteService,
        _tierGateService = tierGateService,
        _currentUser = currentUser,
        super(
          QuoteBuilderState(
            quote: initialQuote ?? QuoteModel.draft(createdByUid: currentUser.userID),
            tier: tierGateService.resolveTierFromUser(currentUser),
          ),
        );

  void updateClient(ClientSnapshot snapshot, {String? clientId}) {
    emit(state.copyWith(
      quote: state.quote.copyWith(clientSnapshot: snapshot, clientId: clientId),
    ));
  }

  void updateNotes(String value) {
    emit(state.copyWith(quote: state.quote.copyWith(notes: value)));
  }

  void updateTerms(String value) {
    emit(state.copyWith(quote: state.quote.copyWith(terms: value)));
  }

  void updateValidUntil(DateTime? date) {
    emit(state.copyWith(quote: state.quote.copyWith(validUntil: date)));
  }

  void updateCurrencyCode(String code) {
    emit(state.copyWith(quote: state.quote.copyWith(currencyCode: code)));
  }

  void updateCurrencySymbol(String symbol) {
    emit(state.copyWith(quote: state.quote.copyWith(currencySymbol: symbol)));
  }

  void updateListingContext(ListingContext? context) {
    emit(state.copyWith(quote: state.quote.copyWith(listingContext: context)));
  }

  void addItem(ProDocLineItem item) {
    final items = List<ProDocLineItem>.from(state.quote.items)..add(item);
    _emitWithTotals(items: items);
  }

  void removeItem(int index) {
    final items = List<ProDocLineItem>.from(state.quote.items)..removeAt(index);
    _emitWithTotals(items: items);
  }

  void updateDiscount(AdjustmentType type, double value) {
    _emitWithTotals(discount: ProDocAdjustment(type: type, value: value));
  }

  void updateTax(AdjustmentType type, double value) {
    _emitWithTotals(tax: ProDocAdjustment(type: type, value: value));
  }

  Future<void> saveDraft() async {
    try {
      emit(state.copyWith(isSaving: true, errorMessage: null));
      final saved = await _quoteService.saveDraft(_currentUser.userID, state.quote);
      emit(state.copyWith(isSaving: false, quote: saved));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: 'Failed to save quote'));
    }
  }

  Future<void> sendQuote() async {
    try {
      emit(state.copyWith(isSending: true, errorMessage: null));
      QuoteModel current = state.quote;
      if (current.id.isEmpty) {
        current = await _quoteService.saveDraft(_currentUser.userID, current);
      }
      final updated = await _quoteService.markSent(
        _currentUser.userID,
        current,
        shareExpiry: const Duration(days: 30),
      );
      emit(state.copyWith(isSending: false, quote: updated));
    } catch (e) {
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  void _emitWithTotals({
    List<ProDocLineItem>? items,
    ProDocAdjustment? discount,
    ProDocAdjustment? tax,
  }) {
    final updated = state.quote.copyWith(
      items: items ?? state.quote.items,
      discount: discount ?? state.quote.discount,
      tax: tax ?? state.quote.tax,
    );
    emit(state.copyWith(quote: _quoteService.computeTotals(updated)));
  }
}
