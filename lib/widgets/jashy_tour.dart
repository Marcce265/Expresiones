import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _jashyAsset = 'assets/images/jashy_assistant.png';

enum JashyTourResult { completed, dismissed, doNotDisturb }

class JashyTourStep {
  const JashyTourStep({
    required this.title,
    required this.message,
    this.targetKey,
    this.imageAsset = 'assets/images/jashy_assistant.png',
  });

  final String title;
  final String message;
  final GlobalKey? targetKey;
  final String imageAsset;
}

Future<JashyTourResult?> showJashyTour({
  required BuildContext context,
  required List<JashyTourStep> steps,
  int initialStep = 0,
}) {
  assert(steps.isNotEmpty);
  assert(initialStep >= 0 && initialStep < steps.length);
  return showGeneralDialog<JashyTourResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    barrierLabel: 'Guía de Jashy',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) =>
        JashyTourOverlay(steps: steps, initialStep: initialStep),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: .98, end: 1.0).animate(animation),
        child: child,
      ),
    ),
  );
}

class JashyTourOverlay extends StatefulWidget {
  const JashyTourOverlay({
    super.key,
    required this.steps,
    this.initialStep = 0,
  });

  final List<JashyTourStep> steps;
  final int initialStep;

  @override
  State<JashyTourOverlay> createState() => _JashyTourOverlayState();
}

class _JashyTourOverlayState extends State<JashyTourOverlay> {
  late int _index = widget.initialStep;

  Rect? _targetRect(Size screenSize) {
    final context = widget.steps[_index].targetKey?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final rect = (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        .inflate(8)
        .intersect(Offset.zero & screenSize);
    return rect.isEmpty ? null : rect;
  }

  void _previous() => setState(() => _index--);

  void _next() {
    if (_index == widget.steps.length - 1) {
      Navigator.pop(context, JashyTourResult.completed);
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final target = _targetRect(size);
    final mobile = size.width < 700;
    final placeAtTop = target != null && target.center.dy > size.height * .55;
    final placeOnRight = target == null || target.center.dx < size.width / 2;
    final horizontalInset = mobile ? 12.0 : 28.0;
    final verticalInset = mobile ? 12.0 : 24.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                key: const ValueKey('jashy_tour_spotlight'),
                painter: _SpotlightPainter(target),
              ),
            ),
          ),
          Positioned(
            left: mobile || !placeOnRight ? horizontalInset : null,
            right: mobile || placeOnRight ? horizontalInset : null,
            top: placeAtTop ? padding.top + verticalInset : null,
            bottom: placeAtTop ? null : padding.bottom + verticalInset,
            child: _JashySpeechCard(
              key: ValueKey('jashy_tour_step_$_index'),
              step: widget.steps[_index],
              index: _index,
              total: widget.steps.length,
              mobile: mobile,
              onPrevious: _index == 0 ? null : _previous,
              onNext: _next,
              onDismiss: () =>
                  Navigator.pop(context, JashyTourResult.dismissed),
              onDoNotDisturb: () =>
                  Navigator.pop(context, JashyTourResult.doNotDisturb),
            ),
          ),
        ],
      ),
    );
  }
}

class _JashySpeechCard extends StatelessWidget {
  const _JashySpeechCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.mobile,
    required this.onPrevious,
    required this.onNext,
    required this.onDismiss,
    required this.onDoNotDisturb,
  });

  final JashyTourStep step;
  final int index;
  final int total;
  final bool mobile;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDismiss;
  final VoidCallback onDoNotDisturb;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final portraitWidth = mobile ? 78.0 : 124.0;
    final maxWidth = mobile ? screen.width - 24 : 520.0;
    final maxHeight = screen.height * (mobile ? .56 : .62);

    return Semantics(
      container: true,
      liveRegion: true,
      label:
          'Jashy. Paso ${index + 1} de $total. ${step.title}. ${step.message}',
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(mobile ? 18 : 24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x52000000),
                      blurRadius: 28,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 14 : 20,
                    mobile ? 10 : 16,
                    mobile ? 10 : 14,
                    mobile ? 12 : 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'JASHY · GUÍA ${index + 1}/$total',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.pinkStrong),
                            ),
                          ),
                          IconButton(
                            onPressed: onDismiss,
                            tooltip: 'Cerrar guía de Jashy',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                        ],
                      ),
                      Text(
                        step.title,
                        style: mobile
                            ? Theme.of(context).textTheme.titleMedium
                            : Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(step.message),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: onDoNotDisturb,
                            child: const Text('No molestar'),
                          ),
                          if (onPrevious != null)
                            OutlinedButton(
                              onPressed: onPrevious,
                              child: const Text('Atrás'),
                            ),
                          FilledButton(
                            onPressed: onNext,
                            child: Text(
                              index == total - 1 ? 'Listo' : 'Siguiente',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: portraitWidth,
              height: portraitWidth * 1.5,
              child: Semantics(
                image: true,
                label: 'Jashy, asistente de Expresiones',
                child: Image.asset(
                  step.imageAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.target);

  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()..addRect(Offset.zero & size);
    if (target != null) {
      shade
        ..addRRect(RRect.fromRectAndRadius(target!, const Radius.circular(18)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(shade, Paint()..color = const Color(0xB8000000));
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(18)),
        Paint()
          ..color = Colors.white.withValues(alpha: .92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
