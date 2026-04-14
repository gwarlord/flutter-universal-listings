import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:caribtap/listings/services/pdf_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/invoice_builder_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class InvoiceBuilderScreen extends StatefulWidget {
  final String uid;
  final InvoiceModel invoice;
  final ListingsUser currentUser;

  const InvoiceBuilderScreen({
    super.key,
    required this.uid,
    required this.invoice,
    required this.currentUser,
  });

  @override
  State<InvoiceBuilderScreen> createState() => _InvoiceBuilderScreenState();
}

class _InvoiceBuilderScreenState extends State<InvoiceBuilderScreen> {
  final PdfService _pdfService = PdfService();
  final PaymentDetailsService _paymentDetailsService = PaymentDetailsService();
  final TextEditingController _poNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _companyRegistrationController = TextEditingController();
  final TextEditingController _vatNumberController = TextEditingController();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _poNumberController.text = widget.invoice.poNumber;
    _notesController.text = widget.invoice.notes;
    _termsController.text = widget.invoice.terms;
    _companyRegistrationController.text = widget.invoice.listingContext?.companyRegistration ?? '';
    _vatNumberController.text = widget.invoice.listingContext?.vatNumber ?? '';
    _dueDate = widget.invoice.dueDate;
  }

  @override
  void dispose() {
    _poNumberController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    _companyRegistrationController.dispose();
    _vatNumberController.dispose();
    super.dispose();
  }

  NumberFormat _currencyFormatter(InvoiceModel invoice) {
    final code = invoice.currencyCode.isNotEmpty
        ? invoice.currencyCode
        : defaultCurrencyCode();
    final symbol = invoice.currencySymbol.isNotEmpty
        ? invoice.currencySymbol
        : defaultCurrencySymbol(code);
    return NumberFormat.currency(name: code, symbol: symbol);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoiceBuilderCubit(
        invoiceService: InvoiceService(),
        uid: widget.uid,
        initialInvoice: widget.invoice,
      ),
      child: BlocConsumer<InvoiceBuilderCubit, InvoiceBuilderState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!.tr())),
            );
          }
          if (!state.isSending && state.invoice?.status == 'sent') {
            _shareInvoicePdf(state.invoice!);
          }
        },
        builder: (context, state) {
          final invoice = state.invoice;
          if (invoice == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final currency = _currencyFormatter(invoice);
          return Scaffold(
            appBar: AppBar(title: Text('Invoice'.tr())),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _sectionTitle(context, 'Items'.tr()),
                ...invoice.items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      title: Text(
                        item.description,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${item.qty} x ${currency.format(item.unitPrice)}',
                      ),
                      trailing: Text(
                        currency.format(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Due Date'.tr()),
                _datePickerRow(
                  context,
                  label: _dueDate == null
                      ? 'Select date'.tr()
                      : DateFormat('MMM d, y').format(_dueDate!),
                  onTap: () => _pickDueDate(context),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'PO Number'.tr()),
                TextField(
                  controller: _poNumberController,
                  onChanged: (value) => context.read<InvoiceBuilderCubit>().updatePoNumber(value),
                  decoration: InputDecoration(
                    hintText: 'Client purchase order number'.tr(),
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Notes'.tr()),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<InvoiceBuilderCubit>().updateNotes(value),
                  decoration: InputDecoration(
                    hintText: 'Optional notes'.tr(),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Terms'.tr()),
                TextField(
                  controller: _termsController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<InvoiceBuilderCubit>().updateTerms(value),
                  decoration: InputDecoration(
                    hintText: 'Optional terms'.tr(),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(context, 'Company Information'.tr()),
                TextField(
                  controller: _companyRegistrationController,
                  decoration: InputDecoration(
                    labelText: 'Company Registration #'.tr(),
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    hintText: 'Optional'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefix: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.business, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 18)),
                  ),
                  onChanged: (_) => _updateListingContextFromFields(context),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vatNumberController,
                  decoration: InputDecoration(
                    labelText: 'VAT / Tax ID #'.tr(),
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    hintText: 'Optional'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefix: Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 18)),
                  ),
                  onChanged: (_) => _updateListingContextFromFields(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
            bottomNavigationBar: _actionBar(context, state),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _datePickerRow(BuildContext context, {required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            Icon(Icons.calendar_today_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(BuildContext context, InvoiceBuilderState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: state.isSaving
                    ? null
                    : () => context.read<InvoiceBuilderCubit>().saveDraft(),
                child: state.isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Save Draft'.tr()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: state.isSending
                    ? null
                    : () => context.read<InvoiceBuilderCubit>().sendInvoice(),
                child: state.isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Send & Share'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
      context.read<InvoiceBuilderCubit>().updateDueDate(picked);
    }
  }

  Future<PaymentDetailsPublic?> _getPaymentDetails() async {
    try {
      final details = await _paymentDetailsService.getPublic(widget.currentUser.userID);
      return details.hasAnyPaymentMethod ? details : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareInvoicePdf(InvoiceModel invoice) async {
    final tier = TierGateService().resolveTierFromUser(widget.currentUser);
    final canBrand = TierGateService().canUseBranding(tier);
    final businessName = canBrand ? _displayName(widget.currentUser) : null;
    final paymentDetails = await _getPaymentDetails();
    await _pdfService.shareInvoicePdf(
      invoice,
      businessName: businessName,
      includeWatermark: !canBrand,
      hideFooter: canBrand,
      paymentDetails: paymentDetails,
    );
  }

  String _displayName(ListingsUser user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : 'CaribTap Business'.tr();
  }

  void _updateListingContextFromFields(BuildContext context) {
    final currentInvoice = context.read<InvoiceBuilderCubit>().state.invoice;
    if (currentInvoice?.listingContext != null) {
      final updatedContext = currentInvoice!.listingContext!.copyWith(
        companyRegistration: _companyRegistrationController.text.trim(),
        vatNumber: _vatNumberController.text.trim(),
      );
      context.read<InvoiceBuilderCubit>().updateListingContext(updatedContext);
    }
  }
}
