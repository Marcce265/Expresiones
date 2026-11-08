import 'package:flutter/material.dart';

/// Corona dibujada a medida: Material Icons no incluye un icono de corona.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CrownPainter(color: resolvedColor)),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final path = Path()
      ..moveTo(3, 7)
      ..lineTo(5, 19)
      ..lineTo(19, 19)
      ..lineTo(21, 7)
      ..lineTo(15.5, 12)
      ..lineTo(12, 4.5)
      ..lineTo(8.5, 12)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}
