import 'package:cloud_firestore/cloud_firestore.dart';

enum RentalType { general, vehicle }

enum RentalPricingUnit {
  hourly,
  daily,
  weekly,
  monthly,
}

class RentalConfig {
  final bool isRentalEnabled;
  final RentalType rentalType;
  final RentalPricingUnit defaultPricingUnit;
  final double basePrice; // Price per unit
  final int bufferMinutes; // Buffer between bookings
  final bool requiresDeposit;
  final double? depositAmount;
  final bool requiresLicense; // For vehicles
  final int? dailyMileageLimit; // For vehicles
  final double? overagePricePerKm; // For vehicles
  final String? termsAndConditions;

  RentalConfig({
    required this.isRentalEnabled,
    required this.rentalType,
    required this.defaultPricingUnit,
    required this.basePrice,
    this.bufferMinutes = 30,
    this.requiresDeposit = false,
    this.depositAmount,
    this.requiresLicense = false,
    this.dailyMileageLimit,
    this.overagePricePerKm,
    this.termsAndConditions,
  });

  factory RentalConfig.fromJson(Map<String, dynamic> json) {
    return RentalConfig(
      isRentalEnabled: json['isRentalEnabled'] ?? false,
      rentalType: RentalType.values.firstWhere(
        (e) => e.toString() == 'RentalType.${json['rentalType']}',
        orElse: () => RentalType.general,
      ),
      defaultPricingUnit: RentalPricingUnit.values.firstWhere(
        (e) => e.toString() == 'RentalPricingUnit.${json['defaultPricingUnit']}',
        orElse: () => RentalPricingUnit.daily,
      ),
      basePrice: (json['basePrice'] ?? 0.0).toDouble(),
      bufferMinutes: json['bufferMinutes'] ?? 30,
      requiresDeposit: json['requiresDeposit'] ?? false,
      depositAmount: json['depositAmount']?.toDouble(),
      requiresLicense: json['requiresLicense'] ?? false,
      dailyMileageLimit: json['dailyMileageLimit'],
      overagePricePerKm: json['overagePricePerKm']?.toDouble(),
      termsAndConditions: json['termsAndConditions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isRentalEnabled': isRentalEnabled,
      'rentalType': rentalType.toString().split('.').last,
      'defaultPricingUnit': defaultPricingUnit.toString().split('.').last,
      'basePrice': basePrice,
      'bufferMinutes': bufferMinutes,
      'requiresDeposit': requiresDeposit,
      'depositAmount': depositAmount,
      'requiresLicense': requiresLicense,
      'dailyMileageLimit': dailyMileageLimit,
      'overagePricePerKm': overagePricePerKm,
      'termsAndConditions': termsAndConditions,
    };
  }

  RentalConfig copyWith({
    bool? isRentalEnabled,
    RentalType? rentalType,
    RentalPricingUnit? defaultPricingUnit,
    double? basePrice,
    int? bufferMinutes,
    bool? requiresDeposit,
    double? depositAmount,
    bool? requiresLicense,
    int? dailyMileageLimit,
    double? overagePricePerKm,
    String? termsAndConditions,
  }) {
    return RentalConfig(
      isRentalEnabled: isRentalEnabled ?? this.isRentalEnabled,
      rentalType: rentalType ?? this.rentalType,
      defaultPricingUnit: defaultPricingUnit ?? this.defaultPricingUnit,
      basePrice: basePrice ?? this.basePrice,
      bufferMinutes: bufferMinutes ?? this.bufferMinutes,
      requiresDeposit: requiresDeposit ?? this.requiresDeposit,
      depositAmount: depositAmount ?? this.depositAmount,
      requiresLicense: requiresLicense ?? this.requiresLicense,
      dailyMileageLimit: dailyMileageLimit ?? this.dailyMileageLimit,
      overagePricePerKm: overagePricePerKm ?? this.overagePricePerKm,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }
}
