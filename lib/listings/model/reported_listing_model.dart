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
  final String reportType;
  final String? orderId;
  final String? orderStatus;

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
    this.reportType = 'listing',
    this.orderId,
    this.orderStatus,
  });

  bool get isOrderFulfillmentIssue => reportType == 'order_fulfillment_issue';

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
      reportType: data['reportType'] ?? 'listing',
      orderId: data['orderId'] as String?,
      orderStatus: data['orderStatus'] as String?,
    );
  }
}
