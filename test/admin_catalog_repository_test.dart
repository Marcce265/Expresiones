import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/admin/admin_catalog_repository.dart';

void main() {
  test('normaliza nombres y códigos como identificadores seguros (slugs/storage)', () {
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
  });
}
