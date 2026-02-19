import 'dart:io';
import 'dart:typed_data';

import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {

  Future<Uint8List> buildQuotePdf(
    QuoteModel quote, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final doc = pw.Document();
    final client = quote.clientSnapshot;
    final listing = quote.listingContext;
    final currency = _currencyFor(code: quote.currencyCode, symbol: quote.currencySymbol);
    final logo = await _loadLogo(listing?.listingLogoUrl);
    final headerName = (listing?.listingTitle?.isNotEmpty ?? false)
        ? listing!.listingTitle!
        : (businessName ?? 'CaribTap Business');
    final contactLines = <String>[];
    if (listing?.listingPhone != null && listing!.listingPhone!.isNotEmpty) {
      contactLines.add(listing.listingPhone!);
    }
    if (listing?.listingEmail != null && listing!.listingEmail!.isNotEmpty) {
      contactLines.add(listing.listingEmail!);
    }
    if (listing?.listingAddress != null && listing!.listingAddress!.isNotEmpty) {
      contactLines.add(listing.listingAddress!);
    }
    if (listing?.companyRegistration != null && listing!.companyRegistration!.isNotEmpty) {
      contactLines.add('Reg: ${listing.companyRegistration!}');
    }
    if (listing?.vatNumber != null && listing!.vatNumber!.isNotEmpty) {
      contactLines.add('VAT: ${listing.vatNumber!}');
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        pageTheme: includeWatermark ? _watermarkTheme('CaribTap') : null,
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 40,
                        height: 40,
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: pw.Image(logo, fit: pw.BoxFit.cover),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          headerName,
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                        ),
                        for (final line in contactLines)
                          pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Quote', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(quote.quoteNumber.isNotEmpty ? quote.quoteNumber : '-', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Client', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (client != null) ...[
              pw.Text(client.name),
              if (client.companyName.isNotEmpty) pw.Text(client.companyName),
              if (client.email.isNotEmpty) pw.Text(client.email),
              if (client.phone.isNotEmpty) pw.Text(client.phone),
              if (client.address.isNotEmpty) pw.Text(client.address),
            ] else
              pw.Text('No client specified'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['Description', 'Qty', 'Unit', 'Total'],
              data: quote.items.map((item) {
                return [
                  item.description,
                  item.qty.toStringAsFixed(2),
                  currency.format(item.unitPrice),
                  currency.format(item.lineTotal),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 12),
            _totalsSection(quote, currency),
            if (quote.notes.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(quote.notes),
            ],
            if (quote.terms.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(quote.terms),
            ],
          ];
        },
        footer: (context) {
          if (hideFooter) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(footerText ?? 'Generated via CaribTap', style: const pw.TextStyle(fontSize: 10)),
          );
        },
      ),
    );

    if (includeWatermark) {
      // Simple watermark by adding a second page background in future enhancements.
    }

    return doc.save();
  }

  Future<void> shareQuotePdf(
    QuoteModel quote, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final bytes = await buildQuotePdf(
      quote,
      businessName: businessName,
      footerText: footerText,
      includeWatermark: includeWatermark,
      hideFooter: hideFooter,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'quote'}.pdf');
  }

  Future<String> downloadQuotePdf(
    QuoteModel quote, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final bytes = await buildQuotePdf(
      quote,
      businessName: businessName,
      footerText: footerText,
      includeWatermark: includeWatermark,
      hideFooter: hideFooter,
    );
    final filename = '${quote.quoteNumber.isNotEmpty ? quote.quoteNumber : 'quote'}.pdf';
    
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      // Navigate to Downloads folder on Android
      final downloadsPath = '/storage/emulated/0/Download';
      directory = Directory(downloadsPath);
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (directory == null) {
      throw Exception('Unable to get download directory');
    }
    
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Uint8List> buildInvoicePdf(
    InvoiceModel invoice, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final doc = pw.Document();
    final client = invoice.clientSnapshot;
    final listing = invoice.listingContext;
    final currency = _currencyFor(code: invoice.currencyCode, symbol: invoice.currencySymbol);
    final logo = await _loadLogo(listing?.listingLogoUrl);
    final headerName = (listing?.listingTitle?.isNotEmpty ?? false)
        ? listing!.listingTitle!
        : (businessName ?? 'CaribTap Business');
    final contactLines = <String>[];
    if (listing?.listingPhone != null && listing!.listingPhone!.isNotEmpty) {
      contactLines.add(listing.listingPhone!);
    }
    if (listing?.listingEmail != null && listing!.listingEmail!.isNotEmpty) {
      contactLines.add(listing.listingEmail!);
    }
    if (listing?.listingAddress != null && listing!.listingAddress!.isNotEmpty) {
      contactLines.add(listing.listingAddress!);
    }
    if (listing?.companyRegistration != null && listing!.companyRegistration!.isNotEmpty) {
      contactLines.add('Reg: ${listing.companyRegistration!}');
    }
    if (listing?.vatNumber != null && listing!.vatNumber!.isNotEmpty) {
      contactLines.add('VAT: ${listing.vatNumber!}');
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        pageTheme: includeWatermark ? _watermarkTheme('CaribTap') : null,
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 40,
                        height: 40,
                        margin: const pw.EdgeInsets.only(right: 8),
                        child: pw.Image(logo, fit: pw.BoxFit.cover),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          headerName,
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                        ),
                        for (final line in contactLines)
                          pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Invoice', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : '-', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Client', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            if (client != null) ...[
              pw.Text(client.name),
              if (client.companyName.isNotEmpty) pw.Text(client.companyName),
              if (client.email.isNotEmpty) pw.Text(client.email),
              if (client.phone.isNotEmpty) pw.Text(client.phone),
              if (client.address.isNotEmpty) pw.Text(client.address),
            ] else
              pw.Text('No client specified'),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: const ['Description', 'Qty', 'Unit', 'Total'],
              data: invoice.items.map((item) {
                return [
                  item.description,
                  item.qty.toStringAsFixed(2),
                  currency.format(item.unitPrice),
                  currency.format(item.lineTotal),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
            ),
            pw.SizedBox(height: 12),
            _totalsSectionFromInvoice(invoice, currency),
            if (invoice.notes.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.notes),
            ],
            if (invoice.terms.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text('Terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice.terms),
            ],
          ];
        },
        footer: (context) {
          if (hideFooter) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(footerText ?? 'Generated via CaribTap', style: const pw.TextStyle(fontSize: 10)),
          );
        },
      ),
    );

    if (includeWatermark) {
      // Simple watermark by adding a second page background in future enhancements.
    }

    return doc.save();
  }

  Future<void> shareInvoicePdf(
    InvoiceModel invoice, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final bytes = await buildInvoicePdf(
      invoice,
      businessName: businessName,
      footerText: footerText,
      includeWatermark: includeWatermark,
      hideFooter: hideFooter,
    );
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'invoice'}.pdf');
  }

  Future<String> downloadInvoicePdf(
    InvoiceModel invoice, {
    String? businessName,
    String? footerText,
    bool includeWatermark = false,
    bool hideFooter = false,
  }) async {
    final bytes = await buildInvoicePdf(
      invoice,
      businessName: businessName,
      footerText: footerText,
      includeWatermark: includeWatermark,
      hideFooter: hideFooter,
    );
    final filename = '${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'invoice'}.pdf';
    
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      // Navigate to Downloads folder on Android
      final downloadsPath = '/storage/emulated/0/Download';
      directory = Directory(downloadsPath);
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (directory == null) {
      throw Exception('Unable to get download directory');
    }
    
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  pw.PageTheme _watermarkTheme(String text) {
    return pw.PageTheme(
      buildBackground: (context) => pw.Center(
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 80,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  pw.Widget _totalsSection(QuoteModel quote, NumberFormat currency) {
    final discountAmount = quote.discount.applyTo(quote.subtotal);
    final taxableBase = (quote.subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final taxAmount = quote.tax.applyTo(taxableBase);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _totalRow('Subtotal', currency.format(quote.subtotal)),
        if (discountAmount > 0) _totalRow('Discount', '-${currency.format(discountAmount)}'),
        if (taxAmount > 0) _totalRow('Tax', currency.format(taxAmount)),
        pw.Divider(),
        _totalRow('Total', currency.format(quote.total), isBold: true),
      ],
    );
  }

  pw.Widget _totalsSectionFromInvoice(InvoiceModel invoice, NumberFormat currency) {
    final discountAmount = invoice.discount.applyTo(invoice.subtotal);
    final taxableBase = (invoice.subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final taxAmount = invoice.tax.applyTo(taxableBase);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _totalRow('Subtotal', currency.format(invoice.subtotal)),
        if (discountAmount > 0) _totalRow('Discount', '-${currency.format(discountAmount)}'),
        if (taxAmount > 0) _totalRow('Tax', currency.format(taxAmount)),
        pw.Divider(),
        _totalRow('Total', currency.format(invoice.total), isBold: true),
      ],
    );
  }

  NumberFormat _currencyFor({required String code, required String symbol}) {
    final effectiveSymbol = symbol.trim().isNotEmpty
        ? symbol
        : NumberFormat.simpleCurrency(name: code).currencySymbol;
    return NumberFormat.currency(name: code, symbol: effectiveSymbol);
  }

  Future<pw.ImageProvider?> _loadLogo(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _totalRow(String label, String value, {bool isBold = false}) {
    final style = pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(value, style: style),
      ],
    );
  }
}
