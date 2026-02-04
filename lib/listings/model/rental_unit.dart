import 'package:cloud_firestore/cloud_firestore.dart';

enum RentalUnitStatus {
  available,
  rented,
  maintenance,
  unavailable,
}

class RentalUnit {
  final String id;
  final String listingId;
  final String unitName; // e.g., "Unit 1", "Red Honda Civic", "Drill Set A"
  final String? description;
  final List<String> photoUrls;
  final RentalUnitStatus status;
  
  // Vehicle-specific fields
  final String? licensePlate;
  final String? vin;
  final int? currentOdometer;
  final String? fuelLevel; // "Full", "3/4", "1/2", "1/4", "Empty"
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  RentalUnit({
    required this.id,
    required this.listingId,
    required this.unitName,
    this.description,
    this.photoUrls = const [],
    required this.status,
    this.licensePlate,
    this.vin,
    this.currentOdometer,
    this.fuelLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RentalUnit.fromJson(Map<String, dynamic> json, String id) {
    return RentalUnit(
      id: id,
      listingId: json['listingId'] ?? '',
      unitName: json['unitName'] ?? '',
      description: json['description'],
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
      status: RentalUnitStatus.values.firstWhere(
        (e) => e.toString() == 'RentalUnitStatus.${json['status']}',
        orElse: () => RentalUnitStatus.available,
      ),
      licensePlate: json['licensePlate'],
      vin: json['vin'],
      currentOdometer: json['currentOdometer'],
      fuelLevel: json['fuelLevel'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'unitName': unitName,
      'description': description,
      'photoUrls': photoUrls,
      'status': status.toString().split('.').last,
      'licensePlate': licensePlate,
      'vin': vin,
      'currentOdometer': currentOdometer,
      'fuelLevel': fuelLevel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RentalUnit copyWith({
    String? id,
    String? listingId,
    String? unitName,
    String? description,
    List<String>? photoUrls,
    RentalUnitStatus? status,
    String? licensePlate,
    String? vin,
    int? currentOdometer,
    String? fuelLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentalUnit(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      unitName: unitName ?? this.unitName,
      description: description ?? this.description,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      licensePlate: licensePlate ?? this.licensePlate,
      vin: vin ?? this.vin,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
