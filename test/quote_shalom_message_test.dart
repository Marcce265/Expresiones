import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const details = CoordinationDetails(
    name: 'Paul Matos Medina',
    phone: '916889129',
    deliveryMethod: DeliveryMethod.shalom,
    shalomAgencyId: 'cerro-de-pasco',
    shalomAgencyName: 'CERRO DE PASCO',
    shalomAgencyLocality: 'CHAUPIMARCA · PASCO',
    shalomAgencyAddress: 'JR. HUARICAPCHA S/N A.H. TUPAC AMARU CHAUPIMARCA',
    customFields: {
      'Nombre': 'Paul',
      'Apellidos': 'Matos Medina',
      'DNI': '42555477',
    },
  );

  test('el mensaje completo conserva datos y costo variable de Shalom', () {
    final message = QuoteMessageBuilder.build(
      id: 'COT-TEST',
      lines: const [],
      details: details,
    );

    expect(message, contains('Agencia Shalom: CERRO DE PASCO'));
    expect(message, contains('CHAUPIMARCA · PASCO'));
    expect(message, contains('JR. HUARICAPCHA'));
    expect(message, contains('Nombres y apellidos: Paul Matos Medina'));
    expect(message, isNot(contains('\nNombre:')));
    expect(message, isNot(contains('\nApellidos:')));
    expect(message, contains('DNI: 42555477'));
    expect(message, contains('desde S/ 5.00'));
    expect(message, contains('tamaño y peso'));
  });

  test('WhatsApp recibe solo una introducción corta sin datos sensibles', () {
    final message = QuoteMessageBuilder.buildWhatsappIntro(
      id: 'COT-TEST',
      details: details,
    );

    expect(message, contains('COT-TEST'));
    expect(message, contains('Paul Matos Medina'));
    expect(message, isNot(contains('42555477')));
    expect(message, isNot(contains('916889129')));
    expect(message, isNot(contains('JR. HUARICAPCHA')));
    expect(message.length, lessThan(180));
  });
}
