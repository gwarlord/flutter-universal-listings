import 'package:cloud_firestore/cloud_firestore.dart';

class DealAdModel {
  final String id;
  final String listerId;
  final String listingId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String caption;
  final int durationDays;
  final double pricePaid;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'approved', 'rejected', 'expired'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? reviewerId;
  final String authorID;

  DealAdModel({
    required this.id,
    required this.listerId,
    required this.listingId,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.durationDays,
    required this.pricePaid,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.reviewerId,
    required this.authorID,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'listerId': listerId,
    'listingId': listingId,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'caption': caption,
    'durationDays': durationDays,
    'pricePaid': pricePaid,
    'startDate': startDate,
    'endDate': endDate,
    'status': status,
    'createdAt': createdAt,
    'approvedAt': approvedAt,
    'reviewerId': reviewerId,
    'authorID': authorID,
  };

  factory DealAdModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DealAdModel(
      id: doc.id,
      listerId: data['listerId'],
      listingId: data['listingId'],
      mediaUrl: data['mediaUrl'],
      mediaType: data['mediaType'],
      caption: data['caption'],
      durationDays: data['durationDays'],
      pricePaid: (data['pricePaid'] as num).toDouble(),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      reviewerId: data['reviewerId'],
      authorID: data['authorID'],
    );
  }
}
