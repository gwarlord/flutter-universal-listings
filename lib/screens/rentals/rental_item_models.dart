import 'package:cloud_firestore/cloud_firestore.dart';

/// Rental cart item model for local cart state
class RentalCartItem {
  final String rentalUnitId;
  final String unitName;
  final String rentalType; // 'general', 'vehicle', etc.
  final DateTime startDate;
  final DateTime endDate;
  final double pricePerDay;
  final double totalPrice;
  final String currencyCode;
  final String? photoUrl;
  final Map<String, dynamic>? details; // Additional rental details

  RentalCartItem({
    required this.rentalUnitId,
    required this.unitName,
    required this.rentalType,
    required this.startDate,
    required this.endDate,
    required this.pricePerDay,
    required this.totalPrice,
    this.currencyCode = 'USD',
    this.photoUrl,
    this.details,
  });

  int get durationDays => endDate.difference(startDate).inDays + 1;

  RentalCartItem copyWith({
    String? rentalUnitId,
    String? unitName,
    String? rentalType,
    DateTime? startDate,
    DateTime? endDate,
    double? pricePerDay,
    double? totalPrice,
    String? currencyCode,
    String? photoUrl,
    Map<String, dynamic>? details,
  }) {
    return RentalCartItem(
      rentalUnitId: rentalUnitId ?? this.rentalUnitId,
      unitName: unitName ?? this.unitName,
      rentalType: rentalType ?? this.rentalType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      totalPrice: totalPrice ?? this.totalPrice,
      currencyCode: currencyCode ?? this.currencyCode,
      photoUrl: photoUrl ?? this.photoUrl,
      details: details ?? this.details,
    );
  }
}

/// Browse-friendly rental item model
class RentalItemBrowse {
  final String id;
  final String listingId;
  final String unitName;
  final String? description;
  final String rentalType; // 'general', 'vehicle'
  final double basePrice;
  final String pricingUnit; // 'hourly', 'daily', 'weekly', 'monthly'
  final String currencyCode;
  final List<String> photos;
  final bool isAvailable;
  final int stockQty; // Number of units available
  final Map<String, dynamic>? vehicleDetails; // {licensePlate, make, model, year, color}
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  RentalItemBrowse({
    required this.id,
    required this.listingId,
    required this.unitName,
    this.description,
    this.rentalType = 'general',
    this.basePrice = 0.0,
    this.pricingUnit = 'daily',
    this.currencyCode = 'USD',
    this.photos = const [],
    this.isAvailable = true,
    this.stockQty = 1,
    this.vehicleDetails,
    this.createdAt,
    this.updatedAt,
  });

  factory RentalItemBrowse.fromJson(Map<String, dynamic> json) {
    return RentalItemBrowse(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      unitName: json['unitName'] ?? '',
      description: json['description'],
      rentalType: json['rentalType'] ?? 'general',
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      pricingUnit: json['pricingUnit'] ?? 'daily',
      currencyCode: json['currencyCode'] ?? 'USD',
      photos: List<String>.from(json['photos'] ?? []),
      isAvailable: json['isAvailable'] ?? true,
      stockQty: json['stockQty'] ?? 1,
      vehicleDetails: json['vehicleDetails'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'unitName': unitName,
      'description': description,
      'rentalType': rentalType,
      'basePrice': basePrice,
      'pricingUnit': pricingUnit,
      'currencyCode': currencyCode,
      'photos': photos,
      'isAvailable': isAvailable,
      'stockQty': stockQty,
      'vehicleDetails': vehicleDetails,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
