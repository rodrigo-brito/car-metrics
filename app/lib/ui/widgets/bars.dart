import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Barra horizontal 0..100 % sobre um trilho; null = só o trilho.
class HBar extends StatelessWidget {
  const HBar({super.key, required this.pct, required this.color, this.height = 5});
  final double? pct;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = pct;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Palette.line),
            if (p != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: clampD(p, 0, 100) / 100,
                  heightFactor: 1,
                  child: ColoredBox(color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Linha "rótulo | barra | valor" da página do motor.
class BarRow extends StatelessWidget {
  const BarRow({super.key, required this.label, required this.pct, required this.color, required this.text});
  final String label;
  final double? pct;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: Palette.muted, fontSize: 14))),
          Expanded(child: HBar(pct: pct, color: color, height: 8)),
          SizedBox(
            width: 72,
            child: Text(text, textAlign: TextAlign.end, style: const TextStyle(color: Palette.txt, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Barra centrada em zero, ±25 %, para os trims de combustível.
class TrimRow extends StatelessWidget {
  const TrimRow({super.key, required this.label, required this.pct});
  final String label;
  final double? pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: Palette.muted, fontSize: 14))),
          Expanded(
            child: SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (context, cons) {
                  final half = cons.maxWidth / 2;
                  final p = pct;
                  double wpx = 0;
                  double left = half;
                  var color = Palette.ok;
                  if (p != null) {
                    final v = clampD(p, -25, 25);
                    wpx = v.abs() / 25 * half;
                    left = v >= 0 ? half : half - wpx;
                    color = v.abs() < 8 ? Palette.ok : (v.abs() < 15 ? Palette.warn : Palette.bad);
                  }
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 3,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Palette.line, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      if (p != null)
                        Positioned(
                          left: left,
                          top: 3,
                          width: wpx,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                          ),
                        ),
                      Positioned(
                        left: half - 0.5,
                        top: 0,
                        width: 1,
                        height: 14,
                        child: const ColoredBox(color: Palette.muted),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              '${fmtSigned(pct, 1)}%',
              textAlign: TextAlign.end,
              style: const TextStyle(color: Palette.txt, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// "chave  valor" em linha, para a página do motor.
class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key, this.color = Palette.txt});
  final String k;
  final String v;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(k, style: const TextStyle(color: Palette.muted, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha "chave | valor" da página de diagnóstico.
class InfoLine extends StatelessWidget {
  const InfoLine(this.k, this.v, {super.key, this.color = Palette.txt});
  final String k;
  final String v;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 108, child: Text(k, style: const TextStyle(color: Palette.muted, fontSize: 14))),
          Expanded(child: Text(v, style: TextStyle(color: color, fontSize: 14))),
        ],
      ),
    );
  }
}
