import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'invoice_builder_state.dart';

class InvoiceBuilderCubit extends Cubit<InvoiceBuilderState> {
  final InvoiceService _invoiceService;
  final String _uid;

  InvoiceBuilderCubit({
    required InvoiceService invoiceService,
    required String uid,
    InvoiceModel? initialInvoice,
  })  : _invoiceService = invoiceService,
        _uid = uid,
        super(InvoiceBuilderState(invoice: initialInvoice));

  void updateNotes(String value) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(notes: value)));
  }

  void updateTerms(String value) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(terms: value)));
  }

  void updatePoNumber(String value) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(poNumber: value)));
  }

  void updateDueDate(DateTime? date) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(dueDate: date)));
  }

  void updateListingContext(dynamic context) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(listingContext: context)));
  }

  void updateCurrencyCode(String code) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(currencyCode: code)));
  }

  void updateCurrencySymbol(String symbol) {
    emit(state.copyWith(invoice: state.invoice?.copyWith(currencySymbol: symbol)));
  }

  Future<void> saveDraft() async {
    final invoice = state.invoice;
    if (invoice == null) return;
    try {
      emit(state.copyWith(isSaving: true, errorMessage: null));
      final saved = await _invoiceService.saveDraft(_uid, invoice);
      emit(state.copyWith(isSaving: false, invoice: saved));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: 'Failed to save invoice'));
    }
  }

  Future<void> sendInvoice() async {
    final invoice = state.invoice;
    if (invoice == null) return;
    try {
      emit(state.copyWith(isSending: true, errorMessage: null));
      InvoiceModel current = invoice;
      if (current.id.isEmpty) {
        current = await _invoiceService.saveDraft(_uid, current);
      }
      final updated = await _invoiceService.markSent(
        _uid,
        current,
        shareExpiry: const Duration(days: 30),
      );
      emit(state.copyWith(isSending: false, invoice: updated));
    } catch (e) {
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<void> markPaid() async {
    final invoice = state.invoice;
    if (invoice == null) return;
    try {
      emit(state.copyWith(isSaving: true, errorMessage: null));
      final updated = await _invoiceService.markPaid(_uid, invoice);
      emit(state.copyWith(isSaving: false, invoice: updated));
    } catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: 'Failed to mark paid'));
    }
  }
}
