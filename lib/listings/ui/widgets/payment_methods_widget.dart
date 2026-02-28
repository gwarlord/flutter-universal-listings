import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/payment_details_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget to display public payment details for a listing
/// Only shows if displayMode is public_listing
class PaymentMethodsWidget extends StatelessWidget {
  final PaymentDetailsPublic paymentDetails;

  const PaymentMethodsWidget({
    super.key,
    required this.paymentDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (!paymentDetails.hasAnyPaymentMethod) {
      return const SizedBox.shrink();
    }

    final isDark = isDarkMode(context);
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bank Transfer
            if (paymentDetails.bankTransfer != null && paymentDetails.bankTransfer!.enabled) ...[
              _buildSectionHeader('Bank Transfer', Icons.account_balance),
              const SizedBox(height: 8),
              _buildBankTransferDetails(context, paymentDetails.bankTransfer!),
              const SizedBox(height: 16),
            ],

            // Payment Apps
            if (paymentDetails.paymentApps.isNotEmpty) ...[
              _buildSectionHeader('Payment Apps', Icons.apps),
              const SizedBox(height: 8),
              ...paymentDetails.paymentApps.where((app) => app.enabled).map((app) {
                return _buildPaymentAppTile(context, app);
              }),
            ],

            // Notes
            if (paymentDetails.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paymentDetails.notes,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildBankTransferDetails(BuildContext context, BankTransferDetails bank) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bank.bankName.isNotEmpty) _buildInfoRow('Bank', bank.bankName),
          if (bank.accountName.isNotEmpty) _buildInfoRow('Account Name', bank.accountName),
          if (bank.accountNumber.isNotEmpty)
            _buildCopyableRow(context, 'Account Number', bank.accountNumber),
          if (bank.branch.isNotEmpty) _buildInfoRow('Branch', bank.branch),
          if (bank.currency.isNotEmpty) _buildInfoRow('Currency', bank.currency),
          if (bank.swiftBic.isNotEmpty) _buildCopyableRow(context, 'SWIFT/BIC', bank.swiftBic),
          if (bank.iban.isNotEmpty) _buildCopyableRow(context, 'IBAN', bank.iban),
          if (bank.instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bank.instructions,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              showSnackBar(context, 'Copied to clipboard');
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 16, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAppTile(BuildContext context, PaymentApp app) {
    final icon = _getPaymentAppIcon(app.type);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: app.url.isNotEmpty ? () => _launchUrl(app.url) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 24, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.label.isNotEmpty ? app.label : app.type.displayText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (app.handle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        app.handle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (app.handle.isNotEmpty)
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: app.handle));
                    showSnackBar(context, 'Copied to clipboard');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.copy, size: 18, color: Colors.blue[700]),
                  ),
                ),
              if (app.url.isNotEmpty)
                Icon(Icons.open_in_new, size: 18, color: Colors.blue[700]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentAppIcon(PaymentAppType type) {
    switch (type) {
      case PaymentAppType.paypal:
        return Icons.account_balance_wallet;
      case PaymentAppType.cashApp:
      case PaymentAppType.zelle:
      case PaymentAppType.wise:
      case PaymentAppType.revolut:
        return Icons.payments;
      case PaymentAppType.venmo:
        return Icons.swap_horiz;
      case PaymentAppType.linx:
      case PaymentAppType.wipay:
        return Icons.credit_card;
      case PaymentAppType.other:
        return Icons.payment;
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
