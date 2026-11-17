import 'dart:math';

import '../config.dart';
import '../data/vehicle_data.dart';
import 'obd_source.dart';

/// Simula um ciclo urbano/rodoviário com física simplificada, para
/// desenvolver a interface sem o carro. Porte do `obd_mock.h`.
class MockSource extends ObdSource {
  MockSource({int Function()? clock, int? seed})
      : _clock = clock,
        _rnd = Random(seed);

  /// Relógio em ms, injetável para testes. Sem ele, conta a partir de [begin].
  final int Function()? _clock;
  final Random _rnd;
  final Stopwatch _sw = Stopwatch();

  ObdState _state = ObdState.idle;
  int _last = 0;
  int _nextChange = 0;
  double _speed = 0;
  double _target = 0;
  double _coolant = 32;
  double _intake = 28;
  double _fuel = 62;
  bool _milCleared = false;

  int get _now => _clock?.call() ?? _sw.elapsedMilliseconds;

  /// Inteiro em [lo, hi), como o `random(min, max)` do Arduino.
  int _rand(int lo, int hi) => lo + _rnd.nextInt(hi - lo);

  @override
  Future<bool> begin() async {
    _sw.start();
    _last = _now;
    _state = ObdState.mock;
    _pickTarget();
    onStateChanged?.call();
    return true;
  }

  @override
  ObdState get state => _state;
  @override
  String get name => 'Mock';
  @override
  String get protocol => 'simulação';
  @override
  int get signalDbm => -55;

  @override
  Future<void> update(VehicleData d) async {
    final now = _now;
    final dt = (now - _last) / 1000.0;
    if (dt < 0.05) return;
    _last = now;

    // alvo de velocidade muda a cada "trecho"
    if (now > _nextChange) _pickTarget();

    // aproxima da velocidade alvo com aceleração limitada
    final diff = _target - _speed;
    final double accel = (diff * 0.6).clamp(-4.5, 2.5).toDouble(); // m/s²
    _speed += accel * 3.6 * dt;
    if (_speed < 0) _speed = 0;
    _speed += (_rand(-10, 11) / 10.0) * dt; // tremidinha

    // marcha e rpm
    const ratios = [0.0, 120.0, 70.0, 48.0, 36.0, 29.0, 24.0]; // rpm por km/h
    var gear = 1;
    if (_speed > 95) {
      gear = 6;
    } else if (_speed > 70) {
      gear = 5;
    } else if (_speed > 50) {
      gear = 4;
    } else if (_speed > 30) {
      gear = 3;
    } else if (_speed > 12) {
      gear = 2;
    }
    var rpm = _speed < 2 ? 850.0 + _rand(-30, 30) : _speed * ratios[gear] + _rand(-40, 40);
    if (accel > 0.5) rpm += accel * 600;
    rpm = rpm.clamp(700.0, 6500.0).toDouble();

    // carga e MAF (motor 1.6L, VE variável)
    final double load =
        _speed < 2 ? 0.18 : (0.2 + accel * 0.2 + _speed / 250.0).clamp(0.15, 0.95).toDouble();
    final maf = rpm / 60.0 * 0.8 * 1.2 * load * 0.7; // g/s (1.6L, 4 tempos, VE ~70%)

    // temperaturas: motor esquenta até ~90 °C
    _coolant += (90.0 - _coolant) * 0.004 * dt * 10;
    _intake = 28 + (_speed > 40 ? -2 : 3) + _rand(-10, 10) / 10.0;

    // combustível cai devagar, tensão oscila
    _fuel -= maf / (fuelAfr * fuelDensity) * dt / 50.0 * 100;
    if (_fuel < 5) _fuel = 62;
    final batt = 14.1 + _rand(-8, 8) / 100.0 - (accel > 1.5 ? 0.2 : 0.0);

    d.rpm = rpm;
    d.speedKmh = _speed;
    d.coolantC = _coolant;
    d.intakeC = _intake;
    d.mafGs = maf;
    d.loadPct = load * 100;
    d.throttlePct = (load * 100 + 5).clamp(0.0, 100.0).toDouble();
    d.fuelPct = null;
    d.batteryV = batt;
    d.mapKpa = 30 + load * 70;
    // dados de motor
    d.timingDeg = 8 + load * 20 + (rpm - 800) / 400.0;
    d.stftPct = 2.0 * sin(now / 1500.0) + _rand(-10, 10) / 10.0;
    d.ltftPct = 3.5 + _rand(-3, 3) / 10.0;
    d.o2s1V = 0.45 + 0.4 * sin(now / 350.0);
    d.o2s2V = 0.62 + _rand(-2, 2) / 100.0;
    d.fuelSystem = _coolant < 60 ? 1 : (accel > 1.8 ? 4 : 2);
    d.obdStd = 'OBD-II (CARB)';
    d.vin = '9BROBD2MOCK000001';
    // após 45 s acende a luz de injeção para exercitar alerta e página de diagnóstico
    final mil = now > 45000 && !_milCleared;
    d.milOn = mil;
    d.dtcCount = mil ? 1 : 0;
    d.distMilKm = mil ? (now - 45000) / 1000.0 * 0.02 : 0.0;
    d.updatedAt = now;
  }

  @override
  Future<void> requestDtcs(VehicleData d) async {
    d.dtcs = d.milOn ? ['P0171'] : [];
    d.dtcsRead = true;
    d.dtcsReadAt = _now;
  }

  @override
  Future<bool> clearDtcs(VehicleData d) async {
    d.dtcs = [];
    d.dtcsRead = true;
    d.milOn = false;
    d.dtcCount = 0;
    _milCleared = true;
    return true;
  }

  @override
  Future<void> dispose() async {
    _sw.stop();
    _state = ObdState.idle;
  }

  void _pickTarget() {
    final r = _rnd.nextInt(100);
    if (r < 15) {
      _target = 0; // semáforo
    } else if (r < 55) {
      _target = _rand(25, 60).toDouble(); // cidade
    } else if (r < 85) {
      _target = _rand(60, 95).toDouble(); // avenida
    } else {
      _target = _rand(95, 125).toDouble(); // rodovia
    }
    _nextChange = _now + _rand(6000, 18000);
  }
}
