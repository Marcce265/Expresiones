import 'dart:io';

import 'package:expresiones/data/seed_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

void main() {
  test(
    'generated module covers include optimized detail and thumbnail files',
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

        final detail = File(detailPath!);
        final thumbnail = File(thumbnailPath!);
        expect(detail.existsSync(), isTrue, reason: detail.path);
        expect(thumbnail.existsSync(), isTrue, reason: thumbnail.path);
        expect(detail.lengthSync(), lessThan(1024 * 1024), reason: detail.path);
        expect(
          thumbnail.lengthSync(),
          lessThan(300 * 1024),
          reason: thumbnail.path,
        );

        final detailImage = image_lib.decodeImage(detail.readAsBytesSync());
        final thumbnailImage = image_lib.decodeImage(
          thumbnail.readAsBytesSync(),
        );
        expect(detailImage?.width, 1200, reason: detail.path);
        expect(detailImage?.height, 1200, reason: detail.path);
        expect(thumbnailImage?.width, 640, reason: thumbnail.path);
        expect(thumbnailImage?.height, 640, reason: thumbnail.path);
      }
    },
  );
}
