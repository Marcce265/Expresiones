import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/main.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/screens/catalog_screen.dart';
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

  test('incluye las 34 variantes únicas de limpiapipas', () {
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

  test('ajusta las fotos al formato de cada material', () {
    final limpiapipas = seedCatalogProducts.first;
    final cinta = seedCatalogProducts.firstWhere(
      (product) => product.id == 'cinta-satinada-100m',
    );
    final floratape = seedCatalogProducts.firstWhere(
      (product) => product.id == 'floratape',
    );
    final brochetas = seedCatalogProducts.firstWhere(
      (product) => product.id == 'brochetas',
    );
    final frases = seedCatalogProducts.firstWhere(
      (product) => product.id == 'frases-en-vinil',
    );

    expect(productImageFit(limpiapipas), BoxFit.cover);
    expect(
      productImageFit(limpiapipas, variant: limpiapipas.variants.first),
      BoxFit.contain,
    );
    expect(productImageFit(cinta), BoxFit.cover);
    expect(
      productImageFit(
        floratape,
        variant: floratape.variantById('catalogo-134'),
      ),
      BoxFit.contain,
    );
    expect(
      productImageFit(
        floratape,
        variant: floratape.variantById('catalogo-132'),
      ),
      BoxFit.cover,
    );
    expect(
      productImageFit(
        brochetas,
        variant: brochetas.variantById('catalogo-137'),
      ),
      BoxFit.contain,
    );
    expect(
      productImageFit(frases, variant: frases.variantById('catalogo-157')),
      BoxFit.contain,
    );
    expect(
      productImageFit(frases, variant: frases.variantById('catalogo-171')),
      BoxFit.cover,
    );
  });

  test('incluye solo los 80 tonos numerados de cinta satinada', () {
    final cinta = seedCatalogProducts.firstWhere(
      (product) => product.id == 'cinta-satinada-100m',
    );

    expect(cinta.variants, hasLength(80));
    expect(cinta.variants.first.name, 'N.º 01 · Blanco perla');
    expect(cinta.variants.last.name, 'N.º 80 · Verde neón');
    expect(
      cinta.variants.map((variant) => variant.imageUrl).toSet(),
      hasLength(80),
    );
    expect(
      cinta.variants.every(
        (variant) =>
            variant.imageUrl ==
            'assets/images/satin_optimized/satin_${variant.attributes['paletteNumber']}.webp',
      ),
      isTrue,
    );
  });

  test('usa portada y precios compartidos solo cuando corresponde', () {
    final limpiapipas = seedCatalogProducts.firstWhere(
      (product) => product.id == 'limpiapipas-premium-8mm',
    );
    final cinta = seedCatalogProducts.firstWhere(
      (product) => product.id == 'cinta-satinada-100m',
    );
    final alambre = seedCatalogProducts.firstWhere(
      (product) => product.id == 'alambre-floral',
    );

    expect(usesSharedFamilyPricing(limpiapipas), isTrue);
    expect(usesSharedFamilyPricing(cinta), isTrue);
    expect(usesSharedFamilyPricing(alambre), isFalse);
    expect(
      productFamilyHeroAsset(limpiapipas),
      'assets/images/family_heroes/limpiapipas.webp',
    );
    expect(
      productFamilyHeroAsset(cinta),
      'assets/images/family_heroes/cinta_satinada.webp',
    );
  });

  test('todas las familias del catálogo tienen imágenes para su portada', () {
    final families = seedCatalogProducts.where(
      (product) =>
          product.isActive &&
          product.category == ProductCategory.materials &&
          product.variants.where((variant) => variant.isActive).length > 1,
    );

    expect(families, isNotEmpty);
    for (final product in families) {
      final hasVariantImage = product.variants.any(
        (variant) =>
            variant.isActive &&
            variant.imageUrl != null &&
            variant.imageUrl!.isNotEmpty,
      );
      expect(
        productFamilyHeroAsset(product) != null || hasVariantImage,
        isTrue,
        reason: '${product.name} necesita una portada',
      );
    }
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

    tester.view.physicalSize = const Size(375, 812);
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

  testWidgets('agrupa los precios al entrar a una familia del catálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    Widget catalog(List<CatalogProduct> products) => MaterialApp(
      home: Scaffold(
        body: CatalogScreen(
          products: products,
          onProduct: (_, _) {},
          onBack: () {},
          onOpenQuote: () {},
        ),
      ),
    );

    await tester.pumpWidget(catalog(seedCatalogProducts));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Limpiapipas premium 8 mm'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('family-overview-limpiapipas-premium-8mm')),
      findsOneWidget,
    );
    expect(find.text('34 colores'), findsOneWidget);
    expect(find.text('Mismos precios para todas las opciones'), findsOneWidget);
    expect(find.text('S/ 5.00 c/u'), findsOneWidget);
    expect(find.text('S/ 4.50 c/u'), findsOneWidget);
    expect(find.text('S/ 4.30 c/u'), findsOneWidget);
    expect(find.text('S/ 4.00 c/u'), findsOneWidget);
    expect(find.text('S/ 5.00'), findsNothing);

    final updatedProducts = [
      for (final product in seedCatalogProducts)
        if (product.id == 'limpiapipas-premium-8mm')
          CatalogProduct.fromMap({
            ...product.toMap(),
            'basePrice': 6,
          }, id: product.id)
        else
          product,
    ];
    await tester.pumpWidget(catalog(updatedProducts));
    await tester.pumpAndSettle();
    expect(find.text('S/ 6.00 c/u'), findsOneWidget);

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
