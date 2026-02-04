import 'package:cloud_firestore/cloud_firestore.dart';

enum EvidenceType { checkout, checkin }

enum MediaType { photo, video }

class RentalMedia {
  final String url;
  final MediaType type;
  final DateTime timestamp;
  final String? notes;

  RentalMedia({
    required this.url,
    required this.type,
    required this.timestamp,
    this.notes,
  });

  factory RentalMedia.fromJson(Map<String, dynamic> json) {
    return RentalMedia(
      url: json['url'] ?? '',
      type: MediaType.values.firstWhere(
        (e) => e.toString() == 'MediaType.${json['type']}',
        orElse: () => MediaType.photo,
      ),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'notes': notes,
    };
  }
}

class RentalEvidence {
  final EvidenceType type;
  final List<RentalMedia> media; // Min 2 photos required
  final List<String> checklist; // e.g., ["Keys present", "No visible damage"]
  final bool damageReported;
  final String? damageDescription;
  final List<String> damagePhotoUrls;
  
  // Vehicle-specific
  final int? odometerReading;
  final String? fuelLevel;
  final List<String>? licensePhotoUrls; // For checkout only
  
  final DateTime timestamp;
  final String capturedBy; // userId

  RentalEvidence({
    required this.type,
    required this.media,
    required this.checklist,
    this.damageReported = false,
    this.damageDescription,
    this.damagePhotoUrls = const [],
    this.odometerReading,
    this.fuelLevel,
    this.licensePhotoUrls,
    required this.timestamp,
    required this.capturedBy,
  });

  factory RentalEvidence.fromJson(Map<String, dynamic> json) {
    return RentalEvidence(
      type: EvidenceType.values.firstWhere(
        (e) => e.toString() == 'EvidenceType.${json['type']}',
        orElse: () => EvidenceType.checkout,
      ),
      media: (json['media'] as List?)
              ?.map((m) => RentalMedia.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      checklist: List<String>.from(json['checklist'] ?? []),
      damageReported: json['damageReported'] ?? false,
      damageDescription: json['damageDescription'],
      damagePhotoUrls: List<String>.from(json['damagePhotoUrls'] ?? []),
      odometerReading: json['odometerReading'],
      fuelLevel: json['fuelLevel'],
      licensePhotoUrls: json['licensePhotoUrls'] != null
          ? List<String>.from(json['licensePhotoUrls'])
          : null,
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capturedBy: json['capturedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'media': media.map((m) => m.toJson()).toList(),
      'checklist': checklist,
      'damageReported': damageReported,
      'damageDescription': damageDescription,
      'damagePhotoUrls': damagePhotoUrls,
      'odometerReading': odometerReading,
      'fuelLevel': fuelLevel,
      'licensePhotoUrls': licensePhotoUrls,
      'timestamp': Timestamp.fromDate(timestamp),
      'capturedBy': capturedBy,
    };
  }
}
