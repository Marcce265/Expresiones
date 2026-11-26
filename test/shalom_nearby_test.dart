import 'package:expresiones/models/shalom_agency.dart';
import 'package:expresiones/screens/shalom_agency_picker.dart';
import 'package:expresiones/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _DeniedLocation implements DeviceLocationService {
  @override
  Future<Position> currentPosition() async {
    throw const LocationPermissionException('Sin permiso de ubicación.');
  }
}

class _FixedLocation implements DeviceLocationService {
  @override
  Future<Position> currentPosition() async => Position(
    latitude: -12.07,
    longitude: -75.21,
    timestamp: DateTime(2026, 11, 23),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  testWidgets('Shalom conserva la búsqueda al denegar ubicación', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShalomAgencyPicker(
          locationService: _DeniedLocation(),
          loadCatalog: () async => ShalomAgencyCatalog.fromJson({
            'agencies': [
              {
                'id': 'test-huancayo',
                'name': 'Huancayo',
                'openingHours': '08:00 a 12:00',
                'isPublic': true,
                'canReceive': true,
              },
            ],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin permiso de ubicación.'), findsNothing);
    await tester.tap(find.text('Agencias cerca de mí'));
    await tester.pumpAndSettle();
    expect(find.text('Sin permiso de ubicación.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Huancayo');
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Sin resultados'), findsNothing);
    expect(find.byType(Card), findsWidgets);
    expect(find.text('Horario: 08:00 a 12:00'), findsOneWidget);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('Shalom ordena los destinos elegibles por proximidad', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ShalomAgencyPicker(
          locationService: _FixedLocation(),
          loadCatalog: () async => ShalomAgencyCatalog.fromJson({
            'agencies': [
              {
                'id': 'far',
                'name': 'Agencia lejana',
                'latitude': -12.05,
                'longitude': -77.04,
                'isPublic': true,
                'canReceive': true,
              },
              {
                'id': 'near',
                'name': 'Huancayo centro',
                'latitude': -12.08,
                'longitude': -75.22,
                'isPublic': true,
                'canReceive': true,
              },
              {
                'id': 'third',
                'name': 'Agencia sur',
                'latitude': -12.15,
                'longitude': -75.21,
                'isPublic': true,
                'canReceive': true,
              },
              {
                'id': 'second',
                'name': 'Agencia este',
                'latitude': -12.07,
                'longitude': -75.17,
                'isPublic': true,
                'canReceive': true,
              },
              {
                'id': 'unavailable',
                'name': 'Solo recojo',
                'latitude': -12.07,
                'longitude': -75.21,
                'isPublic': true,
                'canReceive': false,
              },
            ],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nearbyButton = find.text('Agencias cerca de mí');
    final search = find.byType(TextField);
    await tester.tap(nearbyButton);
    await tester.pumpAndSettle();
    final near = find.text('Huancayo centro');
    final second = find.text('Agencia este');
    final third = find.text('Agencia sur');
    final far = find.text('Agencia lejana');
    expect(tester.getTopLeft(near).dy, lessThan(tester.getTopLeft(second).dy));
    expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(third).dy));
    expect(find.text('Solo recojo'), findsNothing);
    expect(find.text('Ver más agencias'), findsNothing);

    await tester.enterText(search, 'lejána');
    await tester.pump(const Duration(milliseconds: 250));
    expect(near, findsNothing);
    expect(far, findsOneWidget);
    await tester.tap(find.byTooltip('Borrar búsqueda'));
    await tester.pumpAndSettle();
    expect(near, findsOneWidget);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}
