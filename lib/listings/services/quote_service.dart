import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/invoice_model.dart';
import 'package:caribtap/listings/model/quote_model.dart';
import 'package:caribtap/listings/services/share_link_service.dart';

class QuoteService {
  final FirebaseFirestore _firestore;
  final ShareLinkService _shareLinkService;

  QuoteService({
    FirebaseFirestore? firestore,
    ShareLinkService? shareLinkService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _shareLinkService = shareLinkService ?? ShareLinkService();

  CollectionReference<Map<String, dynamic>> _quotesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('quotes');
  }

  DocumentReference<Map<String, dynamic>> _counterRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('counters').doc('quotes');
  }

  DocumentReference<Map<String, dynamic>> _sendCounterRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('counters').doc('send_actions');
  }

  CollectionReference<Map<String, dynamic>> _invoicesRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('invoices');
  }

  Stream<List<QuoteModel>> streamQuotes(String uid, {int? limit}) {
    Query<Map<String, dynamic>> query = _quotesRef(uid).orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => QuoteModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Stream<QuoteModel?> streamQuote(String uid, String quoteId) {
    return _quotesRef(uid).doc(quoteId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return QuoteModel.fromJson(doc.data()!, doc.id);
    });
  }

  Future<QuoteModel> saveDraft(String uid, QuoteModel quote) async {
    final now = DateTime.now();
    final computed = computeTotals(quote);
    final data = computed.copyWith(updatedAt: now, createdAt: quote.createdAt ?? now);

    if (quote.id.isEmpty) {
      final docRef = _quotesRef(uid).doc();
      final quoteNumber = quote.quoteNumber.isNotEmpty ? quote.quoteNumber : await _nextQuoteNumber(uid);
      final newQuote = data.copyWith(
        id: docRef.id,
        quoteNumber: quoteNumber,
      );
      await docRef.set(newQuote.toJson());
      return newQuote;
    }

    await _quotesRef(uid).doc(quote.id).update(data.toJson());
    return data;
  }

  Future<void> deleteQuote(String uid, String quoteId) async {
    await _quotesRef(uid).doc(quoteId).delete();
  }

  Future<InvoiceModel> convertToInvoice(String uid, QuoteModel quote) async {
    final now = DateTime.now();
    final invoiceNumber = await _nextInvoiceNumber(uid);
    final invoice = InvoiceModel(
      id: '',
      invoiceNumber: invoiceNumber,
      status: 'draft',
      clientId: quote.clientId,
      clientSnapshot: quote.clientSnapshot,
      sourceQuoteId: quote.id,
      listingContext: quote.listingContext,
      items: quote.items,
      subtotal: quote.subtotal,
      discount: quote.discount,
      tax: quote.tax,
      total: quote.total,
      currencyCode: quote.currencyCode,
      currencySymbol: quote.currencySymbol,
      notes: quote.notes,
      terms: quote.terms,
      dueDate: null,
      createdAt: now,
      updatedAt: now,
      sentAt: null,
      paidAt: null,
      shareToken: null,
      createdByUid: uid,
    );

    final docRef = _invoicesRef(uid).doc();
    final saved = invoice.copyWith(id: docRef.id);
    await docRef.set(saved.toJson());
    return saved;
  }

  Future<QuoteModel> markSent(String uid, QuoteModel quote, {Duration? shareExpiry}) async {
    await _enforceSendLimit(uid);

    final now = DateTime.now();
    final token = quote.shareToken ??
        await _shareLinkService.createPublicDoc(
          ownerUid: uid,
          type: 'quote',
          docId: quote.id,
          expiresIn: shareExpiry,
          snapshot: _buildPublicSnapshot(quote),
        );

    final updated = quote.copyWith(
      status: 'sent',
      sentAt: now,
      shareToken: token,
      updatedAt: now,
    );
    await _quotesRef(uid).doc(quote.id).update(updated.toJson());
    return updated;
  }

  Map<String, dynamic> _buildPublicSnapshot(QuoteModel quote) {
    return {
      'quoteNumber': quote.quoteNumber,
      'status': quote.status,
      'clientSnapshot': quote.clientSnapshot?.toJson(),
      'items': quote.items.map((item) => item.toJson()).toList(),
      'subtotal': quote.subtotal,
      'discount': quote.discount.toJson(),
      'tax': quote.tax.toJson(),
      'total': quote.total,
      'currencyCode': quote.currencyCode,
      'currencySymbol': quote.currencySymbol,
      'notes': quote.notes,
      'terms': quote.terms,
      'validUntil': quote.validUntil != null ? Timestamp.fromDate(quote.validUntil!) : null,
      'listingContext': quote.listingContext?.toJson(),
      'createdAt': quote.createdAt != null ? Timestamp.fromDate(quote.createdAt!) : null,
      'updatedAt': quote.updatedAt != null ? Timestamp.fromDate(quote.updatedAt!) : null,
    };
  }

  Future<QuoteModel> markAccepted(String uid, QuoteModel quote) async {
    final now = DateTime.now();
    final updated = quote.copyWith(
      status: 'accepted',
      acceptedAt: now,
      updatedAt: now,
    );
    await _quotesRef(uid).doc(quote.id).update(updated.toJson());
    return updated;
  }

  Future<QuoteModel> markDeclined(String uid, QuoteModel quote) async {
    final now = DateTime.now();
    final updated = quote.copyWith(
      status: 'declined',
      declinedAt: now,
      updatedAt: now,
    );
    await _quotesRef(uid).doc(quote.id).update(updated.toJson());
    return updated;
  }

  QuoteModel computeTotals(QuoteModel quote) {
    final subtotal = quote.items.fold<double>(0, (sum, item) {
      return sum + (item.lineTotal);
    });
    final discountAmount = quote.discount.applyTo(subtotal);
    final taxableBase = (subtotal - discountAmount).clamp(0, double.infinity).toDouble();
    final taxAmount = quote.tax.applyTo(taxableBase);
    final total = (subtotal - discountAmount + taxAmount).clamp(0, double.infinity).toDouble();

    return quote.copyWith(
      subtotal: subtotal,
      total: total,
    );
  }

  Future<String> _nextQuoteNumber(String uid) async {
    return _firestore.runTransaction((transaction) async {
      final ref = _counterRef(uid);
      final snapshot = await transaction.get(ref);
      final current = snapshot.data()?['nextNumber'] as int? ?? 1;
      final nextNumber = current + 1;
      transaction.set(ref, {'nextNumber': nextNumber}, SetOptions(merge: true));
      return 'Q-${current.toString().padLeft(6, '0')}';
    });
  }

  Future<String> _nextInvoiceNumber(String uid) async {
    final ref = _firestore.collection('users').doc(uid).collection('counters').doc('invoices');
    return _firestore.runTransaction((transaction) async {
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
