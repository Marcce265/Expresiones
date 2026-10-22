import 'dart:async';

import 'package:expresiones/models/catalog_models.dart';
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
}
