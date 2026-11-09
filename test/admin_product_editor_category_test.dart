import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('un producto nuevo hereda el módulo activo del filtro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminProductEditorDialog(
            repository: AdminCatalogRepository(client: client),
            initialCategory: ProductCategory.crowns,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coronas'), findsOneWidget);
    expect(find.text('Materiales'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
