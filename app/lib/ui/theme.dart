import 'package:flutter/material.dart';

/// Paleta do painel, convertida do RGB565 de `ui.h`.
class Palette {
  Palette._();
  static const bg = Color(0xFF000000);
  static const panel = Color(0xFF101410);
  static const line = Color(0xFF212421);
  static const txt = Color(0xFFF7F3F7);
  static const muted = Color(0xFF8A888A);
  static const accent = Color(0xFF00FFFF); // ciano
  static const ok = Color(0xFF00FF42); // verde
  static const warn = Color(0xFFFFA500); // laranja
  static const bad = Color(0xFFFF0000); // vermelho
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Colors.black,
    secondary: Palette.ok,
    onSecondary: Colors.black,
    surface: Palette.panel,
    onSurface: Palette.txt,
    error: Palette.bad,
    onError: Colors.black,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: Palette.bg);
  return base.copyWith(
    dividerColor: Palette.line,
    textTheme: base.textTheme.apply(bodyColor: Palette.txt, displayColor: Palette.txt),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.panel,
      contentTextStyle: TextStyle(color: Palette.txt),
    ),
  );
}
