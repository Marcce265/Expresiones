import 'package:flutter_test/flutter_test.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/services/map_launcher_service.dart';
import 'package:expresiones/services/quote_message.dart';

void main() {
  group('MapLauncherService', () {
    test('buildGeoUri construye URI con esquema geo: y coordenadas', () {
      final uri = MapLauncherService.buildGeoUri(
        latitude: -12.046374,
        longitude: -77.042793,
      );

      expect(uri.scheme, 'geo');
      expect(uri.toString(), 'geo:-12.046374,-77.042793?q=-12.046374,-77.042793');
    });

    test('buildGeoUri incluye etiqueta codificada si se proporciona', () {
      final uri = MapLauncherService.buildGeoUri(
        latitude: -12.0673,
        longitude: -75.2049,
        label: 'Agencia Huancayo Central',
      );

      expect(uri.scheme, 'geo');
      expect(uri.toString(), contains('Agencia%20Huancayo%20Central'));
    });

    test('buildWebMapUri construye enlace a Google Maps', () {
      final uri = MapLauncherService.buildWebMapUri(
        latitude: -12.0673,
        longitude: -75.2049,
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['query'], '-12.0673,-75.2049');
    });
  });

  group('CoordinationDetails con geolocalización', () {
    test('serializa y deserializa coordenadas de agencia Shalom', () {
      const details = CoordinationDetails(
        name: 'Carlos Mendoza',
        phone: '987654321',
        deliveryMethod: DeliveryMethod.shalom,
        destination: 'Huancayo · Junín',
        shalomAgencyId: '123',
        shalomAgencyName: 'Agencia Huancayo Real',
        shalomAgencyAddress: 'Av. Real 450',
        shalomAgencyLocality: 'Huancayo · Huancayo · Junín',
        shalomAgencyLatitude: -12.0673,
        shalomAgencyLongitude: -75.2049,
      );

      final json = details.toJson();
      expect(json['shalomAgencyLatitude'], -12.0673);
      expect(json['shalomAgencyLongitude'], -75.2049);

      final copy = CoordinationDetails.fromJson(json);
      expect(copy.shalomAgencyLatitude, -12.0673);
      expect(copy.shalomAgencyLongitude, -75.2049);
      expect(copy.shalomAgencyName, 'Agencia Huancayo Real');
    });

    test('QuoteMessageBuilder incluye link a Google Maps si hay coordenadas', () {
      const product = CatalogProduct(
        id: 'mat_01',
        name: 'Limpiapipas',
        category: ProductCategory.materials,
        basePrice: 2.0,
      );

      final lines = [
        const ResolvedQuoteLine(
          line: QuoteLine(productId: 'mat_01', quantity: 10),
          product: product,
        ),
      ];

      final message = QuoteMessageBuilder.build(
        id: 'COT-TEST-GEO',
        lines: lines,
        details: const CoordinationDetails(
          name: 'Carlos Mendoza',
          phone: '987654321',
          deliveryMethod: DeliveryMethod.shalom,
          shalomAgencyId: '123',
          shalomAgencyName: 'Agencia Huancayo Real',
          shalomAgencyAddress: 'Av. Real 450',
          shalomAgencyLocality: 'Huancayo · Junín',
          shalomAgencyLatitude: -12.0673,
          shalomAgencyLongitude: -75.2049,
        ),
      );

      expect(message, contains('COT-TEST-GEO'));
      expect(message, contains('Agencia Shalom: Agencia Huancayo Real'));
      expect(message, contains('Mapa: https://www.google.com/maps/search/?api=1&query=-12.0673,-75.2049'));
    });
  });
}
