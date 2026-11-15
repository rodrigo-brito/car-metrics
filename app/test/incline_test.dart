import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:painel_tr4/incline/incline_controller.dart';
import 'package:painel_tr4/incline/incline_math.dart';
import 'package:painel_tr4/ui/pages/incline_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const g = 9.81;
double rad(double d) => d * math.pi / 180;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CarFrame', () {
    // celular em pé, retrato, tela para o motorista: x = direita, y = cima, z = para trás
    final upright = CarFrame.fromGravity(const Vec3(0, g, 0));

    test('nivelado mede zero', () {
      final i = upright.measure(const Vec3(0, g, 0));
      expect(i.pitchDeg, closeTo(0, 1e-9));
      expect(i.rollDeg, closeTo(0, 1e-9));
    });

    test('subida de 20° dá longitudinal +20', () {
      // frente sobe: o "para cima" do mundo tomba para a frente do carro (-z do celular)
      final i = upright.measure(Vec3(0, g * math.cos(rad(20)), -g * math.sin(rad(20))));
      expect(i.pitchDeg, closeTo(20, 1e-6));
      expect(i.rollDeg, closeTo(0, 1e-6));
    });

    test('rodas da direita mais baixas dão lateral positiva', () {
      // carro tomba para a direita: o "para cima" do mundo vai para a esquerda do carro
      final i = upright.measure(Vec3(-g * math.sin(rad(18)), g * math.cos(rad(18)), 0));
      expect(i.rollDeg, closeTo(18, 1e-6));
      expect(i.pitchDeg, closeTo(0, 1e-6));
    });

    test('suporte inclinado para trás, calibrado, mede a partir do zero', () {
      // celular reclinado 25° no suporte
      final mount = Vec3(0, g * math.cos(rad(25)), g * math.sin(rad(25)));
      final f = CarFrame.fromGravity(mount);
      expect(f.measure(mount).pitchDeg, closeTo(0, 1e-9));
      // carro tomba 10° para a esquerda: o "cima" do mundo vai para a direita do carro (+x)
      final up = f.up * math.cos(rad(10)) + f.right * math.sin(rad(10));
      final i = f.measure(up * g);
      expect(i.rollDeg, closeTo(-10, 1e-6));
      expect(i.pitchDeg, closeTo(0, 1e-6));
    });

    test('paisagem com o topo para a esquerda: direita da tela é -y', () {
      final f = CarFrame.fromGravity(const Vec3(g, 0, 0));
      expect(f.right.y, closeTo(-1, 1e-9));
      expect(f.forward.z, closeTo(-1, 1e-9));
    });

    test('deitado no console com o topo para a frente', () {
      final f = CarFrame.fromGravity(const Vec3(0, 0, g));
      expect(f.forward.y, closeTo(1, 1e-9));
      expect(f.right.x, closeTo(1, 1e-9));
    });

    test('ida e volta pela lista salva', () {
      final f = CarFrame.fromList(upright.toList())!;
      expect(f.forward.z, upright.forward.z);
    });
  });

  test('girar a tela sem calibração não grava pico falso', () async {
    final ctrl = StreamController<Vec3>();
    final c = InclineController(source: ctrl.stream)..attach();
    await Future<void>.delayed(Duration.zero);
    for (var k = 0; k < 50; k++) {
      ctrl.add(const Vec3(0, g, 0));
    }
    // vira para paisagem de uma vez
    for (var k = 0; k < 50; k++) {
      ctrl.add(const Vec3(g, 0, 0));
    }
    await Future<void>.delayed(Duration.zero);
    expect(c.maxRollLeft, lessThan(1));
    expect(c.maxRollRight, lessThan(1));
    expect(c.now!.rollDeg.abs(), lessThan(1));
    c.detach();
    c.dispose();
    unawaited(ctrl.close());
  });

  test('faixas de alerta', () {
    expect(rollLevel(10), InclineLevel.ok);
    expect(rollLevel(-18), InclineLevel.warn);
    expect(rollLevel(27), InclineLevel.danger);
    expect(pitchLevel(25), InclineLevel.warn);
    expect(pitchLevel(-31), InclineLevel.danger);
  });

  testWidgets('página mostra inclinação, máximos e calibra', (tester) async {
    final ctrl = StreamController<Vec3>();
    final c = InclineController(source: ctrl.stream);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: InclinePage(controller: c))));
    await tester.pump();
    expect(find.text('LATERAL'), findsOneWidget);
    expect(find.text('LONGITUDINAL'), findsOneWidget);
    expect(find.textContaining('Sem calibração'), findsOneWidget);

    // 200 amostras de tombamento de 12° para a direita (o filtro converge)
    for (var k = 0; k < 200; k++) {
      ctrl.add(Vec3(-g * math.sin(rad(12)), g * math.cos(rad(12)), 0));
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('12°'), findsOneWidget);
    expect(find.text('para a direita'), findsOneWidget);

    await tester.tap(find.text('Zerar no plano'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Zerar'));
    await tester.pump(const Duration(seconds: 1));
    ctrl.add(Vec3(-g * math.sin(rad(12)), g * math.cos(rad(12)), 0));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Sem calibração'), findsNothing);
    expect(find.text('nivelado'), findsNWidgets(2));
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('incline_frame'), hasLength(9));

    await tester.pumpWidget(const SizedBox());
    c.dispose();
    unawaited(ctrl.close());
  });
}
