import 'package:flutter/material.dart';

import '../../app/vehicle_controller.dart';
import '../../data/vehicle_data.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/bars.dart';
import '../widgets/two_column.dart';

/// Página 3, diagnóstico: luz de injeção, falhas, códigos (modo 03), apagar com
/// confirmação (modo 04), VIN, norma, protocolo, sinal e erro.
class DiagPage extends StatelessWidget {
  const DiagPage({super.key, required this.controller});
  final VehicleController controller;

  @override
  Widget build(BuildContext context) {
    final d = controller.data;
    final src = controller.source;
    final rssi = src?.signalDbm ?? 0;
    final err = src?.lastError ?? '';
    final dist = d.distMilKm ?? 0;

    return TwoColumnList(
      left: [
        InfoLine('luz injeção', d.milOn ? 'ACESA' : 'apagada', color: d.milOn ? Palette.bad : Palette.ok),
        InfoLine(
          'falhas',
          '${d.dtcCount}${dist > 0 ? '   ${fmt(dist, 0)} km com luz' : ''}',
          color: d.dtcCount > 0 ? Palette.warn : Palette.txt,
        ),
        if (!d.dtcsRead)
          const InfoLine('códigos', 'lendo...', color: Palette.muted)
        else if (d.dtcs.isEmpty)
          const InfoLine('códigos', 'nenhum', color: Palette.ok)
        else
          _DtcChips(codes: d.dtcs),
      ],
      right: [
        const Divider(color: Palette.line),
        InfoLine('veículo', d.vin.isEmpty ? '--' : d.vin),
        InfoLine('norma', d.obdStd.isEmpty ? '--' : d.obdStd),
        InfoLine('protocolo', src == null || src.protocol.isEmpty ? '--' : src.protocol),
        InfoLine('fonte', src == null ? obdStateName(ObdState.idle) : '${src.name}  ${obdStateName(src.state)}'),
        InfoLine(
          'sinal',
          rssi == 0 ? '--' : '$rssi dBm',
          color: rssi == 0
              ? Palette.muted
              : rssi > -75
                  ? Palette.ok
                  : rssi > -85
                      ? Palette.warn
                      : Palette.bad,
        ),
        InfoLine('erro', err.isEmpty ? '-' : err, color: err.isEmpty ? Palette.txt : Palette.bad),
      ],
      tail: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: src == null ? null : controller.requestDtcs,
                icon: const Icon(Icons.refresh),
                label: const Text('Reler códigos'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Palette.bad, foregroundColor: Colors.black),
                onPressed: src == null ? null : () => _confirmClear(context),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Apagar falhas'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Apagar envia o modo 04 à ECU: limpa os códigos e a luz de injeção, mas não a causa.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.panel,
        title: const Text('Apagar falhas?'),
        content: const Text('Os códigos armazenados e a luz de injeção serão apagados na ECU.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.bad, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await controller.clearDtcs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? 'Falhas apagadas' : 'A ECU não confirmou o apagamento')),
    );
  }
}

class _DtcChips extends StatelessWidget {
  const _DtcChips({required this.codes});
  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 108, child: Text('códigos', style: TextStyle(color: Palette.muted, fontSize: 14))),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in codes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: Palette.bad),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(color: Palette.bad, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
