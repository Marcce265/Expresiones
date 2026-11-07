import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Store Modules Navigation & Catalog', () {
    test('ProductCategory maps koreanPaper and crowns correctly', () {
      expect(ProductCategory.fromValue('korean_paper'), ProductCategory.koreanPaper);
      expect(ProductCategory.fromValue('papel_coreano'), ProductCategory.koreanPaper);
      expect(ProductCategory.fromValue('papel'), ProductCategory.koreanPaper);
      expect(ProductCategory.fromValue('crowns'), ProductCategory.crowns);
      expect(ProductCategory.fromValue('coronas'), ProductCategory.crowns);
      expect(ProductCategory.fromValue('materials'), ProductCategory.materials);
    });

    test('CatalogProduct.fromMap detects module in attributes', () {
      final product = CatalogProduct.fromMap({
        'id': 'papel-coreano-liso',
        'name': 'Papel coreano liso',
        'category': 'materials',
        'attributes': {'catalogGroup': 'Papel Coreano', 'module': 'korean_paper'},
      });
      expect(product.category, ProductCategory.koreanPaper);
      expect(product.isKoreanPaper, isTrue);
    });

    testWidgets('CatalogScreen renders module selector chips (Opción A)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final products = <CatalogProduct>[
        CatalogProduct(
          id: 'limpiapipas',
          name: 'Limpiapipas premium 8 mm',
          basePrice: 5.0,
          category: ProductCategory.materials,
          attributes: const {'catalogGroup': 'Limpiapipas'},
        ),
        CatalogProduct(
          id: 'papel-rosa',
          name: 'Papel coreano rosa pastel',
          basePrice: 8.0,
          category: ProductCategory.koreanPaper,
          attributes: const {'catalogGroup': 'Lisos'},
        ),
      ];

      ProductCategory? activeCategory;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogScreen(
              products: products,
              initialCategory: ProductCategory.materials,
              onCategoryChanged: (cat) => activeCategory = cat,
              onProduct: (_, _) {},
              onBack: () {},
              onOpenQuote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Module selector chips exist
      expect(find.text('Materiales'), findsWidgets);
      expect(find.text('Papel Coreano'), findsWidgets);
      expect(find.text('Coronas'), findsOneWidget);
      expect(find.text('Próx.'), findsOneWidget);

      // Initially shows Materiales product
      expect(find.text('LIMPIAPIPAS PREMIUM 8 MM'), findsOneWidget);
      expect(find.text('PAPEL COREANO ROSA PASTEL'), findsNothing);

      // Tap Papel Coreano chip
      await tester.tap(find.text('Papel Coreano').first);
      await tester.pumpAndSettle();

      expect(activeCategory, ProductCategory.koreanPaper);
      expect(find.text('PAPEL COREANO ROSA PASTEL'), findsOneWidget);
      expect(find.text('LIMPIAPIPAS PREMIUM 8 MM'), findsNothing);
    });

    testWidgets('CatalogScreen shows warm empty state for module with no items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final products = <CatalogProduct>[
        CatalogProduct(
          id: 'limpiapipas',
          name: 'Limpiapipas premium 8 mm',
          basePrice: 5.0,
          category: ProductCategory.materials,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogScreen(
              products: products,
              initialCategory: ProductCategory.koreanPaper,
              onProduct: (_, _) {},
              onBack: () {},
              onOpenQuote: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Papel Coreano muy pronto'), findsOneWidget);
      expect(find.text('Ver Materiales'), findsOneWidget);

      // Tap Ver Materiales button
      await tester.tap(find.text('Ver Materiales'));
      await tester.pumpAndSettle();

      expect(find.text('LIMPIAPIPAS PREMIUM 8 MM'), findsOneWidget);
    });
  });
}
