import 'dart:async';

import 'package:painel_tr4/obd/elm_link.dart';

/// Adaptador ELM327 de mentira: responde a cada comando pela tabela [responses]
/// (sem o prompt; o `>` é acrescentado), como se já estivesse com ATE0/ATS0/ATH0.
class FakeLink implements ElmLink {
  FakeLink(this.responses, {this.defaultAt = 'OK', this.defaultPid = 'NO DATA'});

  final Map<String, String> responses;
  final String defaultAt;
  final String defaultPid;
  final List<String> sent = [];
  bool connected = false;
  bool failConnect = false;
  final StreamController<List<int>> _ctrl = StreamController<List<int>>.broadcast(sync: true);

  @override
  String get name => 'fake';
  @override
  bool get isConnected => connected;
  @override
  Stream<List<int>> get incoming => _ctrl.stream;

  @override
  Future<void> connect() async {
    if (failConnect) throw ElmLinkException('adaptador BLE não encontrado');
    connected = true;
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!connected) throw ElmLinkException('BLE desconectado');
    final c = String.fromCharCodes(bytes).trim();
    sent.add(c);
    final r = responses[c] ?? (c.startsWith('AT') ? defaultAt : defaultPid);
    _ctrl.add('$r\r\r>'.codeUnits);
  }

  @override
  Future<int> readRssi() async => -60;

  @override
  Future<void> disconnect() async {
    connected = false;
  }
}

/// Respostas de uma ECU parecida com a da TR4: CAN (protocolo A6), com MAP e sem MAF.
final Map<String, String> tr4Responses = {
  'ATZ': 'ELM327 v1.5',
  'ATDPN': 'A6',
  '0100': '4100BE3EB811',
  '0120': '412080000000',
  '010C': '410C1AF8', // 1726 rpm
  '010D': '410D3C', // 60 km/h
  '010B': '410B64', // 100 kPa
  '0105': '410582', // 90 °C
  'ATRV': '14.2V',
  '0101': '41018107E500', // luz acesa, 1 falha
  '010F': '410F46', // 30 °C
  '0104': '410480', // 50,2 %
  '0111': '411133', // 20 %
  '0106': '41068A', // +7,8 %
  '0107': '410780', // 0 %
  '010E': '410E90', // 8°
  '0114': '41145AFF', // 0,45 V
  '0115': '41157A', // 0,61 V
  '0103': '41030200', // malha fechada
  '0121': '41210000', // 0 km com luz
  '011C': '411C01', // OBD-II (CARB)
  '0902': '014\r0:490201394252\r1:5452344D4F434B\r2:30303030303031',
  '03': '430101710000',
  '04': '44',
};
