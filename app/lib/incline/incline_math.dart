import 'dart:math' as math;

/// Vetor 3D no referencial do celular (x para a direita da tela em retrato, y para o topo,
/// z saindo da tela), o mesmo do acelerômetro do Android.
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  Vec3 get unit {
    final l = length;
    return l == 0 ? this : this * (1 / l);
  }

  List<double> toList() => [x, y, z];
  static Vec3 fromList(List<double> l) => Vec3(l[0], l[1], l[2]);
}

/// Inclinação do carro em graus.
class Incline {
  const Incline(this.pitchDeg, this.rollDeg);

  /// Longitudinal: positivo = frente para cima (subida).
  final double pitchDeg;

  /// Lateral: positivo = tombado para a direita (rodas da direita mais baixas).
  final double rollDeg;
}

double _sgn(double v) => v < 0 ? -1 : 1;

/// Referencial do carro escrito em coordenadas do celular: para cima, para a direita e
/// para a frente. Sai da leitura do acelerômetro com o carro parado no plano, porque o
/// acelerômetro parado mede a reação à gravidade, que aponta para cima.
///
/// Supõe a tela virada para o motorista: o eixo horizontal da tela, como ela é vista,
/// é o eixo lateral do carro. Funciona em retrato, em paisagem e com o celular deitado
/// no console (topo apontando para a frente).
class CarFrame {
  const CarFrame(this.up, this.right, this.forward);
  final Vec3 up;
  final Vec3 right;
  final Vec3 forward;

  factory CarFrame.fromGravity(Vec3 gravity) {
    final up = gravity.unit;
    // a direita da tela como vista: em retrato é ±x, em paisagem é ±y
    final Vec3 screenRight = up.y.abs() >= up.x.abs()
        ? Vec3(_sgn(up.y), 0, 0)
        : Vec3(0, -_sgn(up.x), 0);
    final right = (screenRight - up * screenRight.dot(up)).unit;
    final forward = up.cross(right);
    return CarFrame(up, right, forward);
  }

  /// Orientação aproximada do celular (qual eixo aponta para cima): 0 retrato, 1 de cabeça
  /// para baixo, 2 e 3 paisagem. Serve para perceber quando a tela girou.
  static int orientationOf(Vec3 g) =>
      g.y.abs() >= g.x.abs() ? (g.y >= 0 ? 0 : 1) : (g.x >= 0 ? 2 : 3);

  /// Sem calibração: supõe o celular em pé no suporte, na orientação em que está.
  factory CarFrame.assumeUpright(Vec3 gravity) {
    final ideal = gravity.y.abs() >= gravity.x.abs() ? Vec3(0, _sgn(gravity.y), 0) : Vec3(_sgn(gravity.x), 0, 0);
    return CarFrame.fromGravity(ideal);
  }

  /// Inclinação a partir da leitura (filtrada) do acelerômetro.
  Incline measure(Vec3 gravity) {
    final n = gravity.unit;
    double asinDeg(double v) => math.asin(v.clamp(-1.0, 1.0)) * 180 / math.pi;
    return Incline(asinDeg(n.dot(forward)), -asinDeg(n.dot(right)));
  }

  List<double> toList() => [...up.toList(), ...right.toList(), ...forward.toList()];

  static CarFrame? fromList(List<double>? l) {
    if (l == null || l.length != 9) return null;
    return CarFrame(Vec3.fromList(l.sublist(0, 3)), Vec3.fromList(l.sublist(3, 6)), Vec3.fromList(l.sublist(6, 9)));
  }
}

/// Filtro passa-baixa exponencial, para a leitura não pular com buracos e acelerações.
class LowPass {
  LowPass({this.alpha = 0.08});
  final double alpha;
  Vec3? _v;
  Vec3? get value => _v;

  /// Descarta o histórico e começa da amostra [s].
  void reset(Vec3 s) => _v = s;

  Vec3 add(Vec3 s) {
    final v = _v;
    return _v = v == null ? s : v + (s - v) * alpha;
  }
}
