import 'package:flutter/material.dart';

/// SmartGarden IoT — custom logo widget.
/// Renders a leaf silhouette with IoT circuit traces inside a gradient circle.
class SmartGardenLogo extends StatelessWidget {
  final double size;

  const SmartGardenLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.45 : 0.25),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _LogoPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── Leaf body ────────────────────────────────────────────────────────────
    final leafPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final leafPath = Path()
      ..moveTo(cx, cy - h * 0.29)
      ..cubicTo(cx + w * 0.24, cy - h * 0.30, cx + w * 0.27, cy + h * 0.07, cx, cy + h * 0.13)
      ..cubicTo(cx - w * 0.27, cy + h * 0.07, cx - w * 0.24, cy - h * 0.30, cx, cy - h * 0.29)
      ..close();
    canvas.drawPath(leafPath, leafPaint);

    // ── Leaf vein ─────────────────────────────────────────────────────────────
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy - h * 0.22), Offset(cx, cy + h * 0.11), veinPaint);

    // ── Stem ──────────────────────────────────────────────────────────────────
    final stemPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.048
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, cy + h * 0.13), Offset(cx, cy + h * 0.32), stemPaint);

    // ── IoT circuit traces ────────────────────────────────────────────────────
    final tracePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = w * 0.022
      ..style = PaintingStyle.stroke;

    // Left trace: vertical then horizontal
    canvas.drawLine(Offset(cx - w * 0.31, cy - h * 0.04), Offset(cx - w * 0.31, cy + h * 0.23), tracePaint);
    canvas.drawLine(Offset(cx - w * 0.31, cy + h * 0.23), Offset(cx - w * 0.10, cy + h * 0.23), tracePaint);

    // Right trace: vertical then horizontal
    canvas.drawLine(Offset(cx + w * 0.31, cy - h * 0.04), Offset(cx + w * 0.31, cy + h * 0.23), tracePaint);
    canvas.drawLine(Offset(cx + w * 0.31, cy + h * 0.23), Offset(cx + w * 0.10, cy + h * 0.23), tracePaint);

    // ── Circuit nodes (dots) ──────────────────────────────────────────────────
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.38);
    final smallDot = Paint()..color = Colors.white.withValues(alpha: 0.25);

    canvas.drawCircle(Offset(cx - w * 0.31, cy - h * 0.04), w * 0.040, dotPaint);
    canvas.drawCircle(Offset(cx + w * 0.31, cy - h * 0.04), w * 0.040, dotPaint);
    canvas.drawCircle(Offset(cx - w * 0.31, cy + h * 0.23), w * 0.028, smallDot);
    canvas.drawCircle(Offset(cx + w * 0.31, cy + h * 0.23), w * 0.028, smallDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
