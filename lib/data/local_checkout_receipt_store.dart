import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/checkout_order.dart';

class LocalCheckoutReceiptStore {
  static const storageKey = 'expresiones.last_order.v1';

  Future<void> save(CheckoutOrder order) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(order.toJson()));
  }

  Future<CheckoutOrder?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? CheckoutOrder.fromJson(
              decoded.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            )
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }
}
