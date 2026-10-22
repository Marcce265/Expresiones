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

  test(
    'la imagen editada reemplaza derivados antiguos de familia y variante',
    () {
      final product =
          SupabaseCatalogMapper(
                resolveImage: (path) =>
                    path == null ? null : 'https://cdn/$path',
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
                    'cover_path': 'uploads/new-cover.webp',
                    'cover_thumb_path': 'derived/old-thumb.webp',
                    'cover_detail_path': 'derived/old-detail.webp',
                  },
                ],
                variants: [
                  {
                    'id': 'variant-uuid',
                    'family_id': 'family-uuid',
                    'slug': 'piel',
                    'name': 'Piel',
                    'active': true,
                    'image_path': 'uploads/new-variant.webp',
                    'thumb_path': 'derived/old-variant-thumb.webp',
                    'detail_path': 'derived/old-variant-detail.webp',
                  },
                ],
                familyPriceTiers: const [],
                variantPriceTiers: const [],
              )
              .single;

      expect(product.imageUrl, 'https://cdn/uploads/new-cover.webp');
      expect(product.thumbnailUrl, 'https://cdn/uploads/new-cover.webp');
      expect(
        product.variants.single.imageUrl,
        'https://cdn/uploads/new-variant.webp',
      );
      expect(
        product.variants.single.thumbnailUrl,
        'https://cdn/uploads/new-variant.webp',
      );
    },
  );

  test('ignora rutas canónicas vacías y conserva el mejor fallback', () {
    final product =
        SupabaseCatalogMapper(resolveImage: (path) => path?.toString())
            .mapCatalog(
              families: [
                {
                  'id': 'family-uuid',
                  'slug': 'familia',
                  'name': 'Familia',
                  'kind': 'materials',
                  'base_price': 1,
                  'active': true,
                  'cover_path': '   ',
                  'cover_detail_path': 'family/detail.webp',
                  'cover_thumb_path': 'family/thumb.webp',
                },
              ],
              variants: const [],
              familyPriceTiers: const [],
              variantPriceTiers: const [],
            )
            .single;

    expect(product.imageUrl, 'family/detail.webp');
    expect(product.thumbnailUrl, 'family/thumb.webp');
  });
}
