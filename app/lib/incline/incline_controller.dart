import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'incline_math.dart';

enum InclineLevel { ok, warn, danger }

InclineLevel rollLevel(double deg) => deg.abs() >= inclineRollDanger
    ? InclineLevel.danger
    : deg.abs() >= inclineRollWarn
        ? InclineLevel.warn
        : InclineLevel.ok;

InclineLevel pitchLevel(double deg) => deg.abs() >= inclinePitchDanger
    ? InclineLevel.danger
    : deg.abs() >= inclinePitchWarn
        ? InclineLevel.warn
        : InclineLevel.ok;

/// Lê o acelerômetro, filtra, converte para inclinação do carro, guarda a calibração
/// (zero) e os máximos da sessão, e vibra ao entrar na faixa de perigo.
/// Fica ligado só enquanto alguma tela o usa ([attach]/[detach]).
class InclineController extends ChangeNotifier {
  InclineController({Stream<Vec3>? source}) : _sourceOverride = source;

  static final InclineController instance = InclineController();

  static const _kCal = 'incline_frame';

  final Stream<Vec3>? _sourceOverride;
  final LowPass _filter = LowPass();
  StreamSubscription<Vec3>? _sub;
  int _users = 0;
  bool _loaded = false;

  CarFrame? _cal;
  bool get calibrated => _cal != null;

  Incline? _now;
  Incline? get now => _now;

  double maxPitchUp = 0;
  double maxPitchDown = 0;
  double maxRollLeft = 0;
  double maxRollRight = 0;

  bool _wasDanger = false;
  int _lastBuzz = 0;
  String? error;

  void attach() {
    _users++;
    if (_users == 1) _start();
  }

  void detach() {
    _users--;
    if (_users <= 0) {
      _users = 0;
      _sub?.cancel();
      _sub = null;
    }
  }

  Future<void> _start() async {
    if (!_loaded) {
      _loaded = true;
      try {
        final p = await SharedPreferences.getInstance();
        _cal = CarFrame.fromList(p.getStringList(_kCal)?.map(double.parse).toList());
      } catch (_) {}
    }
    final src = _sourceOverride ??
        accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) => Vec3(e.x, e.y, e.z));
    _sub = src.listen(_onSample, onError: (Object e) {
      error = 'acelerômetro indisponível: $e';
      notifyListeners();
    });
  }

  int? _orientation;

  void _onSample(Vec3 s) {
    if (s.length < 1) return;
    // sem calibração o referencial segue a orientação do celular; ao girar a tela, recomeça
    // o filtro e os máximos, senão a transição vira um pico falso de inclinação
    if (_cal == null) {
      final o = CarFrame.orientationOf(s);
      if (_orientation != null && o != _orientation) {
        _filter.reset(s);
        maxPitchUp = maxPitchDown = maxRollLeft = maxRollRight = 0;
      }
      _orientation = o;
    }
    final g = _filter.add(s);
    final frame = _cal ?? CarFrame.assumeUpright(g);
    final inc = frame.measure(g);
    _now = inc;
    if (inc.pitchDeg > maxPitchUp) maxPitchUp = inc.pitchDeg;
    if (-inc.pitchDeg > maxPitchDown) maxPitchDown = -inc.pitchDeg;
    if (inc.rollDeg > maxRollRight) maxRollRight = inc.rollDeg;
    if (-inc.rollDeg > maxRollLeft) maxRollLeft = -inc.rollDeg;

    final danger = rollLevel(inc.rollDeg) == InclineLevel.danger || pitchLevel(inc.pitchDeg) == InclineLevel.danger;
    final t = DateTime.now().millisecondsSinceEpoch;
    if (danger && (!_wasDanger || t - _lastBuzz > 1500)) {
      _lastBuzz = t;
      HapticFeedback.heavyImpact();
    }
    _wasDanger = danger;
    notifyListeners();
  }

  /// Toma a posição atual como zero (carro parado num lugar plano).
  Future<void> calibrate() async {
    final g = _filter.value;
    if (g == null || g.length < 1) return;
    _cal = CarFrame.fromGravity(g);
    resetMax();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kCal, _cal!.toList().map((v) => v.toString()).toList());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearCalibration() async {
    _cal = null;
    resetMax();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kCal);
    } catch (_) {}
    notifyListeners();
  }

  void resetMax() {
    maxPitchUp = maxPitchDown = maxRollLeft = maxRollRight = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
