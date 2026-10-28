import 'dart:async';

import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/order_success_screen.dart';
import 'package:expresiones/screens/payment_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = CatalogProduct(
    id: 'cinta',
    name: 'Cinta satinada',
    category: ProductCategory.materials,
    basePrice: 10,
    unitLabel: 'rollo',
  );
  const line = ResolvedQuoteLine(
    line: QuoteLine(productId: 'cinta', quantity: 1),
    product: product,
  );
  const details = CoordinationDetails(name: 'María', phone: '999999999');

  testWidgets(
    'simula el pago sin pedir datos financieros y permite reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PaymentScreen(
              lines: const [line],
              details: details,
              onBack: () {},
              onProcessPayment: (method) async {
                attempts++;
                return SimulatedPayment(
                  reference: 'SIM-ERROR',
                  method: method,
                  status: SimulatedPaymentStatus.declined,
                  amount: 10,
                  processedAt: DateTime(2026, 10, 24),
                );
              },
              onApproved: (_) async {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('CVV'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Simular pago'));
      await tester.tap(find.textContaining('Simular pago'));
      await tester.pumpAndSettle();

      expect(find.text('La simulación fue rechazada'), findsOneWidget);
      await tester.tap(find.text('Volver a intentar'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
    },
  );

  testWidgets('impide salir mientras la simulación está procesándose', (
    tester,
  ) async {
    final payment = Completer<SimulatedPayment>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: PaymentScreen(
                      lines: const [line],
                      details: details,
                      onBack: () => Navigator.of(context).pop(),
                      onProcessPayment: (_) => payment.future,
                      onApproved: (_) async {},
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir pago'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir pago'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Simular pago'));
    await tester.tap(find.textContaining('Simular pago'));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Completa tu compra simulada'), findsOneWidget);

    payment.complete(
      SimulatedPayment(
        reference: 'SIM-CANCELADA',
        method: SimulatedPaymentMethod.demoCard,
        status: SimulatedPaymentStatus.declined,
        amount: 10,
        processedAt: DateTime(2026, 10, 24),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Abrir pago'), findsOneWidget);
  });

  testWidgets('muestra comprobante, referencia y todas las acciones finales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final payment = SimulatedPayment(
      reference: 'SIM-20261024-120000-000',
      method: SimulatedPaymentMethod.demoYape,
      status: SimulatedPaymentStatus.approved,
      amount: 10,
      processedAt: DateTime(2026, 10, 24, 12),
    );
    final order = CheckoutOrder.fromQuote(
      id: 'PED-PRUEBA',
      lines: const [line],
      details: details,
      payment: payment,
      createdAt: payment.processedAt,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: OrderSuccessScreen(
            order: order,
            onSendWhatsapp: () async {},
            onCopySummary: () async {},
            onHome: () {},
            onNewOrder: () {},
          ),
        ),
      ),
    );

    expect(find.text('SIM-20261024-120000-000'), findsOneWidget);
    expect(find.text('No se realizó ningún cobro'), findsOneWidget);
    expect(find.text('Enviar pedido por WhatsApp'), findsOneWidget);
    expect(find.text('Copiar resumen'), findsOneWidget);
    expect(find.text('Guardar PDF'), findsOneWidget);
    expect(find.text('Guardar Excel'), findsOneWidget);
  });

  testWidgets('conserva el nombre administrado del método elegido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SimulatedPayment? approved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PaymentScreen(
            lines: const [line],
            details: details,
            settings: const StorefrontSettings(
              texts: {
                StorefrontText.paymentYapeMethod: 'Billetera escolar demo',
              },
            ),
            onBack: () {},
            onProcessPayment: (method) async => SimulatedPayment(
              reference: 'SIM-ETIQUETA',
              method: method,
              status: SimulatedPaymentStatus.approved,
              amount: 10,
              processedAt: DateTime(2026, 10, 24),
            ),
            onApproved: (payment) async => approved = payment,
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Billetera escolar demo'));
    await tester.tap(find.text('Billetera escolar demo'));
    await tester.ensureVisible(find.textContaining('Simular pago'));
    await tester.tap(find.textContaining('Simular pago'));
    await tester.pumpAndSettle();

    expect(approved?.methodLabel, 'Billetera escolar demo');
  });
}
