import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/deal_ad_model.dart';

class DealAdService {
  final _adsRef = FirebaseFirestore.instance.collection('deal_ads');

  Future<void> submitAd(DealAdModel ad) async {
    await _adsRef.doc(ad.id).set(ad.toMap());
  }

  Future<void> deleteAd(String adId) async {
    await _adsRef.doc(adId).delete();
  }

  Stream<List<DealAdModel>> getPendingAds() {
    return _adsRef.where('status', isEqualTo: 'pending').snapshots().map(
      (snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList(),
    );
  }

  Stream<List<DealAdModel>> getApprovedAds() {
    return _adsRef.where('status', isEqualTo: 'approved').orderBy('approvedAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((doc) => DealAdModel.fromDoc(doc)).toList(),
    );
  }

  Future<void> approveAd(String adId, String reviewerId) async {
    await _adsRef.doc(adId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'reviewerId': reviewerId,
    });
  }

  Future<void> rejectAd(String adId, String reviewerId) async {
    await _adsRef.doc(adId).update({
      'status': 'rejected',
      'approvedAt': FieldValue.serverTimestamp(),
      'reviewerId': reviewerId,
    });
  }
}
