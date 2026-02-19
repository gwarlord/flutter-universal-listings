import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/invoice_service.dart';
import 'package:caribtap/listings/services/pdf_service.dart';
import 'package:caribtap/listings/services/share_link_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/invoice_detail_cubit.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String uid;
  final String invoiceId;
  final ListingsUser currentUser;

  const InvoiceDetailScreen({
    super.key,
    required this.uid,
    required this.invoiceId,
    required this.currentUser,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final NumberFormat _currency = NumberFormat.simpleCurrency();
  final PdfService _pdfService = PdfService();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoiceDetailCubit(
        invoiceService: InvoiceService(),
        uid: widget.uid,
        invoiceId: widget.invoiceId,
      )..start(),
      child: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
        builder: (context, state) {
          if (state is InvoiceDetailLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (state is InvoiceDetailError) {
            return Scaffold(
              appBar: AppBar(title: Text('Invoice'.tr())),
              body: Center(child: Text(state.message)),
            );
          }

          final InvoiceModel invoice;
          if (state is InvoiceDetailLoaded) {
            invoice = state.invoice;
          } else if (state is InvoiceDetailWorking) {
            invoice = state.invoice;
          } else {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            appBar: AppBar(title: Text(invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'Invoice'.tr())),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Items'.tr()),
                ...invoice.items.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.description),
                    subtitle: Text('${item.qty} x ${_currency.format(item.unitPrice)}'),
                    trailing: Text(_currency.format(item.lineTotal)),
                  );
                }).toList(),
                const SizedBox(height: 16),
                _sectionTitle('Totals'.tr()),
                _totalRow('Subtotal'.tr(), _currency.format(invoice.subtotal)),
                if (invoice.discount.applyTo(invoice.subtotal) > 0)
                  _totalRow('Discount'.tr(), '-${_currency.format(invoice.discount.applyTo(invoice.subtotal))}'),
                if (invoice.tax.applyTo(invoice.subtotal) > 0)
                  _totalRow('Tax'.tr(), _currency.format(invoice.tax.applyTo(invoice.subtotal))),
                const Divider(),
                _totalRow('Total'.tr(), _currency.format(invoice.total), isBold: true),
                const SizedBox(height: 16),
                if (invoice.notes.isNotEmpty) ...[
                  _sectionTitle('Notes'.tr()),
                  Text(invoice.notes),
                  const SizedBox(height: 16),
                ],
                if (invoice.terms.isNotEmpty) ...[
                  _sectionTitle('Terms'.tr()),
                  Text(invoice.terms),
                  const SizedBox(height: 16),
                ],
              ],
            ),
            bottomNavigationBar: _actionBar(context, invoice),
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
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }

  Widget _actionBar(BuildContext context, InvoiceModel invoice) {
    final canSend = invoice.items.isNotEmpty && invoice.clientSnapshot?.name.isNotEmpty == true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canSend
                    ? () async {
                        if (invoice.shareToken != null && invoice.status == 'sent') {
                          await _shareToken(invoice);
                        } else {
                          await context.read<InvoiceDetailCubit>().sendInvoice(invoice);
                        }
                      }
                    : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(invoice.status == 'sent' ? 'Share Link'.tr() : 'Send & Share'.tr()),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: invoice.items.isEmpty
                    ? null
                    : () => _shareInvoicePdf(invoice),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text('Generate PDF'.tr()),
              ),
            ),
            if (invoice.status != 'paid')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<InvoiceDetailCubit>().markPaid(invoice),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('Mark Paid'.tr()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToken(InvoiceModel invoice) async {
    final token = invoice.shareToken;
    if (token == null || token.isEmpty) return;
    final link = ShareLinkService().buildPublicDocLink(type: 'invoice', token: token);
    await Share.share('Invoice link: $link');
  }

  Future<void> _shareInvoicePdf(InvoiceModel invoice) async {
    final tier = TierGateService().resolveTierFromUser(widget.currentUser);
    final canBrand = TierGateService().canUseBranding(tier);
    final businessName = canBrand ? _displayName(widget.currentUser) : null;
    await _pdfService.shareInvoicePdf(
      invoice,
      businessName: businessName,
      includeWatermark: !canBrand,
      hideFooter: canBrand,
    );
  }

  String _displayName(ListingsUser user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : 'CaribTap Business';
  }
}
