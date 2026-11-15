import 'package:flutter/material.dart';

import '../../app/vehicle_controller.dart';
import '../theme.dart';

/// Alerta em tela cheia, como no painel: fundo na cor do alerta, título e valor em preto.
/// Um toque dispensa.
class AlertOverlay extends StatelessWidget {
  const AlertOverlay({super.key, required this.alert, required this.onDismiss});
  final ActiveAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = alert.severe ? Palette.bad : Palette.warn;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: ColoredBox(
        color: color,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                alert.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Text(
                alert.value,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 56, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 32),
              const Text('toque para dispensar', style: TextStyle(color: Colors.black54, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
