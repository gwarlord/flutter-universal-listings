part of 'invoice_detail_cubit.dart';

abstract class InvoiceDetailState {
  const InvoiceDetailState();
}

class InvoiceDetailLoading extends InvoiceDetailState {
  const InvoiceDetailLoading();
}

class InvoiceDetailLoaded extends InvoiceDetailState {
  final InvoiceModel invoice;

  const InvoiceDetailLoaded({required this.invoice});
}

class InvoiceDetailWorking extends InvoiceDetailState {
  final InvoiceModel invoice;

  const InvoiceDetailWorking({required this.invoice});
}

class InvoiceDetailError extends InvoiceDetailState {
  final String message;

  const InvoiceDetailError({required this.message});
}
