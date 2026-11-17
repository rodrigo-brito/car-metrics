import 'package:flutter/material.dart';

import 'app/vehicle_controller.dart';
import 'ui/pages/connect_page.dart';
import 'ui/theme.dart';

void main() => runApp(const PainelApp());

/// Painel OBD2: computador de bordo no celular: mesmas métricas e páginas do painel ESP32,
/// lendo o adaptador KONNWEI (ELM327 por BLE) direto, ou um mock para desenvolver sem o carro.
class PainelApp extends StatefulWidget {
  const PainelApp({super.key, this.autoScan = true});

  /// Varrer o Bluetooth ao abrir (false nos testes).
  final bool autoScan;

  @override
  State<PainelApp> createState() => _PainelAppState();
}

class _PainelAppState extends State<PainelApp> {
  final VehicleController _controller = VehicleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel OBD2',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ConnectPage(controller: _controller, autoScan: widget.autoScan),
    );
  }
}
