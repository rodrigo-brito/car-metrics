import 'package:flutter_test/flutter_test.dart';
import 'package:painel_tr4/data/vehicle_data.dart';
import 'package:painel_tr4/obd/elm_source.dart';

import 'fake_link.dart';

void main() {
  group('parsers', () {
    test('parse acha os bytes do PID com ou sem espaços', () {
      expect(ElmSource.parse('410C1AF8', 0x0C), [0x1A, 0xF8]);
      expect(ElmSource.parse('41 0C 1A F8\r', 0x0C), [0x1A, 0xF8]);
      expect(ElmSource.parse('SEARCHING...\r410D3C', 0x0D), [0x3C]);
      expect(ElmSource.parse('NO DATA', 0x0C), isNull);
      expect(ElmSource.parse('410D3C', 0x0C), isNull);
      expect(ElmSource.parse('4100BE3EB811', 0x00, max: 4), [0xBE, 0x3E, 0xB8, 0x11]);
    });

    test('decodeDtc monta a letra e o primeiro algarismo', () {
      expect(ElmSource.decodeDtc('0171'), 'P0171');
      expect(ElmSource.decodeDtc('1234'), 'P1234');
      expect(ElmSource.decodeDtc('4123'), 'C0123');
      expect(ElmSource.decodeDtc('8ABC'), 'B0ABC');
      expect(ElmSource.decodeDtc('C000'), 'U0000');
      expect(ElmSource.decodeDtc('12'), '');
    });

    test('parseDtcs pula o byte de contagem só em CAN', () {
      expect(ElmSource.parseDtcs('430101710000', 'A6'), ['P0171']);
      expect(ElmSource.parseDtcs('43 02 01 71 03 00', '6'), ['P0171', 'P0300']);
      expect(ElmSource.parseDtcs('430171', '3'), ['P0171']);
      expect(ElmSource.parseDtcs('4300', 'A6'), isEmpty);
      expect(ElmSource.parseDtcs('NO DATA', 'A6'), isEmpty);
    });

    test('parseVin junta o multi-quadro CAN', () {
      expect(ElmSource.parseVin('014\r0:490201394252\r1:5452344D4F434B\r2:30303030303031'), '9BRTR4MOCK0000001');
      expect(ElmSource.parseVin('014\r0: 49 02 01 39 42 52\r1: 54 52 34 4D 4F 43 4B\r2: 30 30 30 30 30 30 31'),
          '9BRTR4MOCK0000001');
      expect(ElmSource.parseVin('NO DATA'), isNull);
      expect(ElmSource.parseVin('4902013942'), isNull);
    });

    test('parseVoltage', () {
      expect(ElmSource.parseVoltage('14.2V'), 14.2);
      expect(ElmSource.parseVoltage('12.0'), 12.0);
      expect(ElmSource.parseVoltage('?'), isNull);
      expect(ElmSource.parseVoltage('0.0V'), isNull);
    });
  });

  group('ElmSource', () {
    test('inicializa o adaptador, lê a máscara de PIDs e o protocolo', () async {
      final link = FakeLink(tr4Responses);
      var now = 100000;
      final src = ElmSource(link, clock: () => now);
      expect(await src.begin(), isTrue);
      expect(src.state, ObdState.connected);
      expect(src.protocol, 'A6');
      expect(link.sent.take(7), ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0', 'ATAT1']);
      expect(link.sent, containsAllInOrder(['0100', '0120', 'ATDPN']));
      expect(link.sent, isNot(contains('0140')));
      expect(src.has(0x0C), isTrue);
      expect(src.has(0x0B), isTrue);
      expect(src.has(0x10), isFalse);
      expect(src.has(0x2F), isFalse);
      expect(src.has(0x21), isTrue);
      expect(src.supportedList, '01 03 04 05 06 07 0B 0C 0D 0E 0F 11 13 14 15 1C 20 21');
    });

    test('lê rápidos e lentos em rodízio, VIN e norma', () async {
      final link = FakeLink(tr4Responses);
      var now = 100000;
      final src = ElmSource(link, clock: () => now);
      expect(await src.begin(), isTrue);
      final d = VehicleData();
      for (var i = 0; i < 100; i++) {
        now += 200;
        await src.update(d);
      }
      expect(d.vin, '9BRTR4MOCK0000001');
      expect(d.obdStd, 'OBD-II (CARB)');
      expect(d.rpm, 1726);
      expect(d.speedKmh, 60);
      expect(d.mapKpa, 100);
      expect(d.mafGs, isNull);
      expect(d.coolantC, 90);
      expect(d.batteryV, 14.2);
      expect(d.milOn, isTrue);
      expect(d.dtcCount, 1);
      expect(d.intakeC, 30);
      expect(d.loadPct, closeTo(50.2, 0.1));
      expect(d.throttlePct, closeTo(20, 0.1));
      expect(d.stftPct, closeTo(7.8, 0.1));
      expect(d.ltftPct, 0);
      expect(d.timingDeg, 8);
      expect(d.o2s1V, closeTo(0.45, 0.001));
      expect(d.o2s2V, closeTo(0.61, 0.001));
      expect(d.fuelSystem, 2);
      expect(d.distMilKm, 0);
      expect(src.signalDbm, -60);
      // nunca pediu o que a ECU não declarou
      expect(link.sent, isNot(contains('0110')));
      expect(link.sent, isNot(contains('012F')));
    });

    test('respeita o ciclo mínimo dos rápidos', () async {
      final link = FakeLink(tr4Responses);
      var now = 100000;
      final src = ElmSource(link, clock: () => now, slowMs: 1000000);
      await src.begin();
      final d = VehicleData();
      await src.update(d); // estáticos
      link.sent.clear();
      for (var i = 0; i < 10; i++) {
        now += 10; // 100 ms no total: cabe só uma rodada de três PIDs
        await src.update(d);
      }
      expect(link.sent, ['010C', '010D', '010B']);
    });

    test('ECU dormindo: fica em "sem ECU" e conecta quando ela acorda', () async {
      final map = Map<String, String>.of(tr4Responses)..['0100'] = 'UNABLE TO CONNECT';
      final link = FakeLink(map);
      var now = 100000;
      final src = ElmSource(link, clock: () => now);
      expect(await src.begin(), isTrue);
      expect(src.state, ObdState.waitingEcu);
      expect(src.lastError, contains('ECU'));
      final d = VehicleData();
      await src.update(d);
      expect(src.state, ObdState.waitingEcu);
      map['0100'] = tr4Responses['0100']!;
      now += 6000;
      await src.update(d);
      expect(src.state, ObdState.connected);
      expect(src.lastError, isEmpty);
    });

    test('link que não conecta vira erro com mensagem', () async {
      final link = FakeLink(tr4Responses)..failConnect = true;
      final src = ElmSource(link);
      expect(await src.begin(), isFalse);
      expect(src.state, ObdState.error);
      expect(src.lastError, 'adaptador BLE não encontrado');
    });

    test('adaptador que não responde aos AT vira erro', () async {
      final link = FakeLink({'ATZ': '?'}, defaultAt: '?');
      final src = ElmSource(link);
      expect(await src.begin(), isFalse);
      expect(src.state, ObdState.error);
      expect(src.lastError, contains('AT'));
    });

    test('queda do link durante a leitura vira erro', () async {
      final link = FakeLink(tr4Responses);
      final src = ElmSource(link);
      await src.begin();
      link.connected = false;
      await src.update(VehicleData());
      expect(src.state, ObdState.error);
      expect(src.lastError, 'conexão caiu');
    });

    test('comandos são serializados: um por vez, na ordem', () async {
      final link = FakeLink(tr4Responses);
      final src = ElmSource(link);
      await src.begin();
      link.sent.clear();
      final f1 = src.cmd('010C');
      final f2 = src.cmd('010D');
      final f3 = src.cmd('ATRV');
      expect(await f1, '410C1AF8');
      expect(await f2, '410D3C');
      expect(await f3, '14.2V');
      expect(link.sent, ['010C', '010D', 'ATRV']);
    });

    test('modo 03 lê os códigos e modo 04 apaga', () async {
      final link = FakeLink(tr4Responses);
      final src = ElmSource(link);
      await src.begin();
      final d = VehicleData()
        ..milOn = true
        ..dtcCount = 1;
      await src.requestDtcs(d);
      expect(d.dtcsRead, isTrue);
      expect(d.dtcs, ['P0171']);
      expect(await src.clearDtcs(d), isTrue);
      expect(d.dtcs, isEmpty);
      expect(d.milOn, isFalse);
      expect(d.dtcCount, 0);
    });
  });
}
