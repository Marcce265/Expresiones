import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PriceTier por presentación', () {
    test('convierte el total de una docena al precio unitario persistido', () {
      final tier = PriceTier.fromPresentationTotal(
        minQuantity: 12,
        totalPrice: 30,
        label: 'Docena',
      );

      expect(tier.unitPrice, 2.5);
      expect(tier.presentationTotal, 30);
      expect(tier.toMap(), {
        'minQuantity': 12,
        'unitPrice': 2.5,
        'label': 'Docena',
      });
    });

    test('conserva exactamente el total de un ciento', () {
      final tier = PriceTier.fromPresentationTotal(
        minQuantity: 100,
        totalPrice: 200,
        label: 'Ciento',
      );

      expect(tier.unitPrice, 2);
      expect(tier.presentationTotal, 200);
    });

    test('rechaza cantidades y montos que no pueden cobrarse', () {
      expect(
        () => PriceTier.fromPresentationTotal(minQuantity: 0, totalPrice: 10),
        throwsArgumentError,
      );
      expect(
        () => PriceTier.fromPresentationTotal(
          minQuantity: 12,
          totalPrice: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => PriceTier.fromPresentationTotal(
          minQuantity: 12,
          totalPrice: double.infinity,
        ),
        throwsArgumentError,
      );
    });
  });

  test('oculta el número de paleta solo en el nombre público', () {
    const variant = ProductVariant(
      id: 'satin-01',
      name: 'N.º 01 · Blanco perla',
      sku: 'SAT-01',
      attributes: {'paletteNumber': '01'},
    );

    expect(variantDisplayName(variant), 'Blanco perla');
    expect(variant.name, 'N.º 01 · Blanco perla');
    expect(variant.sku, 'SAT-01');
  });
}
