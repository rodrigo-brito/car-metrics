import '../config.dart';

/// Leitura mais recente do veículo. `null` = ainda não lido / não suportado
/// (equivale ao NAN do firmware).
class VehicleData {
  double? rpm; // rotações/min
  double? speedKmh;
  double? coolantC; // temperatura do líquido de arrefecimento
  double? intakeC; // temperatura do ar de admissão
  double? mafGs; // fluxo de ar, g/s
  double? loadPct; // carga do motor
  double? throttlePct;
  double? fuelPct; // nível do tanque
  double? batteryV; // tensão lida pelo adaptador (ATRV)
  double? mapKpa;
  double? timingDeg; // avanço de ignição
  double? stftPct; // correção de combustível curto prazo (banco 1)
  double? ltftPct; // correção de combustível longo prazo (banco 1)
  double? o2s1V; // sonda lambda 1 (pré-catalisador)
  double? o2s2V; // sonda lambda 2 (pós-catalisador)
  int fuelSystem = -1; // PID 03: 1 malha aberta, 2 fechada, 4 aberta por carga, 8/16 falha
  bool milOn = false; // luz de injeção
  int dtcCount = 0; // falhas armazenadas (PID 01)
  double? distMilKm; // distância rodada com a luz acesa
  String obdStd = ''; // PID 1C, texto
  String vin = ''; // modo 09

  /// Códigos de falha (modo 03), lidos sob demanda. [dtcsRead] falso = ainda não lidos.
  List<String> dtcs = [];
  bool dtcsRead = false;
  int dtcsReadAt = 0;

  // derivados
  double? fuelLph; // consumo instantâneo em L/h
  double? kmPerL; // consumo instantâneo em km/L (null se parado)

  int updatedAt = 0; // ms da última leitura

  void reset() {
    rpm = speedKmh = coolantC = intakeC = mafGs = loadPct = throttlePct = null;
    fuelPct = batteryV = mapKpa = timingDeg = stftPct = ltftPct = o2s1V = o2s2V = null;
    fuelSystem = -1;
    milOn = false;
    dtcCount = 0;
    distMilKm = null;
    obdStd = '';
    vin = '';
    dtcs = [];
    dtcsRead = false;
    dtcsReadAt = 0;
    fuelLph = kmPerL = null;
    updatedAt = 0;
  }
}

/// Acumulados da viagem desde a conexão.
class TripData {
  double distanceKm = 0;
  double fuelL = 0;
  double maxSpeed = 0;
  int startMs = 0;
  int movingMs = 0;

  double? get avgKmPerL => fuelL > 0.001 ? distanceKm / fuelL : null;
  double? get avgSpeed => movingMs > 1000 ? distanceKm / (movingMs / 3600000.0) : null;

  void reset(int nowMs) {
    distanceKm = 0;
    fuelL = 0;
    maxSpeed = 0;
    startMs = nowMs;
    movingMs = 0;
  }
}

enum ObdState { idle, connecting, initializing, waitingEcu, connected, mock, error }

String obdStateName(ObdState s) {
  switch (s) {
    case ObdState.idle:
      return 'parado';
    case ObdState.connecting:
      return 'conectando';
    case ObdState.initializing:
      return 'inicializando';
    case ObdState.waitingEcu:
      return 'sem ECU (ignição?)';
    case ObdState.connected:
      return 'conectado';
    case ObdState.mock:
      return 'simulação';
    case ObdState.error:
      return 'erro';
  }
}

String fuelSystemName(int v) {
  switch (v) {
    case 1:
      return 'malha aberta';
    case 2:
      return 'malha fechada';
    case 4:
      return 'aberta (carga)';
    case 8:
      return 'aberta (falha)';
    case 16:
      return 'fechada (falha)';
    default:
      return '--';
  }
}

String obdStdName(int v) {
  switch (v) {
    case 1:
      return 'OBD-II (CARB)';
    case 2:
      return 'OBD (EPA)';
    case 3:
      return 'OBD e OBD-II';
    case 4:
      return 'OBD-I';
    case 6:
      return 'EOBD';
    case 7:
      return 'EOBD e OBD-II';
    case 9:
      return 'EOBD, OBD, OBD-II';
    case 13:
      return 'JOBD';
    default:
      return 'outra';
  }
}

/// Deriva o consumo a partir do MAF e integra a viagem. [dtMs] = tempo desde a última chamada.
/// Sem MAF, estima o fluxo de ar por speed-density com MAP, rpm e temperatura de admissão.
void deriveAndIntegrate(
  VehicleData d,
  TripData t,
  int dtMs, {
  double afr = fuelAfr,
  double density = fuelDensity,
  double displacementL = engineDisplacementL,
  double ve = engineVe,
}) {
  var maf = d.mafGs;
  final map = d.mapKpa;
  final rpm = d.rpm;
  if (maf == null && map != null && rpm != null && rpm > 0) {
    // speed-density: massa de ar por ciclo pela lei dos gases ideais (R = 287 J/kg·K)
    final iatK = (d.intakeC ?? 30.0) + 273.15;
    final airDensity = map * 1000.0 / (287.0 * iatK); // kg/m³
    maf = rpm / 60.0 / 2.0 * (displacementL / 1000.0) * airDensity * ve * 1000.0; // g/s
  }
  if (maf != null) {
    final lph = maf * 3600.0 / (afr * density); // g/s -> L/h
    d.fuelLph = lph;
    final v = d.speedKmh;
    d.kmPerL = (v != null && v > 2 && lph > 0.01) ? v / lph : null;
  }
  final dtH = dtMs / 3600000.0;
  final speed = d.speedKmh;
  if (speed != null) {
    t.distanceKm += speed * dtH;
    if (speed > t.maxSpeed) t.maxSpeed = speed;
    if (speed > 2) t.movingMs += dtMs;
  }
  final lph = d.fuelLph;
  if (lph != null) t.fuelL += lph * dtH;
}
