import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Conteúdo de página que se adapta à orientação.
/// Retrato: [left], [right] e [tail] em sequência, numa coluna.
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
              maxScale: 1.25,
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
        // retrato: uma coluna só, também sem rolagem (reduz para caber, como em paisagem)
        return Padding(
          padding: pad,
          child: FitWithoutScroll(
            maxScale: 1.25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...left, ...right, ...tail],
            ),
          ),
        );
      },
    );
  }
}

/// Mostra [child] na largura disponível, na altura natural dele, sem rolagem:
/// - se passar da altura disponível, reduz tudo na mesma proporção;
/// - se sobrar altura, amplia até [maxScale] (montando o filho mais estreito, para a
///   largura final continuar a mesma), para o conteúdo ocupar a tela.
class FitWithoutScroll extends SingleChildRenderObjectWidget {
  const FitWithoutScroll({super.key, required Widget super.child, this.maxScale = 1});
  final double maxScale;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFit(maxScale);

  @override
  void updateRenderObject(BuildContext context, _RenderFit renderObject) => renderObject.maxScale = maxScale;
}

class _RenderFit extends RenderProxyBox {
  _RenderFit(this._maxScale);

  double _maxScale;
  set maxScale(double v) {
    if (v == _maxScale) return;
    _maxScale = v;
    markNeedsLayout();
  }

  double _scale = 1;
  Offset _offset = Offset.zero;

  Matrix4 get _transform => Matrix4.translationValues(_offset.dx, _offset.dy, 0)..scaleByDouble(_scale, _scale, 1, 1);

  @override
  void performLayout() {
    size = constraints.biggest;
    final c = child;
    if (c == null) return;
    final w = size.width;
    c.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
    var h = c.size.height;
    var s = h > size.height ? size.height / h : 1.0;
    if (h > 0 && h < size.height && _maxScale > 1) {
      final k = (size.height / h).clamp(1.0, _maxScale);
      if (k > 1.02) {
        c.layout(BoxConstraints.tightFor(width: w / k), parentUsesSize: true);
        h = c.size.height;
        s = (size.height / h).clamp(0.0, k);
      }
    }
    _scale = s;
    // centralizado na horizontal, colado no topo
    _offset = Offset((w - c.size.width * s) / 2, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    layer =
        context.pushTransform(needsCompositing, offset, _transform, super.paint, oldLayer: layer as TransformLayer?);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transform);
}
