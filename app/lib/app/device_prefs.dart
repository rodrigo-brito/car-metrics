import 'package:shared_preferences/shared_preferences.dart';

/// O adaptador OBD padrão: o último ao qual o app conectou com sucesso.
class SavedDevice {
  const SavedDevice({required this.id, required this.name});
  final String id;
  final String name;

  String get label => name.isEmpty ? id : name;
}

/// Guarda e lê o dispositivo padrão entre aberturas do app.
class DevicePrefs {
  DevicePrefs._();

  static const _kId = 'obd_device_id';
  static const _kName = 'obd_device_name';

  static Future<SavedDevice?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString(_kId);
      if (id == null || id.isEmpty) return null;
      return SavedDevice(id: id, name: p.getString(_kName) ?? '');
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SavedDevice d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kId, d.id);
    await p.setString(_kName, d.name);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kName);
  }
}
