import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final products = seedCatalogProducts;
  final published = products
      .where(
        (product) =>
            product.isActive && product.category == ProductCategory.materials,
      )
      .toList(growable: false);
  final future = products
      .where((product) => product.category != ProductCategory.materials)
      .toList(growable: false);

  test('conserva el inventario completo y el catálogo público esperado', () {
    expect(products, hasLength(36));
    expect(
      products.fold<int>(0, (total, item) => total + item.variants.length),
      238,
    );

    expect(published, hasLength(30));
    expect(
      published.fold<int>(0, (total, item) => total + item.variants.length),
      223,
    );

    expect(future, hasLength(6));
    expect(future.every((product) => !product.isActive), isTrue);
  });

  test('publica la cinta organza tornasol como una sola familia', () {
    final ribbon = products.singleWhere(
      (product) => product.id == 'cinta-tornasol-4cm-7m',
    );

    expect(
      products.any((product) => product.id == 'cinta-organza-tornasol'),
      isFalse,
    );
    expect(ribbon.name, 'Cinta organza tornasol 4 cm × 7 m');
    expect(ribbon.basePrice, 8);
    expect(ribbon.variants, hasLength(9));
    expect(ribbon.variants.map((variant) => variant.name), [
      'Perla',
      'Melón',
      'Rosa bebé',
      'Blanco',
      'Amarillo tornasol',
      'Rojo coral',
      'Turquesa',
      'Celeste',
      'Lila',
    ]);
    expect(
      ribbon.priceTiers.map((tier) => (tier.minQuantity, tier.unitPrice)),
      [(6, 7.5), (12, 7)],
    );
  });

  test('mantiene slugs y SKU sin duplicados', () {
    final slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
    final familyIds = products.map((product) => product.id).toList();

    expect(familyIds.toSet(), hasLength(familyIds.length));
    expect(familyIds.every(slugPattern.hasMatch), isTrue);

    final skus = <String>[];
    for (final product in products) {
      final variantIds = product.variants.map((variant) => variant.id).toList();
      expect(
        variantIds.toSet(),
        hasLength(variantIds.length),
        reason: '${product.id} contiene slugs de variante duplicados',
      );
      expect(
        variantIds.every(slugPattern.hasMatch),
        isTrue,
        reason: '${product.id} contiene un slug de variante inválido',
      );

      for (final variant in product.variants) {
        final sku = variant.sku?.trim();
        if (sku != null && sku.isNotEmpty) skus.add(sku);
      }
    }

    expect(skus.toSet(), hasLength(skus.length));
    expect(
      published
          .expand((product) => product.variants)
          .every((variant) => variant.sku?.trim().isNotEmpty ?? false),
      isTrue,
    );
  });

  test('todos los precios publicados son definitivos', () {
    expect(published.every((product) => !product.priceIsEstimate), isTrue);
    expect(future.every((product) => product.priceIsEstimate), isTrue);
  });
}
