/// Formatação igual à do painel: `--` quando não há leitura.
String fmt(double? v, int dec, [String nan = '--']) => v == null ? nan : v.toStringAsFixed(dec);

String fmtSigned(double? v, int dec) => v == null ? '--' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(dec)}';

/// hh:mm:ss
String fmtDuration(int ms) {
  final s = ms < 0 ? 0 : ms ~/ 1000;
  final h = s ~/ 3600;
  final m = (s ~/ 60) % 60;
  final sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(sec)}';
}
