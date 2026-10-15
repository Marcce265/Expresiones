import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/admin/admin_catalog_repository.dart';

void main() {
  test('normaliza nombres y códigos como IDs seguros de Firestore', () {
    expect(
      AdminCatalogRepository.normalizedDocumentId('  Cinta Satinada 100 m '),
      'cinta-satinada-100-m',
    );
    expect(
      AdminCatalogRepository.normalizedDocumentId('SAT/01 · Turquesa'),
      'sat-01-turquesa',
    );
  });
}
