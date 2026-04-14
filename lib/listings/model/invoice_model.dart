import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String status;
  final String? clientId;
  final ClientSnapshot? clientSnapshot;
  final String? sourceQuoteId;
  final ListingContext? listingContext;
  final List<ProDocLineItem> items;
  final double subtotal;
  final ProDocAdjustment discount;
  final ProDocAdjustment tax;
  final double total;
  final String currencyCode;
  final String currencySymbol;
  final String notes;
  final String terms;
  final String poNumber;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? sentAt;
  final DateTime? paidAt;
  final String? shareToken;
  final String createdByUid;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.status,
    required this.clientId,
    required this.clientSnapshot,
    required this.sourceQuoteId,
    required this.listingContext,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.currencyCode,
    required this.currencySymbol,
    required this.notes,
    required this.terms,
    required this.poNumber,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.sentAt,
    required this.paidAt,
    required this.shareToken,
    required this.createdByUid,
  });

  factory InvoiceModel.draft({
    required String createdByUid,
  }) {
    return InvoiceModel(
      id: '',
      invoiceNumber: '',
      status: 'draft',
      clientId: null,
      clientSnapshot: null,
      sourceQuoteId: null,
      listingContext: null,
      items: const [],
      subtotal: 0,
      discount: const ProDocAdjustment(type: AdjustmentType.amount, value: 0),
      tax: const ProDocAdjustment(type: AdjustmentType.amount, value: 0),
      total: 0,
      currencyCode: defaultCurrencyCode(),
      currencySymbol: defaultCurrencySymbol(),
      notes: '',
      terms: '',
      poNumber: '',
      dueDate: null,
      createdAt: null,
      updatedAt: null,
      sentAt: null,
      paidAt: null,
      shareToken: null,
      createdByUid: createdByUid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceNumber': invoiceNumber,
      'status': status,
      'clientId': clientId,
      'clientSnapshot': clientSnapshot?.toJson(),
      'sourceQuoteId': sourceQuoteId,
      'listingContext': listingContext?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount.toJson(),
      'tax': tax.toJson(),
      'total': total,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'notes': notes,
      'terms': terms,
      'poNumber': poNumber,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'shareToken': shareToken,
      'createdByUid': createdByUid,
    };
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json, String docId) {
    final itemsJson = (json['items'] as List?) ?? const [];
    return InvoiceModel(
      id: docId,
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      clientId: json['clientId']?.toString(),
      clientSnapshot: json['clientSnapshot'] != null
          ? ClientSnapshot.fromJson(Map<String, dynamic>.from(json['clientSnapshot'] as Map))
          : null,
      sourceQuoteId: json['sourceQuoteId']?.toString(),
        listingContext: json['listingContext'] != null
          ? ListingContext.fromJson(Map<String, dynamic>.from(json['listingContext'] as Map))
          : null,
      items: itemsJson
          .map((item) => ProDocLineItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: ProDocAdjustment.fromJson(json['discount']),
      tax: ProDocAdjustment.fromJson(json['tax']),
        total: (json['total'] as num?)?.toDouble() ?? 0,
        currencyCode: json['currencyCode']?.toString() ?? defaultCurrencyCode(),
        currencySymbol:
          json['currencySymbol']?.toString() ?? defaultCurrencySymbol(json['currencyCode']?.toString()),
      notes: json['notes']?.toString() ?? '',
      terms: json['terms']?.toString() ?? '',
      poNumber: json['poNumber']?.toString() ?? '',
      dueDate: readDateTime(json['dueDate']),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
      sentAt: readDateTime(json['sentAt']),
      paidAt: readDateTime(json['paidAt']),
      shareToken: json['shareToken']?.toString(),
      createdByUid: json['createdByUid']?.toString() ?? '',
    );
  }

  InvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
    String? status,
    String? clientId,
    ClientSnapshot? clientSnapshot,
    String? sourceQuoteId,
    ListingContext? listingContext,
    List<ProDocLineItem>? items,
    double? subtotal,
    ProDocAdjustment? discount,
    ProDocAdjustment? tax,
    double? total,
    String? currencyCode,
    String? currencySymbol,
    String? notes,
    String? terms,
    String? poNumber,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
    DateTime? paidAt,
    String? shareToken,
    String? createdByUid,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientSnapshot: clientSnapshot ?? this.clientSnapshot,
      sourceQuoteId: sourceQuoteId ?? this.sourceQuoteId,
      listingContext: listingContext ?? this.listingContext,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      poNumber: poNumber ?? this.poNumber,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      paidAt: paidAt ?? this.paidAt,
      shareToken: shareToken ?? this.shareToken,
      createdByUid: createdByUid ?? this.createdByUid,
    );
  }
}
