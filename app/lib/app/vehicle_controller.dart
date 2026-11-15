import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../data/vehicle_data.dart';
import '../obd/obd_source.dart';
import '../ui/format.dart';

/// Alerta em tela cheia (motor quente, bateria baixa, luz de injeção).
class ActiveAlert {
  const ActiveAlert(this.title, this.value, {required this.severe});
  final String title;
  final String value;

  /// true = vermelho (motor quente); false = laranja.
  final bool severe;
}

/// Equivalente ao `loop()` do firmware: dirige a fonte de dados um passo por vez,
/// deriva consumo, integra a viagem, cuida de páginas e alertas, e avisa a interface.
class VehicleController extends ChangeNotifier {
  VehicleController({int Function()? clock}) : _clock = clock ?? _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final int Function() _clock;
  final VehicleData data = VehicleData();
  final TripData trip = TripData();

  /// Histórico da sonda 1 para o mini gráfico (anel de 48 amostras, uma por quadro).
  final List<double> o2History = List<double>.filled(48, 0.45);
  int _o2Idx = 0;
  int get o2Index => _o2Idx;

  ObdSource? _source;
  ObdSource? get source => _source;
  ObdState get state => _source?.state ?? ObdState.idle;

  int _page = 0;
  int get page => _page;

  bool _blink = false;
  bool get blink => _blink;

  ActiveAlert? _alert;
  ActiveAlert? get alert => _alert;

  Timer? _timer;
  Timer? _alertTimer;
  bool _busy = false;
  int _lastIntegrate = 0;
  int _lastNotify = 0;
  int _lastBlink = 0;
  bool _aCool = false;
  bool _aBatt = false;
  bool _aMil = false;

  bool get running => _timer != null;
  int get tripElapsedMs => trip.startMs == 0 ? 0 : _clock() - trip.startMs;

  /// Conecta na fonte e, se deu certo, começa o laço de leitura. [runLoop] false deixa
  /// o avanço por conta de quem chama [tick] (testes).
  Future<bool> start(ObdSource src, {bool runLoop = true}) async {
    await stop();
    _source = src;
    src.onStateChanged = notifyListeners;
    data.reset();
    trip.reset(_clock());
    _aCool = _aBatt = _aMil = false;
    _o2Idx = 0;
    o2History.fillRange(0, o2History.length, 0.45);
    notifyListeners();
    final ok = await src.begin();
    if (!ok) {
      notifyListeners();
      return false;
    }
    final now = _clock();
    trip.reset(now);
    _lastIntegrate = now;
    _lastNotify = 0;
    if (runLoop) {
      _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
        tick();
      });
    }
    notifyListeners();
    return true;
  }

  /// Um passo do laço: um comando na fonte, derivação, viagem, alertas, redesenho.
  Future<void> tick() async {
    final src = _source;
    if (_busy || src == null) return;
    _busy = true;
    try {
      await src.update(data);
      final now = _clock();
      deriveAndIntegrate(data, trip, now - _lastIntegrate);
      _lastIntegrate = now;
      if (now - _lastBlink >= 500) {
        _lastBlink = now;
        _blink = !_blink;
      }
      if (_alert == null) _checkAlerts(now);
      if (now - _lastNotify >= uiRefreshMs) {
        _lastNotify = now;
        final o2 = data.o2s1V;
        if (o2 != null) {
          o2History[_o2Idx] = o2;
          _o2Idx = (_o2Idx + 1) % o2History.length;
        }
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
  }

  /// Troca de página; ao entrar no diagnóstico relê os códigos (modo 03), como o firmware.
  void goToPage(int p) {
    if (p == _page) return;
    _page = p;
    if (p == 2) requestDtcs();
    notifyListeners();
  }

  Future<void> requestDtcs() async {
    final src = _source;
    if (src == null) return;
    data.dtcsRead = false;
    notifyListeners();
    await src.requestDtcs(data);
    notifyListeners();
  }

  /// Modo 04 e releitura. Devolve true se a ECU confirmou.
  Future<bool> clearDtcs() async {
    final src = _source;
    if (src == null) return false;
    final ok = await src.clearDtcs(data);
    data.dtcsRead = false;
    notifyListeners();
    await src.requestDtcs(data);
    notifyListeners();
    return ok;
  }

  void dismissAlert() {
    _alertTimer?.cancel();
    _alertTimer = null;
    if (_alert != null) {
      _alert = null;
      notifyListeners();
    }
  }

  /// Cada condição dispara uma vez e rearma quando volta ao normal.
  void _checkAlerts(int now) {
    final engineOn = (data.rpm ?? 0) > 400;
    final cool = data.coolantC;
    if (cool != null && cool > alertCoolantC) {
      if (!_aCool) {
        _aCool = true;
        _showAlert('MOTOR QUENTE', '${fmt(cool, 0)} °C', severe: true);
      }
    } else {
      _aCool = false;
    }
    final v = data.batteryV;
    if (engineOn && v != null && v < alertBatteryV) {
      if (!_aBatt) {
        _aBatt = true;
        _showAlert('BATERIA BAIXA', '${fmt(v, 1)} V', severe: false);
      }
    } else if (v != null && v >= alertBatteryV + 0.3) {
      _aBatt = false;
    }
    if (data.milOn) {
      if (!_aMil) {
        _aMil = true;
        _showAlert('LUZ DE INJEÇÃO', '${data.dtcCount} ${data.dtcCount == 1 ? 'falha' : 'falhas'}', severe: false);
      }
    } else {
      _aMil = false;
    }
  }

  void _showAlert(String title, String value, {required bool severe}) {
    _alert = ActiveAlert(title, value, severe: severe);
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(milliseconds: alertShowMs), () {
      _alertTimer = null;
      _alert = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Para o laço e desconecta.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _alertTimer?.cancel();
    _alertTimer = null;
    _alert = null;
    final src = _source;
    _source = null;
    if (src != null) {
      src.onStateChanged = null;
      await src.dispose();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    final src = _source;
    _source = null;
    if (src != null) {
      src.onStateChanged = null;
      src.dispose();
    }
    super.dispose();
  }
}
