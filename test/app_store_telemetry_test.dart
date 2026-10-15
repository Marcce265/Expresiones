import 'dart:convert';

import 'package:expresiones/data/seed_catalog.dart';
import 'package:expresiones/data/telemetry_local_store.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/services/commerce_telemetry_service.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('no rearma abandono al restaurar un carrito ya enviado', () async {
    final product = seedCatalogProducts.first;
    SharedPreferences.setMockInitialValues({
      'expresiones.quote.v1': jsonEncode([
        QuoteLine(productId: product.id, quantity: 1).toJson(),
      ]),
    });
    final telemetry = CommerceTelemetryService(
      localStore: MemoryTelemetryStore(),
    );
    final store = AppStore(() async => [product], telemetry: telemetry);

    await store.initialize();

    expect(store.hasQuote, isTrue);
    expect(telemetry.quoteActivity, isNull);
    store.dispose();
  });
}
