import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/admin/admin_catalog_repository.dart';

void main() {
  test(
    'normaliza nombres y códigos como identificadores seguros (slugs/storage)',
    () {
      expect(
        AdminCatalogRepository.normalizedDocumentId('  Cinta Satinada 100 m '),
        'cinta-satinada-100-m',
      );
      expect(
        AdminCatalogRepository.normalizedDocumentId('SAT/01 · Turquesa'),
        'sat-01-turquesa',
      );
      expect(
        AdminCatalogRepository.normalizedDocumentId('---Rosas & Regalos---'),
        'rosas-regalos',
      );
      expect(
        AdminCatalogRepository.normalizedDocumentId('100% Hecho a mano!'),
        '100-hecho-a-mano',
      );
    },
  );

  group('carga de imágenes del catálogo', () {
    test('crea una ruta relativa segura y conserva las carpetas', () {
      expect(
        AdminCatalogRepository.buildCatalogImagePath(
          folder: r'products\Limpiapipas Premium\variants',
          fileName: 'Piel final.PNG',
          contentType: 'image/png',
          timestampMicros: 123456,
        ),
        'products/limpiapipas-premium/variants/123456-piel-final.png',
      );
      expect(AdminCatalogRepository.catalogImageCacheSeconds, '31536000');
    });

    test('valida contenido vacío, tamaño y formato antes de subir', () {
      expect(
        () => AdminCatalogRepository.validateCatalogImageUpload(
          bytes: Uint8List(0),
          contentType: 'image/png',
        ),
        throwsFormatException,
      );
      expect(
        () => AdminCatalogRepository.validateCatalogImageUpload(
          bytes: Uint8List(AdminCatalogRepository.maximumCatalogImageBytes + 1),
          contentType: 'image/webp',
        ),
        throwsFormatException,
      );
      expect(
        () => AdminCatalogRepository.validateCatalogImageUpload(
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/gif',
        ),
        throwsFormatException,
      );
    });

    test('acepta JPG, PNG y WebP hasta el límite configurado', () {
      for (final contentType
          in AdminCatalogRepository.allowedCatalogImageTypes) {
        expect(
          () => AdminCatalogRepository.validateCatalogImageUpload(
            bytes: Uint8List.fromList([1]),
            contentType: contentType,
          ),
          returnsNormally,
        );
      }
    });
  });
}
