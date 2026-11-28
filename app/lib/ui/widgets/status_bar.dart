import 'package:flutter/material.dart';

import '../../app/vehicle_controller.dart';
import '../../data/vehicle_data.dart';
import '../format.dart';
import '../theme.dart';

/// Barra de status do topo, comum às três páginas: ponto de estado, nome da página,
/// fonte/estado, selo INJEÇÃO quando a luz está acesa e tempo de viagem.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.controller, required this.pageName, this.onDisconnect});
  final VehicleController controller;

  /// Vazio em paisagem, onde a aba ativa já mostra o nome da página.
  final String pageName;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final st = controller.state;
    final src = controller.source;
    final blink = controller.blink;
    var dot = st == ObdState.connected
        ? Palette.ok
        : st == ObdState.mock
            ? Palette.accent
            : st == ObdState.error
                ? Palette.bad
                : Palette.warn;
    final transient = st == ObdState.connecting || st == ObdState.initializing || st == ObdState.waitingEcu;
    if (transient && blink) dot = Palette.panel;
    final stateText = st == ObdState.connected && src != null ? src.name : obdStateName(st);

    return Container(
      height: 44,
      color: Palette.panel,
      padding: const EdgeInsets.only(left: 12, right: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          // nome da página e fonte num texto só: em telas estreitas as reticências
          // cortam primeiro o estado, nunca o nome da página
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: pageName,
                    style: const TextStyle(color: Palette.txt, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  TextSpan(
                    text: pageName.isEmpty ? stateText : '   $stateText',
                    style: const TextStyle(color: Palette.muted, fontSize: 14),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // selo e tempo encolhem juntos se a barra ficar estreita (paisagem, com as abas ao lado)
          // sem o nome da página (paisagem), selo e tempo têm prioridade sobre o estado
          Flexible(
            flex: pageName.isEmpty ? 4 : 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  if (controller.data.milOn)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: blink ? Palette.warn : Palette.bad,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'INJEÇÃO',
                        style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  Text(
                    fmtDuration(controller.tripElapsedMs),
                    style: const TextStyle(color: Palette.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          if (onDisconnect != null)
            IconButton(
              onPressed: onDisconnect,
              tooltip: 'Desconectar',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.power_settings_new, color: Palette.muted, size: 20),
            ),
        ],
      ),
    );
  }
}
