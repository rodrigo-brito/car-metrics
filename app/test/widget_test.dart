import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:painel_tr4/app/vehicle_controller.dart';
import 'package:painel_tr4/main.dart';
import 'package:painel_tr4/ui/pages/dashboard_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('tela de conexão oferece varredura, simulação e inclinômetro', (tester) async {
    await tester.pumpWidget(const PainelApp(autoScan: false));
    await tester.pump();
    expect(find.text('Procurar'), findsOneWidget);
    expect(find.text('Simulação'), findsOneWidget);
    expect(find.text('Inclinômetro (sem OBD)'), findsOneWidget);
    expect(find.text('DISPOSITIVOS BLUETOOTH'), findsOneWidget);
    expect(find.textContaining('computador'), findsOneWidget);
    expect(find.text('padrão'), findsNothing);
  });

  testWidgets('dispositivo padrão salvo aparece no topo', (tester) async {
    SharedPreferences.setMockInitialValues({'obd_device_id': 'AA:BB:CC:DD:EE:FF', 'obd_device_name': 'OBDII'});
    await tester.pumpWidget(const PainelApp(autoScan: false));
    await tester.pumpAndSettle();
    expect(find.text('padrão'), findsOneWidget);
    expect(find.text('OBDII'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
    await tester.tap(find.byTooltip('Esquecer padrão'));
    await tester.pumpAndSettle();
    expect(find.text('padrão'), findsNothing);
    final p = await SharedPreferences.getInstance();
    expect(p.getString('obd_device_id'), isNull);
  });

  testWidgets('tela de conexão em paisagem não estoura', (tester) async {
    tester.view.physicalSize = const Size(2340, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PainelApp(autoScan: false));
    await tester.pump();
    expect(find.text('Procurar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('as três páginas mostram as métricas do painel', (tester) async {
    // tela de celular em retrato, para o rodapé da viagem caber sem rolar
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = VehicleController(clock: () => 0);
    c.data
      ..rpm = 2500
      ..speedKmh = 72
      ..coolantC = 88
      ..batteryV = 14.1
      ..mapKpa = 45
      ..intakeC = 31
      ..loadPct = 40
      ..throttlePct = 22
      ..timingDeg = 18
      ..stftPct = 2.5
      ..ltftPct = -3
      ..o2s1V = 0.52
      ..o2s2V = 0.65
      ..fuelSystem = 2
      ..fuelLph = 6
      ..kmPerL = 12
      ..milOn = true
      ..dtcCount = 1
      ..dtcs = ['P0171']
      ..dtcsRead = true
      ..vin = '9BRTR4MOCK0000001'
      ..obdStd = 'OBD-II (CARB)';
    c.trip.distanceKm = 12.3;
    c.trip.fuelL = 1.1;

    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));

    // dirigir
    expect(find.text('DIRIGIR'), findsWidgets);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('2500 rpm'), findsOneWidget);
    expect(find.text('consumo'), findsOneWidget);
    expect(find.text('média'), findsOneWidget);
    expect(find.text('motor'), findsOneWidget);
    expect(find.text('bateria'), findsOneWidget);
    expect(find.text('INJEÇÃO'), findsOneWidget);
    expect(find.text('12.3 km'), findsOneWidget);

    // motor
    await tester.tap(find.text('MOTOR'));
    await tester.pumpAndSettle();
    expect(find.text('trim curto'), findsOneWidget);
    expect(find.text('trim longo'), findsOneWidget);
    expect(find.text('+2.5%'), findsOneWidget);
    expect(find.text('-3.0%'), findsOneWidget);
    expect(find.text('malha fechada'), findsOneWidget);
    expect(find.text('45 kPa'), findsOneWidget);
    expect(find.text('sonda 1'), findsOneWidget);

    // diagnóstico
    await tester.tap(find.text('DIAGNÓSTICO'));
    await tester.pumpAndSettle();
    expect(find.text('ACESA'), findsOneWidget);
    expect(find.text('P0171'), findsOneWidget);
    expect(find.text('9BRTR4MOCK0000001'), findsOneWidget);
    expect(find.text('OBD-II (CARB)'), findsOneWidget);
    expect(find.text('Apagar falhas'), findsOneWidget);
    expect(find.text('Reler códigos'), findsOneWidget);
    c.dispose();
  });

  for (final size in const [Size(1920, 1080), Size(2400, 1080)]) {
    testWidgets('painel em paisagem ${size.width.toInt()}x${size.height.toInt()} cabe sem rolar', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final c = VehicleController(clock: () => 0);
      c.data
        ..rpm = 2500
        ..speedKmh = 72
        ..stftPct = 2.5
        ..milOn = true
        ..dtcCount = 2
        ..dtcs = ['P0171', 'P0300']
        ..dtcsRead = true;
      await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));
      final e0 = tester.takeException();
      if (e0 != null) fail('DIRIGIR: $e0');
      expect(find.text('72'), findsOneWidget);
      expect(find.text('consumo'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      for (final tab in ['MOTOR', 'DIAGNÓSTICO']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsNothing, reason: tab);
        final e = tester.takeException();
        if (e != null) fail('$tab: $e');
      }
      expect(find.text('Apagar falhas'), findsOneWidget);
      expect(find.text('P0300'), findsOneWidget);
      await tester.tap(find.text('MOTOR'));
      await tester.pumpAndSettle();
      expect(find.text('trim curto'), findsOneWidget);
      expect(find.text('sonda 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }

  testWidgets('girar a tela mantém a aba atual', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = VehicleController(clock: () => 0);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));
    await tester.tap(find.text('MOTOR'));
    await tester.pumpAndSettle();
    expect(find.text('trim curto'), findsOneWidget);
    tester.view.physicalSize = const Size(1080, 2400);
    await tester.pumpAndSettle();
    expect(find.text('trim curto'), findsOneWidget);
    expect(find.text('consumo'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('painel sem leituras mostra "--" e não quebra', (tester) async {
    final c = VehicleController(clock: () => 0);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: c)));
    expect(find.text('--'), findsWidgets);
    expect(find.text('INJEÇÃO'), findsNothing);
    expect(find.text('00:00:00'), findsOneWidget);
    c.dispose();
  });
}
