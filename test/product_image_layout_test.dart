import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/product_detail_screen.dart';
import 'package:expresiones/widgets/product_card.dart';
import 'package:expresiones/widgets/product_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final product = CatalogProduct(
    id: 'limpiapipas-premium-8mm',
    name: 'Limpiapipas premium 8 mm',
    category: ProductCategory.materials,
    basePrice: 5,
    variants: [
      ProductVariant(
        id: 'amarillo-mostaza',
        name: 'Amarillo mostaza',
        sku: 'XS-34',
      ),
    ],
  );
  final variant = ProductVariant(
    id: 'amarillo-mostaza',
    name: 'Amarillo mostaza',
    sku: 'XS-34',
  );

  testWidgets('el carrito rápido aparece solo en artículos individuales', (
    tester,
  ) async {
    final individual = CatalogProduct(
      id: 'coronita',
      name: 'Coronita',
      category: ProductCategory.materials,
      basePrice: 4,
    );
    final added = <(String, String?)>[];
    var openedFamily = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final tile in [
                (product: product, variant: null),
                (product: individual, variant: null),
                (product: product, variant: variant),
              ])
                SizedBox(
                  width: 180,
                  height: 238,
                  child: ProductCard(
                    product: tile.product,
                    variant: tile.variant,
                    compact: true,
                    showPrice: tile.variant == null,
                    onTap: () => openedFamily = true,
                    onAdd: (product, variantId) =>
                        added.add((product.id, variantId)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final familyCard = find.byWidgetPredicate(
      (widget) =>
          widget is ProductCard &&
          widget.product == product &&
          widget.variant == null,
    );
    final cartButton = find.byIcon(Icons.add_shopping_cart_rounded);
    expect(find.descendant(of: familyCard, matching: cartButton), findsNothing);
    expect(cartButton, findsNWidgets(2));

    await tester.tap(familyCard);
    expect(openedFamily, isTrue);
    expect(added, isEmpty);
    await tester.tap(cartButton.at(0));
    await tester.tap(cartButton.at(1));
    expect(added, [(individual.id, null), (product.id, variant.id)]);
  });

  testWidgets('la foto de limpiapipas llena la tarjeta sin padding interno', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 238,
            child: ProductCard(
              product: product,
              variant: variant,
              compact: true,
              showPrice: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final visualFinder = find.byType(ProductVisual);
    final visual = tester.widget<ProductVisual>(visualFinder);
    final imageStack = find.ancestor(
      of: visualFinder,
      matching: find.byType(Stack),
    );

    expect(visual.fit, BoxFit.cover);
    expect(imageStack, findsOneWidget);
    expect(tester.getSize(visualFinder), tester.getSize(imageStack));
  });

  testWidgets(
    'la tarjeta familiar muestra la portada administrada más reciente',
    (tester) async {
      const managedCover = 'https://cdn.example/catalog/new-cover.webp';
      final updatedProduct = CatalogProduct(
        id: 'limpiapipas-premium-8mm',
        name: 'Limpiapipas premium 8 mm',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: managedCover,
        thumbnailUrl: managedCover,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 238,
              child: ProductCard(
                product: updatedProduct,
                compact: true,
                showPrice: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final visual = tester.widget<ProductVisual>(find.byType(ProductVisual));
      expect(visual.imageAsset, managedCover);
      expect(visual.imageAsset, isNot(productFamilyHeroAsset(updatedProduct)));
    },
  );

  for (final viewport in const [Size(390, 844), Size(900, 900)]) {
    testWidgets(
      'el detalle de limpiapipas es cuadrado en ${viewport.width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProductDetailScreen(
                product: product,
                onAdd: ({
                  required quantity,
                  variantId,
                  required customization,
                }) {},
              ),
            ),
          ),
        );
        await tester.pump();

        final visualFinder = find.byType(ProductVisual);
        final aspectFinder = find.ancestor(
          of: visualFinder,
          matching: find.byType(AspectRatio),
        );
        final visualSize = tester.getSize(visualFinder);

        expect(aspectFinder, findsOneWidget);
        expect(visualSize, tester.getSize(aspectFinder));
        expect(visualSize.width, closeTo(visualSize.height, 0.01));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'el detalle de cinta satinada es cuadrado en ${viewport.width.toInt()} px para encuadrar fotos de celular',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final ribbonProduct = CatalogProduct(
          id: 'cinta-satinada-100m',
          name: 'Cinta satinada 100 m',
          category: ProductCategory.materials,
          basePrice: 29,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProductDetailScreen(
                product: ribbonProduct,
                onAdd: ({
                  required quantity,
                  variantId,
                  required customization,
                }) {},
              ),
            ),
          ),
        );
        await tester.pump();

        final visualFinder = find.byType(ProductVisual);
        final aspectFinder = find.ancestor(
          of: visualFinder,
          matching: find.byType(AspectRatio),
        );
        final visualSize = tester.getSize(visualFinder);

        expect(aspectFinder, findsOneWidget);
        expect(visualSize, tester.getSize(aspectFinder));
        expect(visualSize.width, closeTo(visualSize.height, 0.01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('el detalle de otros productos conserva su proporción', (
    tester,
  ) async {
    final otherProduct = CatalogProduct(
      id: 'otro-material',
      name: 'Otro material',
      category: ProductCategory.materials,
      basePrice: 10,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductDetailScreen(
            product: otherProduct,
            onAdd: ({
              required int quantity,
              String? variantId,
              required String customization,
            }) {},
          ),
        ),
      ),
    );

    final visualFinder = find.byType(ProductVisual);
    final aspectFinder = find.ancestor(
      of: visualFinder,
      matching: find.byType(AspectRatio),
    );
    expect(aspectFinder, findsOneWidget);
    expect(tester.widget<AspectRatio>(aspectFinder).aspectRatio, 1.18);
  });

  testWidgets('el detalle conserva la opción elegida sin selector interno', (
    tester,
  ) async {
    final ribbon = CatalogProduct(
      id: 'cinta-satinada-100m',
      name: 'Cinta satinada 100 m',
      category: ProductCategory.materials,
      basePrice: 29,
      variants: [
        ProductVariant(
          id: 'satin-01',
          name: 'N.º 01 · Blanco perla',
          sku: 'SAT-01',
          attributes: {'paletteNumber': '01'},
        ),
        ProductVariant(
          id: 'satin-02',
          name: 'N.º 02 · Marfil',
          sku: 'SAT-02',
          attributes: {'paletteNumber': '02'},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductDetailScreen(
            product: ribbon,
            onAdd: ({
              required int quantity,
              String? variantId,
              required String customization,
            }) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('BLANCO PERLA'), findsWidgets);
    expect(find.text('MARFIL'), findsNothing);
    expect(find.textContaining('N.º'), findsNothing);
    expect(find.text('Color'), findsNothing);
  });
}
