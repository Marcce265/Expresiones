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

  final SupabaseClient? client;
  final StorefrontSettings fallback;

  @override
  Stream<StorefrontSettings> watch() async* {
    final activeClient = client;
    if (activeClient == null) {
      yield fallback;
      return;
    }
    try {
      await for (final rows
          in activeClient
              .from('site_settings')
              .stream(primaryKey: const ['id'])
              .eq('id', 'public')) {
        yield rows.isEmpty ? fallback : _settingsFromRow(rows.first);
      }
    } catch (_) {
      yield fallback;
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
