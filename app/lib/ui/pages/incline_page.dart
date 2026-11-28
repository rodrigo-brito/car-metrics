import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config.dart';
import '../../incline/incline_controller.dart';
import '../theme.dart';
import '../widgets/one_line.dart';

Color levelColor(InclineLevel l) => switch (l) {
      InclineLevel.ok => Palette.ok,
      InclineLevel.warn => Palette.warn,
      InclineLevel.danger => Palette.bad,
    };

/// Página do inclinômetro: inclinação lateral (vista de trás) e longitudinal (vista de lado),
/// pelo acelerômetro do celular. Não depende do OBD. [standalone] mostra com barra própria,
/// para abrir direto da tela inicial.
class InclinePage extends StatefulWidget {
  const InclinePage({super.key, this.controller, this.standalone = false});
  final InclineController? controller;
  final bool standalone;

  @override
  State<InclinePage> createState() => _InclinePageState();
}

class _InclinePageState extends State<InclinePage> {
  late final InclineController _c = widget.controller ?? InclineController.instance;

  @override
  void initState() {
    super.initState();
    _c.attach();
  }

  @override
  void dispose() {
    _c.detach();
    super.dispose();
  }

  Future<void> _calibrate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        title: const Text('Zerar inclinômetro?'),
        content: const Text(
          'Pare o carro num lugar plano, com o celular já preso no suporte na posição de uso. '
          'A posição atual passa a valer 0° nos dois sentidos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zerar')),
        ],
      ),
    );
    if (ok == true) await _c.calibrate();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: _c,
      builder: (context, _) => _buildBody(context),
    );
    if (!widget.standalone) return body;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.panel,
        title: const Text('Inclinômetro', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(child: body),
    );
  }

  Widget _buildBody(BuildContext context) {
    final inc = _c.now;
    final roll = inc?.rollDeg;
    final pitch = inc?.pitchDeg;
    final lateral = _Dial(
      title: 'LATERAL',
      angle: roll,
      level: roll == null ? null : rollLevel(roll),
      direction: roll == null || roll.abs() < 0.5 ? 'nivelado' : (roll > 0 ? 'para a direita' : 'para a esquerda'),
      painter: (a, c) => _RearCarPainter(a, c, inclineRollWarn, inclineRollDanger),
      maxText: 'máx  esq ${_c.maxRollLeft.toStringAsFixed(0)}°   dir ${_c.maxRollRight.toStringAsFixed(0)}°',
    );
    final longitudinal = _Dial(
      title: 'LONGITUDINAL',
      angle: pitch,
      level: pitch == null ? null : pitchLevel(pitch),
      direction: pitch == null || pitch.abs() < 0.5 ? 'nivelado' : (pitch > 0 ? 'subida' : 'descida'),
      painter: (a, c) => _SideCarPainter(a, c, inclinePitchWarn, inclinePitchDanger),
      maxText: 'máx  subida ${_c.maxPitchUp.toStringAsFixed(0)}°   descida ${_c.maxPitchDown.toStringAsFixed(0)}°',
    );

    final controls = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: inc == null ? null : _calibrate,
              icon: const Icon(Icons.straighten),
              label: const OneLine('Zerar no plano'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _c.resetMax,
              icon: const Icon(Icons.restart_alt),
              label: const OneLine('Zerar máximos'),
            ),
          ),
        ],
      ),
    );

    final notice = _c.error ??
        (_c.calibrated
            ? null
            : 'Sem calibração: supondo o celular em pé no suporte. Pare no plano e toque em "Zerar no plano".');

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight;
        final dials = wide
            ? Row(children: [Expanded(child: lateral), Expanded(child: longitudinal)])
            : Column(children: [Expanded(child: lateral), Expanded(child: longitudinal)]);
        return Column(
          children: [
            if (notice != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Palette.warn),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(notice, style: const TextStyle(color: Palette.warn, fontSize: 12)),
              ),
            Expanded(child: dials),
            controls,
          ],
        );
      },
    );
  }
}

class _Dial extends StatelessWidget {
  const _Dial({
    required this.title,
    required this.angle,
    required this.level,
    required this.direction,
    required this.painter,
    required this.maxText,
  });
  final String title;
  final double? angle;
  final InclineLevel? level;
  final String direction;
  final CustomPainter Function(double angle, Color color) painter;
  final String maxText;

  @override
  Widget build(BuildContext context) {
    final a = angle;
    final color = level == null ? Palette.muted : levelColor(level!);
    final danger = level == InclineLevel.danger;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: danger ? Palette.bad.withValues(alpha: 0.12) : Palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: danger ? Palette.bad : Palette.panel, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OneLine(
                  title,
                  style: const TextStyle(
                      color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    a == null ? '--' : '${a.abs().toStringAsFixed(0)}°',
                    style: TextStyle(color: color, fontSize: 52, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                ),
                OneLine(direction, style: TextStyle(color: color, fontSize: 14)),
                const SizedBox(height: 6),
                Text(maxText, style: const TextStyle(color: Palette.muted, fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: CustomPaint(painter: painter(a ?? 0, color), child: const SizedBox.expand()),
          ),
        ],
      ),
    );
  }
}

/// Base comum: arco de escala ±45° com faixas coloridas, horizonte fixo e o carro girando.
abstract class _CarPainter extends CustomPainter {
  _CarPainter(this.angleDeg, this.color, this.warn, this.danger);
  final double angleDeg;
  final Color color;
  final double warn;
  final double danger;

  /// Desenha o carro centrado em (0,0), com as rodas apoiadas em y = 0, largura ~ [w].
  void drawCar(Canvas canvas, double w, Paint body, Paint dark);

  /// Sinal da rotação na tela: positivo gira no sentido horário.
  double get screenSign;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width / 2, size.height * 0.85) - 6;
    if (r <= 10) return;
    final center = Offset(size.width / 2, size.height * 0.5 + r * 0.35);

    // escala: arco superior de -45° a +45° em volta do carro
    final arcRect = Rect.fromCircle(center: center, radius: r);
    void band(double from, double to, Color c) {
      final p = Paint()
        ..color = c.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5;
      double toRad(double d) => (-90 + d) * math.pi / 180;
      canvas.drawArc(arcRect, toRad(from), (to - from) * math.pi / 180, false, p);
    }

    band(-warn, warn, Palette.ok);
    band(warn, danger, Palette.warn);
    band(-danger, -warn, Palette.warn);
    band(danger, 45, Palette.bad);
    band(-45, -danger, Palette.bad);

    // marca a cada 15°
    final tick = Paint()
      ..color = Palette.muted
      ..strokeWidth = 1.5;
    for (var d = -45; d <= 45; d += 15) {
      final t = (-90 + d) * math.pi / 180;
      final o = Offset(math.cos(t), math.sin(t));
      canvas.drawLine(center + o * (r - 10), center + o * (r + 4), tick);
    }

    // ponteiro no arco
    final shown = (angleDeg * screenSign).clamp(-45.0, 45.0);
    final pt = (-90 + shown) * math.pi / 180;
    final po = Offset(math.cos(pt), math.sin(pt));
    canvas.drawLine(
      center + po * (r * 0.62),
      center + po * (r + 6),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // horizonte fixo
    canvas.drawLine(
      Offset(center.dx - r, center.dy),
      Offset(center.dx + r, center.dy),
      Paint()
        ..color = Palette.line
        ..strokeWidth = 2,
    );

    // carro girado em torno do ponto de apoio
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(shown * math.pi / 180);
    final body = Paint()..color = color;
    final dark = Paint()..color = Palette.bg;
    drawCar(canvas, r * 1.05, body, dark);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarPainter old) => old.angleDeg != angleDeg || old.color != color;
}

/// Vista traseira (inclinação lateral). Tombar para a direita gira no sentido horário.
class _RearCarPainter extends _CarPainter {
  _RearCarPainter(super.angleDeg, super.color, super.warn, super.danger);

  @override
  double get screenSign => 1;

  @override
  void drawCar(Canvas canvas, double w, Paint body, Paint dark) {
    final h = w * 0.62;
    final wheelW = w * 0.16;
    final wheelH = w * 0.22;
    // rodas
    final wheel = Paint()..color = Palette.muted;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w / 2, -wheelH, wheelW, wheelH), Radius.circular(wheelW * 0.3)),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w / 2 - wheelW, -wheelH, wheelW, wheelH), Radius.circular(wheelW * 0.3)),
      wheel,
    );
    // carroceria
    final bodyTop = -h;
    final bodyRect = Rect.fromLTRB(-w * 0.47, -h * 0.62, w * 0.47, -wheelH * 0.45);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.04)), body);
    // cabine
    final cabin = Path()
      ..moveTo(-w * 0.40, -h * 0.62)
      ..lineTo(-w * 0.33, bodyTop)
      ..lineTo(w * 0.33, bodyTop)
      ..lineTo(w * 0.40, -h * 0.62)
      ..close();
    canvas.drawPath(cabin, body);
    // vidro traseiro
    final glass = Path()
      ..moveTo(-w * 0.33, -h * 0.66)
      ..lineTo(-w * 0.29, bodyTop + h * 0.07)
      ..lineTo(w * 0.29, bodyTop + h * 0.07)
      ..lineTo(w * 0.33, -h * 0.66)
      ..close();
    canvas.drawPath(glass, dark);
    // estepe na tampa, típico do Pajero
    canvas.drawCircle(Offset(0, -h * 0.36), w * 0.12, dark);
    canvas.drawCircle(Offset(0, -h * 0.36), w * 0.07, body);
  }
}

/// Vista lateral (inclinação longitudinal), frente para a direita. Subida gira no anti-horário.
class _SideCarPainter extends _CarPainter {
  _SideCarPainter(super.angleDeg, super.color, super.warn, super.danger);

  @override
  double get screenSign => -1;

  @override
  void drawCar(Canvas canvas, double w, Paint body, Paint dark) {
    final h = w * 0.42;
    final wr = w * 0.12;
    // carroceria
    final bodyRect = Rect.fromLTRB(-w / 2, -h * 0.62, w / 2, -wr * 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.03)), body);
    // cabine, com o capô à direita (frente)
    final cabin = Path()
      ..moveTo(-w * 0.48, -h * 0.62)
      ..lineTo(-w * 0.46, -h)
      ..lineTo(w * 0.12, -h)
      ..lineTo(w * 0.24, -h * 0.62)
      ..close();
    canvas.drawPath(cabin, body);
    // janelas
    final win = Path()
      ..moveTo(-w * 0.42, -h * 0.66)
      ..lineTo(-w * 0.41, -h * 0.93)
      ..lineTo(w * 0.10, -h * 0.93)
      ..lineTo(w * 0.19, -h * 0.66)
      ..close();
    canvas.drawPath(win, dark);
    canvas.drawRect(Rect.fromLTRB(-w * 0.13, -h * 0.95, -w * 0.10, -h * 0.64), body);
    // estepe na traseira
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(-w * 0.56, -h * 0.58, -w * 0.5, -h * 0.18), Radius.circular(w * 0.02)),
      body,
    );
    // rodas
    final wheel = Paint()..color = Palette.muted;
    for (final x in [-w * 0.3, w * 0.3]) {
      canvas.drawCircle(Offset(x, -wr), wr, dark);
      canvas.drawCircle(Offset(x, -wr), wr * 0.88, wheel);
      canvas.drawCircle(Offset(x, -wr), wr * 0.4, dark);
    }
  }
}
