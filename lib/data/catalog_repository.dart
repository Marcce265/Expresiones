import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_models.dart';
import 'seed_catalog.dart';
import 'supabase_catalog_mapper.dart';

enum CatalogDataSource { supabase, cache, localSeed }

/// Local-first catalog access backed by normalized Supabase tables.
///
/// The embedded seed makes first launch and offline use immediate. Once a
/// Supabase response succeeds it is cached locally, including a valid empty
/// catalog, so a deliberate remote removal never resurrects old seed data.
class CatalogRepository {
  CatalogRepository({
    this.client,
    List<CatalogProduct>? fallbackProducts,
    this.cacheKey = 'expresiones.catalog.supabase.v1',
  }) : _fallbackProducts = List.unmodifiable(
         fallbackProducts ?? seedCatalogProducts,
       );

  final SupabaseClient? client;
  final List<CatalogProduct> _fallbackProducts;
  final String cacheKey;

  CatalogDataSource _lastSource = CatalogDataSource.localSeed;
  Object? _lastError;

  CatalogDataSource get lastSource => _lastSource;
  Object? get lastError => _lastError;

  Future<List<CatalogProduct>> loadProducts() async {
    _lastError = null;
    final cached = await _loadCache();
    if (cached != null) {
      _lastSource = CatalogDataSource.cache;
      return _sorted(cached);
    }
    return _useFallback();
  }

  /// Emits a fresh snapshot and then refreshes after any normalized table edit.
  Stream<List<CatalogProduct>> watchProducts({
    bool includeInactive = false,
  }) async* {
    _lastError = null;
    final activeClient = client;
    if (activeClient == null) {
      final cached = await _loadCache();
      if (cached != null) {
        _lastSource = CatalogDataSource.cache;
        yield _sorted(cached);
      } else {
        yield _useFallback(includeInactive: includeInactive);
      }
      return;
    }

    try {
      final products = await _fetchRemote(includeInactive: includeInactive);
      _lastSource = CatalogDataSource.supabase;
      _lastError = null;
      if (!includeInactive) await _saveCache(products);
      yield products;
    } catch (error) {
      _lastError = error;
      final cached = includeInactive ? null : await _loadCache();
      if (cached != null) {
        _lastSource = CatalogDataSource.cache;
        yield _sorted(cached);
      } else {
        yield _useFallback(includeInactive: includeInactive);
      }
    }

    final changes = StreamController<void>();
    final subscriptions = <StreamSubscription<dynamic>>[];
    Timer? debounce;

    void scheduleRefresh() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), () {
        if (!changes.isClosed) changes.add(null);
      });
    }

    void watchTable(String table) {
      final subscription = activeClient
          .from(table)
          .stream(primaryKey: const ['id'])
          .listen(
            (_) => scheduleRefresh(),
            onError: (Object error, StackTrace stackTrace) {
              _lastError = error;
            },
          );
      subscriptions.add(subscription);
    }

    for (final table in const [
      'families',
      'variants',
      'family_price_tiers',
      'variant_price_tiers',
    ]) {
      watchTable(table);
    }

    try {
      await for (final _ in changes.stream) {
        try {
          final products = await _fetchRemote(
            includeInactive: includeInactive,
          );
          _lastSource = CatalogDataSource.supabase;
          _lastError = null;
          if (!includeInactive) await _saveCache(products);
          yield products;
        } catch (error) {
          // Keep the last good catalog on screen while connectivity recovers.
          _lastError = error;
        }
      }
    } finally {
      debounce?.cancel();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await changes.close();
    }
  }

  Future<CatalogProduct?> findById(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    final products = await loadProducts();
    for (final product in products) {
      if (product.id == normalizedId) return product;
    }
    return null;
  }

  Future<List<CatalogProduct>> byCategory(ProductCategory category) async {
    final products = await loadProducts();
    return List.unmodifiable(
      products.where((product) => product.category == category),
    );
  }

  Future<List<CatalogProduct>> _fetchRemote({
    required bool includeInactive,
  }) async {
    final activeClient = client;
    if (activeClient == null) {
      return _useFallback(includeInactive: includeInactive);
    }

    final rows = await Future.wait([
      _readRows(activeClient, 'families'),
      _readRows(activeClient, 'variants'),
      _readRows(activeClient, 'family_price_tiers'),
      _readRows(activeClient, 'variant_price_tiers'),
    ]);
    final families = includeInactive
        ? rows[0]
        : rows[0].where(_isActive).toList();
    final activeFamilyIds = {
      for (final family in families) '${family['id'] ?? ''}',
    };
    final variants = rows[1].where((variant) {
      if (!activeFamilyIds.contains('${variant['family_id'] ?? ''}')) {
        return false;
      }
      return includeInactive || _isActive(variant);
    }).toList();

    return SupabaseCatalogMapper(resolveImage: _resolveImage).mapCatalog(
      families: families,
      variants: variants,
      familyPriceTiers: rows[2],
      variantPriceTiers: rows[3],
    );
  }

  Future<List<Map<String, dynamic>>> _readRows(
    SupabaseClient client,
    String table,
  ) async {
    final response = await client.from(table).select();
    return [
      for (final row in response)
        Map<String, dynamic>.from(row),
    ];
  }

  bool _isActive(Map<String, dynamic> row) => row['active'] != false;

  String? _resolveImage(Object? rawPath) {
    var path = rawPath?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    if (path.startsWith('assets/') ||
        path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:')) {
      return path;
    }
    if (path.startsWith('storage://catalog/')) {
      path = path.substring('storage://catalog/'.length);
    } else if (path.startsWith('catalog/')) {
      path = path.substring('catalog/'.length);
    }
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    return client?.storage.from('catalog').getPublicUrl(path);
  }

  Future<List<CatalogProduct>?> _loadCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(cacheKey);
      if (encoded == null) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return null;
      return List.unmodifiable(
        decoded
            .whereType<Map>()
            .map(
              (item) => CatalogProduct.fromMap(
                item.map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCache(List<CatalogProduct> products) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        cacheKey,
        jsonEncode([for (final product in products) product.toMap()]),
      );
    } catch (_) {
      // Storage quota and privacy-mode failures must not break the catalog.
    }
  }

  List<CatalogProduct> _useFallback({bool includeInactive = false}) {
    _lastSource = CatalogDataSource.localSeed;
    return _sorted(
      _fallbackProducts
          .where((product) => includeInactive || product.isActive)
          .toList(),
    );
  }

  List<CatalogProduct> _sorted(List<CatalogProduct> products) {
    products.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(products);
  }
}
