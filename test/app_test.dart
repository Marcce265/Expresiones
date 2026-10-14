import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/main.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:expresiones/widgets/product_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('aplica automáticamente los precios por volumen', () {
    final product = seedCatalogProducts.first;

    expect(product.unitPriceFor(1, variantId: 'morado-uva'), 5);
    expect(product.unitPriceFor(12, variantId: 'morado-uva'), 4.50);
    expect(product.unitPriceFor(100, variantId: 'morado-uva'), 4.30);
    expect(product.totalFor(12, variantId: 'morado-uva'), 54);
  });

  test('incluye las 34 variantes verificadas del catálogo de limpiapipas', () {
    final product = seedCatalogProducts.first;

    expect(product.variants, hasLength(34));
    expect(product.variantById('rojo-coral')?.sku, 'XS-B02');
    expect(
      product.variantById('celeste-turquesa')?.stockStatus,
      StockStatus.outOfStock,
    );
    expect(
      product.variants.every((variant) => variant.imageUrl != null),
      isTrue,
    );
  });

  test('llena la casilla con las fotos de materiales', () {
    final limpiapipas = seedCatalogProducts.first;
    final cinta = seedCatalogProducts.firstWhere(
      (product) => product.id == 'cinta-satinada-100m',
    );

    expect(productImageFit(limpiapipas), BoxFit.contain);
    expect(productImageFit(cinta), BoxFit.cover);
  });

  test('genera el mensaje final de WhatsApp con datos y total', () {
    final product = seedCatalogProducts.first;
    final lines = [
      ResolvedQuoteLine(
        line: const QuoteLine(
          productId: 'limpiapipas-premium-8mm',
          variantId: 'morado-uva',
          quantity: 12,
        ),
        product: product,
      ),
    ];

    final message = QuoteMessageBuilder.build(
      id: 'COT-PRUEBA',
      lines: lines,
      details: const CoordinationDetails(
        name: 'María López',
        phone: '999999999',
      ),
    );

    expect(message, contains('COT-PRUEBA'));
    expect(message, contains('Morado uva'));
    expect(message, contains('S/ 54.00'));
    expect(message, contains('Recojo en Huancayo'));
  });

  testWidgets('muestra el inicio y la navegación principal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(() async => seedCatalogProducts);
    await store.initialize();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expresiones'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.text('Cotización'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
  });
}
