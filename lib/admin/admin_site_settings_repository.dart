import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/storefront_settings.dart';

class AdminSiteSettingsRepository {
  AdminSiteSettingsRepository({required this.client});

  final SupabaseClient client;

  static const _cacheKey = 'expresiones.site_settings.cache';
  static StorefrontSettings? _cachedSettings;
  static StorefrontSettings? get cachedSettings => _cachedSettings;

  static Future<void> loadLocalCache() async {
    if (_cachedSettings != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cachedSettings = StorefrontSettings.fromMap(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistCache(StorefrontSettings settings) async {
    _cachedSettings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(settings.toMap()));
    } catch (_) {}
  }

  Stream<StorefrontSettings> watch() => client
      .from('site_settings')
      .stream(primaryKey: const ['id'])
      .eq('id', 'public')
      .map((rows) {
        if (rows.isEmpty || rows.first['data'] is! Map) {
          return _cachedSettings ?? const StorefrontSettings();
        }
        final data = (rows.first['data'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final settings = StorefrontSettings.fromMap(data);
        _persistCache(settings);
        return settings;
      });

  Future<void> save(StorefrontSettings settings) async {
    await _persistCache(settings);
    await client
        .from('site_settings')
        .upsert({'id': 'public', 'data': settings.toMap()});
  }
}
