import 'dart:math';

import 'package:flutter/material.dart';

/// Amplia o conteúdo em telas grandes (tablets) na mesma proporção, para os indicadores
/// ocuparem a tela em vez de ficarem do tamanho do celular no meio de um espaço vazio.
///
/// O [child] é montado como se a tela tivesse o lado menor de [referenceShortSide] dp
/// e depois ampliado até o tamanho real. Celulares (lado menor até ~[referenceShortSide])
/// ficam como estão.
class ScreenScale extends StatelessWidget {
  const ScreenScale({
    super.key,
    required this.child,
    this.referenceShortSide = 400,
    this.referenceLongSide = 700,
    this.maxFactor = 2.4,
  });
  final Widget child;
  final double referenceShortSide;
  final double referenceLongSide;
  final double maxFactor;

  /// Fator de ampliação para uma área de [size] dp.
  static double factorFor(
    Size size, {
    double referenceShortSide = 400,
    double referenceLongSide = 700,
    double maxFactor = 2.4,
  }) {
    // o lado maior também limita: numa janela quase quadrada (tela dividida) ampliar só
    // pelo lado menor deixaria a área útil apertada demais
    final f = min(size.shortestSide / referenceShortSide, size.longestSide / referenceLongSide);
    return f < 1 ? 1 : (f > maxFactor ? maxFactor : f);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedWidth || !box.hasBoundedHeight) return child;
        final s = factorFor(
          box.biggest,
          referenceShortSide: referenceShortSide,
          referenceLongSide: referenceLongSide,
          maxFactor: maxFactor,
        );
        if (s <= 1.05) return child;
        final w = box.maxWidth / s;
        final h = box.maxHeight / s;
        final mq = MediaQuery.of(context);
        // FittedBox só amplia se o próprio tamanho dele for a área toda
        return SizedBox(
          width: box.maxWidth,
          height: box.maxHeight,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: w,
              height: h,
              child: MediaQuery(
                data: mq.copyWith(
                  size: Size(w, h),
                  padding: mq.padding / s,
                  viewPadding: mq.viewPadding / s,
                  viewInsets: mq.viewInsets / s,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
