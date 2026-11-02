import 'package:expresiones/theme/app_theme.dart';
import 'package:expresiones/widgets/jashy_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Jashy recorre los pasos y permite activar No molestar', (
    tester,
  ) async {
    final catalogKey = GlobalKey();
    JashyTourResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: catalogKey,
                onPressed: () async {
                  result = await showJashyTour(
                    context: context,
                    steps: [
                      JashyTourStep(
                        title: 'Este es el catálogo',
                        message: 'Aquí encontrarás todos los materiales.',
                        targetKey: catalogKey,
                      ),
                      const JashyTourStep(
                        title: 'Este es tu carrito',
                        message: 'Aquí revisarás lo que elegiste.',
                      ),
                    ],
                  );
                },
                child: const Text('Abrir guía'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir guía'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('jashy_tour_spotlight')), findsOneWidget);
    expect(find.text('Este es el catálogo'), findsOneWidget);
    expect(find.text('JASHY · GUÍA 1/2'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Este es tu carrito'), findsOneWidget);
    expect(find.text('JASHY · GUÍA 2/2'), findsOneWidget);

    await tester.tap(find.text('No molestar'));
    await tester.pumpAndSettle();
    expect(result, JashyTourResult.doNotDisturb);
  });

  testWidgets('el tour se adapta a 320 px con texto ampliado', (tester) async {
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
              child: FilledButton(
                onPressed: () => showJashyTour(
                  context: context,
                  steps: const [
                    JashyTourStep(
                      title: 'Te acompaño en esta sección',
                      message: 'Toca cada producto para elegir su color y la cantidad que necesitas. Después agrégalo a tu carrito.',
                    ),
                  ],
                ),
                child: const Text('Ayuda'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ayuda'));
    await tester.pumpAndSettle();

    expect(find.text('Te acompaño en esta sección'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
