import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadAdMedia(File file, String listerId, String adId) async {
    final ext = file.path.split('.').last;
    final ref = _storage.ref().child('deal_ads/$listerId/$adId.$ext');
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }
}
