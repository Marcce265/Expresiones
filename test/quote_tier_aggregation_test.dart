import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ProductVariant> colors(int count) => [
    for (var index = 0; index < count; index++)
      ProductVariant(id: 'color-$index', name: 'Color $index'),
  ];

  CatalogProduct productWith({List<ProductVariant>? variants}) =>
      CatalogProduct(
        id: 'limpiapipas-premium',
        name: 'Limpiapipas premium',
        category: ProductCategory.materials,
        basePrice: 5,
        unitLabel: 'paquete',
        priceTiers: [
          PriceTier(minQuantity: 12, unitPrice: 4.5, label: 'Docena'),
          PriceTier(minQuantity: 100, unitPrice: 4.3, label: 'Ciento'),
        ],
        variants: variants ?? colors(12),
      );

  test('suma todos los colores para aplicar el precio de docena', () {
    final product = productWith();
    final lines = [
      for (var index = 0; index < 12; index++)
        QuoteLine(
          productId: product.id,
          variantId: product.variants[index].id,
          quantity: 1,
        ),
    ];

    final resolved = resolveQuoteLines(
      lines: lines,
      products: {product.id: product},
    );

    expect(resolved, hasLength(12));
    expect(resolved.every((line) => line.tierQuantity == 12), isTrue);
    expect(resolved.every((line) => line.unitPrice == 4.5), isTrue);
    expect(resolved.every((line) => line.priceTierLabel == 'DOCENA'), isTrue);
    expect(resolved.fold<double>(0, (sum, line) => sum + line.total), 54);
  });

  test('no aplica el tramo si la suma de colores no llega al mínimo', () {
    final product = productWith();
    final lines = [
      for (var index = 0; index < 11; index++)
        QuoteLine(
          productId: product.id,
          variantId: product.variants[index].id,
          quantity: 1,
        ),
    ];

    final resolved = resolveQuoteLines(
      lines: lines,
      products: {product.id: product},
    );

    expect(resolved.every((line) => line.unitPrice == 5), isTrue);
    expect(resolved.fold<double>(0, (sum, line) => sum + line.total), 55);
  });

  test(
    'el mensaje conserva el total por línea y muestra el precio unitario',
    () {
      final product = productWith();
      final lines = [
        QuoteLine(
          productId: product.id,
          variantId: product.variants.first.id,
          quantity: 2,
        ),
        for (var index = 1; index < 11; index++)
          QuoteLine(
            productId: product.id,
            variantId: product.variants[index].id,
            quantity: 1,
          ),
      ];

      final resolved = resolveQuoteLines(
        lines: lines,
        products: {product.id: product},
      );
      final message = QuoteMessageBuilder.build(
        id: 'COT-PRUEBA',
        lines: resolved,
        details: const CoordinationDetails(
          name: 'Paul Matos Medina',
          phone: '916889129',
        ),
      );

      expect(resolved.first.total, 9);
      expect(resolved.first.unitPrice, 4.5);
      expect(message, contains('DOCENA: S/ 9.00 · S/ 4.50 c/u'));
      expect(message, contains('Subtotal de productos: S/ 54.00'));
      expect(message, isNot(contains('Por PAQUETE: S/ 5.00')));
    },
  );

  test('los tramos propios de una variante no se mezclan con el producto', () {
    final special = ProductVariant(
      id: 'especial',
      name: 'Especial',
      priceTiers: [PriceTier(minQuantity: 6, unitPrice: 3, label: 'Especial')],
    );
    final product = productWith(variants: [...colors(12), special]);
    final lines = [
      for (var index = 0; index < 6; index++)
        QuoteLine(
          productId: product.id,
          variantId: product.variants[index].id,
          quantity: 1,
        ),
      for (var index = 0; index < 6; index++)
        QuoteLine(productId: product.id, variantId: special.id, quantity: 1),
    ];

    final resolved = resolveQuoteLines(
      lines: lines,
      products: {product.id: product},
    );

    expect(resolved.take(6).every((line) => line.unitPrice == 5), isTrue);
    expect(resolved.skip(6).every((line) => line.unitPrice == 3), isTrue);
  });
}
