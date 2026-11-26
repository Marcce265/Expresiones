import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/coordination_screen.dart';
import 'package:expresiones/screens/review_screen.dart';
import 'package:expresiones/services/quote_pdf_share_service.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/shalom_embedded_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime get _testDate => DateTime(2026, 11, 25);
DateTime _morningInLima() => DateTime.utc(2026, 11, 25, 11);

void main() {
  testWidgets('Datos pide la forma de entrega antes del contacto', (
    tester,
  ) async {
    await _pumpCoordination(tester);
    final delivery = tester.getTopLeft(find.text('Forma de entrega'));
    final contact = tester.getTopLeft(find.text('Tus datos de contacto'));
    expect(delivery.dy, lessThan(contact.dy));
    expect(find.text('Tu pedido'), findsNothing);
    expect(find.textContaining('Revisar mi cotización'), findsOneWidget);
  });

  testWidgets('recojo no solicita datos de identidad de Shalom', (
    tester,
  ) async {
    await _pumpCoordination(tester);

    expect(find.text('NOMBRE *'), findsOneWidget);
    expect(find.text('TELÉFONO *'), findsOneWidget);
    expect(find.text('DNI *'), findsNothing);
    expect(find.text('FECHA DE NACIMIENTO *'), findsNothing);
    expect(find.text('HORARIO DE RECOJO'), findsOneWidget);
  });

  testWidgets('Shalom solicita identidad y nombre completo obligatorios', (
    tester,
  ) async {
    await _pumpCoordination(tester);

    await tester.tap(find.text('Envío por Shalom').first);
    await tester.pumpAndSettle();

    expect(find.text('NOMBRE *'), findsOneWidget);
    expect(find.text('APELLIDOS *'), findsOneWidget);
    expect(find.text('DNI *'), findsOneWidget);
    expect(find.text('FECHA DE NACIMIENTO *'), findsNothing);
    expect(find.text('HORARIO DE RECOJO'), findsNothing);
    expect(find.text('Buscar agencia'), findsOneWidget);
    expect(find.byType(ShalomEmbeddedMap), findsOneWidget);
    expect(find.textContaining('La agencia entregará el envío'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo te llamas?'),
      'M',
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

    expect(find.text('Escribe un nombre válido.'), findsOneWidget);
    expect(find.text('Escribe tus apellidos.'), findsOneWidget);
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

  testWidgets(
    'Shalom abre su pantalla anterior desde el botón Cambiar agencia',
    (tester) async {
      await _pumpCoordination(
        tester,
        initial: const CoordinationDetails(
          deliveryMethod: DeliveryMethod.shalom,
          shalomAgencyId: 'agency-test',
          shalomAgencyName: 'Bagua Grande',
          shalomAgencyLatitude: -5.75,
          shalomAgencyLongitude: -78.44,
        ),
        cartQuantity: 100,
      );

      final changeAgency = find.text('Cambiar agencia');
      await tester.ensureVisible(changeAgency);
      await tester.tap(changeAgency);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Agencias Shalom'), findsOneWidget);
      Navigator.of(tester.element(find.text('Agencias Shalom'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(changeAgency, findsOneWidget);
      expect(find.textContaining('Embalaje: S/ 7.00'), findsOneWidget);
      final map = tester.widget<ShalomEmbeddedMap>(
        find.byType(ShalomEmbeddedMap),
      );
      expect(map.selectedAgencyId, 'agency-test');
      expect(map.showOtherAgencies, isTrue);
    },
  );

  testWidgets('la fecha deseada es obligatoria', (tester) async {
    var submitted = false;
    await _pumpCoordination(tester, onSubmit: (_) => submitted = true);
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo te llamas?'),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tus apellidos'),
      'Rojas',
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

  testWidgets('el calendario integrado permite elegir un día en español', (
    tester,
  ) async {
    await _pumpCoordination(tester);

    final calendar = find.byKey(const ValueKey('delivery-calendar'));
    expect(calendar, findsOneWidget);
    final today = _testDate;
    final next = DateTime(today.year, today.month + 1);
    final forward = find.byTooltip('Mes siguiente');
    await tester.ensureVisible(forward);
    await tester.pumpAndSettle();
    await tester.tap(forward);
    await tester.pumpAndSettle();
    final context = tester.element(calendar);
    expect(
      find.text(MaterialLocalizations.of(context).formatMonthYear(next)),
      findsOneWidget,
    );
    final day = find.descendant(
      of: calendar,
      matching: find.widgetWithText(TextButton, '1'),
    );
    await tester.ensureVisible(day);
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(find.text('07:00 - 08:00'), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('recojo exige y conserva un horario de atención', (tester) async {
    CoordinationDetails? submitted;
    await _pumpCoordination(
      tester,
      initial: CoordinationDetails(desiredDate: _testDate),
      onSubmit: (details) => submitted = details,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Cómo te llamas?'),
      'Ana',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tus apellidos'),
      'Rojas',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '+51 999 999 999'),
      '999999999',
    );

    final submit = find.widgetWithText(FilledButton, 'Revisar mi cotización');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Selecciona un horario de recojo.'), findsOneWidget);

    final firstSlot = find.text('07:00 - 08:00');
    await tester.ensureVisible(firstSlot);
    await tester.tap(firstSlot);

    // Intentar enviar sin marcar las dos casillas separadas debe bloquearse
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(submitted, isNull);
    expect(
      find.text(
        'Marca ambas casillas por separado (Términos y Condiciones y Política de Privacidad) para continuar.',
      ),
      findsOneWidget,
    );

    // Marcar solo una casilla tampoco permite continuar (prohibido un solo chulito para todo)
    final termsCheckbox = find.byKey(const ValueKey('consent_terms_checkbox'));
    await tester.ensureVisible(termsCheckbox);
    await tester.tap(termsCheckbox);
    await tester.pump();
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(submitted, isNull);

    // Marcar la segunda casilla separada (Política de Privacidad) habilita el envío y registra fecha/hora/canal
    final privacyCheckbox = find.byKey(
      const ValueKey('consent_privacy_checkbox'),
    );
    await tester.ensureVisible(privacyCheckbox);
    await tester.tap(privacyCheckbox);
    await tester.pump();

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(submitted?.customFields['Horario de recojo'], '07:00 - 08:00');
    expect(submitted?.termsAcceptedAt, isNotNull);
    expect(submitted?.privacyAcceptedAt, isNotNull);
    expect(submitted?.legalPolicyVersion, '2026-11-PE');
    expect(submitted?.legalAcceptedVia, contains('dos_casillas_separadas'));
  });

  testWidgets('muestra los horarios configurados para el día elegido', (
    tester,
  ) async {
    await _pumpCoordination(
      tester,
      initial: CoordinationDetails(desiredDate: _testDate),
      pickupTimeSlotsForDate: (_) => const ['10:00 - 11:00', '11:00 - 12:00'],
    );

    expect(find.text('10:00 - 11:00'), findsOneWidget);
    expect(find.text('11:00 - 12:00'), findsOneWidget);
    expect(find.text('07:00 - 08:00'), findsNothing);
  });

  testWidgets('recojo retira los horarios vencidos según la hora de Lima', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 25, 18, 5);
    await _pumpCoordination(
      tester,
      initial: CoordinationDetails(desiredDate: _testDate),
      now: () => now,
      pickupTimeSlotsForDate: (_) => const ['12:00 - 13:00', '14:00 - 15:00'],
    );

    expect(find.text('12:00 - 13:00'), findsNothing);
    expect(find.text('14:00 - 15:00'), findsOneWidget);

    // 01:00 UTC the next day is still 20:00 of the 25th in Lima.
    now = DateTime.utc(2026, 11, 26, 1);
    await tester.pump(const Duration(minutes: 1));
    final today = find.widgetWithText(TextButton, '25');
    expect(tester.widget<TextButton>(today).onPressed, isNull);
    expect(find.text('14:00 - 15:00'), findsNothing);

    final tomorrow = find.widgetWithText(TextButton, '26');
    await tester.ensureVisible(tomorrow);
    await tester.tap(tomorrow);
    await tester.pumpAndSettle();
    expect(find.text('12:00 - 13:00'), findsOneWidget);
  });

  testWidgets('la revisión comercial no muestra el pago de prueba', (
    tester,
  ) async {
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ReviewScreen(
          lines: const [],
          details: CoordinationDetails(desiredDate: DateTime(2026, 11, 2)),
          quoteId: 'COT-TEST',
          message: 'Cotización de prueba',
          onSharePdf: (_) async {
            shared = true;
            return QuotePdfShareOutcome.shared;
          },
          onSendWhatsapp: () async {},
          onEditQuote: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Compartir cotización PDF'), findsOneWidget);
    expect(find.text('Enviar mensaje por WhatsApp'), findsOneWidget);
    expect(find.text('Guardar PDF'), findsOneWidget);
    expect(find.text('Guardar Excel'), findsNothing);
    expect(find.text('Copiar mensaje'), findsNothing);
    expect(find.text('Continuar al pago de prueba'), findsNothing);
    expect(find.text('Pago'), findsNothing);
    expect(find.text('Listo'), findsNothing);
    expect(find.textContaining('sin pagar'), findsNothing);

    final shareButton = find.text('Compartir cotización PDF');
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(shared, isTrue);
    expect(find.text('Cotización PDF compartida.'), findsOneWidget);
  });

  testWidgets(
    'actualiza el horario publicado mientras el formulario está abierto',
    (tester) async {
      final date = _testDate;
      var slots = const ['07:00 - 08:00'];
      List<String> slotsForDate(DateTime _) => slots;
      final initial = CoordinationDetails(
        desiredDate: date,
        customFields: const {'Horario de recojo': '07:00 - 08:00'},
      );
      await _pumpCoordination(
        tester,
        initial: initial,
        pickupTimeSlotsForDate: slotsForDate,
      );
      expect(find.text('07:00 - 08:00'), findsOneWidget);

      slots = const ['12:00 - 13:00'];
      await _pumpCoordination(
        tester,
        initial: initial,
        pickupTimeSlotsForDate: slotsForDate,
      );
      expect(find.text('07:00 - 08:00'), findsNothing);
      expect(find.text('12:00 - 13:00'), findsOneWidget);
    },
  );
}

Future<void> _pumpCoordination(
  WidgetTester tester, {
  ValueChanged<CoordinationDetails>? onSubmit,
  CoordinationDetails initial = const CoordinationDetails(),
  StorefrontSettings settings = const StorefrontSettings(),
  List<String> Function(DateTime date)? pickupTimeSlotsForDate,
  DateTime Function() now = _morningInLima,
  int cartQuantity = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CoordinationScreen(
        initial: initial,
        earliestDate: _testDate,
        now: now,
        cartQuantity: cartQuantity,
        deliveryWeekdays: (_) => const {
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        },
        pickupTimeSlotsForDate: pickupTimeSlotsForDate,
        onSubmit: onSubmit ?? (_) {},
        settings: settings,
      ),
    ),
  );
  await tester.pump();
}
