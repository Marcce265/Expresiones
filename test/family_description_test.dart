import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/catalog_screen.dart';
import 'package:expresiones/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la descripción de la familia se muestra una sola vez para todas las opciones',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = CatalogProduct(
        id: 'cinta-tornasol-4cm-7m',
        name: 'Cinta organza tornasol 4 cm × 7 m',
        description: 'Cinta de organza tornasol de 4 cm de ancho y 7 m de largo.',
        unitLabel: 'rollo',
        basePrice: 8,
        category: ProductCategory.materials,
        attributes: const {
          'assetCount': '2',
          'catalogGroup': 'Cintas especiales',
        },
        variants: [
          ProductVariant(id: 'perla', name: 'Perla'),
          ProductVariant(id: 'melon', name: 'Melón'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogScreen(
              products: [product],
              initialCategory: ProductCategory.materials,
              onProduct: (_, _) {},
              onBack: () {},
              onOpenQuote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProductCard).first);
      await tester.pumpAndSettle();

      expect(find.text('Descripción del producto'), findsOneWidget);
      expect(
        find.text('CINTA DE ORGANZA TORNASOL DE 4 CM DE ANCHO Y 7 M DE LARGO.'),
        findsOneWidget,
      );
      expect(find.text('OPCIONES: 2 TONOS'), findsOneWidget);
      expect(find.text('SECCIÓN: CINTAS ESPECIALES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
