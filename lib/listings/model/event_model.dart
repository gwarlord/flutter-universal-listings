import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  String id;
  String title;
  String description;
  String createdBy;
  int createdAtSeconds;
  int startAtSeconds;
  int endAtSeconds;
  double latitude;
  double longitude;
  String venueName;
  String countryCode;
  String posterImageUrl;
  String status;

  EventModel({
    this.id = '',
    this.title = '',
    this.description = '',
    this.createdBy = '',
    int? createdAtSeconds,
    int? startAtSeconds,
    int? endAtSeconds,
    this.latitude = 0,
    this.longitude = 0,
    this.venueName = '',
    this.countryCode = '',
    this.posterImageUrl = '',
    this.status = 'active',
  })  : createdAtSeconds = createdAtSeconds ?? Timestamp.now().seconds,
        startAtSeconds = startAtSeconds ?? Timestamp.now().seconds,
        endAtSeconds = endAtSeconds ?? Timestamp.now().seconds;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final geoPoint = json['geoPoint'] as GeoPoint?;

    return EventModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
      createdAtSeconds: _parseSeconds(json['createdAtSeconds']),
      startAtSeconds: _parseSeconds(json['startAtSeconds']),
      endAtSeconds: _parseSeconds(json['endAtSeconds']),
      latitude: (json['latitude'] as num?)?.toDouble() ?? geoPoint?.latitude ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? geoPoint?.longitude ?? 0,
      venueName: (json['venueName'] ?? '').toString(),
      countryCode: (json['countryCode'] ?? '').toString(),
      posterImageUrl: (json['posterImageUrl'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAtSeconds': createdAtSeconds,
      'startAtSeconds': startAtSeconds,
      'endAtSeconds': endAtSeconds,
      'latitude': latitude,
      'longitude': longitude,
      'geoPoint': GeoPoint(latitude, longitude),
      'venueName': venueName,
      'countryCode': countryCode,
      'posterImageUrl': posterImageUrl,
      'status': status,
    };
  }

  static int _parseSeconds(dynamic raw) {
    if (raw is Timestamp) {
      return raw.seconds;
    }
    if (raw is num) {
      final value = raw.toInt();
      return value > 10000000000 ? (value ~/ 1000) : value;
    }
    return Timestamp.now().seconds;
  }
}
