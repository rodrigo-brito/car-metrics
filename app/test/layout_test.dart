import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:painel_tr4/app/vehicle_controller.dart';
import 'package:painel_tr4/ui/pages/dashboard_screen.dart';

/// Janelas que o painel precisa aguentar sem estourar e sem rolagem: celular nas duas
/// orientações, tablet inteiro e em tela dividida (metade, um terço, faixa baixa).
const _windows = <Size>[
  Size(360, 740),
  Size(740, 360),
  Size(427, 800),
  Size(640, 800),
  Size(800, 640),
  Size(800, 600),
  Size(520, 400),
  Size(1280, 800),
  Size(800, 1280),
  Size(1280, 400),
];

VehicleController _filled() {
  final c = VehicleController(clock: () => 0);
  c.data
    ..rpm = 6500
    ..speedKmh = 188
    ..coolantC = 104
    ..batteryV = 12.1
    ..mapKpa = 101
    ..intakeC = 45
    ..loadPct = 100
    ..throttlePct = 100
    ..timingDeg = -12
    ..stftPct = -24.5
    ..ltftPct = 24.5
    ..o2s1V = 0.52
    ..o2s2V = 0.65
    ..fuelSystem = 2
    ..fuelLph = 25.5
    ..kmPerL = 4.5
    ..milOn = true
    ..dtcCount = 3
    ..dtcs = ['P0171', 'P0300', 'P0420']
    ..dtcsRead = true
    ..vin = '9BRTR4MOCK0000001'
    ..obdStd = 'OBD-II (CARB)';
  c.trip.distanceKm = 1234.5;
  c.trip.fuelL = 111.12;
  c.trip.maxSpeed = 188;
  return c;
}

void main() {
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final w in _windows) {
      testWidgets('painel ${w.width.toInt()}x${w.height.toInt()} fonte ${scale}x: sem estouro nem rolagem',
          (tester) async {
        tester.view.physicalSize = w * 2;
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final c = _filled();
        addTearDown(c.dispose);
        await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));
        // dirigir, motor e diagnóstico (a inclinação usa sensores, que não há no teste)
        for (var p = 0; p < 3; p++) {
          if (p > 0) {
            await tester.tap(find.text(DashboardScreen.pageNames[p]).last);
            for (var i = 0; i < 10; i++) {
              await tester.pump(const Duration(milliseconds: 50));
            }
          }
          expect(tester.takeException(), isNull, reason: 'página $p');
          // nenhuma página do painel deve precisar rolar (o PageView é horizontal)
          final vertical = tester
              .widgetList<Scrollable>(find.byType(Scrollable))
              .where((s) => s.axisDirection == AxisDirection.down || s.axisDirection == AxisDirection.up);
          expect(vertical, isEmpty, reason: 'página $p rola');
        }
      });
    }
  }
}
