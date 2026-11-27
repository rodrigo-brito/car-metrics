import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/device_prefs.dart';
import '../../app/vehicle_controller.dart';
import '../../data/vehicle_data.dart';
import '../../obd/ble_link.dart';
import '../../obd/ble_scanner.dart';
import '../../obd/elm_source.dart';
import '../../obd/mock_source.dart';
import '../../obd/obd_source.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'incline_page.dart';
import '../widgets/two_column.dart';

/// Tela inicial: ao abrir, varre o Bluetooth e lista os dispositivos. Qualquer um pode ser
/// escolhido; o último conectado com sucesso vira o padrão e é conectado sozinho quando
/// aparece na primeira varredura. Também há o modo simulação, para usar sem o carro.
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.controller, this.autoScan = true});
  final VehicleController controller;

  /// false nos testes, onde não há Bluetooth.
  final bool autoScan;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  List<BleScanDevice> _devices = [];
  SavedDevice? _saved;
  bool _scanning = false;
  bool _scanned = false;
  bool _connecting = false;
  String _connectingTo = '';
  bool _cancelled = false;

  /// A conexão automática ao padrão só acontece uma vez, na abertura do app.
  bool _autoConnect = true;
  String? _msg;
  StreamSubscription<List<BleScanDevice>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final saved = await DevicePrefs.load();
    if (!mounted) return;
    setState(() => _saved = saved);
    if (widget.autoScan) await _scan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    super.dispose();
  }

  /// Permissões e adaptador ligado. Devolve false (e mostra o motivo) se faltar algo.
  Future<bool> _ensureBle() async {
    try {
      final perm = await BlePermissions.request();
      if (perm != null) {
        if (mounted) setState(() => _msg = perm);
        return false;
      }
      final adapter = await BleScanner.ensureAdapterOn();
      if (adapter != null) {
        if (mounted) setState(() => _msg = adapter);
        return false;
      }
      return true;
    } catch (e) {
      if (mounted) setState(() => _msg = 'Bluetooth indisponível: $e');
      return false;
    }
  }

  Future<void> _scan() async {
    setState(() {
      _msg = null;
      _devices = [];
      _scanned = false;
    });
    if (!await _ensureBle() || !mounted) return;
    await _scanSub?.cancel();
    await _isScanningSub?.cancel();
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _scanned = true;
    });
    _isScanningSub = BleScanner.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
    _scanSub = BleScanner.scan(seconds: 8).listen(
      (list) {
        if (!mounted) return;
        setState(() => _devices = _sorted(list));
        _maybeAutoConnect(list);
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _msg = 'varredura falhou: $e';
            _scanning = false;
          });
        }
      },
    );
  }

  /// Padrão primeiro, depois os que parecem OBD, depois por sinal.
  List<BleScanDevice> _sorted(List<BleScanDevice> list) {
    final savedId = _saved?.id;
    int rank(BleScanDevice d) => d.id == savedId ? 0 : (d.looksLikeObd ? 1 : 2);
    return [...list]..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : b.rssi.compareTo(a.rssi);
      });
  }

  void _maybeAutoConnect(List<BleScanDevice> list) {
    final saved = _saved;
    if (!_autoConnect || saved == null || _connecting) return;
    for (final d in list) {
      if (d.id == saved.id) {
        _autoConnect = false;
        _connect(d);
        return;
      }
    }
  }

  Future<void> _connect(BleScanDevice dev) async {
    _autoConnect = false;
    await BleScanner.stop();
    final label = dev.name.isEmpty ? (dev.id == _saved?.id ? _saved!.label : dev.id) : dev.name;
    await _start(
      ElmSource(BleLink(dev.device, label: label)),
      label: label,
      saveAs: SavedDevice(id: dev.id, name: dev.name.isEmpty ? (_saved?.id == dev.id ? _saved!.name : '') : dev.name),
    );
  }

  /// Conecta direto no padrão pelo endereço, sem esperar a varredura achá-lo.
  Future<void> _connectSaved() async {
    final saved = _saved;
    if (saved == null) return;
    _autoConnect = false;
    if (!await _ensureBle()) return;
    await BleScanner.stop();
    await _start(
      ElmSource(BleLink(BleScanner.deviceFromId(saved.id), label: saved.label)),
      label: saved.label,
      saveAs: saved,
    );
  }

  Future<void> _forgetSaved() async {
    await DevicePrefs.clear();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _devices = _sorted(_devices);
    });
  }

  Future<void> _startMock() async {
    _autoConnect = false;
    await BleScanner.stop().catchError((_) {});
    await _start(MockSource(), label: 'simulação');
  }

  Future<void> _cancel() async {
    _cancelled = true;
    await widget.controller.stop();
  }

  Future<void> _start(ObdSource src, {required String label, SavedDevice? saveAs}) async {
    setState(() {
      _connecting = true;
      _connectingTo = label;
      _cancelled = false;
      _msg = null;
    });
    final ok = await widget.controller.start(src);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (_cancelled) {
      if (ok) await widget.controller.stop();
      if (mounted) setState(() => _msg = 'conexão cancelada');
      return;
    }
    if (!ok) {
      setState(() => _msg = src.lastError.isEmpty ? 'não conectou em $label' : '$label: ${src.lastError}');
      return;
    }
    if (saveAs != null) {
      await DevicePrefs.save(saveAs);
      if (mounted) setState(() => _saved = saveAs);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DashboardScreen(controller: widget.controller)),
    );
    // voltou do painel (desconectou): lista de novo, sem reconectar sozinho
    if (mounted && widget.autoScan) await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final list = _buildDeviceList();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth > box.maxHeight) {
              // horizontal: controles à esquerda (cabem sem rolar), lista à direita
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: box.maxWidth * 0.45,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                      child: FitWithoutScroll(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildHeader(compact: true),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(color: Palette.line, width: 1),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 20, 20), children: list),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [..._buildHeader(), const SizedBox(height: 8), ...list],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildHeader({bool compact = false}) {
    final c = widget.controller;
    final saved = _saved;
    final busy = _connecting;
    final msg = _msg;
    return [
      SizedBox(height: compact ? 0 : 12),
      Text(
        compact ? 'Painel OBD2' : 'Painel\nOBD2',
        style: TextStyle(
          color: Palette.accent,
          fontSize: compact ? 28 : 36,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      SizedBox(height: compact ? 6 : 10),
      Container(
        width: 60,
        height: 3,
        decoration: BoxDecoration(color: Palette.line, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(height: 12),
      const Text(
        'computador de bordo · adaptador ELM327 por Bluetooth',
        style: TextStyle(color: Palette.muted, fontSize: 14),
      ),
      SizedBox(height: compact ? 12 : 20),
      if (saved != null) ...[
        _SavedCard(
          saved: saved,
          enabled: !busy,
          onConnect: _connectSaved,
          onForget: _forgetSaved,
        ),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: busy || _scanning ? null : _scan,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Procurar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy ? null : _startMock,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Simulação'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const InclinePage(standalone: true)),
                ),
        icon: const Icon(Icons.terrain),
        label: const Text('Inclinômetro (sem OBD)'),
      ),
      const SizedBox(height: 16),
      if (_connecting)
        ListenableBuilder(
          listenable: c,
          builder: (context, _) => Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_connectingTo · ${obdStateName(c.state)}',
                  style: const TextStyle(color: Palette.muted),
                ),
              ),
              TextButton(onPressed: _cancel, child: const Text('Cancelar')),
            ],
          ),
        ),
      if (msg != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg, style: const TextStyle(color: Palette.bad)),
        ),
    ];
  }

  List<Widget> _buildDeviceList() {
    final savedId = _saved?.id;
    return [
      Row(
        children: [
          const Expanded(
            child: Text(
              'DISPOSITIVOS BLUETOOTH',
              style: TextStyle(color: Palette.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
          if (_scanning) const Text('procurando...', style: TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
      if (_scanning)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(color: Palette.accent, backgroundColor: Palette.line),
        ),
      if (!_scanned && !_scanning)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Toque em "Procurar".', style: TextStyle(color: Palette.muted)),
        ),
      if (_scanned && !_scanning && _devices.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Nenhum dispositivo encontrado. O adaptador só aparece com a ignição no contato '
            'e some enquanto outro aparelho estiver conectado nele (ele aceita um cliente por vez).',
            style: TextStyle(color: Palette.muted),
          ),
        ),
      for (final d in _devices)
        _DeviceTile(device: d, isDefault: d.id == savedId, enabled: !_connecting, onTap: () => _connect(d)),
      if (_devices.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Toque num dispositivo para conectar; ele passa a ser o padrão. O painel ESP32, se estiver '
            'ligado, perde a conexão enquanto o app estiver em uso.',
            style: TextStyle(color: Palette.muted, fontSize: 12),
          ),
        ),
    ];
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({required this.saved, required this.enabled, required this.onConnect, required this.onForget});
  final SavedDevice saved;
  final bool enabled;
  final VoidCallback onConnect;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Palette.panel,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Palette.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.star, color: Palette.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('padrão', style: TextStyle(color: Palette.muted, fontSize: 12)),
                  Text(
                    saved.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.txt, fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: enabled ? onConnect : null, child: const Text('Conectar')),
            IconButton(
              onPressed: enabled ? onForget : null,
              tooltip: 'Esquecer padrão',
              icon: const Icon(Icons.close, color: Palette.muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.isDefault, required this.enabled, required this.onTap});
  final BleScanDevice device;
  final bool isDefault;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final obd = device.looksLikeObd;
    final hi = isDefault || obd;
    return Card(
      color: Palette.panel,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        leading: Icon(
          isDefault ? Icons.star : (obd ? Icons.directions_car : Icons.bluetooth),
          color: hi ? Palette.accent : Palette.muted,
        ),
        title: Text(
          device.name.isEmpty ? '(sem nome)' : device.name,
          style: TextStyle(color: hi ? Palette.txt : Palette.muted, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${device.id}${device.hasFff0 ? '  [FFF0]' : ''}${isDefault ? '  · padrão' : ''}',
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
        trailing: Text('${device.rssi} dBm', style: const TextStyle(color: Palette.muted)),
      ),
    );
  }
}
