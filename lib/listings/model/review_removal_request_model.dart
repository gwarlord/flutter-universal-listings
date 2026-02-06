import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewRemovalRequestModel {
  String id;
  String reviewId;
  String listingId;
  String listerId;
  String reviewerId;
  String reasonCategory;
  String reasonText;
  String status; // PENDING, APPROVED, REJECTED
  int createdAt;
  int? updatedAt;
  String? adminId;
  String? adminNotes;
  String? rejectionReasonVisibleToLister;

  ReviewRemovalRequestModel({
    this.id = '',
    required this.reviewId,
    required this.listingId,
    required this.listerId,
    required this.reviewerId,
    required this.reasonCategory,
    required this.reasonText,
    this.status = 'PENDING',
    int? createdAt,
    this.updatedAt,
    this.adminId,
    this.adminNotes,
    this.rejectionReasonVisibleToLister,
  }) : createdAt = createdAt ?? Timestamp.now().seconds;

  factory ReviewRemovalRequestModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewRemovalRequestModel(
      id: doc.id,
      reviewId: data['reviewId'] ?? '',
      listingId: data['listingId'] ?? '',
      listerId: data['listerId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reasonCategory: data['reasonCategory'] ?? '',
      reasonText: data['reasonText'] ?? '',
      status: data['status'] ?? 'PENDING',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).seconds
          : data['createdAt'],
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).seconds
          : data['updatedAt'],
      adminId: data['adminId'],
      adminNotes: data['adminNotes'],
      rejectionReasonVisibleToLister: data['rejectionReasonVisibleToLister'],
    );
  }

  factory ReviewRemovalRequestModel.fromJson(Map<String, dynamic> json) {
    return ReviewRemovalRequestModel(
      id: json['id'] ?? '',
      reviewId: json['reviewId'] ?? '',
      listingId: json['listingId'] ?? '',
      listerId: json['listerId'] ?? '',
      reviewerId: json['reviewerId'] ?? '',
      reasonCategory: json['reasonCategory'] ?? '',
      reasonText: json['reasonText'] ?? '',
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).seconds
          : json['createdAt'],
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).seconds
          : json['updatedAt'],
      adminId: json['adminId'],
      adminNotes: json['adminNotes'],
      rejectionReasonVisibleToLister: json['rejectionReasonVisibleToLister'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'listingId': listingId,
      'listerId': listerId,
      'reviewerId': reviewerId,
      'reasonCategory': reasonCategory,
      'reasonText': reasonText,
      'status': status,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (adminId != null) 'adminId': adminId,
      if (adminNotes != null) 'adminNotes': adminNotes,
      if (rejectionReasonVisibleToLister != null)
        'rejectionReasonVisibleToLister': rejectionReasonVisibleToLister,
    };
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  String get statusDisplay {
    switch (status) {
      case 'PENDING':
        return 'Pending Review';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }
}
