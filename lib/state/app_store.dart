import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_models.dart';
import '../models/coordination_details.dart';
import '../models/quote_line.dart';

typedef CatalogLoader = Future<List<CatalogProduct>> Function();

class AppStore extends ChangeNotifier {
  AppStore(this._catalogLoader);

  static const _cartKey = 'expresiones.quote.v1';
  static const _detailsKey = 'expresiones.coordination.v1';

  final CatalogLoader _catalogLoader;
  final Map<String, QuoteLine> _cart = {};
  List<CatalogProduct> _products = const [];
  CoordinationDetails _details = const CoordinationDetails();
  bool _isLoading = true;
  String? _errorMessage;

  List<CatalogProduct> get products => List.unmodifiable(_products);
  CoordinationDetails get details => _details;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasQuote => _cart.isNotEmpty;

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
  int get productionPoints =>
      resolvedLines.fold(0, (sum, item) => sum + item.productionPoints);
  int get maximumLeadDays => resolvedLines.fold(
    0,
    (maximum, item) => item.leadDays > maximum ? item.leadDays : maximum,
  );

  DateTime get earliestDesiredDate {
    final now = DateTime.now();
    var date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: maximumLeadDays));
    if (date.weekday == DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _restoreLocalState();
    await reloadCatalog(notifyAtStart: false);
  }

  Future<void> reloadCatalog({bool notifyAtStart = true}) async {
    if (notifyAtStart) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final loaded = await _catalogLoader();
      _products = loaded.where((product) => product.isActive).toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order == 0 ? a.name.compareTo(b.name) : order;
        });
      if (_products.isEmpty) {
        _errorMessage = 'El catálogo está vacío por el momento.';
      }
      _removeMissingCartLines();
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
    notifyListeners();
  }

  void updateQuantity(QuoteLine line, int quantity) {
    if (quantity <= 0) {
      removeLine(line);
      return;
    }
    if (!_cart.containsKey(line.key)) return;
    _cart[line.key] = line.copyWith(quantity: quantity);
    _persistCart();
    notifyListeners();
  }

  void removeLine(QuoteLine line) {
    _cart.remove(line.key);
    _persistCart();
    notifyListeners();
  }

  void updateDetails(CoordinationDetails details) {
    _details = details;
    _persistDetails();
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

  void _removeMissingCartLines() {
    final productIds = _products.map((product) => product.id).toSet();
    _cart.removeWhere((_, line) => !productIds.contains(line.productId));
    _persistCart();
  }

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
}
