import 'package:expresiones/screens/help_screen.dart';
import 'package:expresiones/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('oculta el acceso administrativo directo desde Ayuda', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HelpScreen(
            onContact: () {},
            onPrivacy: () {},
            onAdminLogin: () => opened = true,
            onAssistantGuide: () {},
            assistantMuted: false,
          ),
        ),
      ),
    );

    final button = find.byKey(const ValueKey('admin-login-button'));
    expect(button, findsNothing);
    expect(opened, isFalse);
  });
}
