import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/home_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildHome() => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: HomeScreen(
        products: seedCatalogProducts,
        popularProducts: seedCatalogProducts.take(6).toList(growable: false),
        onBrowse: (_) {},
        onProduct: (_, _) {},
        onOpenQuote: () {},
        quoteQuantity: 0,
      ),
    ),
  );

  testWidgets('aprovecha el escritorio ancho sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('Sin registro'), findsOneWidget);
    expect(find.text('Todo el catálogo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva una portada limpia en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('Encuentra lo que necesitas'), findsOneWidget);
    expect(find.text('Sin registro'), findsNothing);
    expect(find.text('Todo el catálogo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra productos reales y abre su variante destacada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const family = CatalogProduct(
      id: 'limpiapipas',
      name: 'Limpiapipas premium 8 mm',
      category: ProductCategory.materials,
      basePrice: 5,
      variants: [
        ProductVariant(id: 'verde-militar', name: 'Verde militar'),
        ProductVariant(id: 'morado-uva', name: 'Morado uva'),
      ],
    );
    String? openedVariant;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomeScreen(
            products: const [family],
            popularProducts: const [family],
            onBrowse: (_) {},
            onProduct: (_, variantId) => openedVariant = variantId,
            onOpenQuote: () {},
            quoteQuantity: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verde militar'), findsOneWidget);
    expect(find.text('Morado uva'), findsOneWidget);
    expect(find.text('Limpiapipas premium 8 mm'), findsNothing);

    await tester.tap(find.text('Verde militar'));
    expect(openedVariant, 'verde-militar');
    expect(tester.takeException(), isNull);
  });
}
