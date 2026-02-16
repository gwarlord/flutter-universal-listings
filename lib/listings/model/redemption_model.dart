import 'package:cloud_firestore/cloud_firestore.dart';

class Redemption {
  final String dealId;
  final Timestamp redeemedAt;

  Redemption({required this.dealId, required this.redeemedAt});

  factory Redemption.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Redemption(
      dealId: doc.id,
      redeemedAt: data['redeemedAt'] as Timestamp,
    );
  }
}
