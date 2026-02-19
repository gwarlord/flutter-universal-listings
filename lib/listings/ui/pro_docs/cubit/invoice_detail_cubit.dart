import 'dart:async';

import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'invoice_detail_state.dart';

class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final InvoiceService _invoiceService;
  final String _uid;
  final String _invoiceId;

  StreamSubscription<InvoiceModel?>? _subscription;

  InvoiceDetailCubit({
    required InvoiceService invoiceService,
    required String uid,
    required String invoiceId,
  })  : _invoiceService = invoiceService,
        _uid = uid,
        _invoiceId = invoiceId,
        super(const InvoiceDetailLoading());

  void start() {
    _subscription?.cancel();
    _subscription = _invoiceService.streamInvoice(_uid, _invoiceId).listen(
      (invoice) {
        if (invoice == null) {
          emit(const InvoiceDetailError(message: 'Invoice not found'));
        } else {
          emit(InvoiceDetailLoaded(invoice: invoice));
        }
      },
      onError: (error) {
        emit(const InvoiceDetailError(message: 'Failed to load invoice'));
      },
    );
  }

  Future<void> markPaid(InvoiceModel invoice) async {
    emit(InvoiceDetailWorking(invoice: invoice));
    try {
      await _invoiceService.markPaid(_uid, invoice);
    } catch (e) {
      emit(const InvoiceDetailError(message: 'Failed to mark paid'));
    }
  }

  Future<void> sendInvoice(InvoiceModel invoice) async {
    emit(InvoiceDetailWorking(invoice: invoice));
    try {
      await _invoiceService.markSent(_uid, invoice, shareExpiry: const Duration(days: 30));
    } catch (e) {
      emit(InvoiceDetailError(message: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
