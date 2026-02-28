import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/pdf_service.dart';
import 'package:caribtap/listings/services/quote_service.dart';
import 'package:caribtap/listings/services/share_link_service.dart';
import 'package:caribtap/listings/services/tier_gate_service.dart';
import 'package:caribtap/listings/ui/pro_docs/cubit/quote_detail_cubit.dart';
import 'package:caribtap/listings/ui/pro_docs/invoice_builder_screen.dart';
import 'package:caribtap/listings/ui/pro_docs/quote_builder_screen.dart';
import 'package:caribtap/listings/ui/widgets/payment_methods_stream_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class QuoteDetailScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final String quoteId;

  const QuoteDetailScreen({
    super.key,
    required this.currentUser,
    required this.quoteId,
  });

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final PdfService _pdfService = PdfService();

  NumberFormat _currencyFor(QuoteModel quote) {
    final code = quote.currencyCode.isNotEmpty
        ? quote.currencyCode
        : NumberFormat.simpleCurrency().currencyName ?? 'USD';
    final symbol = quote.currencySymbol.isNotEmpty
        ? quote.currencySymbol
        : NumberFormat.simpleCurrency(name: code).currencySymbol;
    return NumberFormat.currency(name: code, symbol: symbol);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QuoteDetailCubit(
        quoteService: QuoteService(),
        uid: widget.currentUser.userID,
        quoteId: widget.quoteId,
      )..start(),
      child: BlocBuilder<QuoteDetailCubit, QuoteDetailState>(
        builder: (context, state) {
          if (state is QuoteDetailLoading) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (state is QuoteDetailError) {
            return Scaffold(
              appBar: AppBar(title: Text('Quote'.tr())),
              body: Center(child: Text(state.message)),
            );
          }

          final QuoteModel quote;
          if (state is QuoteDetailLoaded) {
            quote = state.quote;
          } else if (state is QuoteDetailWorking) {
            quote = state.quote;
          } else {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'Quote'.tr()),
              actions: [
                if (quote.status == 'draft')
                  IconButton(
                    onPressed: () {
                      push(
                        context,
                        QuoteBuilderScreen(
                          currentUser: widget.currentUser,
                          initialQuote: quote,
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_rounded),
                  ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusHeader(quote),
                const SizedBox(height: 12),
                _sectionTitle('Client'.tr()),
                _clientSection(quote),
                const SizedBox(height: 16),
                _sectionTitle('Items'.tr()),
                _itemsSection(quote, _currencyFor(quote)),
                const SizedBox(height: 16),
                _sectionTitle('Totals'.tr()),
                _totalsSection(quote, _currencyFor(quote)),
                const SizedBox(height: 16),
                PaymentMethodsStreamWidget(userId: widget.currentUser.userID),
                const SizedBox(height: 16),
                _sectionTitle('Dates'.tr()),
                _dateRow('Valid until'.tr(), _formatDate(quote.validUntil)),
                _dateRow('Sent'.tr(), _formatDate(quote.sentAt)),
                _dateRow('Accepted'.tr(), _formatDate(quote.acceptedAt)),
                _dateRow('Declined'.tr(), _formatDate(quote.declinedAt)),
                const SizedBox(height: 16),
                if (quote.notes.isNotEmpty) ...[
                  _sectionTitle('Notes'.tr()),
                  Text(quote.notes),
                  const SizedBox(height: 16),
                ],
                if (quote.terms.isNotEmpty) ...[
                  _sectionTitle('Terms'.tr()),
                  Text(quote.terms),
                  const SizedBox(height: 16),
                ],
              ],
            ),
            bottomNavigationBar: _actionBar(context, quote),
          );
        },
      ),
    );
  }

  Widget _statusHeader(QuoteModel quote) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'Quote'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        _statusChip(quote.status),
      ],
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

  Widget _clientSection(QuoteModel quote) {
    final client = quote.clientSnapshot;
    if (client == null) {
      return Text('No client selected'.tr());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(client.name.isNotEmpty ? client.name : 'Client'.tr()),
        if (client.companyName.isNotEmpty) Text(client.companyName),
        if (client.email.isNotEmpty) Text(client.email),
        if (client.phone.isNotEmpty) Text(client.phone),
        if (client.address.isNotEmpty) Text(client.address),
      ],
    );
  }

  Widget _itemsSection(QuoteModel quote, NumberFormat currency) {
    if (quote.items.isEmpty) {
      return Text('No items'.tr());
    }
    return Column(
      children: quote.items.map((item) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.description),
          subtitle: Text('${item.qty} x ${currency.format(item.unitPrice)}'),
          trailing: Text(currency.format(item.lineTotal)),
        );
      }).toList(),
    );
  }

  Widget _totalsSection(QuoteModel quote, NumberFormat currency) {
    return Column(
      children: [
        _totalRow('Subtotal'.tr(), currency.format(quote.subtotal)),
        if (quote.discount.applyTo(quote.subtotal) > 0)
          _totalRow('Discount'.tr(), '-${currency.format(quote.discount.applyTo(quote.subtotal))}'),
        if (quote.tax.applyTo(quote.subtotal) > 0)
          _totalRow('Tax'.tr(), currency.format(quote.tax.applyTo(quote.subtotal))),
        const Divider(),
        _totalRow('Total'.tr(), currency.format(quote.total), isBold: true),
      ],
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

  Widget _dateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context, QuoteModel quote) {
    final canSend = quote.items.isNotEmpty && quote.clientSnapshot?.name.isNotEmpty == true;
    final canAccept = quote.status == 'sent';
    final tier = TierGateService().resolveTierFromUser(widget.currentUser);
    final canUseInvoices = TierGateService().canUseInvoices(tier);
    final canConvert = canUseInvoices && quote.status == 'accepted';
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
                        if (quote.shareToken != null && quote.status == 'sent') {
                          await _shareToken(quote);
                        } else {
                          await context.read<QuoteDetailCubit>().sendQuote(quote);
                        }
                      }
                    : null,
                icon: const Icon(Icons.send_rounded),
                label: Text(quote.status == 'sent' ? 'Share Link'.tr() : 'Send & Share'.tr()),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: quote.items.isEmpty
                    ? null
                    : () => _shareQuotePdf(quote),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text('Generate PDF'.tr()),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: quote.items.isEmpty
                    ? null
                    : () => _downloadQuotePdf(quote),
                icon: const Icon(Icons.download_rounded),
                label: Text('Download PDF'.tr()),
              ),
            ),
            if (canConvert)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final invoice = await context.read<QuoteDetailCubit>().convertToInvoice(quote);
                    if (!mounted || invoice == null) return;
                    push(
                      context,
                      InvoiceBuilderScreen(
                        uid: widget.currentUser.userID,
                        invoice: invoice,
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text('Convert to Invoice'.tr()),
                ),
              ),
            if (canAccept)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<QuoteDetailCubit>().markAccepted(quote),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('Mark Accepted'.tr()),
                ),
              ),
            if (canAccept)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<QuoteDetailCubit>().markDeclined(quote),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text('Mark Declined'.tr()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('MMM d, y').format(value);
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft'.tr();
      case 'sent':
        return 'Sent'.tr();
      case 'accepted':
        return 'Accepted'.tr();
      case 'declined':
        return 'Declined'.tr();
      case 'expired':
        return 'Expired'.tr();
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'sent':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'expired':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _shareToken(QuoteModel quote) async {
    final token = quote.shareToken;
    if (token == null || token.isEmpty) return;
    final link = ShareLinkService().buildPublicDocLink(type: 'quote', token: token);
    await Share.share('Quote link: $link');
  }

  Future<void> _shareQuotePdf(QuoteModel quote) async {
    final tier = TierGateService().resolveTierFromUser(widget.currentUser);
    final canBrand = TierGateService().canUseBranding(tier);
    final businessName = canBrand ? _displayName(widget.currentUser) : null;
    await _pdfService.shareQuotePdf(
      quote,
      businessName: businessName,
      includeWatermark: !canBrand,
      hideFooter: canBrand,
    );
  }

  Future<void> _downloadQuotePdf(QuoteModel quote) async {
    try {
      final tier = TierGateService().resolveTierFromUser(widget.currentUser);
      final canBrand = TierGateService().canUseBranding(tier);
      final businessName = canBrand ? _displayName(widget.currentUser) : null;
      final path = await _pdfService.downloadQuotePdf(
        quote,
        businessName: businessName,
        includeWatermark: !canBrand,
        hideFooter: canBrand,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF downloaded to: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF: $e')),
      );
    }
  }

  String _displayName(ListingsUser user) {
    final name = '${user.firstName} ${user.lastName}'.trim();
    return name.isNotEmpty ? name : 'CaribTap Business';
  }
}
