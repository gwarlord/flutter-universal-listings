import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum AdjustmentType {
  amount,
  percent,
}

class ProDocAdjustment {
  final AdjustmentType type;
  final double value;

  const ProDocAdjustment({
    required this.type,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
    };
  }

  factory ProDocAdjustment.fromJson(dynamic data) {
    if (data == null) {
      return const ProDocAdjustment(type: AdjustmentType.amount, value: 0);
    }
    if (data is num) {
      return ProDocAdjustment(type: AdjustmentType.amount, value: data.toDouble());
    }
    final map = Map<String, dynamic>.from(data as Map);
    final typeValue = (map['type'] ?? 'amount').toString().toLowerCase();
    final type = typeValue == 'percent' ? AdjustmentType.percent : AdjustmentType.amount;
    return ProDocAdjustment(
      type: type,
      value: (map['value'] as num?)?.toDouble() ?? 0,
    );
  }

  double applyTo(double subtotal) {
    if (value <= 0) return 0;
    if (type == AdjustmentType.percent) {
      return subtotal * (value / 100);
    }
    return value;
  }
}

class ProDocLineItem {
  final String description;
  final double qty;
  final double unitPrice;
  final double lineTotal;

  ProDocLineItem({
    required this.description,
    required this.qty,
    required this.unitPrice,
    double? lineTotal,
  }) : lineTotal = lineTotal ?? (qty * unitPrice);

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'qty': qty,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }

  factory ProDocLineItem.fromJson(Map<String, dynamic> json) {
    return ProDocLineItem(
      description: json['description']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble(),
    );
  }
}

class ClientSnapshot {
  final String name;
  final String email;
  final String phone;
  final String companyName;
  final String address;

  const ClientSnapshot({
    required this.name,
    required this.email,
    required this.phone,
    required this.companyName,
    required this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'companyName': companyName,
      'address': address,
    };
  }

  factory ClientSnapshot.fromJson(Map<String, dynamic> json) {
    return ClientSnapshot(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class ListingContext {
  final String? listingId;
  final String? listingTitle;
  final String? listingLogoUrl;
  final String? listingPhone;
  final String? listingEmail;
  final String? listingAddress;
  final String? companyRegistration;
  final String? vatNumber;

  const ListingContext({
    this.listingId,
    this.listingTitle,
    this.listingLogoUrl,
    this.listingPhone,
    this.listingEmail,
    this.listingAddress,
    this.companyRegistration,
    this.vatNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingLogoUrl': listingLogoUrl,
      'listingPhone': listingPhone,
      'listingEmail': listingEmail,
      'listingAddress': listingAddress,
      'companyRegistration': companyRegistration,
      'vatNumber': vatNumber,
    };
  }

  factory ListingContext.fromJson(Map<String, dynamic> json) {
    return ListingContext(
      listingId: json['listingId']?.toString(),
      listingTitle: json['listingTitle']?.toString(),
      listingLogoUrl: json['listingLogoUrl']?.toString(),
      listingPhone: json['listingPhone']?.toString(),
      listingEmail: json['listingEmail']?.toString(),
      listingAddress: json['listingAddress']?.toString(),
      companyRegistration: json['companyRegistration']?.toString(),
      vatNumber: json['vatNumber']?.toString(),
    );
  }

  ListingContext copyWith({
    String? listingId,
    String? listingTitle,
    String? listingLogoUrl,
    String? listingPhone,
    String? listingEmail,
    String? listingAddress,
    String? companyRegistration,
    String? vatNumber,
  }) {
    return ListingContext(
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingLogoUrl: listingLogoUrl ?? this.listingLogoUrl,
      listingPhone: listingPhone ?? this.listingPhone,
      listingEmail: listingEmail ?? this.listingEmail,
      listingAddress: listingAddress ?? this.listingAddress,
      companyRegistration: companyRegistration ?? this.companyRegistration,
      vatNumber: vatNumber ?? this.vatNumber,
    );
  }
}

String defaultCurrencyCode() {
  final formatter = NumberFormat.simpleCurrency();
  return formatter.currencyName ?? 'USD';
}

String defaultCurrencySymbol([String? code]) {
  final formatter = NumberFormat.simpleCurrency(name: code ?? defaultCurrencyCode());
  return formatter.currencySymbol;
}

DateTime? readDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
