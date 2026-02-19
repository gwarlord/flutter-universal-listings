import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore;

  ClientService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _clientsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('clients');
  }

  Stream<List<ClientModel>> streamClients(String uid) {
    return _clientsRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClientModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<ClientModel?> getClient(String uid, String clientId) async {
    final doc = await _clientsRef(uid).doc(clientId).get();
    if (!doc.exists) return null;
    return ClientModel.fromJson(doc.data()!, doc.id);
  }

  Future<String> createClient(String uid, ClientModel client) async {
    final now = DateTime.now();
    final docRef = _clientsRef(uid).doc();
    await docRef.set(client.copyWith(createdAt: now, updatedAt: now).toJson());
    return docRef.id;
  }

  Future<void> updateClient(String uid, ClientModel client) async {
    await _clientsRef(uid).doc(client.id).update(
          client.copyWith(updatedAt: DateTime.now()).toJson(),
        );
  }

  Future<void> deleteClient(String uid, String clientId) async {
    await _clientsRef(uid).doc(clientId).delete();
  }
}
