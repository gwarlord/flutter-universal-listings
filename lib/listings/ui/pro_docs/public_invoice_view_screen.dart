import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PublicInvoiceViewScreen extends StatelessWidget {
  final String token;

  const PublicInvoiceViewScreen({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency();
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: Text('Invoice'.tr())),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('public_docs').doc(token).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Invoice not found'.tr()));
          }
          final data = snapshot.data!.data() ?? {};
          final type = data['type']?.toString();
          if (type != 'invoice') {
            return Center(child: Text('Invalid invoice link'.tr()));
          }
          final invoice = data['snapshot'] as Map<String, dynamic>?;
          if (invoice == null) {
            return Center(child: Text('Invoice unavailable'.tr()));
          }

          final items = (invoice['items'] as List?) ?? const [];
          final client = invoice['clientSnapshot'] as Map<String, dynamic>?;

          final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
          final discount = ProDocAdjustment.fromJson(invoice['discount']);
          final tax = ProDocAdjustment.fromJson(invoice['tax']);
          final discountAmount = discount.applyTo(subtotal);
          final taxableBase = (subtotal - discountAmount).clamp(0, double.infinity).toDouble();
          final taxAmount = tax.applyTo(taxableBase);
          final total = (invoice['total'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Client'.tr()),
              if (client != null) ...[
                Text(client['name']?.toString() ?? ''),
                if ((client['companyName'] ?? '').toString().isNotEmpty) Text(client['companyName'].toString()),
                if ((client['email'] ?? '').toString().isNotEmpty) Text(client['email'].toString()),
                if ((client['phone'] ?? '').toString().isNotEmpty) Text(client['phone'].toString()),
                if ((client['address'] ?? '').toString().isNotEmpty) Text(client['address'].toString()),
              ] else
                Text('No client'.tr()),
              const SizedBox(height: 16),
              _sectionTitle('Items'.tr()),
              ...items.map((item) {
                final itemMap = item as Map<String, dynamic>;
                final description = itemMap['description']?.toString() ?? '';
                final qty = (itemMap['qty'] as num?)?.toDouble() ?? 0;
                final unitPrice = (itemMap['unitPrice'] as num?)?.toDouble() ?? 0;
                final lineTotal = (itemMap['lineTotal'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(description),
                  subtitle: Text('${qty.toStringAsFixed(2)} x ${currency.format(unitPrice)}'),
                  trailing: Text(currency.format(lineTotal)),
                );
              }).toList(),
              const SizedBox(height: 12),
              _totalRow('Subtotal'.tr(), currency.format(subtotal)),
              if (discountAmount > 0) _totalRow('Discount'.tr(), '-${currency.format(discountAmount)}'),
              if (taxAmount > 0) _totalRow('Tax'.tr(), currency.format(taxAmount)),
              const Divider(),
              _totalRow('Total'.tr(), currency.format(total), isBold: true),
              const SizedBox(height: 16),
              if ((invoice['notes'] ?? '').toString().isNotEmpty) ...[
                _sectionTitle('Notes'.tr()),
                Text(invoice['notes'].toString()),
              ],
              if ((invoice['terms'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle('Terms'.tr()),
                Text(invoice['terms'].toString()),
              ],
            ],
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
}
