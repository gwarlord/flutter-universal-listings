import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ShareLinkService {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ShareLinkService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createPublicDoc({
    required String ownerUid,
    required String type,
    required String docId,
    Duration? expiresIn,
    Map<String, dynamic>? snapshot,
  }) async {
    final token = _uuid.v4();
    final now = DateTime.now();
    final data = <String, dynamic>{
      'type': type,
      'ownerUid': ownerUid,
      'docId': docId,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': expiresIn != null ? Timestamp.fromDate(now.add(expiresIn)) : null,
    };

    if (snapshot != null) {
      data['snapshot'] = snapshot;
    }

    await _firestore.collection('public_docs').doc(token).set(data);
    return token;
  }

  String buildPublicDocLink({
    required String type,
    required String token,
  }) {
    return 'caribtap://prodoc/$type/$token';
  }
}
