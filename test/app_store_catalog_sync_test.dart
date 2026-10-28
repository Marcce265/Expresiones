import 'dart:async';

import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/models/checkout_order.dart';
import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/quote_line.dart';
import 'package:expresiones/models/simulated_payment.dart';
import 'package:expresiones/data/site_settings_repository.dart';
import 'package:expresiones/data/production_capacity_repository.dart';
import 'package:expresiones/models/production_capacity.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/state/app_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'reemplaza la portada y elimina familias al recibir un catálogo nuevo',
    () async {
      SharedPreferences.setMockInitialValues({});
      final updates = StreamController<List<CatalogProduct>>();
      const original = CatalogProduct(
        id: 'familia',
        name: 'Familia',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: 'https://cdn.example/old-cover.webp',
        thumbnailUrl: 'https://cdn.example/old-cover.webp',
      );
      const updated = CatalogProduct(
        id: 'familia',
        name: 'Familia',
        category: ProductCategory.materials,
        basePrice: 5,
        imageUrl: 'https://cdn.example/new-cover.webp',
        thumbnailUrl: 'https://cdn.example/new-cover.webp',
      );
      final store = AppStore(
        () async => const [original],
        catalogStreamLoader: () => updates.stream,
      );
      addTearDown(() async {
        store.dispose();
        await updates.close();
      });

      await store.initialize();
      expect(store.products.single.previewImageUrl, original.previewImageUrl);

      updates.add(const [updated]);
      await Future<void>.delayed(Duration.zero);
      expect(store.products.single.previewImageUrl, updated.previewImageUrl);

      updates.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(store.products, isEmpty);
      expect(store.errorMessage, 'El catálogo está vacío por el momento.');
    },
  );

  test('carga y actualiza la configuración pública', () async {
    SharedPreferences.setMockInitialValues({});
    final updates = StreamController<StorefrontSettings>();
    final repository = _FakeSiteSettingsRepository(
      initial: const StorefrontSettings(
        whatsappNumber: '51911111111',
        texts: {StorefrontText.brandName: 'Expresiones inicial'},
      ),
      updates: updates.stream,
    );
    final store = AppStore(
      () async => const [],
      siteSettingsRepository: repository,
    );
    addTearDown(() async {
      store.dispose();
      await updates.close();
    });

    await store.initialize();
    expect(
      store.storefrontSettings.text(StorefrontText.brandName),
      'Expresiones inicial',
    );

    updates.add(
      const StorefrontSettings(
        whatsappNumber: '51922222222',
        texts: {StorefrontText.brandName: 'Expresiones renovada'},
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.storefrontSettings.normalizedWhatsappNumber, '51922222222');
    expect(
      store.storefrontSettings.text(StorefrontText.brandName),
      'Expresiones renovada',
    );
  });

  test('las fechas dependen de los días de entrega, no de capacidad', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = _FakeCapacityRepository(
      ProductionCapacitySnapshot(
        weeklyCapacityPoints: const {
          DateTime.monday: 0,
          DateTime.tuesday: 0,
          DateTime.wednesday: 0,
          DateTime.thursday: 0,
          DateTime.friday: 0,
          DateTime.saturday: 0,
          DateTime.sunday: 0,
        },
        deliveryWeekdays: const {
          'pickup': {DateTime.monday},
          'shalom': {DateTime.saturday},
        },
        reservedPointsByDate: const {'2099-01-05': 999},
        overridesByDate: const {
          '2099-01-05': ProductionDayOverride(isClosed: true),
        },
      ),
    );
    final store = AppStore(
      () async => const [],
      capacityRepository: repository,
    );
    addTearDown(store.dispose);
    await store.initialize();

    var monday = store.earliestDesiredDate;
    while (monday.weekday != DateTime.monday) {
      monday = monday.add(const Duration(days: 1));
    }

    expect(store.isDesiredDateAvailable(monday, DeliveryMethod.pickup), isTrue);
    expect(
      store.isDesiredDateAvailable(
        monday.add(const Duration(days: 1)),
        DeliveryMethod.pickup,
      ),
      isFalse,
    );
  });

  test(
    'completa la compra, vacía el carrito y restaura el comprobante',
    () async {
      SharedPreferences.setMockInitialValues({});
      const product = CatalogProduct(
        id: 'cinta',
        name: 'Cinta satinada',
        category: ProductCategory.materials,
        basePrice: 5,
        unitLabel: 'rollo',
      );
      final store = AppStore(() async => const [product]);
      await store.initialize();
      store.addProduct(product, quantity: 2);
      const details = CoordinationDetails(name: 'María', phone: '999999999');
      store.updateDetails(details);
      final order = CheckoutOrder.fromQuote(
        id: 'PED-PRUEBA',
        lines: const [
          ResolvedQuoteLine(
            line: QuoteLine(productId: 'cinta', quantity: 2),
            product: product,
          ),
        ],
        details: details,
        payment: SimulatedPayment(
          reference: 'SIM-PRUEBA',
          method: SimulatedPaymentMethod.demoCard,
          status: SimulatedPaymentStatus.approved,
          amount: 10,
          processedAt: DateTime(2026, 10, 24),
        ),
        createdAt: DateTime(2026, 10, 24),
      );

      await store.completeCheckout(order);
      expect(store.hasQuote, isFalse);
      expect(store.lastOrder?.id, 'PED-PRUEBA');

      final restored = AppStore(() async => const [product]);
      await restored.initialize();
      expect(restored.lastOrder?.payment.reference, 'SIM-PRUEBA');

      await restored.clearLocalData();
      expect(restored.lastOrder, isNull);
      store.dispose();
      restored.dispose();
    },
  );
}

class _FakeSiteSettingsRepository implements SiteSettingsRepository {
  const _FakeSiteSettingsRepository({
    required this.initial,
    required this.updates,
  });

  final StorefrontSettings initial;
  final Stream<StorefrontSettings> updates;

  @override
  Stream<StorefrontSettings> watch() async* {
    yield initial;
    yield* updates;
  }
}

class _FakeCapacityRepository implements CapacityRepository {
  const _FakeCapacityRepository(this.snapshot);

  final ProductionCapacitySnapshot snapshot;

  @override
  Stream<ProductionCapacitySnapshot> watch() => Stream.value(snapshot);
}
