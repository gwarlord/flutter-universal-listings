import 'package:cloud_firestore/cloud_firestore.dart';

class DealAdModel {
  final String id;
  final String listerId;
  final String listingId;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? thumbnailUrl;
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
  final String adType; // 'advert' or 'promo'
  final List<String> visibilityCountries; // List of country codes, empty = all

  DealAdModel({
    required this.id,
    required this.listerId,
    required this.listingId,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
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
    this.adType = 'promo',
    this.visibilityCountries = const [],
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'listerId': listerId,
    'listingId': listingId,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'thumbnailUrl': thumbnailUrl,
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
    'adType': adType,
    'visibilityCountries': visibilityCountries,
  };

  factory DealAdModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DealAdModel(
      id: doc.id,
      listerId: data['listerId'] ?? '',
      listingId: data['listingId'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      thumbnailUrl: data['thumbnailUrl'] as String?, // Explicitly cast to String?
      caption: data['caption'] ?? '',
      durationDays: data['durationDays'] ?? 0,
      pricePaid: (data['pricePaid'] as num?)?.toDouble() ?? 0.0,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: data['approvedAt'] != null ? (data['approvedAt'] as Timestamp).toDate() : null,
      reviewerId: data['reviewerId'],
      authorID: data['authorID'] ?? '',
      adType: data['adType'] ?? 'promo',
      visibilityCountries: List<String>.from(data['visibilityCountries'] ?? []),
    );
  }
}
