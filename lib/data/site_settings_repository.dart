import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/storefront_settings.dart';

abstract interface class SiteSettingsRepository {
  Stream<StorefrontSettings> watch();
}

/// Reads the single public storefront settings document.
///
/// Local defaults keep the storefront usable while Supabase is unavailable or
/// before the settings migration has been deployed.
class SupabaseSiteSettingsRepository implements SiteSettingsRepository {
  SupabaseSiteSettingsRepository({
    this.client,
    this.fallback = const StorefrontSettings(),
  });

  static const _cacheKey = 'expresiones.site_settings.cache';
  static StorefrontSettings? _cachedSettings;

  final SupabaseClient? client;
  final StorefrontSettings fallback;

  static Future<StorefrontSettings?> _loadCachedSettings() async {
    if (_cachedSettings != null) return _cachedSettings;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _cachedSettings = StorefrontSettings.fromMap(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
          return _cachedSettings;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _persistSettings(StorefrontSettings settings) async {
    _cachedSettings = settings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(settings.toMap()));
    } catch (_) {}
  }

  @override
  Stream<StorefrontSettings> watch() async* {
    final cached = await _loadCachedSettings() ?? fallback;
    yield cached;

    final activeClient = client;
    if (activeClient == null) return;

    try {
      await for (final rows
          in activeClient
              .from('site_settings')
              .stream(primaryKey: const ['id'])
              .eq('id', 'public')) {
        final settings = rows.isEmpty ? cached : _settingsFromRow(rows.first);
        _persistSettings(settings);
        yield settings;
      }
    } catch (_) {
      // Keep cached / fallback on connection failure.
    }
  }

  StorefrontSettings _settingsFromRow(Map<String, dynamic>? row) {
    final data = row?['data'];
    if (data is! Map) return fallback;
    return StorefrontSettings.fromMap(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
