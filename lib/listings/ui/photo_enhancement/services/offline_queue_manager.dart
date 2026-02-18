import 'dart:convert';

import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages offline enhancement queues
class OfflineQueueManager {
  final Future<SharedPreferences> _prefsFuture;
  SharedPreferences? _prefs;

  static const String queueKey = 'photo_enhancement_queue';
  static const String processedKey = 'photo_enhancement_processed';

  OfflineQueueManager({SharedPreferences? prefs})
      : _prefs = prefs,
        _prefsFuture = prefs != null
            ? Future.value(prefs)
            : SharedPreferences.getInstance();

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await _prefsFuture;
  }

  /// Add enhancement request to offline queue
  Future<void> queueEnhancement(EnhancementRequest request) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getQueue();
      queue.add({
        'id': request.id,
        'listingId': request.listingId,
        'category': request.category,
        'subscriptionTier': request.subscriptionTier,
        'enhancements': request.enhancements,
        'includeDisclosure': request.includeDisclosure,
        'userNotes': request.userNotes,
        'createdAt': request.createdAt.toIso8601String(),
      });

      await prefs.setString(queueKey, jsonEncode(queue));
    } catch (e) {
      rethrow;
    }
  }

  /// Get all queued enhancements
  Future<List<Map<String, dynamic>>> getQueue() async {
    try {
      final prefs = await _getPrefs();
      final queueJson = prefs.getString(queueKey);
      if (queueJson == null) return [];

      final decoded = jsonDecode(queueJson) as List;
      return decoded.map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Remove item from queue (after successful processing)
  Future<void> removeFromQueue(String requestId) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getQueue();
      queue.removeWhere((item) => item['id'] == requestId);

      if (queue.isEmpty) {
        await prefs.remove(queueKey);
      } else {
        await prefs.setString(queueKey, jsonEncode(queue));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(queueKey);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if queue has items
  Future<bool> hasQueuedItems() async {
    try {
      final queue = await getQueue();
      return queue.isNotEmpty;
    } catch (e) {
      rethrow;
    }
  }

  /// Get queue size
  Future<int> getQueueSize() async {
    try {
      final queue = await getQueue();
      return queue.length;
    } catch (e) {
      rethrow;
    }
  }

  /// Record a successfully processed enhancement
  Future<void> recordProcessed({
    required String requestId,
    required String variantId,
    required EnhancementResponse response,
  }) async {
    try {
      final prefs = await _getPrefs();
      final processed = await getProcessedList();
      processed.add({
        'requestId': requestId,
        'variantId': variantId,
        'response': response.toJson(),
        'processedAt': DateTime.now().toIso8601String(),
      });

      // Keep only last 50 processed items
      if (processed.length > 50) {
        processed.removeRange(0, processed.length - 50);
      }

      await prefs.setString(processedKey, jsonEncode(processed));
    } catch (e) {
      rethrow;
    }
  }

  /// Get list of recently processed enhancements
  Future<List<Map<String, dynamic>>> getProcessedList() async {
    try {
      final prefs = await _getPrefs();
      final processedJson = prefs.getString(processedKey);
      if (processedJson == null) return [];

      final decoded = jsonDecode(processedJson) as List;
      return decoded.map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Retry a queued enhancement
  Future<Map<String, dynamic>?> getQueuedItem(String requestId) async {
    try {
      final queue = await getQueue();
      final item = queue.firstWhere(
        (item) => item['id'] == requestId,
        orElse: () => {},
      );
      return item.isEmpty ? null : item;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all queued items for a specific listing
  Future<List<Map<String, dynamic>>> getQueuedByListing(
      String listingId) async {
    try {
      final queue = await getQueue();
      return queue
          .where((item) => item['listingId'] == listingId)
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}
