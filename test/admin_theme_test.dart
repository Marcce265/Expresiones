import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el lápiz relleno mantiene contraste blanco sobre negro', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: IconButton.filled(
            tooltip: 'Agregar campo al formulario',
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      ),
    );

    final icon = find.byIcon(Icons.edit_outlined);
    expect(icon, findsOneWidget);
    expect(IconTheme.of(tester.element(icon)).color, Colors.white);
  });
}
