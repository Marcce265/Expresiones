import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
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

  test('el mensaje incluye un solo cargo de transporte y embalaje', () {
    final product = CatalogProduct(
      id: 'test',
      name: 'Limpiapipas',
      sku: 'SKU-INTERNO',
      category: ProductCategory.materials,
      unitLabel: 'paquete',
      basePrice: 5,
    );
    final message = QuoteMessageBuilder.build(
      id: 'COT-TEST',
      lines: [
        ResolvedQuoteLine(
          line: const QuoteLine(productId: 'test', quantity: 99),
          product: product,
        ),
      ],
      details: details,
    );

    expect(message, contains('Agencia Shalom: CERRO DE PASCO'));
    expect(message, contains('CHAUPIMARCA · PASCO'));
    expect(message, contains('JR. HUARICAPCHA'));
    expect(message, contains('Nombres y apellidos: Paul Matos Medina'));
    expect(message, isNot(contains('\nNombre:')));
    expect(message, isNot(contains('\nApellidos:')));
    expect(message, contains('DNI: 42555477'));
    expect(message.split('\n').first, 'Resumen de cotización - COT-TEST');
    expect(message, isNot(contains('Hola, buen día')));
    expect(
      message,
      contains(
        'Subtotal de productos: S/ 495.00\n'
        'Transporte y embalaje: S/ 5.00\n'
        'Total: S/ 500.00',
      ),
    );
    expect('Transporte y embalaje'.allMatches(message), hasLength(1));
    expect(message, isNot(contains('Embalaje para Shalom')));
    expect(message, isNot(contains('SKU-INTERNO')));
    expect(message, isNot(contains('Flete de Shalom')));
    expect(shalomPackingFee(100), 7);
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
