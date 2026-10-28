import 'package:expresiones/models/coordination_details.dart';
import 'package:expresiones/models/storefront_settings.dart';
import 'package:expresiones/screens/coordination_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra el icono configurado en un campo adicional', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CoordinationScreen(
          initial: const CoordinationDetails(),
          earliestDate: DateTime(2026, 10, 27),
          onSubmit: (_) {},
          settings: const StorefrontSettings(
            checkoutFields: [
              CheckoutCustomField(
                id: 'color_preferido',
                label: 'Color preferido',
                icon: 'palette',
                hint: 'Ej. rosado',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('COLOR PREFERIDO'), findsOneWidget);
    expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
