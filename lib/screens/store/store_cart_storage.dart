import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:caribtap/screens/store/cart_models.dart';

class StoreCartStorage {
  static const String _keyPrefix = 'store_cart_';

  static String _keyFor(String listingId) => '$_keyPrefix$listingId';

  static Future<List<CartItem>> getCart(String listingId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(listingId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(CartItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCart(String listingId, List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_keyFor(listingId), payload);
  }

  static Future<void> clearCart(String listingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(listingId));
  }
}
