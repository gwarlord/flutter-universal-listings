import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../model/listing_model.dart';
import 'opening_hours_migration.dart';

Future<void> migrateListingsOpeningHours() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('listings')
      .get();

  for (final doc in snapshot.docs) {
    final data = doc.data();

    // Skip if already migrated
    if (data.containsKey('openingHoursV2')) continue;

    final legacy = data['openingHours'];
    if (legacy == null || legacy.toString().trim().isEmpty) continue;

    final migrated = migrateLegacyOpeningHours(legacy);

    await doc.reference.update({
      'openingHoursV2': migrated.toJson(),
    });

    debugPrint('Migrated listing ${doc.id}');
  }
}
