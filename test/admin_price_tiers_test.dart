import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('el administrador edita el precio unitario de docena y ciento', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final product = CatalogProduct(
      id: 'producto-prueba',
      name: 'Producto de prueba',
      category: ProductCategory.materials,
      description: 'Descripción',
      unitLabel: 'unidad',
      basePrice: 4,
      priceTiers: [PriceTier(minQuantity: 12, unitPrice: 2.5, label: 'Docena')],
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

    expect(find.text('Unidad de venta *'), findsNothing);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -650));
    await tester.pumpAndSettle();

    expect(find.text('Precios por cantidad'), findsNothing);
    expect(find.text('Docena'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.controller?.text == '2.50',
      ),
      findsOneWidget,
    );
    expect(find.text('Docena · Total S/ 30.00 (12 × S/ 2.50)'), findsOneWidget);

    final dozenQuantity = find
        .ancestor(
          of: find.text('Cantidad'),
          matching: find.byType(TextFormField),
        )
        .first;
    final dozenUnitPrice = find
        .ancestor(
          of: find.text('Precio por unidad (S/)'),
          matching: find.byType(TextFormField),
        )
        .first;
    await tester.enterText(dozenQuantity, '1');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();

    expect(find.text('Mínimo 2.'), findsOneWidget);
    expect(
      tester.getTopLeft(dozenQuantity).dy,
      closeTo(tester.getTopLeft(dozenUnitPrice).dy, .5),
    );
    expect(tester.takeException(), isNull);

    await tester.enterText(dozenQuantity, '12');
    tester.state<FormState>(find.byType(Form)).validate();
    await tester.pump();

    await tester.enterText(dozenUnitPrice, '4');
    await tester.pump();
    expect(find.text('Docena · Total S/ 48.00 (12 × S/ 4.00)'), findsOneWidget);

    final addHundred = find.text('Ciento');
    await tester.ensureVisible(addHundred);
    await tester.pumpAndSettle();
    await tester.tap(addHundred);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.controller?.text == '100',
      ),
      findsOneWidget,
    );
  });
}
