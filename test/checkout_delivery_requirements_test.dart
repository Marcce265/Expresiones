import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/coordination_screen.dart';
import 'package:expresiones/screens/review_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recojo no solicita datos de identidad de Shalom', (
    tester,
  ) async {
    await _pumpCoordination(tester);

    expect(find.text('NOMBRE *'), findsOneWidget);
    expect(find.text('TELÉFONO *'), findsOneWidget);
    expect(find.text('DNI *'), findsNothing);
    expect(find.text('FECHA DE NACIMIENTO *'), findsNothing);
    expect(find.text('HORARIO DE ATENCIÓN *'), findsOneWidget);
  });

  testWidgets('Shalom solicita identidad y nombre completo obligatorios', (
    tester,
  ) async {
    await _pumpCoordination(tester);

    await tester.tap(find.text('Envío por Shalom').first);
    await tester.pumpAndSettle();

    expect(find.text('NOMBRE COMPLETO *'), findsOneWidget);
    expect(find.text('DNI *'), findsOneWidget);
    expect(find.text('FECHA DE NACIMIENTO *'), findsNothing);
    expect(find.text('HORARIO DE ATENCIÓN *'), findsNothing);
    expect(
      find.textContaining('el DNI debe pertenecer a una persona mayor de edad'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombres y apellidos'),
      'Marcial',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '+51 999 999 999'),
      '938766452',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '8 dígitos'),
      '1234567',
    );
    final submit = find.widgetWithText(FilledButton, 'Revisar mi cotización');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Escribe tu nombre completo.'), findsOneWidget);
    expect(find.text('El DNI debe tener 8 dígitos.'), findsOneWidget);
  });

  testWidgets('los campos administrativos respetan su forma de entrega', (
    tester,
  ) async {
    await _pumpCoordination(
      tester,
      settings: const StorefrontSettings(
        checkoutFields: [
          CheckoutCustomField(
            id: 'pickup_reference',
            label: 'Referencia de recojo',
            scope: CheckoutFieldScope.pickup,
          ),
          CheckoutCustomField(
            id: 'shalom_reference',
            label: 'Referencia de Shalom',
            scope: CheckoutFieldScope.shalom,
          ),
        ],
      ),
    );

    expect(find.text('REFERENCIA DE RECOJO *'), findsOneWidget);
    expect(find.text('REFERENCIA DE SHALOM *'), findsNothing);

    await tester.tap(find.text('Envío por Shalom').first);
    await tester.pumpAndSettle();

    expect(find.text('REFERENCIA DE RECOJO *'), findsNothing);
    expect(find.text('REFERENCIA DE SHALOM *'), findsOneWidget);
  });

  testWidgets('la fecha deseada es obligatoria', (tester) async {
    var submitted = false;
    await _pumpCoordination(tester, onSubmit: (_) => submitted = true);
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo te llamas?'),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '+51 999 999 999'),
      '999999999',
    );
    final submit = find.widgetWithText(FilledButton, 'Revisar mi cotización');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(submitted, isFalse);
    expect(find.text('Selecciona una fecha.'), findsOneWidget);
  });

  testWidgets('recojo exige y conserva un horario de atención', (tester) async {
    CoordinationDetails? submitted;
    await _pumpCoordination(
      tester,
      initial: CoordinationDetails(desiredDate: DateTime.now()),
      onSubmit: (details) => submitted = details,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo te llamas?'),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '+51 999 999 999'),
      '999999999',
    );

    final submit = find.widgetWithText(FilledButton, 'Revisar mi cotización');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Selecciona un horario de atención.'), findsOneWidget);

    final firstSlot = find.text('07:00 - 08:00');
    await tester.ensureVisible(firstSlot);
    await tester.tap(firstSlot);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(submitted?.customFields['Horario de recojo'], '07:00 - 08:00');
  });

  testWidgets('la revisión comercial no muestra el pago de prueba', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ReviewScreen(
          lines: const [],
          details: CoordinationDetails(desiredDate: DateTime(2026, 11, 2)),
          quoteId: 'COT-TEST',
          message: 'Cotización de prueba',
          onSendWhatsapp: () async {},
          onCopyMessage: () {},
          onEditQuote: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enviar por WhatsApp'), findsOneWidget);
    expect(find.text('Continuar al pago de prueba'), findsNothing);
    expect(find.text('Pago'), findsNothing);
    expect(find.text('Listo'), findsNothing);
    expect(find.textContaining('sin pagar'), findsNothing);
  });
}

Future<void> _pumpCoordination(
  WidgetTester tester, {
  ValueChanged<CoordinationDetails>? onSubmit,
  CoordinationDetails initial = const CoordinationDetails(),
  StorefrontSettings settings = const StorefrontSettings(),
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CoordinationScreen(
        initial: initial,
        earliestDate: DateTime.now(),
        deliveryWeekdays: (_) => const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
        onSubmit: onSubmit ?? (_) {},
        settings: settings,
      ),
    ),
  );
  await tester.pump();
}
