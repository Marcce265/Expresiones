import '../models/catalog_models.dart';

typedef CatalogImageResolver = String? Function(Object? path);

/// Converts the normalized Supabase rows into the stable model used by the UI.
///
/// Database UUIDs remain internal. Family and variant slugs are deliberately
/// exposed as IDs so saved quotes keep working across the migration.
class SupabaseCatalogMapper {
  const SupabaseCatalogMapper({required this.resolveImage});

  final CatalogImageResolver resolveImage;

  List<CatalogProduct> mapCatalog({
    required List<Map<String, dynamic>> families,
    required List<Map<String, dynamic>> variants,
    required List<Map<String, dynamic>> familyPriceTiers,
    required List<Map<String, dynamic>> variantPriceTiers,
  }) {
    final variantsByFamily = <String, List<Map<String, dynamic>>>{};
    for (final variant in variants) {
      final familyId = '${variant['family_id'] ?? ''}';
      if (familyId.isEmpty) continue;
      variantsByFamily.putIfAbsent(familyId, () => []).add(variant);
    }

    final familyTiersByFamily = <String, List<Map<String, dynamic>>>{};
    for (final tier in familyPriceTiers) {
      final familyId = '${tier['family_id'] ?? ''}';
      if (familyId.isEmpty) continue;
      familyTiersByFamily.putIfAbsent(familyId, () => []).add(tier);
    }

    final variantTiersByVariant = <String, List<Map<String, dynamic>>>{};
    for (final tier in variantPriceTiers) {
      final variantId = '${tier['variant_id'] ?? ''}';
      if (variantId.isEmpty) continue;
      variantTiersByVariant.putIfAbsent(variantId, () => []).add(tier);
    }

    final products = <CatalogProduct>[];
    for (final family in families) {
      final familyUuid = '${family['id'] ?? ''}';
      final familyVariants = List<Map<String, dynamic>>.of(
        variantsByFamily[familyUuid] ?? const [],
      );
      familyVariants.sort(_bySortOrderThenName);

      products.add(
        CatalogProduct.fromMap({
          'id': family['slug'],
          'name': family['name'],
          'category': family['kind'],
          'description': family['description'],
          'sku': family['sku'],
          'unitLabel': family['sale_unit'],
          'basePrice': family['base_price'],
          'startingAt': family['starting_at'],
          'priceIsEstimate': family['price_is_reference'],
          'priceTiers': [
            for (final tier in familyTiersByFamily[familyUuid] ?? const [])
              _tierMap(tier),
          ],
          'variants': [
            for (final variant in familyVariants)
              _variantMap(
                variant,
                variantTiersByVariant['${variant['id'] ?? ''}'] ?? const [],
              ),
          ],
          'stock': family['stock_count'],
          'stockStatus': family['stock_status'],
          'leadDays': family['prep_days'],
          'productionPoints': family['production_points'],
          'isActive': family['active'],
          'isFeatured': family['featured'],
          'sortOrder': family['sort_order'],
          'imageUrl': resolveImage(
            family['cover_detail_path'] ??
                family['cover_path'] ??
                family['cover_thumb_path'],
          ),
          'tags': family['tags'],
          'attributes': family['attributes'],
          'createdAt': family['created_at'],
          'updatedAt': family['updated_at'],
        }),
      );
    }

    products.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0
          ? order
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(products);
  }

  Map<String, dynamic> _variantMap(
    Map<String, dynamic> variant,
    List<Map<String, dynamic>> tiers,
  ) {
    return {
      'id': variant['slug'],
      'name': variant['name'],
      'sku': variant['sku'],
      'colorHex': variant['color_hex'],
      'imageUrl': resolveImage(
        variant['detail_path'] ??
            variant['image_path'] ??
            variant['thumb_path'],
      ),
      'priceOverride': variant['base_price'],
      'priceTiers': [for (final tier in tiers) _tierMap(tier)],
      'stock': variant['stock_count'],
      'stockStatus': variant['stock_status'],
      'leadDays': variant['prep_days'],
      'productionPoints': variant['production_points'],
      'isActive': variant['active'],
      'attributes': variant['attributes'],
    };
  }

  Map<String, dynamic> _tierMap(Map<String, dynamic> tier) => {
    'minQuantity': tier['min_qty'],
    'unitPrice': tier['unit_price'],
    'label': tier['label'],
  };

  static int _bySortOrderThenName(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aOrder = _int(a['sort_order']);
    final bOrder = _int(b['sort_order']);
    final order = aOrder.compareTo(bOrder);
    return order != 0
        ? order
        : '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}');
  }

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
