import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'la opción queda abierta con una sola foto y controles laterales',
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
        id: 'limpiapipas',
        name: 'Limpiapipas',
        category: ProductCategory.materials,
        description: 'Material',
        unitLabel: 'paquete',
        basePrice: 5,
        variants: [
          ProductVariant(
            id: 'verde-militar',
            name: 'Verde militar',
            sku: 'XS-1',
            stock: 20,
            stockStatus: StockStatus.inStock,
          ),
          ProductVariant(
            id: 'verde-pasto',
            name: 'Verde pasto',
            sku: 'XS-6',
            stockStatus: StockStatus.lowStock,
          ),
        ],
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

      await tester.scrollUntilVisible(
        find.text('Variantes (2)'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('variant-editor-verde-militar'));
      final secondOption = find.byKey(
        const ValueKey('variant-editor-verde-pasto'),
      );
      await tester.ensureVisible(option);
      await tester.pumpAndSettle();
      expect(secondOption, findsOneWidget);
      expect(
        tester.getTopLeft(option).dy,
        closeTo(tester.getTopLeft(secondOption).dy, 1),
      );

      final image = find.byKey(const ValueKey('variant-image-VERDE MILITAR'));
      final nameField = find.byKey(
        const ValueKey('variant-name-verde-militar'),
      );
      final skuField = find.byKey(const ValueKey('variant-sku-verde-militar'));
      final statusField = find.byKey(
        const ValueKey('variant-status-verde-militar'),
      );
      expect(image, findsOneWidget);
      expect(tester.getSize(image), const Size(250, 250));
      expect(
        tester.getTopLeft(nameField).dx,
        greaterThan(tester.getTopRight(image).dx),
      );
      expect(
        tester.getTopLeft(skuField).dx,
        greaterThan(tester.getTopRight(image).dx),
      );
      expect(
        tester.getTopLeft(statusField).dx,
        greaterThan(tester.getTopRight(image).dx),
      );
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Nombre *'), findsNWidgets(2));
      expect(find.text('Stock exacto'), findsNothing);
      expect(find.text('Consultar disponibilidad'), findsNothing);
      expect(find.text('Hecho a pedido'), findsNothing);
      expect(find.text('Visible en catálogo'), findsNothing);
      final camera = find.byKey(
        const ValueKey('edit-variant-image-VERDE MILITAR'),
      );
      expect(camera, findsOneWidget);
      expect(
        find.descendant(
          of: camera,
          matching: find.byIcon(Icons.photo_camera_rounded),
        ),
        findsOneWidget,
      );
      final visibility = find.byKey(
        const ValueKey('toggle-variant-visibility-VERDE MILITAR'),
      );
      final delete = find.byKey(const ValueKey('delete-variant-VERDE MILITAR'));
      expect(visibility, findsOneWidget);
      expect(delete, findsOneWidget);
      expect(tester.getCenter(camera).dx, tester.getCenter(visibility).dx);
      expect(tester.getCenter(visibility).dx, tester.getCenter(delete).dx);
      expect(
        tester.getCenter(delete).dy,
        greaterThan(tester.getCenter(visibility).dy),
      );
      expect(
        find.descendant(
          of: visibility,
          matching: find.byIcon(Icons.visibility_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(visibility);
      await tester.pump();
      expect(
        find.descendant(
          of: visibility,
          matching: find.byIcon(Icons.visibility_off_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Agregar opción'), findsNothing);
      expect(find.text('Agregar otra opción'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
