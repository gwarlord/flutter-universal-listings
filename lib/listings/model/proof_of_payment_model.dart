import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single proof of payment upload
class ProofOfPaymentUpload {
  String fileUrl;
  String filePath; // Storage path for cleanup
  String fileType; // "IMAGE" or "PDF"
  String? fileName;
  Timestamp uploadedAt;
  String uploadedByUid; // Customer/uploader's UID
  String status; // "SUBMITTED", "VERIFIED", "REJECTED"
  String? reviewerUid;
  Timestamp? reviewedAt;
  String? reviewerNote;

  ProofOfPaymentUpload({
    required this.fileUrl,
    required this.filePath,
    required this.fileType,
    this.fileName,
    required this.uploadedAt,
    required this.uploadedByUid,
    this.status = "SUBMITTED",
    this.reviewerUid,
    this.reviewedAt,
    this.reviewerNote,
  });

  factory ProofOfPaymentUpload.fromJson(Map<String, dynamic> json) {
    return ProofOfPaymentUpload(
      fileUrl: json['fileUrl'] ?? '',
      filePath: json['filePath'] ?? '',
      fileType: json['fileType'] ?? 'IMAGE',
      fileName: json['fileName'],
      uploadedAt: json['uploadedAt'] is Timestamp
          ? json['uploadedAt']
          : Timestamp.now(),
      uploadedByUid: json['uploadedByUid'] ?? '',
      status: json['status'] ?? 'SUBMITTED',
      reviewerUid: json['reviewerUid'],
      reviewedAt: json['reviewedAt'] is Timestamp
          ? json['reviewedAt']
          : null,
      reviewerNote: json['reviewerNote'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileUrl': fileUrl,
      'filePath': filePath,
      'fileType': fileType,
      'fileName': fileName,
      'uploadedAt': uploadedAt,
      'uploadedByUid': uploadedByUid,
      'status': status,
      'reviewerUid': reviewerUid,
      'reviewedAt': reviewedAt,
      'reviewerNote': reviewerNote,
    };
  }

  ProofOfPaymentUpload copyWith({
    String? fileUrl,
    String? filePath,
    String? fileType,
    String? fileName,
    Timestamp? uploadedAt,
    String? uploadedByUid,
    String? status,
    String? reviewerUid,
    Timestamp? reviewedAt,
    String? reviewerNote,
  }) {
    return ProofOfPaymentUpload(
      fileUrl: fileUrl ?? this.fileUrl,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedByUid: uploadedByUid ?? this.uploadedByUid,
      status: status ?? this.status,
      reviewerUid: reviewerUid ?? this.reviewerUid,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewerNote: reviewerNote ?? this.reviewerNote,
    );
  }
}

/// Main proof of payment object stored in order document
class ProofOfPayment {
  bool enabledAtOrderTime; // Snapshot of listing setting at order creation
  List<ProofOfPaymentUpload> uploads;
  String overallStatus; // "NONE", "SUBMITTED", "VERIFIED", "REJECTED"

  ProofOfPayment({
    this.enabledAtOrderTime = false,
    List<ProofOfPaymentUpload>? uploads,
    this.overallStatus = "NONE",
  }) : uploads = uploads ?? [];

  factory ProofOfPayment.fromJson(Map<String, dynamic> json) {
    final uploadsList = (json['uploads'] as List<dynamic>?)
            ?.map((u) => ProofOfPaymentUpload.fromJson(u as Map<String, dynamic>))
            .toList() ??
        [];

    return ProofOfPayment(
      enabledAtOrderTime: json['enabledAtOrderTime'] ?? false,
      uploads: uploadsList,
      overallStatus: json['overallStatus'] ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabledAtOrderTime': enabledAtOrderTime,
      'uploads': uploads.map((u) => u.toJson()).toList(),
      'overallStatus': overallStatus,
    };
  }

  ProofOfPayment copyWith({
    bool? enabledAtOrderTime,
    List<ProofOfPaymentUpload>? uploads,
    String? overallStatus,
  }) {
    return ProofOfPayment(
      enabledAtOrderTime: enabledAtOrderTime ?? this.enabledAtOrderTime,
      uploads: uploads ?? this.uploads,
      overallStatus: overallStatus ?? this.overallStatus,
    );
  }

  /// Get the latest upload (most recent)
  ProofOfPaymentUpload? getLatestUpload() {
    if (uploads.isEmpty) return null;
    return uploads.reduce((a, b) {
      final aTime = a.uploadedAt.toDate();
      final bTime = b.uploadedAt.toDate();
      return aTime.isAfter(bTime) ? a : b;
    });
  }

  /// Check if visible to customer (always visible if POP was ever interacted with)
  /// Shows UI for uploading even if feature wasn't enabled at order time
  bool get isVisibleToCustomer => true;

  /// Check if POP has been uploaded
  bool get hasUploads => uploads.isNotEmpty;

  /// Check if any upload is verified
  bool get isVerified => overallStatus == 'VERIFIED';

  /// Check if any upload is rejected
  bool get isRejected => overallStatus == 'REJECTED';

  /// Check if any upload is submitted awaiting review
  bool get isSubmitted => overallStatus == 'SUBMITTED';
}
