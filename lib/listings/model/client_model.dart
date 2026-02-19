import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';

class ClientModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String companyName;
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.companyName,
    required this.address,
    this.createdAt,
    this.updatedAt,
  });

  ClientSnapshot toSnapshot() {
    return ClientSnapshot(
      name: name,
      email: email,
      phone: phone,
      companyName: companyName,
      address: address,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'companyName': companyName,
      'address': address,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory ClientModel.fromJson(Map<String, dynamic> json, String docId) {
    return ClientModel(
      id: docId,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? companyName,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
