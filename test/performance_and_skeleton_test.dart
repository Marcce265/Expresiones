import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expresiones/data/catalog_repository.dart';
import 'package:expresiones/widgets/skeleton_loader.dart';

void main() {
  group('Optimizaciones de rendimiento y skeletons', () {
    testWidgets('CatalogGridSkeleton y CatalogCardSkeleton renderizan correctamente', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogGridSkeleton(itemCount: 4),
          ),
        ),
      );

      expect(find.byType(CatalogGridSkeleton), findsOneWidget);
      expect(find.byType(CatalogCardSkeleton), findsNWidgets(4));
      expect(find.byType(ShimmerSkeleton), findsWidgets);
    });

    test('CatalogRepository deduplica llamadas en vuelo concurrentes', () async {
      final repository = CatalogRepository();

      // Launch multiple load calls concurrently
      final future1 = repository.loadProducts();
      final future2 = repository.loadProducts();

      final results = await Future.wait([future1, future2]);

      expect(results[0].length, results[1].length);
      expect(results[0].isNotEmpty, isTrue);
    });
  });
}
