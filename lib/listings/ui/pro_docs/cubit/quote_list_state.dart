part of 'quote_list_cubit.dart';

abstract class QuoteListState {
  const QuoteListState();
}

class QuoteListLoading extends QuoteListState {
  const QuoteListLoading();
}

class QuoteListLocked extends QuoteListState {
  final String message;

  const QuoteListLocked({required this.message});
}

class QuoteListLoaded extends QuoteListState {
  final List<QuoteModel> quotes;
  final ProTier tier;
  final bool canUseInvoices;
  final int? limit;
  final bool limitReached;

  const QuoteListLoaded({
    required this.quotes,
    required this.tier,
    required this.canUseInvoices,
    required this.limit,
    required this.limitReached,
  });
}

class QuoteListError extends QuoteListState {
  final String message;

  const QuoteListError({required this.message});
}
