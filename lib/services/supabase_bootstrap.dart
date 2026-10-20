import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBootstrapResult {
  const SupabaseBootstrapResult({
    required this.connected,
    this.client,
    this.message,
  });

  final bool connected;
  final SupabaseClient? client;
  final String? message;
}

/// Initializes Supabase from compile-time values without committing secrets.
///
/// Use `--dart-define-from-file=supabase_config.json`. The public catalog keeps
/// working from its bundled seed when configuration is absent or invalid.
abstract final class SupabaseBootstrap {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<SupabaseBootstrapResult> initialize() async {
    final url = _url.trim();
    final key = (_publishableKey.isNotEmpty ? _publishableKey : _legacyAnonKey)
        .trim();

    if (url.isEmpty || key.isEmpty) {
      return const SupabaseBootstrapResult(
        connected: false,
        message:
            'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY. '
            'La aplicación pública seguirá usando el catálogo local.',
      );
    }

    try {
      await Supabase.initialize(url: url, publishableKey: key);
      return SupabaseBootstrapResult(
        connected: true,
        client: Supabase.instance.client,
      );
    } catch (error) {
      return SupabaseBootstrapResult(
        connected: false,
        message:
            'No se pudo iniciar Supabase. La aplicación pública seguirá '
            'usando el catálogo local: $error',
      );
    }
  }
}
