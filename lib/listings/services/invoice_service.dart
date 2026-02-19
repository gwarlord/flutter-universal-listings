import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/services/share_link_service.dart';

class InvoiceService {
  final FirebaseFirestore _firestore;
  final ShareLinkService _shareLinkService;

  InvoiceService({
    FirebaseFirestore? firestore,
    ShareLinkService? shareLinkService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _shareLinkService = shareLinkService ?? ShareLinkService();

  CollectionReference<Map<String, dynamic>> _invoicesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('invoices');
  }

  DocumentReference<Map<String, dynamic>> _counterRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('counters').doc('invoices');
  }

  DocumentReference<Map<String, dynamic>> _sendCounterRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('counters').doc('send_actions');
  }

  Stream<List<InvoiceModel>> streamInvoices(String uid) {
    return _invoicesRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvoiceModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<InvoiceModel?> streamInvoice(String uid, String invoiceId) {
    return _invoicesRef(uid).doc(invoiceId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return InvoiceModel.fromJson(doc.data()!, doc.id);
    });
  }

  InvoiceModel computeTotals(InvoiceModel invoice) {
    final subtotal = invoice.items.fold<double>(0, (sum, item) {
      return sum + item.lineTotal;
    });
    final discountAmount = invoice.discount.applyTo(subtotal);
    final taxableBase = (subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final taxAmount = invoice.tax.applyTo(taxableBase);
    final total = (subtotal - discountAmount + taxAmount).clamp(0, double.infinity).toDouble();

    return invoice.copyWith(
      subtotal: subtotal,
      total: total,
    );
  }

  Future<InvoiceModel> saveDraft(String uid, InvoiceModel invoice) async {
    final now = DateTime.now();
    final computed = computeTotals(invoice);
    final data = computed.copyWith(updatedAt: now, createdAt: invoice.createdAt ?? now);

    if (invoice.id.isEmpty) {
      final docRef = _invoicesRef(uid).doc();
      final number = invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : await _nextInvoiceNumber(uid);
      final newInvoice = data.copyWith(id: docRef.id, invoiceNumber: number);
      await docRef.set(newInvoice.toJson());
      return newInvoice;
    }

    await _invoicesRef(uid).doc(invoice.id).update(data.toJson());
    return data;
  }

  Future<void> deleteInvoice(String uid, String invoiceId) async {
    await _invoicesRef(uid).doc(invoiceId).delete();
  }

  Future<InvoiceModel> markSent(String uid, InvoiceModel invoice, {Duration? shareExpiry}) async {
    await _enforceSendLimit(uid);

    final now = DateTime.now();
    final token = invoice.shareToken ??
        await _shareLinkService.createPublicDoc(
          ownerUid: uid,
          type: 'invoice',
          docId: invoice.id,
          expiresIn: shareExpiry,
          snapshot: _buildPublicSnapshot(invoice),
        );

    final updated = invoice.copyWith(
      status: 'sent',
      sentAt: now,
      shareToken: token,
      updatedAt: now,
    );
    await _invoicesRef(uid).doc(invoice.id).update(updated.toJson());
    return updated;
  }

  Future<InvoiceModel> markPaid(String uid, InvoiceModel invoice) async {
    final now = DateTime.now();
    final updated = invoice.copyWith(
      status: 'paid',
      paidAt: now,
      updatedAt: now,
    );
    await _invoicesRef(uid).doc(invoice.id).update(updated.toJson());
    return updated;
  }

  Map<String, dynamic> _buildPublicSnapshot(InvoiceModel invoice) {
    return {
      'invoiceNumber': invoice.invoiceNumber,
      'status': invoice.status,
      'clientSnapshot': invoice.clientSnapshot?.toJson(),
      'sourceQuoteId': invoice.sourceQuoteId,
      'listingContext': invoice.listingContext?.toJson(),
      'items': invoice.items.map((item) => item.toJson()).toList(),
      'subtotal': invoice.subtotal,
      'discount': invoice.discount.toJson(),
      'tax': invoice.tax.toJson(),
      'total': invoice.total,
      'currencyCode': invoice.currencyCode,
      'currencySymbol': invoice.currencySymbol,
      'notes': invoice.notes,
      'terms': invoice.terms,
      'dueDate': invoice.dueDate != null ? Timestamp.fromDate(invoice.dueDate!) : null,
      'createdAt': invoice.createdAt != null ? Timestamp.fromDate(invoice.createdAt!) : null,
      'updatedAt': invoice.updatedAt != null ? Timestamp.fromDate(invoice.updatedAt!) : null,
      'sentAt': invoice.sentAt != null ? Timestamp.fromDate(invoice.sentAt!) : null,
      'paidAt': invoice.paidAt != null ? Timestamp.fromDate(invoice.paidAt!) : null,
    };
  }

  Future<String> _nextInvoiceNumber(String uid) async {
    return _firestore.runTransaction((transaction) async {
      final ref = _counterRef(uid);
      final snapshot = await transaction.get(ref);
      final current = snapshot.data()?['nextNumber'] as int? ?? 1;
      final nextNumber = current + 1;
      transaction.set(ref, {'nextNumber': nextNumber}, SetOptions(merge: true));
      return 'INV-${current.toString().padLeft(6, '0')}';
    });
  }

  Future<void> _enforceSendLimit(String uid) async {
    final today = _dateKey(DateTime.now());
    await _firestore.runTransaction((transaction) async {
      final ref = _sendCounterRef(uid);
      final snapshot = await transaction.get(ref);
      final data = snapshot.data() ?? {};
      final currentDate = data['date'] as String?;
      final currentCount = (data['count'] as int?) ?? 0;

      if (currentDate == today) {
        if (currentCount >= 30) {
          throw StateError('Daily send limit reached');
        }
        transaction.set(ref, {'date': today, 'count': currentCount + 1}, SetOptions(merge: true));
      } else {
        transaction.set(ref, {'date': today, 'count': 1}, SetOptions(merge: true));
      }
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
