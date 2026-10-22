import 'package:expresiones/admin/admin_image_draft.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminImageDraft', () {
    test('muestra la misma portada que la tarjeta sin perder el detalle', () {
      const product = CatalogProduct(
        id: 'limpiapipas',
        name: 'Limpiapipas',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: 'https://cdn.example/detail.webp',
        thumbnailUrl: 'https://cdn.example/card.webp',
      );

      final draft = AdminImageDraft.fromProduct(product);

      expect(draft.previewValue, 'https://cdn.example/card.webp');
      expect(draft.persistedValue, 'https://cdn.example/detail.webp');
      expect(draft.changed, isFalse);
    });

    test('no vuelve a persistir una URL pública si la imagen no cambió', () {
      final draft = AdminImageDraft(
        persistedValue:
            'https://demo.supabase.co/storage/v1/object/public/catalog/'
            'products/limpiapipas/cover.webp?version=12',
        previewValue:
            'https://demo.supabase.co/storage/v1/object/public/catalog/'
            'products/limpiapipas/thumb.webp',
      );
      final payload = <String, dynamic>{
        'name': 'Limpiapipas',
        'imageUrl': draft.persistedValue,
      };

      draft.writeReplacementTo(payload);

      expect(draft.persistedValue, 'products/limpiapipas/cover.webp');
      expect(
        draft.previewValue,
        'https://demo.supabase.co/storage/v1/object/public/catalog/'
        'products/limpiapipas/thumb.webp',
      );
      expect(draft.changed, isFalse);
      expect(payload, isNot(contains('imageUrl')));
    });

    test('una imagen elegida reemplaza vista previa y valor persistido', () {
      const variant = ProductVariant(
        id: 'verde-militar',
        name: 'Verde militar',
        imageUrl: 'https://cdn.example/old-detail.webp',
        thumbnailUrl: 'https://cdn.example/old-card.webp',
      );
      final draft = AdminImageDraft.fromVariant(variant);

      draft.replaceWith(' products/limpiapipas/new-image.webp ');

      expect(draft.previewValue, 'products/limpiapipas/new-image.webp');
      expect(draft.persistedValue, 'products/limpiapipas/new-image.webp');
      expect(draft.changed, isTrue);
      final payload = <String, dynamic>{};
      draft.writeReplacementTo(payload);
      expect(payload['imageUrl'], 'products/limpiapipas/new-image.webp');
    });

    test('conserva URLs externas y assets que no pertenecen al bucket', () {
      expect(
        AdminImageDraft.canonicalStorageValue(
          'https://images.example.com/catalog/product.webp?size=large',
        ),
        'https://images.example.com/catalog/product.webp?size=large',
      );
      expect(
        AdminImageDraft.canonicalStorageValue('assets/images/product.webp'),
        'assets/images/product.webp',
      );
      expect(
        AdminImageDraft.canonicalStorageValue(
          'storage://catalog/products/cinta/portada.webp',
        ),
        'products/cinta/portada.webp',
      );
    });

    test('usa la miniatura como valor persistido cuando no hay detalle', () {
      const product = CatalogProduct(
        id: 'producto',
        name: 'Producto',
        category: ProductCategory.materials,
        basePrice: 1,
        thumbnailUrl: 'assets/images/producto.webp',
      );

      final draft = AdminImageDraft.fromProduct(product);

      expect(draft.previewValue, 'assets/images/producto.webp');
      expect(draft.persistedValue, 'assets/images/producto.webp');
    });
  });
}
