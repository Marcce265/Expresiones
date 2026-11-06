import 'package:expresiones/data/customer_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza el celular peruano usado para iniciar sesión', () {
    expect(
      CustomerAccountRepository.normalizePhone('+51 938 766 452'),
      '938766452',
    );
    expect(
      CustomerAccountRepository.loginEmail('938-766-452'),
      '51938766452@clientes.expresiones.app',
    );
  });

  test('rechaza números que no sean celulares peruanos', () {
    expect(
      () => CustomerAccountRepository.normalizePhone('74765942'),
      throwsFormatException,
    );
  });
}
