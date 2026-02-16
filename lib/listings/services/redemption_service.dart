import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instaflutter/listings/model/redemption_model.dart';

class RedemptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetches a specific redemption record if it exists.
  Future<Redemption?> getRedemption(String dealId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('redemptions')
          .doc(dealId)
          .get();

      if (doc.exists) {
        return Redemption.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error checking redemption status: $e');
      return null;
    }
  }

  // Writes a new redemption record to Firestore.
  Future<bool> redeemDeal(String dealId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('redemptions')
          .doc(dealId)
          .set({
        'redeemedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error redeeming deal: $e');
      return false;
    }
  }
}
