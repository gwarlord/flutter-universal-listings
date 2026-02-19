import 'package:caribtap/listings/model/pro_doc_shared.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PublicQuoteViewScreen extends StatefulWidget {
  final String token;

  const PublicQuoteViewScreen({
    super.key,
    required this.token,
  });

  @override
  State<PublicQuoteViewScreen> createState() => _PublicQuoteViewScreenState();
}

class _PublicQuoteViewScreenState extends State<PublicQuoteViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  NumberFormat _currencyFor(Map<String, dynamic> quote) {
    final code = quote['currencyCode']?.toString();
    final symbol = quote['currencySymbol']?.toString();
    final resolvedCode = (code != null && code.isNotEmpty)
        ? code
        : NumberFormat.simpleCurrency().currencyName ?? 'USD';
    final resolvedSymbol = (symbol != null && symbol.isNotEmpty)
        ? symbol
        : NumberFormat.simpleCurrency(name: resolvedCode).currencySymbol;
    return NumberFormat.currency(name: resolvedCode, symbol: resolvedSymbol);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quote'.tr())),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('public_docs').doc(widget.token).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Quote not found'.tr()));
          }
          final data = snapshot.data!.data() ?? {};
          final type = data['type']?.toString();
          if (type != 'quote') {
            return Center(child: Text('Invalid quote link'.tr()));
          }
          final quote = data['snapshot'] as Map<String, dynamic>?;
          if (quote == null) {
            return Center(child: Text('Quote unavailable'.tr()));
          }

          return _buildQuote(context, quote);
        },
      ),
    );
  }

  Widget _buildQuote(BuildContext context, Map<String, dynamic> quote) {
    final items = (quote['items'] as List?) ?? const [];
    final client = quote['clientSnapshot'] as Map<String, dynamic>?;
    final status = quote['status']?.toString() ?? 'draft';
    final currency = _currencyFor(quote);

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
        ...items.map((item) => _itemRow(item as Map<String, dynamic>, currency)).toList(),
        const SizedBox(height: 12),
        _totalsSection(quote, currency),
        const SizedBox(height: 16),
        if ((quote['notes'] ?? '').toString().isNotEmpty) ...[
          _sectionTitle('Notes'.tr()),
          Text(quote['notes'].toString()),
          const SizedBox(height: 16),
        ],
        if ((quote['terms'] ?? '').toString().isNotEmpty) ...[
          _sectionTitle('Terms'.tr()),
          Text(quote['terms'].toString()),
          const SizedBox(height: 16),
        ],
        if (status == 'sent')
          ElevatedButton(
            onPressed: () => _acceptQuote(context),
            child: Text('Accept Quote'.tr()),
          ),
      ],
    );
  }

  Widget _itemRow(Map<String, dynamic> item, NumberFormat currency) {
    final description = item['description']?.toString() ?? '';
    final qty = (item['qty'] as num?)?.toDouble() ?? 0;
    final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
    final lineTotal = (item['lineTotal'] as num?)?.toDouble() ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(description),
      subtitle: Text('${qty.toStringAsFixed(2)} x ${currency.format(unitPrice)}'),
      trailing: Text(currency.format(lineTotal)),
    );
  }

  Widget _totalsSection(Map<String, dynamic> quote, NumberFormat currency) {
    final subtotal = (quote['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = ProDocAdjustment.fromJson(quote['discount']);
    final tax = ProDocAdjustment.fromJson(quote['tax']);
    final discountAmount = discount.applyTo(subtotal);
    final taxableBase = (subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final taxAmount = tax.applyTo(taxableBase);
    final total = (quote['total'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        _totalRow('Subtotal'.tr(), currency.format(subtotal)),
        if (discountAmount > 0) _totalRow('Discount'.tr(), '-${currency.format(discountAmount)}'),
        if (taxAmount > 0) _totalRow('Tax'.tr(), currency.format(taxAmount)),
        const Divider(),
        _totalRow('Total'.tr(), currency.format(total), isBold: true),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _acceptQuote(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Accept Quote'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Your name'.tr()),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Accept'.tr()),
            ),
          ],
        );
      },
    );

    if (accepted != true) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('acceptQuoteByToken');
      await callable.call({
        'token': widget.token,
        'accepterName': nameController.text.trim(),
        'accepterEmail': emailController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quote accepted'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept quote'.tr())),
      );
    }
  }
}
