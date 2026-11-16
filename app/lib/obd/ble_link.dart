import 'dart:async';
import 'dart:math';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'elm_link.dart';

/// `true` se [uuid] é o UUID curto de 16 bits informado (ex.: 'fff0'), em qualquer forma.
bool uuidIs(Guid uuid, String short16) {
  final s = uuid.toString().toLowerCase();
  return s == short16 || s.startsWith('0000$short16-');
}

/// Transporte BLE para o ELM327 (serviço FFF0: FFF1 notify, FFF2 write), o que o KONNWEI usa.
/// Porte de `obd_ble.h`, validado com o adaptador real a partir do firmware.
class BleLink implements ElmLink {
  BleLink(this.device, {this.label});

  final BluetoothDevice device;
  final String? label;

  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  final StreamController<List<int>> _incoming = StreamController<List<int>>.broadcast();
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _connected = false;

  @override
  String get name => label ?? (device.platformName.isNotEmpty ? device.platformName : device.remoteId.str);
  @override
  bool get isConnected => _connected;
  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
    } catch (e) {
      throw ElmLinkException('conexão BLE falhou: $e');
    }
    _connected = true;
    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) _connected = false;
    });

    List<BluetoothService> services = const [];
    try {
      services = await device.discoverServices();
    } catch (e) {
      await _safeDisconnect();
      throw ElmLinkException('descoberta de serviços falhou: $e');
    }
    BluetoothService? svc;
    for (final s in services) {
      if (uuidIs(s.uuid, 'fff0')) {
        svc = s;
        break;
      }
    }
    if (svc == null) {
      await _safeDisconnect();
      throw ElmLinkException('serviço FFF0 ausente');
    }
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;
    for (final c in svc.characteristics) {
      if (uuidIs(c.uuid, 'fff1')) rx = c;
      if (uuidIs(c.uuid, 'fff2')) tx = c;
    }
    // alguns clones usam só FFF1 para os dois sentidos
    if (tx == null && rx != null && (rx.properties.write || rx.properties.writeWithoutResponse)) tx = rx;
    if (rx == null || tx == null) {
      await _safeDisconnect();
      throw ElmLinkException('características FFF1/FFF2 ausentes');
    }
    try {
      await rx.setNotifyValue(true);
    } catch (e) {
      await _safeDisconnect();
      throw ElmLinkException('subscribe FFF1 falhou: $e');
    }
    _notifySub = rx.onValueReceived.listen(_incoming.add);
    _rx = rx;
    _tx = tx;
  }

  @override
  Future<void> write(List<int> bytes) async {
    final tx = _tx;
    if (tx == null || !_connected) throw ElmLinkException('BLE desconectado');
    var mtu = device.mtuNow - 3;
    if (mtu < 20) mtu = 20;
    // escreve sem resposta quando a característica permite, como o firmware; fragmenta pelo MTU
    final withoutResponse = tx.properties.writeWithoutResponse;
    for (var off = 0; off < bytes.length; off += mtu) {
      final end = min(off + mtu, bytes.length);
      try {
        await tx.write(bytes.sublist(off, end), withoutResponse: withoutResponse);
      } catch (e) {
        throw ElmLinkException('escrita BLE falhou: $e');
      }
    }
  }

  @override
  Future<int> readRssi() async {
    try {
      return await device.readRssi();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    final rx = _rx;
    if (rx != null && _connected) {
      try {
        await rx.setNotifyValue(false);
      } catch (_) {
        // já caiu; segue para desconectar
      }
    }
    _rx = null;
    _tx = null;
    await _safeDisconnect();
  }

  Future<void> _safeDisconnect() async {
    _connected = false;
    try {
      await device.disconnect();
    } catch (_) {
      // já desconectado
    }
  }
}
