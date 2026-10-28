import 'package:expresiones/data/product_popularity_repository.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const first = CatalogProduct(
    id: 'primero',
    name: 'Primero',
    category: ProductCategory.materials,
    basePrice: 4,
  );
  const second = CatalogProduct(
    id: 'segundo',
    name: 'Segundo',
    category: ProductCategory.materials,
    basePrice: 5,
  );
  const third = CatalogProduct(
    id: 'tercero',
    name: 'Tercero',
    category: ProductCategory.materials,
    basePrice: 6,
  );

  test(
    'ordena por popularidad y completa hasta seis familias distintas',
    () async {
      SharedPreferences.setMockInitialValues({});
      final popularity = _FakePopularityRepository(
        topProductIds: const ['tercero', 'primero', 'producto-eliminado'],
      );
      final store = AppStore(
        () async => const [first, second, third],
        popularityRepository: popularity,
      );
      addTearDown(store.dispose);

      await store.initialize();

      expect(store.popularProducts.map((product) => product.id), const [
        'tercero',
        'primero',
        'segundo',
      ]);
    },
  );

  test('registra vistas, cantidades añadidas y unidades compradas', () async {
    SharedPreferences.setMockInitialValues({});
    final popularity = _FakePopularityRepository();
    final store = AppStore(
      () async => const [first],
      popularityRepository: popularity,
    );
    addTearDown(store.dispose);
    await store.initialize();

    store.recordProductView(first, null);
    store.addProduct(first, quantity: 2);
    store.updateQuantity(const QuoteLine(productId: 'primero', quantity: 2), 5);
    await _waitFor(
      () => popularity.views.length == 1 && popularity.added.length == 2,
    );

    final order = CheckoutOrder.fromQuote(
      id: 'PED-POPULARIDAD',
      lines: const [
        ResolvedQuoteLine(
          line: QuoteLine(productId: 'primero', quantity: 5),
          product: first,
        ),
      ],
      details: const CoordinationDetails(name: 'María', phone: '999999999'),
      payment: SimulatedPayment(
        reference: 'SIM-POPULARIDAD',
        method: SimulatedPaymentMethod.demoCard,
        status: SimulatedPaymentStatus.approved,
        amount: 20,
        processedAt: DateTime(2026, 10, 24),
      ),
      createdAt: DateTime(2026, 10, 24),
    );
    await store.completeCheckout(order);
    await _waitFor(() => popularity.completed['primero'] == 5);

    expect(popularity.views, const ['primero']);
    expect(popularity.added, const [('primero', 2), ('primero', 3)]);
    expect(popularity.completed, const {'primero': 5});
    expect(
      popularity.loadCalls,
      1,
      reason: 'El ranking se consulta al iniciar, no después de cada evento.',
    );
  });
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('La operación asíncrona de popularidad no terminó a tiempo.');
}

class _FakePopularityRepository implements ProductPopularityRepository {
  _FakePopularityRepository({this.topProductIds = const []});

  final List<String> topProductIds;
  final List<String> views = [];
  final List<(String, int)> added = [];
  final Map<String, int> completed = {};
  int loadCalls = 0;

  @override
  Future<List<String>> loadTopProductIds({int limit = 6}) async {
    loadCalls++;
    return topProductIds.take(limit).toList(growable: false);
  }

  @override
  Future<void> recordAdded(String productId, {required int quantity}) async {
    added.add((productId, quantity));
  }

  @override
  Future<void> recordCompleted(Map<String, int> quantitiesByProduct) async {
    for (final entry in quantitiesByProduct.entries) {
      completed.update(
        entry.key,
        (current) => current + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  @override
  Future<void> recordView(String productId) async {
    views.add(productId);
  }
}
