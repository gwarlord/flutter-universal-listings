import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';

class DealAdAdminService {
  final _adsRef = FirebaseFirestore.instance.collection('deal_ads');

  Stream<List<DealAdModel>> getPendingAds() {
    return _adsRef.where('status', isEqualTo: 'pending').snapshots().map(
      (snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList(),
    );
  }

  Future<void> approveAd(String adId, String reviewerId) async {
    try {
      // Fetch and print the ad document before updating
      final adDoc = await _adsRef.doc(adId).get();
      print('********** FIRESTORE DEBUG **********');
      print('deal_ads/$adId before update: ${adDoc.data()}');
      print('*************************************');
      final updatePayload = {
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
      };
      print('Attempting to update deal_ads/$adId with: $updatePayload');
      await _adsRef.doc(adId).update(updatePayload);
    } catch (e, stack) {
      print('Failed to approve ad $adId: $e\n$stack');
      rethrow;
    }
  }

  Future<void> rejectAd(String adId, String reviewerId) async {
    try {
      final updatePayload = {
        'status': 'rejected',
        'approvedAt': FieldValue.serverTimestamp(),
        'reviewerId': reviewerId,
      };
        print('Attempting to update deal_ads/$adId with: $updatePayload');
      await _adsRef.doc(adId).update(updatePayload);
    } catch (e, stack) {
      print('Failed to reject ad $adId: $e\n$stack');
      rethrow;
    }
  }
}
