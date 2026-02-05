import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/rental_config.dart';

/// Rental catalog item - individual rentable items (tools, vehicles, equipment, etc.)
class RentalCatalogItem {
  final String id;
  final String listingId;  // Parent listing
  final String name;
  final String? description;
  final String category;  // 'Tools', 'Vehicles', 'Equipment', 'Sports', etc.
  final double basePrice;
  final RentalPricingUnit pricingUnit;  // hourly, daily, weekly, monthly
  final String currencyCode;
  final List<String> photos;
  final List<String> videos;
  final bool isAvailable;
  final int stockQty;  // Number of units available
  
  // Rental-specific
  final double? depositAmount;
  final int bufferMinutes;  // Time between rentals
  final bool requiresLicense;
  final String? termsAndConditions;
  
  // Vehicle-specific (optional)
  final String? make;
  final String? model;
  final String? year;
  final String? color;
  final String? licensePlate;
  final String? vin;
  
  // Metadata
  final int sortOrder;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  RentalCatalogItem({
    required this.id,
    required this.listingId,
    required this.name,
    this.description,
    this.category = '',
    required this.basePrice,
    this.pricingUnit = RentalPricingUnit.daily,
    this.currencyCode = 'USD',
    this.photos = const [],
    this.videos = const [],
    this.isAvailable = true,
    this.stockQty = 1,
    this.depositAmount,
    this.bufferMinutes = 30,
    this.requiresLicense = false,
    this.termsAndConditions,
    this.make,
    this.model,
    this.year,
    this.color,
    this.licensePlate,
    this.vin,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory RentalCatalogItem.fromJson(Map<String, dynamic> json, [String? docId]) {
    return RentalCatalogItem(
      id: docId ?? json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? '',
      basePrice: (json['basePrice'] ?? 0).toDouble(),
      pricingUnit: RentalPricingUnit.values.firstWhere(
        (e) => e.toString() == 'RentalPricingUnit.${json['pricingUnit']}',
        orElse: () => RentalPricingUnit.daily,
      ),
      currencyCode: json['currencyCode'] ?? 'USD',
      photos: List<String>.from(json['photos'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      isAvailable: json['isAvailable'] ?? true,
      stockQty: json['stockQty'] ?? 1,
      depositAmount: json['depositAmount'] != null ? (json['depositAmount'] as num).toDouble() : null,
      bufferMinutes: json['bufferMinutes'] ?? 30,
      requiresLicense: json['requiresLicense'] ?? false,
      termsAndConditions: json['termsAndConditions'],
      make: json['make'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      licensePlate: json['licensePlate'],
      vin: json['vin'],
      sortOrder: json['sortOrder'] ?? 0,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'name': name,
      'description': description,
      'category': category,
      'basePrice': basePrice,
      'pricingUnit': pricingUnit.toString().split('.').last,
      'currencyCode': currencyCode,
      'photos': photos,
      'videos': videos,
      'isAvailable': isAvailable,
      'stockQty': stockQty,
      'depositAmount': depositAmount,
      'bufferMinutes': bufferMinutes,
      'requiresLicense': requiresLicense,
      'termsAndConditions': termsAndConditions,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'vin': vin,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  RentalCatalogItem copyWith({
    String? id,
    String? listingId,
    String? name,
    String? description,
    String? category,
    double? basePrice,
    RentalPricingUnit? pricingUnit,
    String? currencyCode,
    List<String>? photos,
    List<String>? videos,
    bool? isAvailable,
    int? stockQty,
    double? depositAmount,
    int? bufferMinutes,
    bool? requiresLicense,
    String? termsAndConditions,
    String? make,
    String? model,
    String? year,
    String? color,
    String? licensePlate,
    String? vin,
    int? sortOrder,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return RentalCatalogItem(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      basePrice: basePrice ?? this.basePrice,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      currencyCode: currencyCode ?? this.currencyCode,
      photos: photos ?? this.photos,
      videos: videos ?? this.videos,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQty: stockQty ?? this.stockQty,
      depositAmount: depositAmount ?? this.depositAmount,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      requiresLicense: requiresLicense ?? this.requiresLicense,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isVehicle => make != null || model != null || year != null;
}
