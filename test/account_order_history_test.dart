import 'package:expresiones/data/customer_account_repository.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late _OrdersRepository repo;
  setUp(() => repo = _OrdersRepository());
  tearDown(() => repo.client.dispose());

  testWidgets('el historial abre el comprobante del pedido elegido', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccountScreen(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PED-DOS'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(find.text('Cinta satinada · Verde'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('S/ 58.00'), findsWidgets);
    expect(find.text('Limpiapipas · Azul'), findsNothing);
    await tester.drag(
      find.descendant(
        of: find.byType(Scaffold).last,
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Huancayo Centro'), findsOneWidget);
    expect(find.text('Jr. Ica 123'), findsOneWidget);
    expect(find.text('SIM-DOS'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Historial de compras'), findsOneWidget);
    expect(find.text('PED-UNO'), findsOneWidget);
    expect(find.text('PED-DOS'), findsOneWidget);
  });
}

class _OrdersRepository extends CustomerAccountRepository {
  _OrdersRepository()
    : super(
        client: SupabaseClient(
          'https://example.invalid',
          'public',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Stream<AuthState> get authChanges => const Stream.empty();

  @override
  Future<CustomerProfile?> currentProfile({bool includeAvatar = true}) async =>
      const CustomerProfile(
        userId: 'qa',
        fullName: 'Prueba',
        phone: '900000000',
      );

  @override
  Future<List<StoredCustomerOrder>> loadMyOrders() async => [
    _order('UNO', 'Limpiapipas', 'Azul', 5),
    _order('DOS', 'Cinta satinada', 'Verde', 29),
  ];

  StoredCustomerOrder _order(
    String ref,
    String product,
    String variant,
    double unitPrice,
  ) {
    final date = DateTime(2026, 11, 23);
    return StoredCustomerOrder(
      customerName: 'Prueba',
      customerPhone: '900000000',
      status: 'paid_simulated',
      order: CheckoutOrder(
        id: 'PED-$ref',
        createdAt: date,
        items: [
          CheckoutOrderItem(
            productId: ref,
            productName: product,
            variantName: variant,
            quantity: 2,
            unitLabel: 'unidad',
            unitPrice: unitPrice,
            lineTotal: 2 * unitPrice,
          ),
        ],
        details: CoordinationDetails(
          name: 'Prueba',
          phone: '900000000',
          deliveryMethod: DeliveryMethod.shalom,
          shalomAgencyName: 'Huancayo Centro',
          shalomAgencyAddress: 'Jr. Ica 123',
          desiredDate: date,
        ),
        productsSubtotal: 2 * unitPrice,
        payment: SimulatedPayment(
          reference: 'SIM-$ref',
          method: SimulatedPaymentMethod.demoYape,
          status: SimulatedPaymentStatus.approved,
          amount: 2 * unitPrice,
          processedAt: date,
        ),
      ),
    );
  }
}
