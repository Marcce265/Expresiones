import '../data/telemetry_local_store.dart';
import '../models/commerce_telemetry.dart';

typedef TelemetryClock = DateTime Function();

abstract interface class CommerceTelemetrySink {
  Future<void> send(List<CommerceTelemetryEvent> events);
}

/// Local-first, anonymous commerce telemetry.
///
/// Events are kept on the device until an optional sink accepts them. The
/// model has no general metadata map, so customer details cannot accidentally
/// be attached to an event.
class CommerceTelemetryService {
  CommerceTelemetryService({
    required this.localStore,
    this.sink,
    TelemetryClock? clock,
    this.abandonmentThreshold = const Duration(hours: 24),
    this.maxPendingEvents = 300,
  }) : _clock = clock ?? DateTime.now;

  final TelemetryLocalStore localStore;
  final CommerceTelemetrySink? sink;
  final TelemetryClock _clock;
  final Duration abandonmentThreshold;
  final int maxPendingEvents;

  final List<CommerceTelemetryEvent> _pending = [];
  AnonymousQuoteActivity? _quoteActivity;
  bool _initialized = false;
  bool _flushing = false;

  List<CommerceTelemetryEvent> get pendingEvents => List.unmodifiable(_pending);
  AnonymousQuoteActivity? get quoteActivity => _quoteActivity;

  Future<void> initialize() async {
    if (_initialized) return;
    _pending
      ..clear()
      ..addAll(await localStore.loadPendingEvents());
    _quoteActivity = await localStore.loadQuoteActivity();
    _initialized = true;
    await detectAbandonedQuote();
    await flush();
  }

  Future<void> recordZeroResultSearch(String query) async {
    await _ensureInitialized();
    final safeTerm = SearchTermPrivacyFilter.sanitize(query);
    if (safeTerm == null) return;
    await _record(
      CommerceTelemetryEvent(
        type: CommerceEventType.zeroResultSearch,
        occurredAt: _clock(),
        searchTerm: safeTerm,
      ),
    );
  }

  Future<void> recordProductView({
    required String productId,
    String? variantId,
  }) async {
    await _ensureInitialized();
    final safeProductId = _safeId(productId);
    if (safeProductId == null) return;
    await _record(
      CommerceTelemetryEvent(
        type: CommerceEventType.productView,
        occurredAt: _clock(),
        productId: safeProductId,
        variantId: _safeId(variantId),
      ),
    );
  }

  Future<void> recordProductAdded({
    required String productId,
    String? variantId,
    required int quantity,
    required int cartItemCount,
    required double cartSubtotal,
  }) async {
    await _ensureInitialized();
    final safeProductId = _safeId(productId);
    if (safeProductId == null) return;
    await _record(
      CommerceTelemetryEvent(
        type: CommerceEventType.productAdded,
        occurredAt: _clock(),
        productId: safeProductId,
        variantId: _safeId(variantId),
        quantityBucket: quantityBucket(quantity),
      ),
    );
    await markQuoteActivity(itemCount: cartItemCount, subtotal: cartSubtotal);
  }

  /// Call after cart additions, quantity changes and removals.
  Future<void> markQuoteActivity({
    required int itemCount,
    required double subtotal,
  }) async {
    await _ensureInitialized();
    if (itemCount <= 0) {
      _quoteActivity = null;
      await localStore.saveQuoteActivity(null);
      return;
    }
    final now = _clock();
    _quoteActivity = AnonymousQuoteActivity(
      startedAt: _quoteActivity?.startedAt ?? now,
      lastActivityAt: now,
      itemCountBucket: itemCountBucket(itemCount),
      valueBucket: valueBucket(subtotal),
    );
    await localStore.saveQuoteActivity(_quoteActivity);
  }

  Future<void> recordQuoteSent() async {
    await _ensureInitialized();
    final activity = _quoteActivity;
    await _record(
      CommerceTelemetryEvent(
        type: CommerceEventType.quoteSent,
        occurredAt: _clock(),
        itemCountBucket: activity?.itemCountBucket,
        valueBucket: activity?.valueBucket,
      ),
    );
    _quoteActivity = null;
    await localStore.saveQuoteActivity(null);
  }

  /// Records abandonment only after a full inactivity threshold.
  ///
  /// This should run at startup and when the app returns to the foreground.
  Future<bool> detectAbandonedQuote() async {
    await _ensureInitialized(skipAbandonmentCheck: true);
    final activity = _quoteActivity;
    if (activity == null) return false;
    final age = _clock().difference(activity.lastActivityAt);
    if (age < abandonmentThreshold) return false;
    await _record(
      CommerceTelemetryEvent(
        type: CommerceEventType.quoteAbandoned,
        occurredAt: _clock(),
        itemCountBucket: activity.itemCountBucket,
        valueBucket: activity.valueBucket,
        abandonmentHoursBucket: abandonmentHoursBucket(age),
      ),
    );
    _quoteActivity = null;
    await localStore.saveQuoteActivity(null);
    return true;
  }

  Future<void> flush() async {
    if (sink == null || _pending.isEmpty || _flushing) return;
    _flushing = true;
    final count = _pending.length;
    final batch = List<CommerceTelemetryEvent>.of(_pending.take(count));
    try {
      await sink!.send(batch);
      _pending.removeRange(0, count);
      await localStore.savePendingEvents(_pending);
    } catch (_) {
      // Offline and quota failures remain queued for the next app session.
    } finally {
      _flushing = false;
    }
  }

  /// Removes queued anonymous events and local quote activity from this device.
  Future<void> clearLocalData() async {
    await _ensureInitialized(skipAbandonmentCheck: true);
    _pending.clear();
    _quoteActivity = null;
    await localStore.savePendingEvents(const []);
    await localStore.saveQuoteActivity(null);
  }

  Future<void> _record(CommerceTelemetryEvent event) async {
    _pending.add(event);
    if (_pending.length > maxPendingEvents) {
      _pending.removeRange(0, _pending.length - maxPendingEvents);
    }
    await localStore.savePendingEvents(_pending);
    await flush();
  }

  Future<void> _ensureInitialized({bool skipAbandonmentCheck = false}) async {
    if (_initialized) return;
    _pending
      ..clear()
      ..addAll(await localStore.loadPendingEvents());
    _quoteActivity = await localStore.loadQuoteActivity();
    _initialized = true;
    if (!skipAbandonmentCheck) await detectAbandonedQuote();
  }

  String? _safeId(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]{0,99}$').hasMatch(text)) {
      return null;
    }
    return text;
  }
}
