import 'package:flutter/material.dart';

/// Conteúdo de página que se adapta à orientação.
/// Retrato: rola [left], [right] e [tail] em sequência.
/// Paisagem: duas colunas lado a lado ([tail] vai ao pé da esquerda), sem rolagem; se não
/// couber na altura, o conjunto é reduzido para caber inteiro na tela.
class TwoColumnList extends StatelessWidget {
  const TwoColumnList({super.key, required this.left, required this.right, this.tail = const [], this.padding});
  final List<Widget> left;
  final List<Widget> right;
  final List<Widget> tail;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 16);
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth > box.maxHeight) {
          final landPad = EdgeInsets.fromLTRB(pad.left, 6, pad.right, 6);
          // em paisagem o divisor que separa as metades em retrato sobra no topo da direita
          final r = right.skipWhile((w) => w is Divider).toList();
          return Padding(
            padding: landPad,
            child: FitWithoutScroll(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...left, ...tail],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: r,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(padding: pad, children: [...left, ...right, ...tail]);
      },
    );
  }
}

/// Mostra [child] na largura disponível, na altura natural dele; se passar da altura
/// disponível, reduz tudo na mesma proporção em vez de rolar.
class FitWithoutScroll extends StatelessWidget {
  const FitWithoutScroll({super.key, required this.child, this.alignment = Alignment.topCenter});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SizedBox(width: box.maxWidth, child: child),
      ),
    );
  }
}
