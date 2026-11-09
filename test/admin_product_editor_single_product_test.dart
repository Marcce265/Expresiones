import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'un producto sin variantes muestra selector de disponibilidad y banner informativo',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      final product = CatalogProduct(
        id: 'corona-azul',
        name: 'Corona Azul',
        category: ProductCategory.crowns,
        description: 'Corona con piedras azules',
        unitLabel: 'unidad',
        basePrice: 25,
        sku: 'CO-01',
        stockStatus: StockStatus.inStock,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminProductEditorDialog(
              repository: AdminCatalogRepository(client: client),
              product: product,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Visibilidad y Estado, Disponibilidad must be present for products without variants
      expect(find.text('Visibilidad y Estado'), findsOneWidget);
      expect(find.text('Disponibilidad'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Pocas unidades'), findsOneWidget);
      expect(find.text('Agotado'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Variantes (0)'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // In Variantes card, informative banner for single products must be visible
      expect(find.text('Variantes (0)'), findsOneWidget);
      expect(find.text('Producto sin variantes'), findsOneWidget);
      expect(
        find.textContaining('Si se vende tal cual (como una corona única)'),
        findsOneWidget,
      );

      // Verify toggling stock status works
      final pocasUnidadesChoice = find.text('Pocas unidades');
      await tester.scrollUntilVisible(
        pocasUnidadesChoice,
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(pocasUnidadesChoice);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
