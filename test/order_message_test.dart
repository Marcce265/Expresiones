import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/services/quote_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resume el pedido y aclara que el pago no fue real', () {
    final order = CheckoutOrder(
      id: 'PED-20261024-123000-001',
      items: const [
        CheckoutOrderItem(
          productId: 'cinta',
          productName: 'Cinta satinada',
          variantName: 'Rojo',
          sku: 'SAT-17',
          unitLabel: 'rollo',
          quantity: 2,
          unitPrice: 5,
          lineTotal: 10,
        ),
      ],
      details: const CoordinationDetails(
        name: 'María',
        phone: '999999999',
        deliveryMethod: DeliveryMethod.shalom,
        shalomAgencyId: 'agencia-1',
        shalomAgencyName: 'BAGUA CAPITAL',
        shalomAgencyLocality: 'Bagua · Amazonas',
        shalomAgencyAddress: 'Jr. Amazonas 126',
      ),
      productsSubtotal: 10,
      payment: SimulatedPayment(
        reference: 'SIM-20261024-123001-001',
        method: SimulatedPaymentMethod.demoYape,
        status: SimulatedPaymentStatus.approved,
        amount: 10,
        processedAt: DateTime(2026, 10, 24, 12, 30),
      ),
      createdAt: DateTime(2026, 10, 24, 12, 30),
    );

    final message = QuoteMessageBuilder.buildOrder(order: order);

    expect(message, contains(order.id));
    expect(message, contains('2 × Cinta satinada · Rojo · SAT-17'));
    expect(message, contains('Agencia Shalom: BAGUA CAPITAL'));
    expect(message, contains('Yape de demostración (simulado)'));
    expect(message, contains(order.payment.reference));
    expect(message, contains('No se realizó ningún cobro real'));
  });
}
