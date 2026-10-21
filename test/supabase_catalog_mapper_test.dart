import 'package:expresiones/data/supabase_catalog_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('separa miniaturas de catálogo e imágenes de detalle', () {
    final product =
        SupabaseCatalogMapper(
              resolveImage: (path) => path == null ? null : 'https://cdn/$path',
            )
            .mapCatalog(
              families: [
                {
                  'id': 'family-uuid',
                  'slug': 'limpiapipas-premium-8mm',
                  'name': 'Limpiapipas',
                  'kind': 'materials',
                  'base_price': 5,
                  'active': true,
                  'cover_thumb_path': 'family/thumb.webp',
                  'cover_detail_path': 'family/detail.webp',
                },
              ],
              variants: [
                {
                  'id': 'variant-uuid',
                  'family_id': 'family-uuid',
                  'slug': 'piel',
                  'name': 'Piel',
                  'active': true,
                  'thumb_path': 'variant/thumb.webp',
                  'detail_path': 'variant/detail.webp',
                },
              ],
              familyPriceTiers: const [],
              variantPriceTiers: const [],
            )
            .single;

    expect(product.thumbnailUrl, 'https://cdn/family/thumb.webp');
    expect(product.imageUrl, 'https://cdn/family/detail.webp');
    expect(
      product.variants.single.previewImageUrl,
      'https://cdn/variant/thumb.webp',
    );
    expect(product.variants.single.imageUrl, 'https://cdn/variant/detail.webp');
  });
}
