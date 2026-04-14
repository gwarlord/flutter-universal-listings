import 'package:cloud_firestore/cloud_firestore.dart';

class SuspensionReasonDetailsResolver {
  static final Map<String, Future<String?>> _cache =
      <String, Future<String?>>{};

  static Future<String?> resolve({
    required String? reasonText,
    String? listingId,
  }) {
    final trimmed = reasonText?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return Future.value(null);
    }

    final cacheKey = '${listingId ?? ''}|$trimmed';
    return _cache.putIfAbsent(
      cacheKey,
      () => _resolveInternal(reasonText: trimmed, listingId: listingId),
    );
  }

  static Future<String?> _resolveInternal({
    required String reasonText,
    String? listingId,
  }) async {
    if (!_isLegacyOrderFraudReason(reasonText)) {
      return reasonText;
    }

    final orderId = _extractOrderId(reasonText);
    if (orderId == null || orderId.isEmpty) {
      return reasonText;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('orderId', isEqualTo: orderId)
          .limit(10)
          .get();

      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        if (data['reportType'] != 'order_fulfillment_issue') {
          return false;
        }
        if (listingId == null || listingId.isEmpty) {
          return true;
        }
        return data['listingId'] == listingId;
      }).toList();

      if (matchingDocs.isEmpty) {
        return reasonText;
      }

      matchingDocs.sort((a, b) {
        final aCreatedAt = a.data()['createdAt'];
        final bCreatedAt = b.data()['createdAt'];
        final aMillis = aCreatedAt is Timestamp
            ? aCreatedAt.millisecondsSinceEpoch
            : 0;
        final bMillis = bCreatedAt is Timestamp
            ? bCreatedAt.millisecondsSinceEpoch
            : 0;
        return bMillis.compareTo(aMillis);
      });

      final data = matchingDocs.first.data();
      final details = <String>[
        'Order fulfillment fraud report',
        'Order ID: $orderId',
      ];

      final orderStatus = (data['orderStatus'] as String?)?.trim();
      if (orderStatus != null && orderStatus.isNotEmpty) {
        details.add('Order status: $orderStatus');
      }

      final reporterName = (data['reporterName'] as String?)?.trim();
      if (reporterName != null && reporterName.isNotEmpty) {
        details.add('Reported by: $reporterName');
      }

      final reason = (data['reason'] as String?)?.trim();
      if (reason != null && reason.isNotEmpty) {
        details.add('Reported issue: $reason');
      }

      return details.join('\n');
    } catch (_) {
      return reasonText;
    }
  }

  static bool _isLegacyOrderFraudReason(String reasonText) {
    return reasonText.startsWith('Order fulfillment fraud report:') &&
        !reasonText.contains('Reported issue:') &&
        !reasonText.contains('Reported by:');
  }

  static String? _extractOrderId(String reasonText) {
    final match = RegExp(r'Order fulfillment fraud report:\s*([A-Za-z0-9-]+)')
        .firstMatch(reasonText);
    return match?.group(1);
  }
}