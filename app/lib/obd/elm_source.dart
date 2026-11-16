import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../data/vehicle_data.dart';
import 'elm_link.dart';
import 'obd_source.dart';

/// Converte os bytes de dados de um PID no valor físico; devolve null se faltarem bytes.
typedef PidConv = double? Function(List<int> b);

/// Protocolo ELM327 independente do transporte. Porte do `ElmBase` de `obd_elm.h`:
/// inicialização (ATZ … ATAT1, 0100 força a busca de protocolo), máscara de PIDs
/// suportados, PIDs rápidos em rodízio, lentos em 13 posições, modo 03/04, VIN.
/// Um comando por vez: [cmd] enfileira e só envia o próximo quando chegar o prompt `>`.
class ElmSource extends ObdSource {
  ElmSource(this.link, {int Function()? clock, this.fastMs = obdFastMs, this.slowMs = obdSlowMs})
      : _clock = clock ?? _wallClock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch;

  final ElmLink link;
  final int fastMs;
  final int slowMs;
  final int Function() _clock;

  ObdState _state = ObdState.idle;
  String _err = '';
  String _protocol = '';
  final List<int> _supported = [0, 0, 0];
  int _lastFast = 0;
  int _lastSlow = 0;
  int _lastEcuTry = 0;
  int _slowIdx = 0;
  int _fastIdx = 0;
  bool _staticDone = false;
  int _rssi = 0;

  final StringBuffer _rxBuf = StringBuffer();
  Completer<void>? _prompt;
  StreamSubscription<List<int>>? _sub;
  Future<void> _queue = Future<void>.value();

  @override
  ObdState get state => _state;
  @override
  String get name => 'ELM327 BLE';
  @override
  String get lastError => _err;
  @override
  String get protocol => _protocol;
  @override
  int get signalDbm => _rssi;

  void _setState(ObdState s) {
    _state = s;
    onStateChanged?.call();
  }

  @override
  Future<bool> begin() async {
    _setState(ObdState.connecting);
    try {
      await link.connect();
    } on ElmLinkException catch (e) {
      _err = e.message;
      _setState(ObdState.error);
      return false;
    } catch (e) {
      _err = 'conexão falhou: $e';
      _setState(ObdState.error);
      return false;
    }
    await _sub?.cancel();
    _sub = link.incoming.listen(_onBytes);
    _setState(ObdState.initializing);
    try {
      if (!await _initAdapter()) {
        _setState(ObdState.error);
        return false;
      }
      // adaptador ok; a ECU pode estar dormindo (ignição desligada): fica aguardando e tenta de novo em update()
      _setState(await _initEcu() ? ObdState.connected : ObdState.waitingEcu);
      return true;
    } catch (e) {
      _err = 'falha na inicialização: $e';
      _setState(ObdState.error);
      return false;
    }
  }

  @override
  Future<void> update(VehicleData d) async {
    if (_state != ObdState.connected && _state != ObdState.waitingEcu) return;
    if (!link.isConnected) {
      _err = 'conexão caiu';
      _setState(ObdState.error);
      return;
    }
    final now = _clock();
    try {
      if (_state == ObdState.waitingEcu) {
        if (now - _lastEcuTry >= 5000) {
          _lastEcuTry = now;
          if (await _initEcu()) _setState(ObdState.connected);
        }
        return;
      }
      // Um comando ELM327 por chamada: cada um leva de 100 a 300 ms esperando o adaptador.
      if (!_staticDone) {
        _staticDone = true;
        await _readStatic(d);
        return;
      }
      if (now - _lastSlow >= slowMs) {
        _lastSlow = now;
        await _readSlow(d);
        return;
      }
      // rápidos em rodízio (rpm, velocidade, MAF/MAP); nova rodada no mínimo a cada fastMs
      if (_fastIdx == 0) {
        if (now - _lastFast < fastMs) return;
        _lastFast = now;
      }
      switch (_fastIdx) {
        case 0:
          if (has(0x0C)) {
            d.rpm = await _readPid(0x0C, d.rpm, (b) => b.length >= 2 ? (b[0] * 256 + b[1]) / 4.0 : null);
          }
        case 1:
          if (has(0x0D)) d.speedKmh = await _readPid(0x0D, d.speedKmh, (b) => b[0].toDouble());
        case 2:
          if (has(0x10)) {
            d.mafGs = await _readPid(0x10, d.mafGs, (b) => b.length >= 2 ? (b[0] * 256 + b[1]) / 100.0 : null);
          } else if (has(0x0B)) {
            d.mapKpa = await _readPid(0x0B, d.mapKpa, (b) => b[0].toDouble());
          }
      }
      _fastIdx = (_fastIdx + 1) % 3;
      d.updatedAt = now;
    } on ElmLinkException catch (e) {
      _err = e.message;
      _setState(ObdState.error);
    } catch (e) {
      _err = 'erro de comunicação: $e';
      _setState(ObdState.error);
    }
  }

  /// Demais PIDs, um por segundo, em rodízio de 13 posições.
  Future<void> _readSlow(VehicleData d) async {
    switch (_slowIdx++ % 13) {
      case 0:
        if (has(0x05)) d.coolantC = await _readPid(0x05, d.coolantC, (b) => b[0] - 40.0);
      case 1:
        await _readVoltage(d);
        await _readRssi();
      case 2:
        if (has(0x01)) await _readMil(d);
      case 3:
        if (has(0x0F)) d.intakeC = await _readPid(0x0F, d.intakeC, (b) => b[0] - 40.0);
      case 4:
        if (has(0x04)) d.loadPct = await _readPid(0x04, d.loadPct, (b) => b[0] * 100.0 / 255);
      case 5:
        if (has(0x11)) d.throttlePct = await _readPid(0x11, d.throttlePct, (b) => b[0] * 100.0 / 255);
      case 6:
        if (has(0x06)) d.stftPct = await _readPid(0x06, d.stftPct, (b) => (b[0] - 128) * 100.0 / 128);
      case 7:
        if (has(0x07)) d.ltftPct = await _readPid(0x07, d.ltftPct, (b) => (b[0] - 128) * 100.0 / 128);
      case 8:
        if (has(0x0E)) d.timingDeg = await _readPid(0x0E, d.timingDeg, (b) => b[0] / 2.0 - 64);
      case 9:
        if (has(0x14)) d.o2s1V = await _readPid(0x14, d.o2s1V, (b) => b[0] / 200.0);
      case 10:
        if (has(0x15)) d.o2s2V = await _readPid(0x15, d.o2s2V, (b) => b[0] / 200.0);
      case 11:
        if (has(0x03)) {
          final v = await _readPid(0x03, null, (b) => b[0].toDouble());
          d.fuelSystem = v == null ? -1 : v.toInt();
        }
      case 12:
        if (has(0x2F)) {
          d.fuelPct = await _readPid(0x2F, d.fuelPct, (b) => b[0] * 100.0 / 255);
        } else if (has(0x21)) {
          d.distMilKm =
              await _readPid(0x21, d.distMilKm, (b) => b.length >= 2 ? (b[0] * 256 + b[1]).toDouble() : null);
        }
    }
  }

  /// Modo 03: códigos de falha armazenados.
  @override
  Future<void> requestDtcs(VehicleData d) async {
    if (_state != ObdState.connected) return;
    try {
      final r = await cmd('03', timeoutMs: 3000);
      d.dtcs = parseDtcs(r, _protocol);
    } on ElmLinkException catch (e) {
      _err = e.message;
    } catch (e) {
      _err = 'erro ao ler falhas: $e';
    }
    d.dtcsRead = true;
    d.dtcsReadAt = _clock();
  }

  /// Modo 04: apaga os códigos e a luz de injeção.
  @override
  Future<bool> clearDtcs(VehicleData d) async {
    if (_state != ObdState.connected) return false;
    final r = await cmd('04', timeoutMs: 3000);
    final ok = r.contains('44') || r.contains('OK');
    if (ok) {
      d.dtcs = [];
      d.dtcsRead = true;
      d.milOn = false;
      d.dtcCount = 0;
    }
    return ok;
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await link.disconnect();
    _state = ObdState.idle;
  }

  /// PIDs que a ECU declarou suportar (0100 / 0120 / 0140).
  bool has(int pid) =>
      pid >= 1 && pid <= 0x60 && ((_supported[(pid - 1) ~/ 32] >> (31 - ((pid - 1) % 32))) & 1) == 1;

  String get supportedList {
    final s = StringBuffer();
    for (var p = 1; p <= 0x60; p++) {
      if (has(p)) s.write('${hex2(p)} ');
    }
    return s.toString().trim();
  }

  // ---------------- camada de comandos ----------------

  /// Envia um comando e lê até o prompt `>`. Os comandos são serializados: o próximo
  /// só sai quando o anterior terminar (ou estourar o tempo), nunca dois ao mesmo tempo.
  Future<String> cmd(String c, {int timeoutMs = 1500}) => _serial(() => _cmdNow(c, timeoutMs));

  Future<T> _serial<T>(Future<T> Function() f) {
    final run = _queue.then((_) => f());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<String> _cmdNow(String c, int timeoutMs) async {
    _rxBuf.clear(); // descarta sobras da resposta anterior (linkFlush)
    final prompt = Completer<void>();
    _prompt = prompt;
    await link.write('$c\r'.codeUnits);
    try {
      await prompt.future.timeout(Duration(milliseconds: timeoutMs));
    } on TimeoutException {
      // devolve o que chegou até aqui, como o firmware
    }
    _prompt = null;
    final s = _rxBuf.toString();
    final i = s.indexOf('>');
    final r = (i >= 0 ? s.substring(0, i) : s).trim();
    debugPrint('[obd] $c -> ${r.replaceAll('\r', ' ')}');
    return r;
  }

  void _onBytes(List<int> bytes) {
    for (final b in bytes) {
      if (b == 0) continue;
      _rxBuf.writeCharCode(b);
      if (b == 0x3E) {
        final p = _prompt;
        if (p != null && !p.isCompleted) p.complete();
      }
    }
  }

  Future<bool> _initAdapter() async {
    const seq = ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0', 'ATAT1'];
    var alive = false;
    for (final c in seq) {
      final r = await cmd(c, timeoutMs: c == 'ATZ' ? 4000 : 1500);
      if (r.contains('ELM') || r.contains('OK')) alive = true;
    }
    if (!alive) _err = 'adaptador não respondeu aos comandos AT';
    return alive;
  }

  Future<bool> _initEcu() async {
    var r = await cmd('0100', timeoutMs: 10000); // força busca de protocolo
    if (!r.contains('41')) {
      _err = 'ECU não respondeu (ignição ligada?)';
      return false;
    }
    _err = '';
    _parseSupported(r, 0x00, 0);
    if (has(0x20)) {
      r = await cmd('0120', timeoutMs: 3000);
      _parseSupported(r, 0x20, 1);
    }
    if (has(0x40)) {
      r = await cmd('0140', timeoutMs: 3000);
      _parseSupported(r, 0x40, 2);
    }
    _protocol = await cmd('ATDPN');
    debugPrint('[obd] protocolo=$_protocol pids=$supportedList');
    return true;
  }

  void _parseSupported(String r, int pid, int idx) {
    final b = parse(r, pid, max: 4);
    if (b != null && b.length == 4) {
      _supported[idx] = (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3];
    }
  }

  /// Lê um PID do modo 01. Mantém [current] se a resposta veio vazia; zera (null) se a
  /// ECU disse NO DATA / UNABLE / 7F01 (PID não exposto).
  Future<double?> _readPid(int pid, double? current, PidConv conv) async {
    final r = await cmd('01${hex2(pid)}', timeoutMs: 1000);
    final b = parse(r, pid);
    if (b != null && b.isNotEmpty) return conv(b);
    if (r.contains('NO DATA') || r.contains('UNABLE') || r.contains('7F01')) return null;
    return current;
  }

  Future<void> _readMil(VehicleData d) async {
    final r = await cmd('0101', timeoutMs: 1000);
    final b = parse(r, 0x01, max: 4);
    if (b != null && b.isNotEmpty) {
      d.milOn = (b[0] & 0x80) != 0;
      d.dtcCount = b[0] & 0x7F;
    }
  }

  Future<void> _readVoltage(VehicleData d) async {
    final r = await cmd('ATRV', timeoutMs: 1000); // ex: "14.2V"
    final v = parseVoltage(r);
    if (v != null) d.batteryV = v;
  }

  Future<void> _readRssi() async {
    try {
      _rssi = await link.readRssi();
    } catch (_) {
      // sem RSSI não é erro
    }
  }

  /// Informações lidas uma vez: norma OBD e VIN.
  Future<void> _readStatic(VehicleData d) async {
    if (has(0x1C)) {
      final v = await _readPid(0x1C, null, (b) => b[0].toDouble());
      if (v != null) d.obdStd = obdStdName(v.toInt());
    }
    final r = await cmd('0902', timeoutMs: 4000);
    final vin = parseVin(r);
    if (vin != null) d.vin = vin;
  }

  // ---------------- parsers puros (testáveis) ----------------

  static String hex2(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();

  /// Procura `41 <pid>` na resposta e devolve os bytes de dados (até [max]); null se não achou.
  static List<int>? parse(String r, int pid, {int max = 8}) {
    final h = r.replaceAll(RegExp(r'[ \r\n]'), '').toUpperCase();
    final tag = '41${hex2(pid)}';
    var i = h.indexOf(tag);
    if (i < 0) return null;
    i += 4;
    final out = <int>[];
    while (out.length < max && i + 1 < h.length) {
      final v = int.tryParse(h.substring(i, i + 2), radix: 16);
      if (v == null || v < 0) break;
      out.add(v);
      i += 2;
    }
    return out;
  }

  /// "14.2V" -> 14.2; null fora de 5..40 V.
  static double? parseVoltage(String r) {
    final v = double.tryParse(r.replaceAll('V', '').trim());
    return v != null && v > 5 && v < 40 ? v : null;
  }

  /// "0171" -> "P0171". Primeiro dígito: 2 bits de letra (P C B U) + 2 bits do primeiro algarismo.
  static String decodeDtc(String hex4) {
    if (hex4.length < 4) return '';
    final a = int.tryParse(hex4[0], radix: 16);
    if (a == null) return '';
    const pre = 'PCBU';
    return '${pre[(a >> 2) & 3]}${a & 3}${hex4.substring(1)}';
  }

  /// Resposta do modo 03 -> lista de códigos. Em CAN (protocolos 6-9, A, B, C) o primeiro
  /// byte depois do 43 é a contagem.
  static List<String> parseDtcs(String r, String protocol) {
    final h = r.replaceAll(RegExp(r'[ \r\n]'), '').toUpperCase();
    final out = <String>[];
    var i = h.indexOf('43');
    if (i < 0) return out;
    i += 2;
    final isCan =
        protocol.isNotEmpty && (protocol[0] == 'A' || protocol.codeUnitAt(protocol.length - 1) >= 0x36);
    if (isCan) i += 2; // byte de contagem
    while (i + 3 < h.length && out.length < 8) {
      final code = decodeDtc(h.substring(i, i + 4));
      i += 4;
      if (code.isEmpty || code == 'P0000') continue;
      out.add(code);
    }
    return out;
  }

  /// Resposta do 0902 -> VIN de 17 caracteres, ou null. O multi-quadro CAN vem como
  /// "014\r0:490201xxxx\r1:xxxx...": remove os "N:" e as quebras antes de procurar 4902.
  static String? parseVin(String r) {
    final h = r.replaceAll(' ', '').replaceAll('\n', '');
    final chars = <String>[];
    for (final ch in h.split('')) {
      if (ch == ':') {
        if (chars.isNotEmpty) chars.removeLast();
        continue;
      }
      if (ch != '\r') chars.add(ch);
    }
    final c = chars.join().toUpperCase();
    var i = c.indexOf('490201');
    if (i < 0) i = c.indexOf('4902');
    if (i < 0) return null;
    i = c.indexOf('4902', i) + 4;
    if (c.substring(i, min(i + 2, c.length)) == '01') i += 2;
    final vin = StringBuffer();
    while (i + 1 < c.length && vin.length < 17) {
      final ch = int.tryParse(c.substring(i, i + 2), radix: 16);
      i += 2;
      if (ch != null && ch >= 0x30 && ch <= 0x5A) vin.writeCharCode(ch);
    }
    return vin.length == 17 ? vin.toString() : null;
  }
}
