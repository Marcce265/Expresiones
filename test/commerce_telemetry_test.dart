import 'package:expresiones/data/telemetry_local_store.dart';
import 'package:expresiones/models/commerce_telemetry.dart';
import 'package:expresiones/services/commerce_telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('descarta búsquedas que podrían contener información personal', () {
    expect(
      SearchTermPrivacyFilter.sanitize('cinta satinada roja'),
      'cinta satinada roja',
    );
    expect(SearchTermPrivacyFilter.sanitize('cinta lavanda'), 'cinta lavanda');
    expect(SearchTermPrivacyFilter.sanitize('999999999'), isNull);
    expect(SearchTermPrivacyFilter.sanitize('999 999 999'), isNull);
    expect(SearchTermPrivacyFilter.sanitize('maria@gmail.com'), isNull);
    expect(SearchTermPrivacyFilter.sanitize('Av. Giráldez 123'), isNull);
    expect(
      SearchTermPrivacyFilter.sanitize('mi dirección es Lima 123'),
      isNull,
    );
  });

  test('registra búsquedas, vistas y agregados sin datos personales', () async {
    final store = MemoryTelemetryStore();
    final service = CommerceTelemetryService(
      localStore: store,
      clock: () => DateTime.utc(2026, 10, 15, 12),
    );
    await service.initialize();

    await service.recordZeroResultSearch('papel coreano verde');
    await service.recordProductView(
      productId: 'cinta-satinada-100m',
      variantId: 'satin-08',
    );
    await service.recordProductAdded(
      productId: 'cinta-satinada-100m',
      variantId: 'satin-08',
      quantity: 12,
      cartItemCount: 2,
      cartSubtotal: 84,
    );

    expect(store.pendingEvents, hasLength(3));
    expect(store.pendingEvents.first.type, CommerceEventType.zeroResultSearch);
    expect(store.pendingEvents.first.searchTerm, 'papel coreano verde');
    expect(store.pendingEvents.last.quantityBucket, '12-49');
    expect(store.quoteActivity?.itemCountBucket, '2-3');
    expect(store.quoteActivity?.valueBucket, '50-99');
    for (final event in store.pendingEvents) {
      final serialized = event.toRemoteMap().toString().toLowerCase();
      expect(serialized, isNot(contains('phone')));
      expect(serialized, isNot(contains('name')));
      expect(serialized, isNot(contains('address')));
      expect(serialized, isNot(contains('note')));
    }
  });

  test('rechaza identificadores que podrían ser datos del cliente', () async {
    final store = MemoryTelemetryStore();
    final service = CommerceTelemetryService(localStore: store);
    await service.initialize();

    await service.recordProductView(productId: '999999999');
    await service.recordProductView(productId: 'maria@gmail.com');

    expect(store.pendingEvents, isEmpty);
  });

  test('detecta cotización abandonada después de 24 horas', () async {
    var now = DateTime.utc(2026, 10, 14, 10);
    final store = MemoryTelemetryStore();
    final firstSession = CommerceTelemetryService(
      localStore: store,
      clock: () => now,
    );
    await firstSession.initialize();
    await firstSession.markQuoteActivity(itemCount: 4, subtotal: 310);

    now = DateTime.utc(2026, 10, 15, 11);
    final reopenedSession = CommerceTelemetryService(
      localStore: store,
      clock: () => now,
    );
    await reopenedSession.initialize();

    final event = store.pendingEvents.single;
    expect(event.type, CommerceEventType.quoteAbandoned);
    expect(event.itemCountBucket, '4-6');
    expect(event.valueBucket, '250-499');
    expect(event.abandonmentHoursBucket, '24-71');
    expect(store.quoteActivity, isNull);
  });

  test('vacía la cola únicamente después de un envío exitoso', () async {
    final store = MemoryTelemetryStore();
    final sink = _RecordingSink();
    final service = CommerceTelemetryService(
      localStore: store,
      sink: sink,
      clock: () => DateTime.utc(2026, 10, 15, 12),
    );
    await service.initialize();
    await service.recordProductView(productId: 'coronita-dorada-3cm');

    expect(sink.received, hasLength(1));
    expect(store.pendingEvents, isEmpty);
  });
}

class _RecordingSink implements CommerceTelemetrySink {
  final List<CommerceTelemetryEvent> received = [];

  @override
  Future<void> send(List<CommerceTelemetryEvent> events) async {
    received.addAll(events);
  }
}
