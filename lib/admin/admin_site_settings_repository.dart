import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/storefront_settings.dart';

class AdminSiteSettingsRepository {
  AdminSiteSettingsRepository({required this.client});

  final SupabaseClient client;

  Stream<StorefrontSettings> watch() => client
      .from('site_settings')
      .stream(primaryKey: const ['id'])
      .eq('id', 'public')
      .map((rows) {
        if (rows.isEmpty || rows.first['data'] is! Map) {
          return const StorefrontSettings();
        }
        final data = (rows.first['data'] as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        return StorefrontSettings.fromMap(data);
      });

  Future<void> save(StorefrontSettings settings) => client
      .from('site_settings')
      .upsert({'id': 'public', 'data': settings.toMap()});
}
