import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:caribtap/listings/services/share_link_service.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/invoice_builder_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceBuilderScreen extends StatefulWidget {
  final String uid;
  final InvoiceModel invoice;

  const InvoiceBuilderScreen({
    super.key,
    required this.uid,
    required this.invoice,
  });

  @override
  State<InvoiceBuilderScreen> createState() => _InvoiceBuilderScreenState();
}

class _InvoiceBuilderScreenState extends State<InvoiceBuilderScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _companyRegistrationController = TextEditingController();
  final TextEditingController _vatNumberController = TextEditingController();
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.invoice.notes;
    _termsController.text = widget.invoice.terms;
    _companyRegistrationController.text = widget.invoice.listingContext?.companyRegistration ?? '';
    _vatNumberController.text = widget.invoice.listingContext?.vatNumber ?? '';
    _dueDate = widget.invoice.dueDate;
  }

  @override
  void dispose() {
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
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (!state.isSending && state.invoice?.status == 'sent') {
            _shareToken(state.invoice);
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
                _sectionTitle('Items'.tr()),
                ...invoice.items.map((item) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: Colors.white.withOpacity(0.95),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      title: Text(
                        item.description,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${item.qty} x ${currency.format(item.unitPrice)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: Text(
                        currency.format(item.lineTotal),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
                _sectionTitle('Due Date'.tr()),
                _datePickerRow(
                  context,
                  label: _dueDate == null
                      ? 'Select date'.tr()
                      : DateFormat('MMM d, y').format(_dueDate!),
                  onTap: () => _pickDueDate(context),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Notes'.tr()),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<InvoiceBuilderCubit>().updateNotes(value),
                  decoration: InputDecoration(
                    hintText: 'Optional notes'.tr(),
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Terms'.tr()),
                TextField(
                  controller: _termsController,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (value) => context.read<InvoiceBuilderCubit>().updateTerms(value),
                  decoration: InputDecoration(
                    hintText: 'Optional terms'.tr(),
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Company Information'.tr()),
                TextField(
                  controller: _companyRegistrationController,
                  decoration: InputDecoration(
                    labelText: 'Company Registration #'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Optional',
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefix: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.business, color: Colors.white70, size: 18)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => _updateListingContextFromFields(context),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vatNumberController,
                  decoration: InputDecoration(
                    labelText: 'VAT / Tax ID #'.tr(),
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Optional',
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefix: const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.receipt_long, color: Colors.white70, size: 18)),
                  ),
                  style: const TextStyle(color: Colors.white),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
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
            Text(label, style: const TextStyle(color: Colors.white)),
            const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.white70),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: const Color(0xFF2C2C2C),
              onSurface: Colors.white,
            ),
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

  Future<void> _shareToken(InvoiceModel? invoice) async {
    final token = invoice?.shareToken;
    if (token == null || token.isEmpty) return;
    final link = ShareLinkService().buildPublicDocLink(type: 'invoice', token: token);
    await Share.share('Invoice link: $link');
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
