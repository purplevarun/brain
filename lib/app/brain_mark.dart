import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// The brain mark: a crystal hexagon with a neural constellation inside —
/// painted version of the app icon, tinted to the theme accent.
class BrainMark extends StatelessWidget {
  const BrainMark({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BrainMarkPainter(color),
    );
  }
}

class _BrainMarkPainter extends CustomPainter {
  const _BrainMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width; // square canvas

    // Hexagon outline.
    final hexR = s * 0.44;
    final hex = Path();
    for (var i = 0; i <= 6; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 6;
      final p = Offset(c.dx + hexR * math.cos(a), c.dy + hexR * math.sin(a));
      i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Ring nodes + edges.
    final ringR = hexR * 0.60;
    final pts = [
      for (var i = 0; i < 6; i++)
        Offset(
          c.dx + ringR * math.cos(-math.pi / 2 + i * math.pi * 2 / 6),
          c.dy + ringR * math.sin(-math.pi / 2 + i * math.pi * 2 / 6),
        ),
    ];
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..color = color.withValues(alpha: 0.75);
    for (final p in pts) {
      canvas.drawLine(c, p, edgePaint);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(pts[i], pts[(i + 1) % 6], edgePaint);
    }

    final nodePaint = Paint()..color = color;
    for (final p in pts) {
      canvas.drawCircle(p, s * 0.052, nodePaint);
    }
    canvas.drawCircle(c, s * 0.085, nodePaint);
  }

  @override
  bool shouldRepaint(_BrainMarkPainter old) => old.color != color;
}
