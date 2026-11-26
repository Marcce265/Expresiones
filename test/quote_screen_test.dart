import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/screens/quote_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tu pedido muestra el importe y el precio por paquete aplicado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final product = CatalogProduct(
      id: 'limpiapipas',
      name: 'Limpiapipas premium',
      category: ProductCategory.materials,
      basePrice: 5,
      unitLabel: 'paquete',
      variants: [
        ProductVariant(id: 'verde', name: 'Verde militar'),
        ProductVariant(id: 'rosa', name: 'Palo rosa'),
      ],
      priceTiers: [PriceTier(minQuantity: 12, unitPrice: 4.5, label: 'Docena')],
    );

    Future<void> display(int pinkQuantity) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CheckoutOrderSummary(
              lines: resolveQuoteLines(
                products: {product.id: product},
                lines: [
                  QuoteLine(
                    productId: product.id,
                    variantId: 'verde',
                    quantity: 6,
                  ),
                  QuoteLine(
                    productId: product.id,
                    variantId: 'rosa',
                    quantity: pinkQuantity,
                  ),
                ],
              ),
              onQuantityChanged: (_, _) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );

    await display(5);
    expect(find.text('S/ 5.00 por paquete'), findsOneWidget);
    expect(find.text('S/ 30.00'), findsOneWidget);

    await display(6);
    expect(find.text('S/ 4.50 por paquete · docena'), findsOneWidget);
    expect(find.text('S/ 27.00'), findsNWidgets(2));
    expect(find.text('S/ 54.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el pedido compacto muestra solo el subtotal y permite quitar productos',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final product = seedCatalogProducts.first;
      final item = ResolvedQuoteLine(
        line: QuoteLine(productId: product.id, quantity: 2),
        product: product,
      );
      QuoteLine? removed;
      Future<void> display() => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutOrderSummary(
                lines: [item],
                onQuantityChanged: (_, _) {},
                onRemove: (line) => removed = line,
              ),
            ),
          ),
        ),
      );

      await display();
      expect(find.text('Tu pedido'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Entrega'), findsNothing);
      expect(find.text('Total'), findsNothing);
      await tester.tap(find.byTooltip('Quitar ${item.displayName}'));
      expect(removed, item.line);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Tu pedido continúa a Datos desde su propia pantalla', (
    tester,
  ) async {
    final product = seedCatalogProducts.first;
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteScreen(
          showOrderSummary: true,
          lines: [
            ResolvedQuoteLine(
              line: QuoteLine(productId: product.id, quantity: 1),
              product: product,
            ),
          ],
          onQuantityChanged: (_, _) {},
          onRemove: (_) {},
          onContinue: () => continued = true,
          onBrowse: () {},
        ),
      ),
    );
    final next = find.text('Continuar con la cotización');
    expect(find.text('Tu pedido'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Tus datos de contacto'), findsNothing);
    await tester.ensureVisible(next);
    await tester.tap(next);
    expect(continued, isTrue);
  });

  testWidgets('el carrito deja el subtotal para la revisión final', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var continued = false;
    final product = seedCatalogProducts.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteScreen(
          lines: [
            ResolvedQuoteLine(
              line: QuoteLine(productId: product.id, quantity: 2),
              product: product,
            ),
          ],
          onQuantityChanged: (_, _) {},
          onRemove: (_) {},
          onContinue: () => continued = true,
          onBrowse: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Resumen del carrito'), findsNothing);
    expect(find.text('Subtotal de productos'), findsNothing);
    expect(find.text('Siguiente: datos para coordinar'), findsOneWidget);

    await tester.tap(find.text('Continuar con la cotización'));
    expect(continued, isTrue);
  });
}
