part of 'invoice_builder_cubit.dart';

class InvoiceBuilderState {
  final InvoiceModel? invoice;
  final bool isSaving;
  final bool isSending;
  final String? errorMessage;

  InvoiceBuilderState({
    required this.invoice,
    this.isSaving = false,
    this.isSending = false,
    this.errorMessage,
  });

  InvoiceBuilderState copyWith({
    InvoiceModel? invoice,
    bool? isSaving,
    bool? isSending,
    String? errorMessage,
  }) {
    return InvoiceBuilderState(
      invoice: invoice ?? this.invoice,
      isSaving: isSaving ?? this.isSaving,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}
