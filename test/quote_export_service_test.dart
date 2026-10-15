import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
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
}
