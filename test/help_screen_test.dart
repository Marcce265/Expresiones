import 'package:expresiones/screens/help_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ofrece acceso administrativo desde Ayuda', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HelpScreen(
            onContact: () {},
            onPrivacy: () {},
            onAdminLogin: () => opened = true,
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('admin-login-button'));
    expect(button, findsOneWidget);

    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opened, isTrue);
  });
}
