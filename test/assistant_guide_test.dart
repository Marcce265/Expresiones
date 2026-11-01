import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/assistant_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la indicación muestra ayuda, acción y cierre accesibles', (
    tester,
  ) async {
    var actionCount = 0;
    var dismissCount = 0;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AssistantGuideCard(
            title: 'Te ayudo a comenzar',
            message: 'Busca un material o entra al catálogo.',
            primaryLabel: 'Ver catálogo',
            onPrimary: () => actionCount++,
            onDismiss: () => dismissCount++,
          ),
        ),
      ),
    );

    expect(find.text('Te ayudo a comenzar'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Jashy, asistente de Expresiones'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver catálogo'));
    await tester.tap(find.byTooltip('Cerrar indicación'));
    expect(actionCount, 1);
    expect(dismissCount, 1);

    semantics.dispose();
  });

  testWidgets('la guía devuelve la opción no volver a mostrar', (tester) async {
    AssistantGuideResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: AssistantHelpButton(
                onPressed: () async {
                  result = await showAssistantGuideSheet(
                    context: context,
                    title: 'Te acompaño paso a paso',
                    message: 'Completa tu cotización en tres pasos.',
                    showDoNotShowAgain: true,
                    steps: const [
                      AssistantGuideStep(
                        title: 'Elige',
                        message: 'Selecciona el material y la cantidad.',
                        icon: Icons.search_rounded,
                      ),
                      AssistantGuideStep(
                        title: 'Revisa',
                        message: 'Comprueba los productos del carrito.',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      AssistantGuideStep(
                        title: 'Envía',
                        message: 'Envía la cotización por WhatsApp.',
                        icon: Icons.chat_outlined,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('¿Necesitas ayuda?'));
    await tester.pumpAndSettle();

    expect(find.text('Te acompaño paso a paso'), findsOneWidget);
    expect(find.text('1. Elige'), findsOneWidget);
    expect(find.text('2. Revisa'), findsOneWidget);
    expect(find.text('3. Envía'), findsOneWidget);

    await tester.tap(find.text('No volver a mostrar'));
    await tester.pumpAndSettle();
    expect(result, AssistantGuideResult.doNotShowAgain);
  });

  testWidgets('la guía no desborda a 320 px con texto ampliado', (
    tester,
  ) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: AssistantHelpButton(
                onPressed: () => showAssistantGuideSheet(
                  context: context,
                  title: assistantGuideTitle,
                  message: assistantGuideMessage,
                  steps: assistantGuideSteps,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('¿Necesitas ayuda?'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, soy Jashy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
