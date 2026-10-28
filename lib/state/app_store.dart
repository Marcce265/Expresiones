import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_checkout_receipt_store.dart';
import '../data/product_popularity_repository.dart';
import '../models/catalog_models.dart';
import '../models/checkout_order.dart';
import '../models/coordination_details.dart';
import '../models/production_capacity.dart';
import '../models/quote_line.dart';
import '../data/production_capacity_repository.dart';
import '../data/site_settings_repository.dart';
import '../models/storefront_settings.dart';
import '../services/commerce_telemetry_service.dart';

typedef CatalogLoader = Future<List<CatalogProduct>> Function();
typedef CatalogStreamLoader = Stream<List<CatalogProduct>> Function();

class AppStore extends ChangeNotifier {
  AppStore(
    this._catalogLoader, {
    this.catalogStreamLoader,
    this.capacityRepository,
    this.siteSettingsRepository,
    this.popularityRepository,
    this.telemetry,
  });

  static const _cartKey = 'expresiones.quote.v1';
  static const _detailsKey = 'expresiones.coordination.v1';

  final CatalogLoader _catalogLoader;
  final CatalogStreamLoader? catalogStreamLoader;
  final CapacityRepository? capacityRepository;
  final SiteSettingsRepository? siteSettingsRepository;
  final ProductPopularityRepository? popularityRepository;
  final CommerceTelemetryService? telemetry;
  final Map<String, QuoteLine> _cart = {};
  List<CatalogProduct> _products = const [];
  List<String> _popularProductIds = const [];
  CoordinationDetails _details = const CoordinationDetails();
  ProductionCapacitySnapshot _capacitySnapshot =
      ProductionCapacitySnapshot.twoPersonFallback();
  StorefrontSettings _storefrontSettings = const StorefrontSettings();
  final LocalCheckoutReceiptStore _receiptStore = LocalCheckoutReceiptStore();
  CheckoutOrder? _lastOrder;
  StreamSubscription<List<CatalogProduct>>? _catalogSubscription;
  StreamSubscription<ProductionCapacitySnapshot>? _capacitySubscription;
  StreamSubscription<StorefrontSettings>? _siteSettingsSubscription;
  bool _isLoading = true;
  String? _errorMessage;

  List<CatalogProduct> get products => List.unmodifiable(_products);
  CoordinationDetails get details => _details;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasQuote => _cart.isNotEmpty;
  ProductionCapacitySnapshot get capacitySnapshot => _capacitySnapshot;
  StorefrontSettings get storefrontSettings => _storefrontSettings;
  CheckoutOrder? get lastOrder => _lastOrder;

  /// Six distinct product families ordered by aggregate public activity.
  ///
  /// Missing or newly-created products are filled from catalog order so the
  /// home page is useful before the first popularity events arrive.
  List<CatalogProduct> get popularProducts {
    final materials = _products
        .where(
          (product) =>
              product.isActive && product.category == ProductCategory.materials,
        )
        .toList(growable: false);
    final byId = {for (final product in materials) product.id: product};
    final selected = <CatalogProduct>[];
    final seen = <String>{};
    for (final id in _popularProductIds) {
      final product = byId[id];
      if (product != null && seen.add(product.id)) selected.add(product);
      if (selected.length == 6) break;
    }
    for (final product in materials) {
      if (selected.length == 6) break;
      if (seen.add(product.id)) selected.add(product);
    }
    return List.unmodifiable(selected);
  }

  List<ResolvedQuoteLine> get resolvedLines {
    final byId = {for (final product in _products) product.id: product};
    return _cart.values
        .where((line) => byId.containsKey(line.productId))
        .map(
          (line) =>
              ResolvedQuoteLine(line: line, product: byId[line.productId]!),
        )
        .toList(growable: false);
  }

  int get cartQuantity =>
      _cart.values.fold(0, (sum, line) => sum + line.quantity);
  double get subtotal => resolvedLines.fold(0, (sum, item) => sum + item.total);
  int get maximumLeadDays => resolvedLines.fold(
    0,
    (maximum, item) => item.leadDays > maximum ? item.leadDays : maximum,
  );

  DateTime get earliestDesiredDate =>
      dateOnly(DateTime.now()).add(Duration(days: maximumLeadDays));

  Set<int> deliveryWeekdaysFor(DeliveryMethod method) =>
      _capacitySnapshot.weekdaysForDelivery(method.name);

  bool isDesiredDateAvailable(DateTime date, DeliveryMethod method) =>
      _capacitySnapshot.isDeliveryDay(method.name, date) &&
      !dateOnly(date).isBefore(earliestDesiredDate);

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _restoreLocalState();
    _lastOrder = await _receiptStore.load();
    await telemetry?.initialize();
    await _startCapacityWatch();
    await _startSiteSettingsWatch();
    await reloadCatalog(notifyAtStart: false);
    await _loadPopularity(notify: false);
    _startCatalogWatch();
  }

  Future<void> reloadCatalog({bool notifyAtStart = true}) async {
    if (notifyAtStart) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final loaded = await _catalogLoader();
      _applyProducts(loaded);
    } catch (error) {
      _errorMessage = 'No pudimos cargar el catálogo: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addProduct(
    CatalogProduct product, {
    int quantity = 1,
    String? variantId,
    String customization = '',
  }) {
    final safeQuantity = quantity < 1 ? 1 : quantity;
    final incoming = QuoteLine(
      productId: product.id,
      quantity: safeQuantity,
      variantId: variantId,
      customization: customization.trim(),
    );
    final current = _cart[incoming.key];
    _cart[incoming.key] = incoming.copyWith(
      quantity: (current?.quantity ?? 0) + safeQuantity,
    );
    _persistCart();
    final commerceTelemetry = telemetry;
    if (commerceTelemetry != null) {
      unawaited(
        commerceTelemetry.recordProductAdded(
          productId: product.id,
          variantId: variantId,
          quantity: safeQuantity,
          cartItemCount: cartQuantity,
          cartSubtotal: subtotal,
        ),
      );
    }
    _recordPopularity(
      (repository) =>
          repository.recordAdded(product.id, quantity: safeQuantity),
    );
    notifyListeners();
  }

  void updateQuantity(QuoteLine line, int quantity) {
    if (quantity <= 0) {
      removeLine(line);
      return;
    }
    final current = _cart[line.key];
    if (current == null) return;
    _cart[line.key] = line.copyWith(quantity: quantity);
    _persistCart();
    _recordQuoteActivity();
    final addedQuantity = quantity - current.quantity;
    if (addedQuantity > 0) {
      _recordPopularity(
        (repository) =>
            repository.recordAdded(line.productId, quantity: addedQuantity),
      );
    }
    notifyListeners();
  }

  void removeLine(QuoteLine line) {
    _cart.remove(line.key);
    _persistCart();
    _recordQuoteActivity();
    notifyListeners();
  }

  void recordProductView(CatalogProduct product, String? variantId) {
    final commerceTelemetry = telemetry;
    if (commerceTelemetry != null) {
      unawaited(
        commerceTelemetry.recordProductView(
          productId: product.id,
          variantId: variantId,
        ),
      );
    }
    _recordPopularity((repository) => repository.recordView(product.id));
  }

  void recordZeroResultSearch(String query) {
    final commerceTelemetry = telemetry;
    if (commerceTelemetry == null) return;
    unawaited(commerceTelemetry.recordZeroResultSearch(query));
  }

  Future<void> recordQuoteSent() async {
    await telemetry?.recordQuoteSent();
  }

  Future<void> detectAbandonedQuote() async {
    await telemetry?.detectAbandonedQuote();
  }

  void updateDetails(CoordinationDetails details) {
    _details = details;
    _persistDetails();
    notifyListeners();
  }

  Future<void> completeCheckout(CheckoutOrder order) async {
    if (!order.payment.isApproved) {
      throw StateError('Solo se puede guardar un pago simulado aprobado.');
    }
    await _receiptStore.save(order);
    // Aggregate metrics are useful for ranking, but must not delay the success
    // screen when the network is slow or unavailable.
    unawaited(_recordCompletedPopularity(order));
    _lastOrder = order;
    _cart.clear();
    _details = const CoordinationDetails();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_cartKey),
      preferences.remove(_detailsKey),
    ]);
    notifyListeners();
  }

  Future<void> clearLocalData() async {
    _cart.clear();
    _details = const CoordinationDetails();
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_cartKey),
      preferences.remove(_detailsKey),
      _receiptStore.clear(),
    ]);
    _lastOrder = null;
    await telemetry?.clearLocalData();
    notifyListeners();
  }

  Future<void> _restoreLocalState() async {
    final preferences = await SharedPreferences.getInstance();
    final rawCart = preferences.getString(_cartKey);
    if (rawCart != null) {
      try {
        final decoded = jsonDecode(rawCart);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final map = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            final line = QuoteLine.fromJson(map);
            if (line.productId.isNotEmpty && line.quantity > 0) {
              _cart[line.key] = line;
            }
          }
        }
      } catch (_) {
        _cart.clear();
      }
    }

    final rawDetails = preferences.getString(_detailsKey);
    if (rawDetails != null) {
      try {
        final decoded = jsonDecode(rawDetails);
        if (decoded is Map) {
          _details = CoordinationDetails.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        _details = const CoordinationDetails();
      }
    }
  }

  void _applyProducts(List<CatalogProduct> loaded) {
    _products = loaded.where((product) => product.isActive).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
    _errorMessage = _products.isEmpty
        ? 'El catálogo está vacío por el momento.'
        : null;
    _removeMissingCartLines();
  }

  Future<void> _loadPopularity({bool notify = true}) async {
    final repository = popularityRepository;
    if (repository == null) return;
    try {
      _popularProductIds = await repository.loadTopProductIds(limit: 6);
      if (notify) notifyListeners();
    } catch (_) {
      // Ranking is optional. Catalog order remains the deterministic fallback.
    }
  }

  void _recordPopularity(
    Future<void> Function(ProductPopularityRepository repository) action,
  ) {
    final repository = popularityRepository;
    if (repository == null) return;
    unawaited(() async {
      try {
        await action(repository);
      } catch (_) {
        // A metrics outage must never block catalog or cart interactions.
      }
    }());
  }

  Future<void> _recordCompletedPopularity(CheckoutOrder order) async {
    final repository = popularityRepository;
    if (repository == null) return;
    final quantities = <String, int>{};
    for (final item in order.items) {
      quantities.update(
        item.productId,
        (current) => current + item.quantity,
        ifAbsent: () => item.quantity,
      );
    }
    try {
      await repository.recordCompleted(quantities);
    } catch (_) {
      // Checkout succeeds even if anonymous aggregate metrics are unavailable.
    }
  }

  void _startCatalogWatch() {
    final loader = catalogStreamLoader;
    if (loader == null) return;
    unawaited(_catalogSubscription?.cancel());
    _catalogSubscription = loader().listen(
      (loaded) {
        _applyProducts(loaded);
        notifyListeners();
      },
      onError: (_) {
        // The last valid catalog remains available while the stream reconnects.
      },
    );
  }

  Future<void> _startCapacityWatch() async {
    final repository = capacityRepository;
    if (repository == null) return;
    await _capacitySubscription?.cancel();
    final ready = Completer<void>();
    _capacitySubscription = repository.watch().listen(
      (snapshot) {
        _capacitySnapshot = snapshot;
        if (ready.isCompleted) {
          notifyListeners();
        } else {
          ready.complete();
        }
      },
      onError: (_) {
        if (!ready.isCompleted) ready.complete();
        // Keep the last valid snapshot or the conservative local fallback.
      },
      onDone: () {
        if (!ready.isCompleted) ready.complete();
      },
    );
    await ready.future;
  }

  Future<void> _startSiteSettingsWatch() async {
    final repository = siteSettingsRepository;
    if (repository == null) return;
    await _siteSettingsSubscription?.cancel();
    final ready = Completer<void>();
    _siteSettingsSubscription = repository.watch().listen(
      (settings) {
        _storefrontSettings = settings;
        if (ready.isCompleted) {
          notifyListeners();
        } else {
          ready.complete();
        }
      },
      onError: (_) {
        if (!ready.isCompleted) ready.complete();
        // Keep the last valid settings or the local defaults.
      },
      onDone: () {
        if (!ready.isCompleted) ready.complete();
      },
    );
    await ready.future;
  }

  void _recordQuoteActivity() {
    final commerceTelemetry = telemetry;
    if (commerceTelemetry == null) return;
    unawaited(
      commerceTelemetry.markQuoteActivity(
        itemCount: cartQuantity,
        subtotal: subtotal,
      ),
    );
  }

  void _removeMissingCartLines() {
    final productsById = {for (final product in _products) product.id: product};
    final migrated = <String, QuoteLine>{};
    for (final line in _cart.values) {
      final updated = _migrateQuoteLine(line);
      if (updated == null) continue;
      final product = productsById[updated.productId];
      if (product == null) continue;
      if (updated.variantId != null &&
          product.variantById(updated.variantId) == null) {
        continue;
      }
      final existing = migrated[updated.key];
      migrated[updated.key] = existing == null
          ? updated
          : updated.copyWith(quantity: existing.quantity + updated.quantity);
    }
    _cart
      ..clear()
      ..addAll(migrated);
    _persistCart();
  }

  QuoteLine? _migrateQuoteLine(QuoteLine line) {
    final variantId = line.variantId;
    if (line.productId == 'cinta-satinada-100m' &&
        variantId != null &&
        variantId.startsWith('catalogo-')) {
      final oldIndex = int.tryParse(variantId.substring(9));
      final paletteNumber = _oldSatinPaletteNumbers[oldIndex];
      if (paletteNumber == null) return null;
      return line.copyWith(
        variantId: 'satin-${paletteNumber.toString().padLeft(2, '0')}',
      );
    }
    if (line.productId == 'limpiapipas-premium-8mm' &&
        variantId == 'catalogo-042') {
      return line.copyWith(variantId: 'marron');
    }
    if (line.productId == 'coronitas-decorativas') {
      final target = switch (variantId) {
        'catalogo-065' || 'catalogo-074' => 'corona-perlada-plateada',
        'catalogo-075' => 'corona-dorada-perlada-5cm',
        'catalogo-076' => 'corona-dorada-perlada-7cm',
        'catalogo-063' || 'catalogo-072' => null,
        _ => 'coronitas-decorativas',
      };
      if (target == null) return null;
      return QuoteLine(
        productId: target,
        variantId: target == 'corona-perlada-plateada'
            ? 'catalogo-065'
            : variantId,
        quantity: line.quantity,
        customization: line.customization,
      );
    }
    return line;
  }

  static const _oldSatinPaletteNumbers = <int, int>{
    18: 54,
    43: 54,
    19: 51,
    44: 51,
    20: 10,
    45: 10,
    21: 17,
    46: 17,
    22: 19,
    47: 19,
    23: 21,
    48: 21,
    24: 6,
    49: 6,
    50: 5,
    51: 30,
    52: 31,
    53: 8,
    56: 8,
    54: 11,
    57: 11,
    60: 11,
    61: 11,
    55: 18,
    58: 18,
    59: 15,
    66: 15,
    62: 1,
    67: 1,
    64: 2,
    68: 2,
    73: 2,
    69: 82,
    70: 32,
  };

  Future<void> _persistCart() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _cartKey,
      jsonEncode(_cart.values.map((line) => line.toJson()).toList()),
    );
  }

  Future<void> _persistDetails() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_detailsKey, jsonEncode(_details.toJson()));
  }

  @override
  void dispose() {
    unawaited(_catalogSubscription?.cancel());
    unawaited(_capacitySubscription?.cancel());
    unawaited(_siteSettingsSubscription?.cancel());
    super.dispose();
  }
}
