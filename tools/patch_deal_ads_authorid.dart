// Patch all deal_ads in Firestore to add authorID field (set to listerId)
// Run this script with `dart run` or in a Dart environment with Firebase Admin SDK

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  final ads = await firestore.collection('deal_ads').get();
  for (final doc in ads.docs) {
    final data = doc.data();
    if (!data.containsKey('authorID') && data.containsKey('listerId')) {
      print('Patching ${doc.id} with authorID: ${data['listerId']}');
      await doc.reference.update({'authorID': data['listerId']});
    }
  }
  print('Patch complete.');
}
