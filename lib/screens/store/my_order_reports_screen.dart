import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/reported_listing_model.dart';

class MyOrderReportsScreen extends StatelessWidget {
  final ListingsUser currentUser;

  const MyOrderReportsScreen({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        title: Text(
          'My Reports'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('reporterId', isEqualTo: currentUser.userID)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(dark);
          }

          final reports = snapshot.data!.docs
              .map((doc) => ReportedListing.fromSnapshot(doc))
              .where((report) => report.reportType == 'order_fulfillment_issue')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (reports.isEmpty) {
            return _buildEmptyState(dark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return _buildReportCard(context, report, dark);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool dark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fact_check_outlined,
              size: 64,
              color: dark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              'No Reports Yet'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your fulfillment issue reports will appear here.'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
      BuildContext context, ReportedListing report, bool dark) {
    final createdAt = report.createdAt.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<String>(
                  future: _resolveDisplayStatus(report),
                  builder: (context, snapshot) =>
                      _buildStatusChip(snapshot.data ?? report.status.toLowerCase()),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (report.orderId != null && report.orderId!.isNotEmpty)
              Text(
                'Order #${_shortOrderId(report.orderId!)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.orange[300] : Colors.orange[800],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              report.listingTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.reason,
              style: TextStyle(
                fontSize: 14,
                color: dark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _resolveDisplayStatus(ReportedListing report) async {
    final rawStatus = report.status.toLowerCase();
    if (rawStatus != 'dismissed' || !report.isOrderFulfillmentIssue) {
      return rawStatus;
    }

    if (report.listingId.isEmpty) {
      return rawStatus;
    }

    try {
      final listingDoc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(report.listingId)
          .get();

      if (!listingDoc.exists) {
        return rawStatus;
      }

      final data = listingDoc.data();
      if (data == null || data['suspended'] != true) {
        return rawStatus;
      }

      final suspensionInfo = data['suspensionInfo'] as Map<String, dynamic>?;
      final reasonText = (suspensionInfo?['reasonText'] as String?)?.trim() ?? '';
      final orderId = report.orderId?.trim() ?? '';

      if (reasonText.isEmpty) {
        return rawStatus;
      }

      final matchesOrder = orderId.isNotEmpty && reasonText.contains(orderId);
      final isFraudSuspension = reasonText.toLowerCase().contains('order fulfillment fraud report');

      if (matchesOrder || isFraudSuspension) {
        return 'resolved';
      }
    } catch (_) {
      return rawStatus;
    }

    return rawStatus;
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'dismissed':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Dismissed'.tr();
        break;
      case 'reviewed':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        label = 'Reviewed'.tr();
        break;
      case 'resolved':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'Action Taken'.tr();
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFEF6C00);
        label = 'Pending'.tr();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _shortOrderId(String orderId) {
    if (orderId.length <= 8) {
      return orderId.toUpperCase();
    }
    return orderId.substring(0, 8).toUpperCase();
  }
}
