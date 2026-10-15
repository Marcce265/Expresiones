import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalog_models.dart';

/// Firestore write access used exclusively by the authenticated admin portal.
///
/// Security is enforced again in `firestore.rules`; hiding the portal URL is
/// never considered authorization.
class AdminCatalogRepository {
  AdminCatalogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Stream<List<CatalogProduct>> watchProducts() {
    return _products.orderBy('sortOrder').snapshots().map((snapshot) {
      final products = snapshot.docs
          .map(
            (document) =>
                CatalogProduct.fromFirestore(document.data(), id: document.id),
          )
          .toList();
      products.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0
            ? order
            : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return List.unmodifiable(products);
    });
  }

  Future<void> createProduct({
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final id = normalizedDocumentId(documentId);
    if (id.isEmpty) {
      throw const FormatException('El producto necesita un identificador.');
    }
    final reference = _products.doc(id);
    if ((await reference.get()).exists) {
      throw StateError('Ya existe un producto con el código $id.');
    }
    await reference.set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> patch) {
    return _products.doc(productId).update({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setProductActive(String productId, bool active) {
    return updateProduct(productId, {'isActive': active});
  }

  Future<void> deleteProduct(String productId) {
    return _products.doc(productId).delete();
  }

  static String normalizedDocumentId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
