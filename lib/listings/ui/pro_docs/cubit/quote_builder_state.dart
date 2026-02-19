part of 'quote_builder_cubit.dart';

class QuoteBuilderState {
  final QuoteModel quote;
  final bool isSaving;
  final bool isSending;
  final String? errorMessage;
  final ProTier tier;

  QuoteBuilderState({
    required this.quote,
    required this.tier,
    this.isSaving = false,
    this.isSending = false,
    this.errorMessage,
  });

  QuoteBuilderState copyWith({
    QuoteModel? quote,
    bool? isSaving,
    bool? isSending,
    String? errorMessage,
    ProTier? tier,
  }) {
    return QuoteBuilderState(
      quote: quote ?? this.quote,
      tier: tier ?? this.tier,
      isSaving: isSaving ?? this.isSaving,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}
