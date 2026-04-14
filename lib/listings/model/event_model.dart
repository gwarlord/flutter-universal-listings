import 'package:cloud_firestore/cloud_firestore.dart';

class TicketType {
  String name;
  double price;
  String currency;
  int? salesDeadlineSeconds;
  String description;

  TicketType({
    this.name = '',
    this.price = 0.0,
    this.currency = 'USD',
    this.salesDeadlineSeconds,
    this.description = '',
  });

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: (json['currency'] ?? 'USD').toString(),
      salesDeadlineSeconds: json['salesDeadlineSeconds'] as int?,
      description: (json['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'currency': currency,
      'salesDeadlineSeconds': salesDeadlineSeconds,
      'description': description,
    };
  }
}

class CommitteeMember {
  String name;
  String contactNumber;
  bool hasWhatsapp;

  CommitteeMember({
    this.name = '',
    this.contactNumber = '',
    this.hasWhatsapp = false,
  });

  factory CommitteeMember.fromJson(Map<String, dynamic> json) {
    return CommitteeMember(
      name: (json['name'] ?? '').toString(),
      contactNumber: (json['contactNumber'] ?? '').toString(),
      hasWhatsapp: json['hasWhatsapp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contactNumber': contactNumber,
      'hasWhatsapp': hasWhatsapp,
    };
  }
}

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
  String ticketInstructions;
  String ticketUrl;
  String facebookUrl;
  String instagramUrl;
  String committee;
  List<TicketType> ticketTypes;
  List<CommitteeMember> committeeMembers;
  bool isDemo;
  bool isFlagged;
  bool isFav;

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
    this.ticketInstructions = '',
    this.ticketUrl = '',
    this.facebookUrl = '',
    this.instagramUrl = '',
    this.committee = '',
    this.ticketTypes = const [],
    this.committeeMembers = const [],
    this.isDemo = false,
    this.isFlagged = false,
    this.isFav = false,
  })  : createdAtSeconds = createdAtSeconds ?? Timestamp.now().seconds,
        startAtSeconds = startAtSeconds ?? Timestamp.now().seconds,
        endAtSeconds = endAtSeconds ?? Timestamp.now().seconds;

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final geoPoint = json['geoPoint'] as GeoPoint?;
    final ticketsRaw = json['ticketTypes'] as List<dynamic>? ?? [];
    final membersRaw = json['committeeMembers'] as List<dynamic>? ?? [];

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
      ticketInstructions: (json['ticketInstructions'] ?? '').toString(),
      ticketUrl: (json['ticketUrl'] ?? '').toString(),
      facebookUrl: (json['facebookUrl'] ?? '').toString(),
      instagramUrl: (json['instagramUrl'] ?? '').toString(),
      committee: (json['committee'] ?? '').toString(),
      ticketTypes: ticketsRaw.map((e) => TicketType.fromJson(e as Map<String, dynamic>)).toList(),
      committeeMembers: membersRaw.map((e) => CommitteeMember.fromJson(e as Map<String, dynamic>)).toList(),
      isDemo: json['isDemo'] as bool? ?? false,
      isFlagged: json['isFlagged'] as bool? ?? false,
      isFav: json['isFav'] as bool? ?? false,
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
      'ticketInstructions': ticketInstructions,
      'ticketUrl': ticketUrl,
      'facebookUrl': facebookUrl,
      'instagramUrl': instagramUrl,
      'committee': committee,
      'ticketTypes': ticketTypes.map((e) => e.toJson()).toList(),
      'committeeMembers': committeeMembers.map((e) => e.toJson()).toList(),
      'isDemo': isDemo,
      'isFlagged': isFlagged,
    }..remove('isFav');
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
