part of 'quote_detail_cubit.dart';

abstract class QuoteDetailState {
  const QuoteDetailState();
}

class QuoteDetailLoading extends QuoteDetailState {
  const QuoteDetailLoading();
}

class QuoteDetailLoaded extends QuoteDetailState {
  final QuoteModel quote;

  const QuoteDetailLoaded({required this.quote});
}

class QuoteDetailWorking extends QuoteDetailState {
  final QuoteModel quote;

  const QuoteDetailWorking({required this.quote});
}

class QuoteDetailError extends QuoteDetailState {
  final String message;

  const QuoteDetailError({required this.message});
}
