import 'package:cloud_firestore/cloud_firestore.dart';

class ReportedListing {
  final String id;
  final String listingId;
  final String listingTitle;
  final String listingAuthorId;
  final String reporterId;
  final String reporterName;
  final String reason;
  final Timestamp createdAt;
  final String status;

  ReportedListing({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingAuthorId,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.createdAt,
    this.status = 'pending',
  });

  factory ReportedListing.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return ReportedListing(
      id: snapshot.id,
      listingId: data['listingId'] ?? '',
      listingTitle: data['listingTitle'] ?? '',
      listingAuthorId: data['listingAuthorId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      reason: data['reason'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
    );
  }
}
