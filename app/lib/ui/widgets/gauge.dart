import 'dart:math';

import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// Velocímetro com arco de rpm em gradiente (ciano → verde → laranja → vermelho),
/// como o do painel: 300° a partir das 7 horas, marcas a cada 1000 rpm, vermelhas acima de 6000.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speedKmh, required this.rpm, this.size = 260});
  final double? speedKmh;
  final double? rpm;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = rpm ?? 0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(r),
        // os textos já são proporcionais ao mostrador; a fonte do sistema não os aumenta,
        // senão passariam do círculo
        child: MediaQuery.withNoTextScaling(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                fmt(speedKmh, 0),
                style: TextStyle(color: Palette.txt, fontSize: size * 0.28, fontWeight: FontWeight.w700, height: 1),
              ),
              Text('km/h', style: TextStyle(color: Palette.muted, fontSize: size * 0.07)),
              SizedBox(height: size * 0.06),
              Text(
                '${fmt(rpm, 0)} rpm',
                style: TextStyle(color: r > 5500 ? Palette.bad : Palette.txt, fontSize: size * 0.075),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cor do arco em função da fração 0..1 da faixa de rpm (0..7000).
Color rpmColor(double t) {
  if (t < 0.55) return Color.lerp(Palette.accent, Palette.ok, t / 0.55)!;
  if (t < 0.8) return Color.lerp(Palette.ok, Palette.warn, (t - 0.55) / 0.25)!;
  return Color.lerp(Palette.warn, Palette.bad, (t - 0.8) / 0.2)!;
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.rpm);
  final double rpm;

  // No firmware o arco vai de 30° a 330° medidos a partir das 6 horas, no sentido horário.
  // No Canvas, 0° fica às 3 horas: o início cai em 120°.
  static const double startDeg = 120;
  static const double spanDeg = 300;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide / 2;
    final thickness = outer * 12 / 77;
    final rect = Rect.fromCircle(center: c, radius: outer - thickness / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = Palette.line;
    canvas.drawArc(rect, _rad(startDeg), _rad(spanDeg), false, paint);

    final r = rpm < 0 ? 0.0 : (rpm > 7000 ? 7000.0 : rpm);
    final end = r / 7000 * spanDeg;
    for (var a = 0.0; a < end; a += 10) {
      final len = min(10.0, end - a);
      paint.color = rpmColor(a / spanDeg);
      canvas.drawArc(rect, _rad(startDeg + a), _rad(len + 0.6), false, paint);
    }

    final inner = outer - thickness;
    final tick = Paint()..strokeWidth = 2;
    for (var k = 0; k <= 7; k++) {
      final ang = _rad(startDeg + k * spanDeg / 7);
      final dir = Offset(cos(ang), sin(ang));
      tick.color = k >= 6 ? Palette.bad : Palette.muted;
      canvas.drawLine(c + dir * (inner - 3), c + dir * (inner - 10), tick);
    }
  }

  double _rad(double deg) => deg * pi / 180;

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) => oldDelegate.rpm != rpm;
}
