import 'package:cloud_firestore/cloud_firestore.dart';

/// Brand model for multi-location business chains
/// Groups multiple listings (locations) under one brand identity
class BrandModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? description;
  final String ownerUid; // User who created/owns the brand
  final bool isVerified; // Admin-only flag
  final bool freshnessExempt; // Admin-only flag to exempt all locations from auto-hide
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  BrandModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.description,
    required this.ownerUid,
    this.isVerified = false,
    this.freshnessExempt = false,
    this.createdAt,
    this.updatedAt,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json, String docId) {
    return BrandModel(
      id: docId,
      name: json['name'] ?? '',
      logoUrl: json['logoUrl'],
      description: json['description'],
      ownerUid: json['ownerUid'] ?? '',
      isVerified: json['isVerified'] ?? false,
      freshnessExempt: json['freshnessExempt'] ?? false,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'description': description,
      'ownerUid': ownerUid,
      'isVerified': isVerified,
      'freshnessExempt': freshnessExempt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  BrandModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? description,
    String? ownerUid,
    bool? isVerified,
    bool? freshnessExempt,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return BrandModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      ownerUid: ownerUid ?? this.ownerUid,
      isVerified: isVerified ?? this.isVerified,
      freshnessExempt: freshnessExempt ?? this.freshnessExempt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
