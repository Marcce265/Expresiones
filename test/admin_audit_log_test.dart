import 'package:expresiones/admin/admin_operations_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin audit log parses the bounded database row contract', () {
    final log = AdminAuditLog.fromMap({
      'id': 12,
      'action': 'update',
      'resource_type': 'catalog_product',
      'resource_id': 'cinta-satinada-100m',
      'resource_label': 'Cinta satinada 100 m',
      'actor_email': 'admin@expresiones.pe',
      'changed_sections': ['prices', 'image'],
      'created_at': '2026-10-27T18:30:00Z',
    });

    expect(log.id, 12);
    expect(log.resourceLabel, 'Cinta satinada 100 m');
    expect(log.changedSections, ['prices', 'image']);
    expect(log.createdAt.toUtc(), DateTime.utc(2026, 10, 27, 18, 30));
  });
}
