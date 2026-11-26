import 'package:expresiones/models/shalom_agency.dart';
import 'package:expresiones/screens/shalom_destination_picker.dart';
import 'package:expresiones/services/device_location_service.dart';
import 'package:expresiones/widgets/shalom_embedded_map.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  testWidgets('Agencia cercana rellena los filtros y ordena tres destinos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = ShalomAgencyCatalog.fromJson({
      'agencies': [
        _agency('4', 'Lejana', latitude: -13),
        _agency('3', 'Tercera', latitude: -12.18),
        _agency('1', 'Primera', latitude: -12.07),
        _agency('2', 'Segunda', district: 'CHILCA', latitude: -12.1),
        _agency('5', 'Solo origen', latitude: -12.06, canReceive: false),
      ],
    });
    ShalomAgency? selected;
    final location = _TestLocation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ShalomDestinationPicker(
                selectedId: selected?.id ?? '',
                showError: false,
                loadCatalog: () async => catalog,
                locationService: location,
                onSelected: (agency) => setState(() => selected = agency),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(location.requests, 0);
    await tester.tap(find.text('Agencia cercana'));
    await tester.pumpAndSettle();

    String? value(String label) => tester
        .widget<DropdownButton<String>>(find.byKey(ValueKey(label)))
        .value;
    expect(value('Departamento'), 'JUNIN');
    expect(value('Provincia'), 'HUANCAYO');
    expect(value('Distrito'), 'EL TAMBO');
    expect(find.byType(Radio<String>), findsNWidgets(3));
    expect(find.text('Lejana'), findsNothing);
    expect(find.text('Solo origen'), findsNothing);
    expect(selected, isNull);
    final first = find.text('Primera');
    final second = find.text('Segunda');
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    await tester.tap(second);
    await tester.pumpAndSettle();
    expect(selected?.id, '2');
    expect(value('Distrito'), 'CHILCA');
    final map = find.byType(ShalomEmbeddedMap);
    expect(tester.getTopLeft(map).dx, greaterThan(tester.getTopLeft(first).dx));
    expect(tester.widget<ShalomEmbeddedMap>(map).selectedAgencyId, '2');
  });

  testWidgets('muestra tres agencias y permite desplazar hasta las demás', (
    tester,
  ) async {
    final catalog = ShalomAgencyCatalog.fromJson({
      'agencies': [
        for (var index = 1; index <= 5; index++)
          _agency('$index', 'Agencia $index'),
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShalomDestinationPicker(
              selectedId: '1',
              showError: false,
              onSelected: (_) {},
              loadCatalog: () async => catalog,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byKey(const ValueKey('agency-results'));
    expect(find.text('Agencia 3').hitTestable(), findsOneWidget);
    expect(find.text('Agencia 4').hitTestable(), findsNothing);
    final firstCard = find.byWidget(
      tester
          .element(find.text('Agencia 1'))
          .findAncestorWidgetOfExactType<Card>()!,
    );
    final radio = find.descendant(
      of: firstCard,
      matching: find.byType(Radio<String>),
    );
    expect(
      tester.getCenter(radio).dy,
      closeTo(tester.getCenter(firstCard).dy, 1),
    );

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(list),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Agencia 4').hitTestable(), findsOneWidget);

    await tester.drag(list, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.text('Agencia 5').hitTestable(), findsOneWidget);
  });

  testWidgets('filtra por ubicación y limpia la agencia al cambiar de zona', (
    tester,
  ) async {
    final catalog = ShalomAgencyCatalog.fromJson({
      'agencies': [
        _agency('1', 'El Tambo Centro'),
        _agency('2', 'El Tambo Norte'),
        _agency('3', 'Chilca Centro', district: 'CHILCA'),
        _agency('4', 'Solo origen', canReceive: false),
        _agency('5', 'Lima Centro', department: 'LIMA', province: 'LIMA'),
      ],
    });
    ShalomAgency? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ShalomDestinationPicker(
                selectedId: selected?.id ?? '',
                showError: false,
                onSelected: (agency) => setState(() => selected = agency),
                loadCatalog: () async => catalog,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(String label) => find.byKey(ValueKey(label));
    Future<void> choose(String label, String value) async {
      await tester.tap(field(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    expect(
      tester.widget<DropdownButton<String>>(field('Provincia')).onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButton<String>>(field('Distrito')).onChanged,
      isNull,
    );
    await choose('Departamento', 'JUNIN');
    await choose('Provincia', 'HUANCAYO');
    await choose('Distrito', 'EL TAMBO');

    expect(find.byType(Radio<String>), findsNWidgets(2));
    expect(find.text('Chilca Centro'), findsNothing);
    expect(find.text('Solo origen'), findsNothing);
    expect(find.text('Lima Centro'), findsNothing);
    await tester.tap(find.text('El Tambo Norte'));
    await tester.pumpAndSettle();
    expect(selected?.id, '2');

    await choose('Departamento', 'LIMA');
    expect(selected, isNull);
    expect(find.byType(Radio<String>), findsNothing);
    expect(
      tester.widget<DropdownButton<String>>(field('Provincia')).value,
      isNull,
    );
    expect(
      tester.widget<DropdownButton<String>>(field('Distrito')).value,
      isNull,
    );
  });
}

Map<String, Object> _agency(
  String id,
  String name, {
  String department = 'JUNIN',
  String province = 'HUANCAYO',
  String district = 'EL TAMBO',
  bool canReceive = true,
  double? latitude,
}) => {
  'id': id,
  'name': name,
  'department': department,
  'province': province,
  'district': district,
  'web': true,
  'canReceive': canReceive,
  'latitude': ?latitude,
  if (latitude != null) 'longitude': -75.21,
};

class _TestLocation implements DeviceLocationService {
  int requests = 0;

  @override
  Future<Position> currentPosition() async {
    requests++;
    return Position(
      latitude: -12.06,
      longitude: -75.21,
      timestamp: DateTime.utc(2026, 11, 26),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
