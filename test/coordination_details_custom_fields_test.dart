import 'package:expresiones/models/coordination_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los campos adicionales sobreviven el guardado local', () {
    const details = CoordinationDetails(
      name: 'María',
      phone: '999999999',
      customFields: {'DNI': '12345678', 'Nombre de quien recoge': 'Ana'},
    );

    final restored = CoordinationDetails.fromJson(details.toJson());

    expect(restored.customFields['DNI'], '12345678');
    expect(restored.customFields['Nombre de quien recoge'], 'Ana');
  });

  test('descarta respuestas adicionales vacías al restaurar', () {
    final details = CoordinationDetails.fromJson({
      'customFields': {'DNI': '  ', 'Referencia': ' Puerta azul '},
    });

    expect(details.customFields, {'Referencia': 'Puerta azul'});
  });
}
