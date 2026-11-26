import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/security/rate_limiter.dart';
import 'package:expresiones/widgets/pickup_location_map.dart';
import 'package:expresiones/widgets/shalom_embedded_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const pickup = PickupLocationSettings();
  for (final (name, cardLabel, pinLabel, map) in const [
    (
      'recojo',
      'Expresiones Eternas',
      'Centrar mapa en la tienda',
      PickupLocationMap(location: pickup),
    ),
    (
      'Shalom',
      'Huancayo Centro',
      'Centrar mapa en Huancayo Centro',
      ShalomEmbeddedMap(
        selectedAgencyId: 'qa',
        selectedAgencyName: 'Huancayo Centro',
        latitude: -12.07,
        longitude: -75.20,
        showOtherAgencies: false,
      ),
    ),
  ]) {
    testWidgets('la tarjeta y el pin de $name recentran con límite de toques', (
      tester,
    ) async {
      ClientRateLimiter.instance.reset();
      addTearDown(ClientRateLimiter.instance.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: map)),
        ),
      );
      await tester.pump();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final initial = controller.camera.center;
      final zoom = controller.camera.zoom;
      final displaced = LatLng(initial.latitude, initial.longitude + 0.0003);

      controller.move(displaced, zoom - 1);
      await tester.pump();
      await tester.tap(find.text(cardLabel));
      await tester.pump();
      expect(controller.camera.center, initial);
      expect(controller.camera.zoom, zoom);

      controller.move(displaced, zoom - 1);
      await tester.pump();
      await tester.tap(find.byTooltip(pinLabel));
      await tester.pump();
      expect(controller.camera.center, initial);
      expect(controller.camera.zoom, zoom);

      controller.move(displaced, zoom - 1);
      await tester.pump();
      await tester.tap(find.text(cardLabel));
      expect(controller.camera.center, displaced);
    });
  }
}
