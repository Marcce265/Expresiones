import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/screens/product_detail_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/store_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el detalle de producto despliega la experiencia UI/UX estilo Rosatel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final product = CatalogProduct(
      id: 'ramo-primaveral',
      name: 'Ramo Primaveral Girasoles',
      category: ProductCategory.bouquets,
      description: 'Hermoso ramo de girasoles con follaje fresco y envoltura de regalo.',
      sku: 'FC-AMA-2-PRI',
      basePrice: 95.0,
      unitLabel: 'ramo',
      variants: [
        ProductVariant(
          id: 'clasico',
          name: 'Clásico',
          sku: 'FC-AMA-2-PRI-C',
        ),
        ProductVariant(
          id: 'especial',
          name: 'Especial con dedicatoria',
          sku: 'FC-AMA-2-PRI-E',
        ),
      ],
    );

    final related = [
      CatalogProduct(
        id: 'ramo-rosas',
        name: 'Ramo Premium 12 Rosas',
        category: ProductCategory.bouquets,
        description: 'Docena de rosas eternas rojas.',
        basePrice: 85.0,
      ),
    ];

    bool addedToCart = false;
    bool boughtNow = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ProductDetailScreen(
            product: product,
            relatedProducts: related,
            onAdd: ({required quantity, variantId, required customization}) {
              addedToCart = true;
            },
            onBuyNow: ({required quantity, variantId, required customization}) {
              boughtNow = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Breadcrumbs
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Ramos'), findsWidgets);
    expect(find.textContaining('PRIMAVERAL GIRASOLES'), findsWidgets);

    // 2. Buy Box: Título, SKU y Precio
    expect(find.text('SKU: FC-AMA-2-PRI-C'), findsOneWidget);
    expect(find.text('S/ 95.00'), findsOneWidget);
    expect(find.text('por RAMO'), findsOneWidget);

    // 3. Botones estilo Rosatel
    expect(find.text('Comprar ahora'), findsOneWidget);
    expect(find.textContaining('Añadir al carrito · S/ 95.00'), findsOneWidget);

    // 4. Tarjeta de entrega y programación
    expect(
      find.text('Puedes programar la fecha y horario de entrega o recojo en tu carrito.'),
      findsOneWidget,
    );

    // 5. Franja de confianza con los 3 pilares
    expect(find.byType(TrustBadgesStrip), findsOneWidget);
    expect(find.text('Calidad premium'), findsOneWidget);
    expect(find.text('Productos seleccionados'), findsOneWidget);
    expect(find.text('Atención personalizada'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Contáctanos'), findsOneWidget);

    // 6. Sección "Descripción del producto"
    expect(find.text('Descripción del producto'), findsOneWidget);
    expect(find.text('Línea Ramos · Expresiones'), findsOneWidget);
    expect(find.text(product.description), findsOneWidget);

    // 7. Productos en la misma categoría
    expect(find.text('Productos en la misma categoría'), findsOneWidget);
    expect(find.text('RAMO PREMIUM 12 ROSAS'), findsOneWidget);

    // 8. Banners informativos y footer
    expect(find.byType(StoreDisclaimerBanner), findsOneWidget);
    expect(find.text('Fotos referenciales'), findsOneWidget);
    expect(find.byType(StoreSpecialOrderBanner), findsOneWidget);
    expect(find.text('¿Buscas un diseño o pedido a medida?'), findsOneWidget);
    expect(find.byType(StoreFooter), findsOneWidget);
    expect(find.text('FORMAS DE PAGO'), findsOneWidget);
    expect(find.text('Yape'), findsOneWidget);

    // 9. Acciones interactivas: Añadir al carrito y Comprar ahora
    await tester.tap(find.widgetWithText(FilledButton, 'Añadir al carrito · S/ 95.00'));
    expect(addedToCart, isTrue);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Comprar ahora'));
    expect(boughtNow, isTrue);

    // 10. Favoritos toggle
    final heart = find.byTooltip('Guardar en favoritos');
    expect(heart, findsOneWidget);
    await tester.tap(heart);
    await tester.pump();
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
  });
}
