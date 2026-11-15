import 'package:flutter/material.dart';

import '../theme.dart';
import 'bars.dart';

/// Mini gráfico da sonda lambda 1 (0..1 V), 48 amostras em anel.
class O2Sparkline extends StatelessWidget {
  const O2Sparkline({super.key, required this.history, required this.index, this.height = 56});
  final List<double> history;
  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(border: Border.all(color: Palette.line)),
      child: SizedBox.expand(child: CustomPaint(painter: _O2Painter(List<double>.of(history), index))),
    );
  }
}

class _O2Painter extends CustomPainter {
  _O2Painter(this.hist, this.idx);
  final List<double> hist;
  final int idx;

  @override
  void paint(Canvas canvas, Size size) {
    final n = hist.length;
    if (n < 2) return;
    final paint = Paint()
      ..color = Palette.accent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final v = clampD(hist[(idx + i) % n], 0, 1);
      final x = i * (size.width - 1) / (n - 1);
      final y = size.height - 1 - v * (size.height - 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_O2Painter oldDelegate) => true;
}
