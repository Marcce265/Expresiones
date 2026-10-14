import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/catalog_models.dart';
import 'seed_catalog.dart';

enum CatalogDataSource { firestore, localSeed }

/// Read-only catalog access with a zero-configuration local fallback.
///
/// This repository never creates, updates or deletes Firestore documents.
class CatalogRepository {
  CatalogRepository({
    FirebaseFirestore? firestore,
    List<CatalogProduct>? fallbackProducts,
    this.collectionPath = 'products',
  }) : _injectedFirestore = firestore,
       _fallbackProducts = List.unmodifiable(
         fallbackProducts ?? seedCatalogProducts,
       );

  final FirebaseFirestore? _injectedFirestore;
  final List<CatalogProduct> _fallbackProducts;
  final String collectionPath;

  CatalogDataSource _lastSource = CatalogDataSource.localSeed;
  Object? _lastError;

  CatalogDataSource get lastSource => _lastSource;
  Object? get lastError => _lastError;

  Future<List<CatalogProduct>> loadProducts() async {
    _lastError = null;
    final firestore = _resolveFirestore();
    if (firestore == null) return _useFallback();

    try {
      final snapshot = await firestore
          .collection(collectionPath)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();
      if (snapshot.docs.isEmpty) return _useFallback();

      final products = snapshot.docs
          .map(
            (document) =>
                CatalogProduct.fromFirestore(document.data(), id: document.id),
          )
          .where((product) => product.isActive)
          .toList();
      _lastSource = CatalogDataSource.firestore;
      return _sorted(products);
    } catch (error) {
      _lastError = error;
      return _useFallback();
    }
  }

  /// Emits Firestore changes when available and otherwise emits the seed once.
  Stream<List<CatalogProduct>> watchProducts() async* {
    _lastError = null;
    final firestore = _resolveFirestore();
    if (firestore == null) {
      yield _useFallback();
      return;
    }

    try {
      await for (final snapshot
          in firestore
              .collection(collectionPath)
              .where('isActive', isEqualTo: true)
              .orderBy('sortOrder')
              .snapshots()) {
        if (snapshot.docs.isEmpty) {
          yield _useFallback();
          continue;
        }

        final products = snapshot.docs
            .map(
              (document) => CatalogProduct.fromFirestore(
                document.data(),
                id: document.id,
              ),
            )
            .where((product) => product.isActive)
            .toList();
        _lastSource = CatalogDataSource.firestore;
        _lastError = null;
        yield _sorted(products);
      }
    } catch (error) {
      _lastError = error;
      yield _useFallback();
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

  FirebaseFirestore? _resolveFirestore() {
    if (_injectedFirestore != null) return _injectedFirestore;

    try {
      if (Firebase.apps.isEmpty) return null;
      final defaultApp = Firebase.apps.where(
        (app) => app.name == defaultFirebaseAppName,
      );
      final app = defaultApp.isNotEmpty
          ? defaultApp.first
          : Firebase.apps.first;
      return FirebaseFirestore.instanceFor(app: app);
    } catch (error) {
      _lastError = error;
      return null;
    }
  }

  List<CatalogProduct> _useFallback() {
    _lastSource = CatalogDataSource.localSeed;
    return _sorted(
      _fallbackProducts.where((product) => product.isActive).toList(),
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
