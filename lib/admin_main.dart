import 'package:flutter/material.dart';

import 'admin/admin_portal.dart';
import 'services/supabase_bootstrap.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supabase = await SupabaseBootstrap.initialize();
  runApp(
    supabase.connected && supabase.client != null
        ? AdminPortalApp(client: supabase.client!)
        : _AdminConfigurationApp(message: supabase.message),
  );
}

class _AdminConfigurationApp extends StatelessWidget {
  const _AdminConfigurationApp({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 54),
                      const SizedBox(height: 16),
                      Text(
                        'Falta conectar Supabase',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message ??
                            'Inicia el panel con las variables del proyecto '
                                'Supabase de Expresiones.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
