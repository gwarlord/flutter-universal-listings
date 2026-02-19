import 'dart:async';

import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'quote_detail_state.dart';

class QuoteDetailCubit extends Cubit<QuoteDetailState> {
  final QuoteService _quoteService;
  final String _uid;
  final String _quoteId;

  StreamSubscription<QuoteModel?>? _subscription;

  QuoteDetailCubit({
    required QuoteService quoteService,
    required String uid,
    required String quoteId,
  })  : _quoteService = quoteService,
        _uid = uid,
        _quoteId = quoteId,
        super(const QuoteDetailLoading());

  void start() {
    _subscription?.cancel();
    _subscription = _quoteService.streamQuote(_uid, _quoteId).listen((quote) {
      if (quote == null) {
        emit(const QuoteDetailError(message: 'Quote not found'));
      } else {
        emit(QuoteDetailLoaded(quote: quote));
      }
    }, onError: (error) {
      emit(const QuoteDetailError(message: 'Failed to load quote'));
    });
  }

  Future<void> markAccepted(QuoteModel quote) async {
    emit(QuoteDetailWorking(quote: quote));
    try {
      await _quoteService.markAccepted(_uid, quote);
    } catch (e) {
      emit(const QuoteDetailError(message: 'Failed to mark accepted'));
    }
  }

  Future<void> markDeclined(QuoteModel quote) async {
    emit(QuoteDetailWorking(quote: quote));
    try {
      await _quoteService.markDeclined(_uid, quote);
    } catch (e) {
      emit(const QuoteDetailError(message: 'Failed to mark declined'));
    }
  }

  Future<void> sendQuote(QuoteModel quote) async {
    emit(QuoteDetailWorking(quote: quote));
    try {
      await _quoteService.markSent(_uid, quote, shareExpiry: const Duration(days: 30));
    } catch (e) {
      emit(QuoteDetailError(message: e.toString()));
    }
  }

  Future<InvoiceModel?> convertToInvoice(QuoteModel quote) async {
    emit(QuoteDetailWorking(quote: quote));
    try {
      final invoice = await _quoteService.convertToInvoice(_uid, quote);
      emit(QuoteDetailLoaded(quote: quote));
      return invoice;
    } catch (e) {
      emit(const QuoteDetailError(message: 'Failed to convert to invoice'));
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
