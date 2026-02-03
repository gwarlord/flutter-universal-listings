// MenuService for CaribTap Menu module
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MenuService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> setMenuEnabled(String listingId, bool enabled) async {
    await _firestore.collection('listings').doc(listingId).set({
      'menuEnabled': enabled,
      'menuUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> uploadMenuUploadImage(String listingId, File file) async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('listings/$listingId/menuUploads/$uuid.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadMenuItemImage(String listingId, String itemId, File file) async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('listings/$listingId/menuItems/$itemId/$uuid.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> updateMenuUploads(String listingId, List uploads) async {
    await _firestore.collection('listings').doc(listingId).set({
      'menuUploads': uploads,
      'menuUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateMenuSections(String listingId, List sections) async {
    await _firestore.collection('listings').doc(listingId).set({
      'menuSections': sections,
      'menuUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
