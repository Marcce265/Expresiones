import 'package:expresiones/data/local_checkout_receipt_store.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/services/simulated_payment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('procesa y restaura un comprobante sin datos financieros', () async {
    SharedPreferences.setMockInitialValues({});
    final moments = <DateTime>[
      DateTime(2026, 10, 24, 16, 30),
      DateTime(2026, 10, 24, 16, 30, 1, 42),
    ].iterator;
    final service = SimulatedPaymentService(
      now: () {
        moments.moveNext();
        return moments.current;
      },
      processingDelay: Duration.zero,
    );
    final orderId = service.createOrderId();
    final payment = (await service.process(
      method: SimulatedPaymentMethod.demoYape,
      amount: 54,
    )).withMethodLabel('Billetera de demostración');
    const product = CatalogProduct(
      id: 'cinta',
      name: 'Cinta satinada',
      category: ProductCategory.materials,
      basePrice: 5,
      unitLabel: 'rollo',
      variants: [ProductVariant(id: 'rojo', name: 'Rojo', sku: 'SAT-17')],
      priceTiers: [PriceTier(minQuantity: 12, unitPrice: 4.5)],
    );
    const line = ResolvedQuoteLine(
      line: QuoteLine(productId: 'cinta', variantId: 'rojo', quantity: 12),
      product: product,
    );
    final order = CheckoutOrder.fromQuote(
      id: orderId,
      lines: const [line],
      details: const CoordinationDetails(name: 'María', phone: '999999999'),
      payment: payment,
      createdAt: payment.processedAt,
    );

    final store = LocalCheckoutReceiptStore();
    await store.save(order);
    final restored = await store.load();

    expect(restored?.id, 'PED-20261024-163000-000');
    expect(restored?.payment.reference, 'SIM-20261024-163001-042');
    expect(restored?.payment.isApproved, isTrue);
    expect(restored?.payment.methodLabel, 'Billetera de demostración');
    expect(restored?.items.single.displayName, 'Cinta satinada · Rojo');
    expect(restored?.productsSubtotal, 54);
    final serialized = (await SharedPreferences.getInstance()).getString(
      LocalCheckoutReceiptStore.storageKey,
    )!;
    expect(serialized, isNot(contains('cardNumber')));
    expect(serialized, isNot(contains('cvv')));
    expect(serialized, isNot(contains('expiry')));
  });

  test('devuelve un rechazo controlado y valida el importe', () async {
    final service = SimulatedPaymentService(
      now: () => DateTime(2026, 10, 24),
      processingDelay: Duration.zero,
    );
    final declined = await service.process(
      method: SimulatedPaymentMethod.demoCard,
      amount: 10,
      result: SimulatedPaymentStatus.declined,
    );
    expect(declined.status, SimulatedPaymentStatus.declined);
    expect(
      () => service.process(method: SimulatedPaymentMethod.demoCard, amount: 0),
      throwsArgumentError,
    );
  });

  test('los comprobantes anteriores conservan la etiqueta predeterminada', () {
    final payment = SimulatedPayment.fromJson({
      'reference': 'SIM-ANTERIOR',
      'method': 'demoCard',
      'status': 'approved',
      'amount': 10,
      'processedAt': '2026-10-24T12:00:00.000',
    });

    expect(payment.methodLabel, 'Tarjeta de demostración');
  });
}
