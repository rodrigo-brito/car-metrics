import 'package:flutter/material.dart';

import '../../app/vehicle_controller.dart';
import '../../data/vehicle_data.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/bars.dart';
import '../widgets/o2_sparkline.dart';
import '../widgets/two_column.dart';

/// Página 2, motor: carga e borboleta, MAP, admissão, avanço, malha, trims e sondas lambda.
class EnginePage extends StatelessWidget {
  const EnginePage({super.key, required this.controller});
  final VehicleController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.data;
    final o2s2 = d.o2s2V;
    return TwoColumnList(
      left: [
        BarRow(label: 'carga', pct: d.loadPct, color: Palette.accent, text: '${fmt(d.loadPct, 0)}%'),
        BarRow(label: 'borboleta', pct: d.throttlePct, color: Palette.ok, text: '${fmt(d.throttlePct, 0)}%'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: KeyValue('MAP', '${fmt(d.mapKpa, 0)} kPa')),
            Expanded(child: KeyValue('admissão', '${fmt(d.intakeC, 0)} °C')),
          ],
        ),
        Row(
          children: [
            Expanded(child: KeyValue('avanço', '${fmt(d.timingDeg, 0)}°')),
            Expanded(
              child: KeyValue(
                'malha',
                fuelSystemName(d.fuelSystem),
                color: d.fuelSystem == 2
                    ? Palette.ok
                    : d.fuelSystem >= 8
                        ? Palette.bad
                        : Palette.warn,
              ),
            ),
          ],
        ),
      ],
      right: [
        const Divider(color: Palette.line),
        Row(
          children: [
            Expanded(child: KeyValue('sonda 1', '${fmt(d.o2s1V, 2)} V')),
            Expanded(
              child: KeyValue(
                'sonda 2',
                '${fmt(o2s2, 2)} V',
                color: o2s2 == null
                    ? Palette.muted
                    : (o2s2 > 0.3 && o2s2 < 0.8)
                        ? Palette.ok
                        : Palette.warn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        O2Sparkline(history: controller.o2History, index: controller.o2Index),
        const Divider(color: Palette.line),
        TrimRow(label: 'trim curto', pct: d.stftPct),
        TrimRow(label: 'trim longo', pct: d.ltftPct),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Num flex, o trim longo andando para o positivo depois de abastecer indica etanol no tanque.',
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
