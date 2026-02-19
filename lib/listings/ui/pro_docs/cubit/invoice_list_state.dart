part of 'invoice_list_cubit.dart';

abstract class InvoiceListState {
  const InvoiceListState();
}

class InvoiceListLoading extends InvoiceListState {
  const InvoiceListLoading();
}

class InvoiceListLoaded extends InvoiceListState {
  final List<InvoiceModel> invoices;

  const InvoiceListLoaded({required this.invoices});
}

class InvoiceListError extends InvoiceListState {
  final String message;

  const InvoiceListError({required this.message});
}
