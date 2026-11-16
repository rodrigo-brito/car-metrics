import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/vehicle_controller.dart';
import '../../config.dart';
import '../../data/vehicle_data.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/gauge.dart';
import '../widgets/tile.dart';

/// Página 1, dirigir: velocímetro com arco de rpm, consumo instantâneo e médio,
/// temperatura do motor, bateria, carga e borboleta, rodapé da viagem.
class DrivePage extends StatelessWidget {
  const DrivePage({super.key, required this.controller});
  final VehicleController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.data;
    final t = controller.trip;
    final moving = (d.speedKmh ?? 0) > 2;

    // consumo: km/l em movimento, l/h parado
    final ValueTile consumo;
    if (moving) {
      final kml = d.kmPerL;
      final c = kml == null
          ? Palette.muted
          : kml >= 12
              ? Palette.ok
              : kml >= 8
                  ? Palette.warn
                  : Palette.bad;
      consumo = ValueTile(label: 'consumo', value: fmt(kml, (kml ?? 0) >= 10 ? 0 : 1), unit: 'km/l', accent: c);
    } else {
      consumo = ValueTile(
        label: 'consumo',
        value: fmt(d.fuelLph, 1),
        unit: 'l/h',
        accent: d.fuelLph == null ? Palette.muted : Palette.accent,
      );
    }
    final avg = t.avgKmPerL;
    final media = ValueTile(
      label: 'média',
      value: fmt(avg, (avg ?? 0) >= 10 ? 0 : 1),
      unit: 'km/l',
      accent: avg == null
          ? Palette.muted
          : avg >= 10
              ? Palette.ok
              : avg >= 7
                  ? Palette.warn
                  : Palette.bad,
    );
    final tc = d.coolantC;
    final motor = ValueTile(
      label: 'motor',
      value: fmt(tc, 0),
      unit: '°C',
      accent: tc == null
          ? Palette.muted
          : tc > alertCoolantC
              ? Palette.bad
              : tc < 70
                  ? Palette.accent
                  : Palette.ok,
      barPct: tc == null ? null : (tc - 40) / 90 * 100,
    );
    final v = d.batteryV;
    final bateria = ValueTile(
      label: 'bateria',
      value: fmt(v, 1),
      unit: 'V',
      accent: v == null
          ? Palette.muted
          : (v < alertBatteryV || v > 15.0)
              ? Palette.bad
              : v < 13.2
                  ? Palette.warn
                  : Palette.ok,
    );

    final details = <Widget>[
      Row(children: [Expanded(child: consumo), const SizedBox(width: 8), Expanded(child: media)]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: motor), const SizedBox(width: 8), Expanded(child: bateria)]),
      const SizedBox(height: 8),
      LoadCard(loadPct: d.loadPct, throttlePct: d.throttlePct),
      const SizedBox(height: 12),
      const Divider(color: Palette.line, height: 1),
      const SizedBox(height: 8),
      _TripFooter(fuelLph: d.fuelLph, trip: controller.trip),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth > box.maxHeight) {
          // horizontal, sem rolagem: velocímetro na altura toda à esquerda; à direita os
          // cards dividem a altura que sobra depois de carga/borboleta e do rodapé
          final gaugeSize = min(box.maxHeight - 12, box.maxWidth * 0.42);
          Widget pair(Widget a, Widget b) => Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)],
                ),
              );
          return Row(
            children: [
              SizedBox(
                width: gaugeSize + 16,
                child: Center(child: SpeedGauge(speedKmh: d.speedKmh, rpm: d.rpm, size: gaugeSize)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                  child: Column(
                    children: [
                      pair(consumo.withHeight(null), media.withHeight(null)),
                      const SizedBox(height: 6),
                      pair(motor.withHeight(null), bateria.withHeight(null)),
                      const SizedBox(height: 6),
                      LoadCard(loadPct: d.loadPct, throttlePct: d.throttlePct),
                      const SizedBox(height: 6),
                      _TripFooter(fuelLph: d.fuelLph, trip: controller.trip),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        final gaugeSize = min(box.maxWidth - 48, 300.0);
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            Center(child: SpeedGauge(speedKmh: d.speedKmh, rpm: d.rpm, size: gaugeSize)),
            const SizedBox(height: 12),
            ...details,
          ],
        );
      },
    );
  }
}

class _TripFooter extends StatelessWidget {
  const _TripFooter({required this.fuelLph, required this.trip});
  final double? fuelLph;
  final TripData trip;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('dist', '${fmt(trip.distanceKm, 1)} km'),
      ('comb.', '${fmt(trip.fuelL, 2)} L'),
      ('l/h', fmt(fuelLph, 1)),
      ('máx', '${fmt(trip.maxSpeed, 0)} km/h'),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.$1, style: const TextStyle(color: Palette.muted, fontSize: 11)),
                Text(it.$2, style: const TextStyle(color: Palette.txt, fontSize: 15)),
              ],
            ),
          ),
      ],
    );
  }
}
