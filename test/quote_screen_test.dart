import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/screens/quote_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
