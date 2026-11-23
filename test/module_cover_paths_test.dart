import 'dart:io';

import 'package:expresiones/data/seed_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'todas las imágenes dinámicas del catálogo provienen de Supabase Storage y no de assets locales',
    () {
      const expectedIds = {
        'tul-con-perlas',
        'alambre-floral',
        'papel-leche-cortado',
        'cinta-tornasol-4cm-7m',
        'cinta-organza-con-perlas',
        'cinta-corazones-dorados',
        'cinta-estampada-lujo',
        'cinta-eternal-love',
        'perlas-decorativas',
        'floratape',
        'brochetas',
        'luz-hada',
        'mariposas-decorativas',
        'frases-en-vinil',
      };

      for (final id in expectedIds) {
        final product = seedCatalogProducts.singleWhere(
          (item) => item.id == id,
        );
        final detailPath = product.imageUrl;
        final thumbnailPath = product.thumbnailUrl;
        expect(detailPath, isNotNull, reason: '$id needs a detail cover');
        expect(thumbnailPath, isNotNull, reason: '$id needs a thumbnail cover');
        expect(
          detailPath,
          startsWith('https://wxoaedvqeuynzinzazsj.supabase.co/storage/v1/object/public/catalog/'),
        );
        expect(
          thumbnailPath,
          startsWith('https://wxoaedvqeuynzinzazsj.supabase.co/storage/v1/object/public/catalog/'),
        );
      }

      for (final product in seedCatalogProducts) {
        if (product.imageUrl != null) {
          expect(product.imageUrl, isNot(startsWith('assets/')));
        }
        if (product.thumbnailUrl != null) {
          expect(product.thumbnailUrl, isNot(startsWith('assets/')));
        }
        for (final variant in product.variants) {
          if (variant.imageUrl != null) {
            expect(variant.imageUrl, isNot(startsWith('assets/')));
          }
          if (variant.thumbnailUrl != null) {
            expect(variant.thumbnailUrl, isNot(startsWith('assets/')));
          }
        }
      }
    },
  );

  test(
    'assets/images contiene únicamente imágenes estáticas de interfaz en formato WebP',
    () {
      final dir = Directory('assets/images');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList()
        ..sort();

      // Solo logo.png se conserva para flutter_launcher_icons en compilación.
      final runtimeImages = files
          .where((path) => path != 'assets/images/logo.png')
          .toList();
      expect(runtimeImages, isNotEmpty);
      for (final path in runtimeImages) {
        expect(path, endsWith('.webp'), reason: '$path debe estar en WebP');
        expect(path, isNot(contains('module_covers')));
        expect(path, isNot(contains('family_heroes')));
        expect(path, isNot(contains('korean_paper')));
        expect(path, isNot(contains('limpiapipas_optimized')));
        expect(path, isNot(contains('catalog_hd')));
        expect(path, isNot(endsWith('catalog_hero.webp')));
      }
    },
  );
}
