import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/home_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/product_card.dart';
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

    expect(find.text('Cotiza sin registro'), findsOneWidget);
    expect(find.text('Ver todo el catálogo'), findsOneWidget);
    expect(find.byType(ProductCard), findsNWidgets(6));
    final cardSize = tester.getSize(find.byType(ProductCard).first);
    expect(cardSize.height, greaterThan(cardSize.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva una portada limpia en móvil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(
      find.text('Encuentra lo que necesitas para crear y expresar más.'),
      findsOneWidget,
    );
    expect(find.text('Cotiza sin registro'), findsNothing);
    expect(find.text('Ver todo el catálogo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra productos reales y abre su variante destacada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final family = CatalogProduct(
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
            products: [family],
            popularProducts: [family],
            onBrowse: (_) {},
            onProduct: (_, variantId) => openedVariant = variantId,
            onOpenQuote: () {},
            quoteQuantity: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VERDE MILITAR'), findsOneWidget);
    expect(find.text('MORADO UVA'), findsOneWidget);
    expect(find.text('LIMPIAPIPAS PREMIUM 8 MM'), findsNWidgets(2));

    await tester.ensureVisible(find.text('VERDE MILITAR'));
    await tester.tap(find.text('VERDE MILITAR'));
    expect(openedVariant, 'verde-militar');
    expect(tester.takeException(), isNull);
  });
}
