import 'package:expresiones/admin/admin_catalog_repository.dart';
import 'package:expresiones/admin/admin_operations_repository.dart';
import 'package:expresiones/admin/admin_portal.dart';
import 'package:expresiones/admin/admin_ui.dart';
import 'package:expresiones/models/catalog_models.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAdminCatalogRepository extends AdminCatalogRepository {
  _FakeAdminCatalogRepository({
    required super.client,
    this.initialProducts = const [],
  });

  final List<CatalogProduct> initialProducts;

  @override
  Stream<List<CatalogProduct>> watchProducts() => Stream.value(initialProducts);
}

class _FakeAdminOperationsRepository extends AdminOperationsRepository {
  _FakeAdminOperationsRepository({required super.client});
}

void main() {
  testWidgets('AdminSectionIntro oculta descripción vacía y soporta modo compacto', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminSectionIntro(
            eyebrow: 'Catálogo administrativo',
            title: 'Catálogo de Materiales',
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('CATÁLOGO ADMINISTRATIVO'), findsOneWidget);
    expect(find.text('Catálogo de Materiales'), findsOneWidget);
    // No hay descripción redundante
    expect(
      find.textContaining('Busca un material o entra por categoría'),
      findsNothing,
    );
  });

  testWidgets(
    'el catálogo administrativo se divide por módulos sin chip "Todos" y con cabecera compacta',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = SupabaseClient(
        'https://example.supabase.co',
        'public-anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      final fakeRepo = _FakeAdminCatalogRepository(
        client: client,
        initialProducts: [
          CatalogProduct(
            id: 'limpiapipas',
            name: 'Limpiapipas Premium',
            category: ProductCategory.materials,
            description: 'Chenil premium',
            basePrice: 5,
          ),
          CatalogProduct(
            id: 'corona-dorada',
            name: 'Corona Reina',
            category: ProductCategory.crowns,
            description: 'Corona metálica',
            basePrice: 15,
          ),
        ],
      );

      final fakeOperations = _FakeAdminOperationsRepository(client: client);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardScreen(
            client: client,
            repository: fakeRepo,
            operations: fakeOperations,
            userEmail: 'admin@expresiones.pe',
            onSignOut: () async {},
            initialSectionIndex: 1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. "Todos" NO debe existir como ChoiceChip
      expect(find.widgetWithText(ChoiceChip, 'Todos'), findsNothing);

      // 2. Módulos individuales presentes
      expect(find.widgetWithText(ChoiceChip, 'Materiales'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Papel Coreano'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Coronas'), findsOneWidget);

      // 3. Módulo activo inicial es Materiales
      expect(find.text('Catálogo de Materiales'), findsOneWidget);
      expect(find.text('Buscar en materiales...'), findsOneWidget);
      expect(find.text('1 material'), findsOneWidget);
      expect(find.text('LIMPIAPIPAS PREMIUM'), findsOneWidget);
      expect(find.text('CORONA REINA'), findsNothing);

      // 4. Cambiar a módulo Coronas
      await tester.tap(find.widgetWithText(ChoiceChip, 'Coronas'));
      await tester.pumpAndSettle();

      // 5. Verifica que se actualice la pantalla y muestre solo Coronas
      expect(find.text('Catálogo de Coronas'), findsOneWidget);
      expect(find.text('Buscar en coronas...'), findsOneWidget);
      expect(find.text('1 corona'), findsOneWidget);
      expect(find.text('CORONA REINA'), findsOneWidget);
      expect(find.text('LIMPIAPIPAS PREMIUM'), findsNothing);
    },
  );
}
