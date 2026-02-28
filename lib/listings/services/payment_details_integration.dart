import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:caribtap/listings/services/payment_details_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

/// Helper to integrate payment details into quotes/invoices
class PaymentDetailsIntegration {
  static final _paymentService = PaymentDetailsService();

  /// Fetch payment details if they should be displayed
  static Future<PaymentDetailsPublic?> getPaymentDetailsForDisplay({
    required String userId,
    required bool isInvoice,
  }) async {
    try {
      final public = await _paymentService.getPublic(userId);
      
      // Only show if enabled
      if (!public.hasAnyPaymentMethod) {
        return null;
      }
      
      return public;
    } catch (e) {
      print('Error fetching payment details: $e');
      return null;
    }
  }

  /// Build PDF section for payment details (used in PDF generation)
  static pw.Widget buildPdfPaymentSection(PaymentDetailsPublic paymentDetails) {
    final widgets = <pw.Widget>[
      pw.SizedBox(height: 12),
      pw.Text(
        'Payment Methods',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
    ];

    // Bank Transfer
    if (paymentDetails.bankTransfer != null && paymentDetails.bankTransfer!.enabled) {
      widgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Bank Transfer',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Bank: ${paymentDetails.bankTransfer!.bankName}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Account: ${paymentDetails.bankTransfer!.accountName}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Account #: ${paymentDetails.bankTransfer!.accountNumber}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (paymentDetails.bankTransfer!.branch.isNotEmpty)
              pw.Text(
                'Branch: ${paymentDetails.bankTransfer!.branch}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            if (paymentDetails.bankTransfer!.instructions.isNotEmpty)
              pw.Text(
                paymentDetails.bankTransfer!.instructions,
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
              ),
            pw.SizedBox(height: 8),
          ],
        ),
      );
    }

    // Payment Apps
    if (paymentDetails.paymentApps.isNotEmpty) {
      final enabledApps = paymentDetails.paymentApps.where((app) => app.enabled).toList();
      if (enabledApps.isNotEmpty) {
        widgets.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Payment Apps',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              for (final app in enabledApps)
                pw.Text(
                  '${app.label}: ${app.handle}${app.url.isNotEmpty ? ' (${app.url})' : ''}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 8),
            ],
          ),
        );
      }
    }

    // Notes
    if (paymentDetails.notes.isNotEmpty) {
      widgets.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              paymentDetails.notes,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
