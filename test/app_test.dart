import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/data/guide_preferences.dart';
import 'package:expresiones/main.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/catalog_screen.dart';
import 'package:expresiones/screens/home_screen.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/product_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('Android con Supabase pide una cuenta antes del catálogo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(() async => seedCatalogProducts);
    await store.initialize();
    addTearDown(store.dispose);
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: ExpresionesApp(supabaseClient: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Inicia sesión o crea una cuenta para entrar al catálogo.'),
      findsOneWidget,
    );
    expect(find.byType(HomeScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(client.dispose);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

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
    expect(productFamilyHeroAsset(limpiapipas), isNull);
    expect(productFamilyHeroAsset(cinta), isNull);
  });

  test(
    'la portada administrada usa únicamente URLs remotas y nunca assets locales',
    () {
      final withoutManagedCover = CatalogProduct(
        id: 'limpiapipas-premium-8mm',
        name: 'Limpiapipas premium 8 mm',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: 'assets/images/family_heroes/limpiapipas.webp',
        variants: [
          ProductVariant(
            id: 'verde-militar',
            name: 'Verde militar',
            imageUrl: 'https://cdn.example/variant-cover.webp',
          ),
        ],
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
        'https://cdn.example/variant-cover.webp',
      );
    },
  );

  test('todas las familias del catálogo tienen imágenes remotas para su portada', () {
    final families = seedCatalogProducts.where(
      (product) =>
          product.isActive &&
          product.category == ProductCategory.materials &&
          product.variants.where((variant) => variant.isActive).length > 1,
    );

    expect(families, isNotEmpty);
    for (final product in families) {
      final cover = productFamilyCoverImage(product);
      expect(
        cover != null && cover.startsWith('https://'),
        isTrue,
        reason: '${product.name} necesita una portada en Supabase Storage',
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
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Inicio', 'Catálogo', 'Carrito', 'Ayuda']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }

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

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Ayuda'),
      ),
    );
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

  testWidgets('la barra inferior navega directamente entre pestañas sin menú duplicado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await const GuidePreferences().markOnboardingSeen();
    final store = AppStore(() async => seedCatalogProducts);
    await store.initialize();

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const ExpresionesApp()),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Expresiones, ir al inicio'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);

    final cartBadges = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(Badge),
    );
    expect(
      tester.widget<Badge>(cartBadges.first).backgroundColor,
      AppColors.rose,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Catálogo'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CatalogScreen), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Carrito'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la portada pública usa la imagen remota configurada por administración',
    (tester) async {
      const configuredUrl =
          'https://wxoaedvqeuynzinzazsj.supabase.co/storage/v1/object/public/catalog/site/home/custom-hero.webp';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              products: const [],
              popularProducts: const [],
              settings: const StorefrontSettings(
                texts: {StorefrontText.homeHeroImage: configuredUrl},
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
              widget.image is NetworkImage &&
              (widget.image as NetworkImage).url == configuredUrl,
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
