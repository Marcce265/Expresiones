import 'package:expresiones/admin/admin_checkout_settings_screen.dart';
import 'package:expresiones/admin/admin_operations_repository.dart';
import 'package:expresiones/admin/admin_site_settings_repository.dart';
import 'package:expresiones/models/production_capacity.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('edita contacto y días dentro de la misma pantalla', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdminCheckoutSettingsScreen(
            repository: _FakeSettingsRepository(),
            operations: _FakeOperationsRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Días de entrega'), findsOneWidget);
    expect(find.text('Tus datos de contacto'), findsOneWidget);

    final pencil = find.byIcon(Icons.edit_outlined);
    expect(pencil, findsOneWidget);
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pump();

    expect(find.text('Agregar campo'), findsWidgets);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Nombre del campo'), findsOneWidget);
    expect(find.text('Icono del campo'), findsOneWidget);
    expect(find.text('Documento'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('el editor inline se adapta al ancho móvil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdminCheckoutSettingsScreen(
            repository: _FakeSettingsRepository(),
            operations: _FakeOperationsRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final pencil = find.byIcon(Icons.edit_outlined);
    final pageScrollable = find
        .ancestor(of: pencil, matching: find.byType(Scrollable))
        .first;
    final scrollable = tester.state<ScrollableState>(pageScrollable);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(pencil);
    await tester.pump();

    expect(find.text('Nombre del campo'), findsOneWidget);
    expect(find.text('Icono del campo'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

SupabaseClient _testClient() => SupabaseClient(
  'https://example.supabase.co',
  'test-publishable-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeSettingsRepository extends AdminSiteSettingsRepository {
  _FakeSettingsRepository() : super(client: _testClient());

  @override
  Stream<StorefrontSettings> watch() => Stream.value(
    const StorefrontSettings(
      pickupLocation: PickupLocationSettings(
        name: 'Expresiones Eternas',
        address: 'Pje. Porvenir 149, Huancayo 12001',
      ),
    ),
  );

  @override
  Future<void> save(StorefrontSettings settings) async {}
}

class _FakeOperationsRepository extends AdminOperationsRepository {
  _FakeOperationsRepository() : super(client: _testClient());

  @override
  Stream<ProductionCapacitySnapshot> watchCapacity() =>
      Stream.value(ProductionCapacitySnapshot.twoPersonFallback());

  @override
  Future<void> saveCapacity(ProductionCapacitySnapshot snapshot) async {}
}
