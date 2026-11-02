import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/assistant_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la mini Jashy despliega y oculta su ayuda', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          floatingActionButton: const AssistantHelpButton(
            title: 'Busca tu material',
            message: 'Escribe un nombre o color.',
          ),
        ),
      ),
    );

    expect(find.byTooltip('Abrir ayuda de Jashy'), findsOneWidget);
    expect(find.text('Escribe un nombre o color.'), findsNothing);

    await tester.tap(find.byTooltip('Abrir ayuda de Jashy'));
    await tester.pumpAndSettle();
    expect(find.text('Busca tu material'), findsOneWidget);
    expect(find.text('Escribe un nombre o color.'), findsOneWidget);
    expect(find.byTooltip('Cerrar ayuda de Jashy'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar ayuda de Jashy'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un nombre o color.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
