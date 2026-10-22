import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/product_detail_screen.dart';
import 'package:expresiones/widgets/product_card.dart';
import 'package:expresiones/widgets/product_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = CatalogProduct(
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
  const variant = ProductVariant(
    id: 'amarillo-mostaza',
    name: 'Amarillo mostaza',
    sku: 'XS-34',
  );

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
      const updatedProduct = CatalogProduct(
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
  }

  testWidgets('el detalle de otros productos conserva su proporción', (
    tester,
  ) async {
    const otherProduct = CatalogProduct(
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
}
