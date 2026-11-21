import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/screens/catalog_screen.dart';
import 'package:expresiones/screens/coordination_screen.dart';
import 'package:expresiones/screens/help_screen.dart';
import 'package:expresiones/screens/home_screen.dart';
import 'package:expresiones/screens/quote_screen.dart';
import 'package:expresiones/screens/review_screen.dart';
import 'package:expresiones/services/catalog_search_engine.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/breadcrumb_bar.dart';
import 'package:expresiones/widgets/store_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<CatalogProduct> _sampleCatalog() {
  return [
    CatalogProduct(
      id: 'cinta-satinada',
      name: 'CINTA SATINADA 100 M',
      category: ProductCategory.materials,
      description: 'Rollo de cinta satinada de 4 cm para rosas eternas.',
      unitLabel: 'rollo',
      basePrice: 29,
      tags: ['cinta', 'satinada', 'liston', 'rollo'],
      variants: [
        ProductVariant(
          id: 'sat-01',
          name: 'N.°1 BLANCO',
          sku: 'SAT-01',
        ),
        ProductVariant(
          id: 'sat-02',
          name: 'N.°2 ROJO PASI\u00d3N',
          sku: 'SAT-02',
        ),
        ProductVariant(
          id: 'sat-03',
          name: 'N.°3 MARFIL',
          sku: 'SAT-03',
        ),
      ],
    ),
    CatalogProduct(
      id: 'cinta-organza',
      name: 'Cinta organza',
      category: ProductCategory.materials,
      description: 'Cinta transl\u00facida para mo\u00f1os y detalles.',
      unitLabel: 'rollo',
      basePrice: 12,
      sku: 'ORG-01',
    ),
    CatalogProduct(
      id: 'cinta-eternal',
      name: 'Cinta Eternal Love',
      category: ProductCategory.materials,
      description: 'Cinta estampada decorativa para ramos.',
      unitLabel: 'rollo',
      basePrice: 15,
      sku: 'ETN-01',
    ),
    CatalogProduct(
      id: 'cinta-doble',
      name: 'CINTA DOBLE CONTACTO',
      category: ProductCategory.materials,
      description: 'Cinta adhesiva doble faz para armado.',
      unitLabel: 'unidad',
      basePrice: 6,
      sku: 'CDC-01',
    ),
    CatalogProduct(
      id: 'limpiapipas',
      name: 'LIMPIAPIPAS PREMIUM',
      category: ProductCategory.materials,
      description: 'Paquete de 100 limpiapipas suaves para flores.',
      unitLabel: 'paquete',
      basePrice: 5,
      variants: [
        ProductVariant(
          id: 'xs-14',
          name: 'VINO',
          sku: 'XS-14',
        ),
        ProductVariant(
          id: 'xs-22',
          name: 'AMARILLO MOSTAZA',
          sku: 'XS-22',
        ),
      ],
    ),
    CatalogProduct(
      id: 'pa-02',
      name: 'PAPEL COREANO ABEJITA Y GIRASOL',
      category: ProductCategory.koreanPaper,
      description: 'Papel coreano impermeable con dise\u00f1o de abejitas.',
      unitLabel: 'paquete',
      basePrice: 10,
      sku: 'PA-02',
    ),
    CatalogProduct(
      id: 'cautin',
      name: 'CAUT\u00cdN EL\u00c9CTRICO',
      category: ProductCategory.materials,
      description: 'Herramienta para sellar cintas.',
      unitLabel: 'unidad',
      basePrice: 18,
      sku: 'CAT-090',
    ),
    CatalogProduct(
      id: 'luz-hada',
      name: 'LUZ HADA LED',
      category: ProductCategory.materials,
      description: 'Guirnalda de luz c\u00e1lida para ramos.',
      unitLabel: 'unidad',
      basePrice: 7,
      sku: 'CAT-088',
    ),
    CatalogProduct(
      id: 'corona',
      name: 'CORONA PERLADA',
      category: ProductCategory.materials,
      description: 'Accesorio met\u00e1lico con perlas.',
      unitLabel: 'unidad',
      basePrice: 8,
      sku: 'CAT-076',
    ),
  ];
}

void main() {
  group('CatalogSearchEngine', () {
    final catalog = _sampleCatalog();

    test('buscar "cintas" encuentra todas las cintas agrupadas sin saturar', () {
      final results = CatalogSearchEngine.searchProducts(catalog, 'cintas');
      final ids = results.map((tile) => tile.product.id).toSet();

      expect(ids, contains('cinta-satinada'));
      expect(ids, contains('cinta-organza'));
      expect(ids, contains('cinta-eternal'));
      expect(ids, contains('cinta-doble'));

      // La familia con variantes no debe expandirse a todas sus variantes
      // cuando la búsqueda es general ("cintas").
      final satinMatches = results
          .where((tile) => tile.product.id == 'cinta-satinada')
          .toList();
      expect(satinMatches.length, 1);
      expect(satinMatches.single.variant, isNull);
    });

    test('búsqueda combinada familia + color encuentra la variante exacta', () {
      final cintaRoja = CatalogSearchEngine.searchProducts(
        catalog,
        'cinta roja',
      );
      expect(cintaRoja, isNotEmpty);
      expect(cintaRoja.first.product.id, 'cinta-satinada');
      expect(cintaRoja.first.variant?.id, 'sat-02');

      final limpiapipasAmarillo = CatalogSearchEngine.searchProducts(
        catalog,
        'limpiapipas amarillo',
      );
      expect(limpiapipasAmarillo, isNotEmpty);
      expect(limpiapipasAmarillo.first.product.id, 'limpiapipas');
      expect(limpiapipasAmarillo.first.variant?.id, 'xs-22');
    });

    test('maneja plurales, tildes y stopwords en español', () {
      final papeles = CatalogSearchEngine.searchProducts(
        catalog,
        'papeles de abejita',
      );
      expect(papeles.map((t) => t.product.id), contains('pa-02'));

      final cautin = CatalogSearchEngine.searchProducts(catalog, 'cautin');
      expect(cautin.map((t) => t.product.id), contains('cautin'));

      final luces = CatalogSearchEngine.searchProducts(catalog, 'luces');
      expect(luces.map((t) => t.product.id), contains('luz-hada'));

      final coronas = CatalogSearchEngine.searchProducts(catalog, 'coronas');
      expect(coronas.map((t) => t.product.id), contains('corona'));
    });

    test('búsqueda por código SKU devuelve la variante exacta primero', () {
      final xs14 = CatalogSearchEngine.searchProducts(catalog, 'XS-14');
      expect(xs14.length, 1);
      expect(xs14.first.variant?.sku, 'XS-14');

      final sat01 = CatalogSearchEngine.searchProducts(catalog, 'sat-01');
      expect(sat01.length, 1);
      expect(sat01.first.variant?.sku, 'SAT-01');
    });

    test('filterFamilyTiles filtra variantes dentro de una familia', () {
      final family = catalog.first;
      final tiles = [
        for (final v in family.variants) (product: family, variant: v),
      ];
      final filtered = CatalogSearchEngine.filterFamilyTiles(
        tiles,
        'rojo pasion',
      );
      expect(filtered.length, 1);
      expect(filtered.single.variant?.id, 'sat-02');
    });

    test('configura tiempos de debounce y paginación anti-saturación', () {
      expect(
        CatalogSearchEngine.inputFilterDebounce,
        const Duration(milliseconds: 450),
      );
      expect(
        CatalogSearchEngine.zeroResultTelemetryDebounce,
        const Duration(seconds: 3),
      );
      expect(CatalogSearchEngine.defaultPageSize, 24);
    });

    test('funciona correctamente sobre el catálogo real seedCatalogProducts', () {
      final cintas = CatalogSearchEngine.searchProducts(
        seedCatalogProducts,
        'cintas',
      );
      expect(cintas, isNotEmpty);
      expect(
        cintas.any((t) => t.product.name.toUpperCase().contains('CINTA')),
        isTrue,
      );
      // No debe inundar con las 46 variantes de cinta satinada al buscar "cintas"
      expect(cintas.length, lessThan(20));

      final limpiapipas = CatalogSearchEngine.searchProducts(
        seedCatalogProducts,
        'limpiapipas',
      );
      expect(limpiapipas, isNotEmpty);
      expect(limpiapipas.first.product.name.toUpperCase(), contains('LIMPIAPIPAS'));

      final cintaBlanca = CatalogSearchEngine.searchProducts(
        seedCatalogProducts,
        'cinta blanco',
      );
      expect(cintaBlanca, isNotEmpty);
      expect(cintaBlanca.first.variant, isNotNull);
    });
  });

  group('Breadcrumbs uniformes (sin INICIO) y StoreFooter en todos los módulos', () {
    final catalog = _sampleCatalog();

    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );
    }

    testWidgets(
      'HomeScreen no tiene breadcrumb, busca con debounce y muestra StoreFooter',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrap(
            HomeScreen(
              products: catalog,
              onBrowse: (_) {},
              onProduct: (_, _) {},
              onOpenQuote: () {},
              quoteQuantity: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBreadcrumbBar), findsNothing);
        expect(find.text('INICIO'), findsNothing);
        expect(find.byType(StoreFooter), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'cintas');
        // Antes de los 450ms no reconstruye los resultados todavía
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Resultados'), findsNothing);

        // Después de 450ms muestra los resultados expandidos (3 tonos de cinta satinada + 3 cintas + cautín)
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Resultados'), findsOneWidget);
        expect(find.text('7 resultados'), findsOneWidget);
        expect(find.text('N.°1 BLANCO'), findsOneWidget);

        // Pulsar el chip popular "Cintas satinadas" expande todos los tonos
        await tester.tap(find.text('Cintas satinadas'));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('3 resultados'), findsOneWidget);
        expect(find.text('N.°1 BLANCO'), findsOneWidget);
        expect(find.text('N.°2 ROJO PASIÓN'), findsOneWidget);
        expect(find.text('N.°3 MARFIL'), findsOneWidget);
      },
    );

    testWidgets('CatalogScreen muestra MATERIALES sin INICIO y StoreFooter', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          CatalogScreen(
            products: catalog,
            initialCategory: ProductCategory.materials,
            onProduct: (_, _) {},
            onBack: () {},
            onOpenQuote: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBreadcrumbBar), findsOneWidget);
      expect(find.text('INICIO'), findsNothing);
      expect(find.text('MATERIALES'), findsWidgets);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.byType(StoreFooter), findsOneWidget);
    });

    testWidgets(
      'QuoteScreen, CoordinationScreen, ReviewScreen y HelpScreen comparten breadcrumb y footer',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final resolved = [
          ResolvedQuoteLine(
            line: QuoteLine(
              productId: catalog.first.id,
              variantId: catalog.first.variants.first.id,
              quantity: 2,
            ),
            product: catalog.first,
          ),
        ];

        // Carrito
        await tester.pumpWidget(
          wrap(
            QuoteScreen(
              lines: resolved,
              onQuantityChanged: (_, _) {},
              onRemove: (_) {},
              onContinue: () {},
              onBrowse: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBreadcrumbBar), findsOneWidget);
        expect(find.text('INICIO'), findsNothing);
        expect(find.text('CARRITO'), findsOneWidget);
        expect(find.byType(StoreFooter), findsOneWidget);

        // Datos
        await tester.pumpWidget(
          wrap(
            CoordinationScreen(
              initial: const CoordinationDetails(),
              earliestDate: DateTime(2026, 11, 20),
              onSubmit: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBreadcrumbBar), findsOneWidget);
        expect(find.text('INICIO'), findsNothing);
        expect(find.text('CARRITO'), findsOneWidget);
        expect(find.text('DATOS'), findsOneWidget);
        expect(find.byType(StoreFooter), findsOneWidget);

        // Revisión
        await tester.pumpWidget(
          wrap(
            ReviewScreen(
              lines: resolved,
              details: const CoordinationDetails(
                name: 'Ana',
                phone: '987654321',
              ),
              quoteId: 'EXP-100',
              message: 'Cotización',
              onCopyMessage: () {},
              onEditQuote: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBreadcrumbBar), findsOneWidget);
        expect(find.text('INICIO'), findsNothing);
        expect(find.text('CARRITO'), findsOneWidget);
        expect(find.text('DATOS'), findsOneWidget);
        expect(find.text('REVISIÓN'), findsOneWidget);
        expect(find.byType(StoreFooter), findsOneWidget);

        // Ayuda
        await tester.pumpWidget(
          wrap(
            HelpScreen(
              onPrivacy: () {},
              onAdminLogin: () {},
              onAssistantGuide: () {},
              assistantMuted: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppBreadcrumbBar), findsOneWidget);
        expect(find.text('INICIO'), findsNothing);
        expect(find.text('AYUDA'), findsOneWidget);
        expect(find.byType(StoreFooter), findsOneWidget);
      },
    );
  });
}
