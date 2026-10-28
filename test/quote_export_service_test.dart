import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/services/quote_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const product = CatalogProduct(
    id: 'cinta-satinada',
    name: 'Cinta satinada',
    category: ProductCategory.materials,
    basePrice: 5,
    unitLabel: 'rollo',
    sku: 'SAT',
    priceTiers: [
      PriceTier(minQuantity: 12, unitPrice: 4.5, label: 'Precio por docena'),
    ],
    variants: [
      ProductVariant(id: 'rojo', name: 'Rojo', sku: 'SAT-17', priceOverride: 5),
    ],
  );
  const line = ResolvedQuoteLine(
    line: QuoteLine(
      productId: 'cinta-satinada',
      variantId: 'rojo',
      quantity: 12,
    ),
    product: product,
  );
  final details = CoordinationDetails(
    name: 'María López',
    phone: '999999999',
    deliveryMethod: DeliveryMethod.shalom,
    shalomAgencyId: 'agencia-huancayo',
    shalomAgencyName: 'Huancayo Centro',
    shalomAgencyLocality: 'Huancayo, Junín',
    shalomAgencyAddress: 'Jr. Ejemplo 123',
    desiredDate: DateTime(2026, 10, 20),
  );

  test('genera un PDF válido con contenido', () async {
    final bytes = await QuoteExportService.buildPdf(
      quoteId: 'COT-TEST-0001',
      lines: const [line],
      details: details,
      generatedAt: DateTime(2026, 10, 15, 10, 30),
    );

    expect(bytes.length, greaterThan(1000));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('genera un XLSX legible con los valores de la cotización', () {
    final bytes = QuoteExportService.buildXlsx(
      quoteId: 'COT-TEST-0001',
      lines: const [line],
      details: details,
      generatedAt: DateTime(2026, 10, 15, 10, 30),
    );

    expect(bytes.take(2), [0x50, 0x4b]);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook['Cotización'];
    expect(
      sheet.cell(CellIndex.indexByString('A1')).value?.toString(),
      'EXPRESIONES',
    );
    expect(
      sheet.cell(CellIndex.indexByString('A5')).value?.toString(),
      contains('Cinta satinada'),
    );
    expect(sheet.cell(CellIndex.indexByString('C5')).value?.toString(), '12');
  });

  test(
    'genera comprobante simulado PDF y XLSX sin datos financieros',
    () async {
      final order = CheckoutOrder(
        id: 'PED-20261024-001',
        items: const [
          CheckoutOrderItem(
            productId: 'cinta-satinada',
            productName: 'Cinta satinada',
            variantId: 'rojo',
            variantName: 'Rojo',
            sku: 'SAT-17',
            unitLabel: 'rollo',
            quantity: 2,
            unitPrice: 5,
            lineTotal: 10,
          ),
        ],
        details: details,
        productsSubtotal: 10,
        payment: SimulatedPayment(
          reference: 'SIM-20261024-001',
          method: SimulatedPaymentMethod.demoYape,
          status: SimulatedPaymentStatus.approved,
          amount: 10,
          processedAt: DateTime(2026, 10, 24, 12),
        ),
        createdAt: DateTime(2026, 10, 24, 12),
      );

      final pdf = await QuoteExportService.buildOrderPdf(order);
      expect(ascii.decode(pdf.take(4).toList()), '%PDF');

      final bytes = QuoteExportService.buildOrderXlsx(order);
      final sheet = Excel.decodeBytes(bytes)['Pedido simulado'];
      expect(
        sheet.cell(CellIndex.indexByString('A3')).value?.toString(),
        contains('No se realizó ningún cobro real'),
      );
      expect(
        sheet.cell(CellIndex.indexByString('A6')).value?.toString(),
        contains('Cinta satinada'),
      );
      expect(
        sheet
            .row(0)
            .followedBy(sheet.row(1))
            .followedBy(sheet.row(2))
            .join(' '),
        isNot(contains('CVV')),
      );
    },
  );
}
