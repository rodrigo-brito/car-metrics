import 'package:flutter/material.dart';

/// Texto que nunca quebra a linha nem é cortado: se não couber na largura, encolhe.
/// Usado nos rótulos e valores do painel, que precisam ficar inteiros em janelas estreitas
/// (tela dividida) e com a fonte do sistema aumentada.
class OneLine extends StatelessWidget {
  const OneLine(this.text, {super.key, this.style, this.alignment = Alignment.centerLeft});
  final String text;
  final TextStyle? style;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}

/// Mostra [child] com pelo menos [minHeight] de altura: se o espaço for menor, monta
/// nessa altura (mantendo a proporção da área) e reduz tudo para caber, em vez de rolar
/// ou estourar.
class MinHeightFit extends StatelessWidget {
  const MinHeightFit({super.key, required this.minHeight, required this.child});
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedHeight || box.maxHeight >= minHeight) return child;
        final k = minHeight / box.maxHeight;
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(width: box.maxWidth * k, height: minHeight, child: child),
          ),
        );
      },
    );
  }
}
