import 'package:flutter_test/flutter_test.dart';
import 'package:painel_tr4/app/vehicle_controller.dart';
import 'package:painel_tr4/data/vehicle_data.dart';
import 'package:painel_tr4/obd/mock_source.dart';

void main() {
  test('mock gera leituras plausíveis e a luz de injeção aos 45 s', () async {
    var now = 0;
    final m = MockSource(clock: () => now, seed: 7);
    expect(await m.begin(), isTrue);
    expect(m.state, ObdState.mock);
    final d = VehicleData();
    for (var i = 0; i < 100; i++) {
      now += 100;
      await m.update(d);
    }
    expect(d.rpm, inInclusiveRange(700, 6500));
    expect(d.speedKmh, inInclusiveRange(0, 130));
    expect(d.coolantC, inInclusiveRange(32, 91));
    expect(d.batteryV, inInclusiveRange(13.5, 14.5));
    expect(d.mafGs, greaterThan(0));
    expect(d.vin, '9BROBD2MOCK000001');
    expect(d.milOn, isFalse);

    while (now < 50000) {
      now += 100;
      await m.update(d);
    }
    expect(d.milOn, isTrue);
    expect(d.dtcCount, 1);
    await m.requestDtcs(d);
    expect(d.dtcs, ['P0171']);
    expect(await m.clearDtcs(d), isTrue);
    expect(d.milOn, isFalse);
    expect(d.dtcs, isEmpty);
    while (now < 60000) {
      now += 100;
      await m.update(d);
    }
    expect(d.milOn, isFalse, reason: 'depois de apagar não acende de novo');
  });

  test('mock ignora passos menores que 50 ms', () async {
    var now = 0;
    final m = MockSource(clock: () => now, seed: 1);
    await m.begin();
    final d = VehicleData();
    now = 20;
    await m.update(d);
    expect(d.rpm, isNull);
    now = 60;
    await m.update(d);
    expect(d.rpm, isNotNull);
  });

  test('controlador integra a viagem, mantém o histórico da sonda e dispara o alerta de injeção', () async {
    var now = 1000;
    final c = VehicleController(clock: () => now);
    final m = MockSource(clock: () => now, seed: 3);
    expect(await c.start(m, runLoop: false), isTrue);
    expect(c.running, isFalse);
    expect(c.state, ObdState.mock);

    var notified = 0;
    c.addListener(() => notified++);
    while (now < 47000) {
      now += 100;
      await c.tick();
    }
    expect(notified, greaterThan(100));
    expect(c.trip.fuelL, greaterThan(0));
    expect(c.trip.startMs, 1000);
    expect(c.tripElapsedMs, 46000);
    expect(c.o2History.where((v) => v != 0.45).length, greaterThan(10));
    expect(c.alert?.title, 'LUZ DE INJEÇÃO');
    expect(c.alert?.value, '1 falha');
    expect(c.data.milOn, isTrue);

    c.dismissAlert();
    expect(c.alert, isNull);
    now += 100;
    await c.tick();
    expect(c.alert, isNull, reason: 'cada condição dispara uma vez');

    c.goToPage(2);
    await Future<void>.delayed(Duration.zero);
    expect(c.data.dtcsRead, isTrue);
    expect(c.data.dtcs, ['P0171']);
    expect(await c.clearDtcs(), isTrue);
    expect(c.data.dtcs, isEmpty);

    await c.stop();
    expect(c.source, isNull);
    expect(c.state, ObdState.idle);
    c.dispose();
  });
}
