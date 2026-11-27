import 'package:expresiones/models/shalom_agency.dart';
import 'package:expresiones/screens/shalom_destination_picker.dart';
import 'package:expresiones/widgets/shalom_embedded_map.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Agencia cercana'), findsNothing);
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

  testWidgets('en celular el mapa es opcional mediante el botón Ver mapa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = ShalomAgencyCatalog.fromJson({
      'agencies': [_agency('1', 'El Tambo Centro', latitude: -12.06)],
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

    expect(find.byType(ShalomEmbeddedMap), findsNothing);
    expect(find.text('Ver mapa'), findsOneWidget);

    await tester.tap(find.text('Ver mapa'));
    await tester.pumpAndSettle();

    expect(find.byType(ShalomEmbeddedMap), findsOneWidget);
    expect(find.text('Ocultar mapa'), findsOneWidget);
  });

  testWidgets('filtra por ubicación y limpia la agencia al cambiar de zona', (
    tester,
  ) async {
    final catalog = ShalomAgencyCatalog.fromJson({
      'agencies': [
        _agency('1', 'Concepción Centro'),
        _agency('2', 'Concepción Norte'),
        _agency('3', 'Matahuasi Centro', district: 'MATAHUASI'),
        _agency('4', 'Solo origen', canReceive: false),
        _agency('5', 'Lima Centro', department: 'LIMA', province: 'LIMA'),
        _agency(
          '6',
          'Huancayo Local',
          department: 'JUNIN',
          province: 'HUANCAYO',
          district: 'EL TAMBO',
        ),
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
    await choose('Provincia', 'CONCEPCION');
    await choose('Distrito', 'CONCEPCION');

    expect(find.byType(Radio<String>), findsNWidgets(2));
    expect(find.text('Matahuasi Centro'), findsNothing);
    expect(find.text('Huancayo Local'), findsNothing);
    expect(find.text('Solo origen'), findsNothing);
    expect(find.text('Lima Centro'), findsNothing);
    await tester.tap(find.text('Concepción Norte'));
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
  String province = 'CONCEPCION',
  String district = 'CONCEPCION',
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
