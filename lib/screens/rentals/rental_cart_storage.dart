import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:caribtap/screens/rentals/rental_item_models.dart';

class RentalCartStorage {
  static const String _keyPrefix = 'rental_cart_';

  static String _keyFor(String listingId) => '$_keyPrefix$listingId';

  static Future<List<RentalCartItem>> getCart(String listingId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(listingId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(RentalCartItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCart(String listingId, List<RentalCartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_keyFor(listingId), payload);
  }

  static Future<void> clearCart(String listingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(listingId));
  }
}
