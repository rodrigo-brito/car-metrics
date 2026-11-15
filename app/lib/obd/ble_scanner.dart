import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';
import 'ble_link.dart';

/// Nome com cara de adaptador OBD (ver [obdNameHints]).
bool looksLikeObdName(String name) {
  final n = name.toUpperCase();
  return obdNameHints.any(n.contains);
}

/// Um dispositivo visto na varredura, do jeito que o firmware lista no serial:
/// nome, endereço, sinal e se anuncia o serviço FFF0.
class BleScanDevice {
  BleScanDevice({required this.device, required this.name, required this.rssi, required this.hasFff0});

  final BluetoothDevice device;
  final String name;
  final int rssi;
  final bool hasFff0;

  String get id => device.remoteId.str;

  /// Provável adaptador OBD: anuncia o serviço FFF0 ou tem nome típico de ELM327.
  bool get looksLikeObd => hasFff0 || looksLikeObdName(name);
}

/// Permissões de Bluetooth em tempo de execução.
class BlePermissions {
  BlePermissions._();

  /// Devolve null se tudo foi concedido, ou a mensagem do que falta.
  /// Android 12+ (API 31): BLUETOOTH_SCAN e BLUETOOTH_CONNECT. Android 11-: localização fina.
  static Future<String?> request() async {
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 31) {
      final r = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      if (r.values.any((s) => !s.isGranted)) {
        return 'permita "Dispositivos por perto" (Bluetooth) para este app nas configurações do Android';
      }
    } else {
      final r = await Permission.locationWhenInUse.request();
      if (!r.isGranted) {
        return 'no Android 11 ou anterior a varredura Bluetooth exige a permissão de localização';
      }
    }
    return null;
  }
}

/// Varredura BLE com flutter_blue_plus.
class BleScanner {
  BleScanner._();

  static Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  /// Garante o adaptador ligado (no Android pede para ligar). Devolve null se ok, ou a mensagem.
  static Future<String?> ensureAdapterOn() async {
    if (!await FlutterBluePlus.isSupported) return 'este aparelho não tem Bluetooth LE';
    var st = await FlutterBluePlus.adapterState.first;
    if (st != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          // o usuário pode ter recusado; a checagem abaixo informa
        }
      }
      st = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first
          .timeout(const Duration(seconds: 5), onTimeout: () => BluetoothAdapterState.unknown);
      if (st != BluetoothAdapterState.on) return 'ligue o Bluetooth';
    }
    return null;
  }

  /// Varre por [seconds] s e emite a lista acumulada (só dispositivos com nome ou com FFF0),
  /// do sinal mais forte para o mais fraco.
  static Stream<List<BleScanDevice>> scan({int seconds = 6}) async* {
    await FlutterBluePlus.startScan(timeout: Duration(seconds: seconds), androidUsesFineLocation: false);
    yield* FlutterBluePlus.scanResults.map((rs) {
      final list = rs.map(_toDevice).where((d) => d.name.isNotEmpty || d.hasFff0).toList();
      list.sort((a, b) => b.rssi.compareTo(a.rssi));
      return list;
    });
  }

  static Future<void> stop() => FlutterBluePlus.stopScan();

  /// Dispositivo pelo endereço salvo, para reconectar sem precisar achá-lo na varredura.
  static BluetoothDevice deviceFromId(String id) => BluetoothDevice.fromId(id);

  static BleScanDevice _toDevice(ScanResult r) {
    final adv = r.advertisementData;
    final name = adv.advName.isNotEmpty ? adv.advName : r.device.platformName;
    final fff0 = adv.serviceUuids.any((u) => uuidIs(u, 'fff0'));
    return BleScanDevice(device: r.device, name: name, rssi: r.rssi, hasFff0: fff0);
  }
}
