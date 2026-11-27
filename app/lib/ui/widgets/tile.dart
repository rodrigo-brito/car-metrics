import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import 'bars.dart';

/// Card de valor da página "dirigir": filete colorido à esquerda, rótulo, valor + unidade
/// e barra opcional embaixo.
class ValueTile extends StatelessWidget {
  const ValueTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    this.barPct,
    this.height = 88,
  });

  /// null = ocupa a altura que o pai der (layout em paisagem).

  final String label;
  final String value;
  final String unit;
  final Color accent;
  final double? barPct;

  /// Cópia com outra altura (null = a do pai).
  ValueTile withHeight(double? h) => ValueTile(
        label: label,
        value: value,
        unit: unit,
        accent: accent,
        barPct: barPct,
        height: h,
      );
  final double? height;

  @override
  Widget build(BuildContext context) {
    // com altura livre (paisagem) o número cresce com o card, para aproveitar a tela
    if (height == null) {
      return LayoutBuilder(
        builder: (context, box) => _card(box.hasBoundedHeight ? box.maxHeight : 88),
      );
    }
    return _card(height!);
  }

  Widget _card(double h) {
    final big = (h * 0.4).clamp(26.0, 72.0);
    final small = (h * 0.15).clamp(13.0, 20.0);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Palette.muted, fontSize: small),
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            color: Palette.txt,
                            fontSize: big,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        SizedBox(width: small * 0.3),
                        Text(
                          unit,
                          style: TextStyle(
                            color: Palette.muted,
                            fontSize: small,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (barPct != null) ...[
                    const SizedBox(height: 6),
                    HBar(
                      pct: barPct,
                      color: accent,
                      height: (h * 0.05).clamp(5.0, 8.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card largo com carga e borboleta, cada um com rótulo, valor e barra na largura toda.
class LoadCard extends StatelessWidget {
  const LoadCard({super.key, required this.loadPct, required this.throttlePct});
  final double? loadPct;
  final double? throttlePct;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: Palette.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  children: [
                    _row('carga', loadPct, Palette.accent),
                    const SizedBox(height: 8),
                    _row('borboleta', throttlePct, Palette.ok),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double? p, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Palette.muted, fontSize: 13),
            ),
            Text(
              '${fmt(p, 0)}%',
              style: const TextStyle(color: Palette.txt, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        HBar(pct: p, color: color),
      ],
    );
  }
}
