import 'dart:async';

import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'invoice_list_state.dart';

class InvoiceListCubit extends Cubit<InvoiceListState> {
  final InvoiceService _invoiceService;
  final String _uid;

  StreamSubscription<List<InvoiceModel>>? _subscription;

  InvoiceListCubit({
    required InvoiceService invoiceService,
    required String uid,
  })  : _invoiceService = invoiceService,
        _uid = uid,
        super(const InvoiceListLoading());

  void start() {
    _subscription?.cancel();
    _subscription = _invoiceService.streamInvoices(_uid).listen(
      (invoices) {
        emit(InvoiceListLoaded(invoices: invoices));
      },
      onError: (error) {
        emit(const InvoiceListError(message: 'Failed to load invoices'));
      },
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
