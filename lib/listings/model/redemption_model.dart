import 'package:cloud_firestore/cloud_firestore.dart';

class Redemption {
  final String dealId;
  final Timestamp redeemedAt;

  Redemption({required this.dealId, required this.redeemedAt});

  factory Redemption.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final timestamp = (data['redeemedAt'] ?? data['lastClaimedAt']) as Timestamp?;
    return Redemption(
      dealId: doc.id,
      redeemedAt: timestamp ?? Timestamp.now(),
    );
  }
}
