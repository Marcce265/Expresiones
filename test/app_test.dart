import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/data/guide_preferences.dart';
import 'package:expresiones/main.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/catalog_screen.dart';
import 'package:expresiones/screens/home_screen.dart';
import 'package:expresiones/screens/quote_screen.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/breadcrumb_bar.dart';
import 'package:expresiones/widgets/product_visual.dart';
import 'package:expresiones/widgets/store_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('el catálogo ofrece añadir rápido solo en fichas individuales', (
    tester,
  ) async {
    final family = CatalogProduct(
      id: 'family-qa',
      name: 'Familia prueba',
      category: ProductCategory.materials,
      basePrice: 5,
      unitLabel: 'paquete',
      variants: [
        ProductVariant(id: 'a', name: 'A'),
        ProductVariant(id: 'b', name: 'B'),
      ],
    );
    final single = CatalogProduct(
      id: 'single-qa',
      name: 'Individual prueba',
      category: ProductCategory.materials,
      basePrice: 5,
      unitLabel: 'unidad',
    );
    final added = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CatalogScreen(
            products: [family, single],
            onProduct: (_, _) =>
                fail('La acción rápida no debe abrir la ficha'),
            onBack: () {},
            onOpenQuote: () {},
            onAddToCart: (product, _) => added.add(product.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Añadir FAMILIA PRUEBA al carrito'), findsNothing);
    final openFamily = find.widgetWithIcon(
      IconButton,
      Icons.arrow_forward_rounded,
    );
    final addIndividual = find.widgetWithIcon(
      IconButton,
      Icons.add_shopping_cart_rounded,
    );
    expect(tester.getSize(openFamily), const Size.square(39));
    expect(tester.getSize(addIndividual), tester.getSize(openFamily));
    expect(tester.getCenter(addIndividual).dy, tester.getCenter(openFamily).dy);
    await tester.tap(find.byTooltip('Añadir INDIVIDUAL PRUEBA al carrito'));
    expect(added, [single.id]);
  });

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
      BoxFit.cover,
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

  test('incluye solo los 46 tonos numerados de cinta satinada', () {
    final cinta = seedCatalogProducts.firstWhere(
      (product) => product.id == 'cinta-satinada-100m',
    );

    expect(cinta.variants, hasLength(46));
    expect(cinta.variants.first.name, 'N.°1 BLANCO');
    expect(cinta.variants.last.name, 'N.º 49 · NEGRO');
    expect(
      cinta.variants.map((variant) => variant.imageUrl).toSet(),
      hasLength(46),
    );
    expect(
      cinta.variants.every(
        (variant) =>
            variant.imageUrl != null &&
            variant.imageUrl!.contains(
              'cinta-satinada-100m/variants/optimized/',
            ),
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
      'assets/images/family_heroes/cinta_satinada_todos_colores.webp',
    );
  });

  test(
    'la portada administrada tiene prioridad sobre el recurso editorial',
    () {
      final withoutManagedCover = CatalogProduct(
        id: 'limpiapipas-premium-8mm',
        name: 'Limpiapipas premium 8 mm',
        category: ProductCategory.materials,
        basePrice: 5,
      );
      final updated = CatalogProduct(
        id: 'limpiapipas-premium-8mm',
        name: 'Limpiapipas premium 8 mm',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: 'https://cdn.example/new-main.webp',
        thumbnailUrl: 'https://cdn.example/new-main.webp',
      );

      expect(
        productFamilyCoverImage(updated),
        'https://cdn.example/new-main.webp',
      );
      expect(
        productFamilyCoverImage(withoutManagedCover),
        productFamilyHeroAsset(withoutManagedCover),
      );
    },
  );

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
    expect(message, contains('MORADO UVA'));
    expect(message, contains('S/ 54.00'));
    expect(message, contains('Recojo en Huancayo'));
  });

  testWidgets(
    'el carrito vacío conserva el encabezado arriba y el pie al fondo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuoteScreen(
              lines: const [],
              onQuantityChanged: (_, _) {},
              onRemove: (_) {},
              onContinue: () {},
              onBrowse: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(AppBreadcrumbBar)).dy, 12);
      expect(tester.getBottomRight(find.byType(StoreFooter)).dy, 900);
      expect(find.text('0 productos'), findsNothing);
    },
  );

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

    expect(find.text('¡Hola! Soy Jashy'), findsOneWidget);
    expect(find.byKey(const ValueKey('jashy_tour_spotlight')), findsOneWidget);
    for (var step = 0; step < 5; step++) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Expresiones, ir al inicio'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Abrir catálogo'), findsOneWidget);
    expect(find.byTooltip('Abrir carrito'), findsOneWidget);
    expect(find.byTooltip('Abrir ayuda'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('¡Hola! Soy Jashy'), findsNothing);
  });

  testWidgets('No molestar cierra el tutorial y conserva la ayuda de Jashy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await const GuidePreferences().markOnboardingSeen();
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

    await tester.tap(find.byTooltip('Abrir ayuda de Jashy'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cerrar ayuda de Jashy'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar ayuda de Jashy'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Abrir ayuda'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Repetir guía de Jashy'));
    await tester.tap(find.text('Repetir guía de Jashy'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('No molestar'));
    await tester.pumpAndSettle();
    expect(find.text('¡Hola! Soy Jashy'), findsNothing);
    await tester.tap(find.byTooltip('Abrir ayuda de Jashy'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cerrar ayuda de Jashy'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar ayuda de Jashy'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Activar guía de Jashy'));
    await tester.tap(find.text('Activar guía de Jashy'));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola! Soy Jashy'), findsOneWidget);
    await tester.tap(find.text('No molestar'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('¡Hola! Soy Jashy'), findsNothing);
    expect(find.byTooltip('Abrir ayuda de Jashy'), findsOneWidget);
  });

  testWidgets('la cabecera móvil agrupa inicio, catálogo, carrito y ayuda arriba', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await const GuidePreferences().markOnboardingSeen();
    final store = AppStore(() async => seedCatalogProducts);
    await store.initialize();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Expresiones, ir al inicio'), findsOneWidget);
    expect(find.byTooltip('Abrir menú'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    final cartBadge = find.descendant(
      of: find.byTooltip('Abrir carrito'),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(cartBadge).backgroundColor, AppColors.rose);

    await tester.tap(find.byTooltip('Abrir catálogo'));
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Abrir carrito'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Abrir menú'), findsNothing);
  });

  testWidgets(
    'la portada pública usa la imagen configurada por administración',
    (tester) async {
      const configuredAsset =
          'assets/images/family_heroes/cinta_satinada_todos_colores.webp';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              products: const [],
              popularProducts: const [],
              settings: const StorefrontSettings(
                texts: {StorefrontText.homeHeroImage: configuredAsset},
              ),
              onBrowse: (_) {},
              onProduct: (_, _) {},
              onOpenQuote: () {},
              quoteQuantity: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == configuredAsset,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('agrupa los precios al entrar a una familia del catálogo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final added = <(String, String?)>[];
    Widget catalog(List<CatalogProduct> products) => MaterialApp(
      home: Scaffold(
        body: CatalogScreen(
          products: products,
          onProduct: (_, _) {},
          onBack: () {},
          onOpenQuote: () {},
          onAddToCart: (product, variantId) =>
              added.add((product.id, variantId)),
        ),
      ),
    );

    await tester.pumpWidget(catalog(seedCatalogProducts));
    await tester.pumpAndSettle();

    expect(find.textContaining(' productos'), findsNothing);

    await tester.tap(find.text('LIMPIAPIPAS PREMIUM 8 MM'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('family-overview-limpiapipas-premium-8mm')),
      findsOneWidget,
    );
    expect(find.text('34 colores'), findsNothing);
    expect(find.text('Mismos precios para todas las opciones'), findsOneWidget);
    expect(find.text('S/ 5.00 c/u'), findsOneWidget);
    expect(find.text('S/ 4.50 c/u'), findsOneWidget);
    expect(find.text('S/ 4.30 c/u'), findsOneWidget);
    expect(find.text('S/ 4.00 c/u'), findsOneWidget);
    expect(find.text('S/ 5.00'), findsNothing);

    final family = seedCatalogProducts.firstWhere(
      (product) => product.id == 'limpiapipas-premium-8mm',
    );
    final variant = family.variants.first;
    final quickAdd = find.byTooltip(
      'Añadir ${variantDisplayName(variant)} al carrito',
    );
    await tester.scrollUntilVisible(
      quickAdd,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final cartButton = find.ancestor(
      of: quickAdd,
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(cartButton), const Size.square(39));
    expect(find.textContaining('Código XS-1'), findsNothing);
    await tester.ensureVisible(cartButton);
    await tester.pumpAndSettle();
    await tester.tap(cartButton);
    expect(added, [(family.id, variant.id)]);
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);

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
