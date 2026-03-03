import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:caribtap/listings/model/event_model.dart';

class EventsFirebaseUtils {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventsCollection =>
      firestore.collection('events');

  Stream<List<EventModel>> watchEvents() {
    return _eventsCollection
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
      try {
        return snapshot.docs.map((doc) {
          final model = EventModel.fromJson(doc.data());
          model.id = doc.id;
          return model;
        }).toList();
      } catch (e, st) {
        debugPrint('EventsFirebaseUtils.watchEvents parse error: $e');
        debugPrint('$st');
        return <EventModel>[];
      }
    });
  }

  Future<List<EventModel>> getEvents() async {
    try {
      final snapshot = await _eventsCollection
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final model = EventModel.fromJson(doc.data());
        model.id = doc.id;
        return model;
      }).toList();
    } catch (e, st) {
      debugPrint('EventsFirebaseUtils.getEvents error: $e');
      debugPrint('$st');
      return <EventModel>[];
    }
  }

  Future<List<EventModel>> getFavoriteEvents({required List<String> eventIds}) async {
    if (eventIds.isEmpty) {
      return <EventModel>[];
    }

    try {
      final futures = eventIds.map((eventId) => _eventsCollection.doc(eventId).get());
      final snapshots = await Future.wait(futures);
      final events = <EventModel>[];

      for (final doc in snapshots) {
        if (!doc.exists) continue;

        final data = doc.data();
        if (data == null) continue;

        final model = EventModel.fromJson(data);
        if (model.status.toLowerCase() != 'active') continue;

        model.id = doc.id;
        model.isFav = true;
        events.add(model);
      }

      return events;
    } catch (e, st) {
      debugPrint('EventsFirebaseUtils.getFavoriteEvents error: $e');
      debugPrint('$st');
      return <EventModel>[];
    }
  }

  Future<void> createEvent(EventModel event) async {
    try {
      final data = event.toJson()..remove('id');

      if (event.id.trim().isEmpty) {
        await _eventsCollection.add(data);
      } else {
        await _eventsCollection.doc(event.id).set(data, SetOptions(merge: true));
      }
    } catch (e, st) {
      debugPrint('EventsFirebaseUtils.createEvent error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _eventsCollection.doc(eventId).delete();
    } catch (e, st) {
      debugPrint('EventsFirebaseUtils.deleteEvent error: $e');
      debugPrint('$st');
      rethrow;
    }
  }
}
