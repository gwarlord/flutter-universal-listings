import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';

class QuoteModel {
  final String id;
  final String quoteNumber;
  final String status;
  final String? clientId;
  final ClientSnapshot? clientSnapshot;
  final List<ProDocLineItem> items;
  final double subtotal;
  final ProDocAdjustment discount;
  final ProDocAdjustment tax;
  final double total;
  final String currencyCode;
  final String currencySymbol;
  final String notes;
  final String terms;
  final DateTime? validUntil;
  final ListingContext? listingContext;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final String? shareToken;
  final String createdByUid;

  QuoteModel({
    required this.id,
    required this.quoteNumber,
    required this.status,
    required this.clientId,
    required this.clientSnapshot,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.currencyCode,
    required this.currencySymbol,
    required this.notes,
    required this.terms,
    required this.validUntil,
    required this.listingContext,
    required this.createdAt,
    required this.updatedAt,
    required this.sentAt,
    required this.acceptedAt,
    required this.declinedAt,
    required this.shareToken,
    required this.createdByUid,
  });

  factory QuoteModel.draft({
    required String createdByUid,
  }) {
    return QuoteModel(
      id: '',
      quoteNumber: '',
      status: 'draft',
      clientId: null,
      clientSnapshot: null,
      items: const [],
      subtotal: 0,
      discount: const ProDocAdjustment(type: AdjustmentType.amount, value: 0),
      tax: const ProDocAdjustment(type: AdjustmentType.amount, value: 0),
      total: 0,
      currencyCode: defaultCurrencyCode(),
      currencySymbol: defaultCurrencySymbol(),
      notes: '',
      terms: '',
      validUntil: null,
      listingContext: null,
      createdAt: null,
      updatedAt: null,
      sentAt: null,
      acceptedAt: null,
      declinedAt: null,
      shareToken: null,
      createdByUid: createdByUid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quoteNumber': quoteNumber,
      'status': status,
      'clientId': clientId,
      'clientSnapshot': clientSnapshot?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount.toJson(),
      'tax': tax.toJson(),
      'total': total,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'notes': notes,
      'terms': terms,
      'validUntil': validUntil != null ? Timestamp.fromDate(validUntil!) : null,
      'listingContext': listingContext?.toJson(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'declinedAt': declinedAt != null ? Timestamp.fromDate(declinedAt!) : null,
      'shareToken': shareToken,
      'createdByUid': createdByUid,
    };
  }

  factory QuoteModel.fromJson(Map<String, dynamic> json, String docId) {
    final itemsJson = (json['items'] as List?) ?? const [];
    return QuoteModel(
      id: docId,
      quoteNumber: json['quoteNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      clientId: json['clientId']?.toString(),
      clientSnapshot: json['clientSnapshot'] != null
          ? ClientSnapshot.fromJson(Map<String, dynamic>.from(json['clientSnapshot'] as Map))
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
      validUntil: readDateTime(json['validUntil']),
      listingContext: json['listingContext'] != null
          ? ListingContext.fromJson(Map<String, dynamic>.from(json['listingContext'] as Map))
          : null,
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
      sentAt: readDateTime(json['sentAt']),
      acceptedAt: readDateTime(json['acceptedAt']),
      declinedAt: readDateTime(json['declinedAt']),
      shareToken: json['shareToken']?.toString(),
      createdByUid: json['createdByUid']?.toString() ?? '',
    );
  }

  QuoteModel copyWith({
    String? id,
    String? quoteNumber,
    String? status,
    String? clientId,
    ClientSnapshot? clientSnapshot,
    List<ProDocLineItem>? items,
    double? subtotal,
    ProDocAdjustment? discount,
    ProDocAdjustment? tax,
    double? total,
    String? currencyCode,
    String? currencySymbol,
    String? notes,
    String? terms,
    DateTime? validUntil,
    ListingContext? listingContext,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
    DateTime? acceptedAt,
    DateTime? declinedAt,
    String? shareToken,
    String? createdByUid,
  }) {
    return QuoteModel(
      id: id ?? this.id,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      status: status ?? this.status,
      clientId: clientId ?? this.clientId,
      clientSnapshot: clientSnapshot ?? this.clientSnapshot,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      validUntil: validUntil ?? this.validUntil,
      listingContext: listingContext ?? this.listingContext,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      declinedAt: declinedAt ?? this.declinedAt,
      shareToken: shareToken ?? this.shareToken,
      createdByUid: createdByUid ?? this.createdByUid,
    );
  }
}
