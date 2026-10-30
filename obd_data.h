#pragma once
#include <Arduino.h>

// Leitura mais recente do veículo. NAN = ainda não lido / não suportado.
struct VehicleData {
  float rpm         = NAN;   // rotações/min
  float speedKmh    = NAN;
  float coolantC    = NAN;   // temperatura do líquido de arrefecimento
  float intakeC     = NAN;   // temperatura do ar de admissão
  float mafGs       = NAN;   // fluxo de ar, g/s
  float loadPct     = NAN;   // carga do motor
  float throttlePct = NAN;
  float fuelPct     = NAN;   // nível do tanque
  float batteryV    = NAN;   // tensão lida pelo adaptador (ATRV)
  float mapKpa      = NAN;
  float timingDeg   = NAN;   // avanço de ignição
  float stftPct     = NAN;   // correção de combustível curto prazo (banco 1)
  float ltftPct     = NAN;   // correção de combustível longo prazo (banco 1)
  float o2s1V       = NAN;   // sonda lambda 1 (pré-catalisador)
  float o2s2V       = NAN;   // sonda lambda 2 (pós-catalisador)
  int   fuelSystem  = -1;    // PID 03: 1 malha aberta, 2 fechada, 4 aberta por carga, 8/16 falha
  bool  milOn       = false; // luz de injeção
  int   dtcCount    = 0;     // falhas armazenadas (PID 01)
  float distMilKm   = NAN;   // distância rodada com a luz acesa
  String obdStd;             // PID 1C, texto
  String vin;                // modo 09

  // códigos de falha (modo 03), lidos sob demanda
  String dtcs[8];
  int    nDtcs      = -1;    // -1 = ainda não lidos
  uint32_t dtcsReadAt = 0;

  // derivados
  float fuelLph     = NAN;   // consumo instantâneo em L/h
  float kmPerL      = NAN;   // consumo instantâneo em km/L (NAN se parado)

  uint32_t updatedAt = 0;    // millis() da última leitura
};

// Acumulados da viagem desde o boot
struct TripData {
  float   distanceKm = 0;
  float   fuelL      = 0;
  float   maxSpeed   = 0;
  uint32_t startMs   = 0;
  uint32_t movingMs  = 0;

  float avgKmPerL() const { return fuelL > 0.001f ? distanceKm / fuelL : NAN; }
  float avgSpeed()  const { return movingMs > 1000 ? distanceKm / (movingMs / 3600000.0f) : NAN; }
};

enum class ObdState { Idle, Connecting, Initializing, WaitingEcu, Connected, Mock, Error };

static const char* obdStateName(ObdState s) {
  switch (s) {
    case ObdState::Idle:         return "parado";
    case ObdState::Connecting:   return "conectando";
    case ObdState::Initializing: return "inicializando";
    case ObdState::WaitingEcu:   return "sem ECU (ignicao?)";
    case ObdState::Connected:    return "conectado";
    case ObdState::Mock:         return "simulacao";
    default:                     return "erro";
  }
}

// Interface comum das fontes de dados (mock, ELM327 BT, futuramente BLE)
class ObdSource {
public:
  virtual ~ObdSource() {}
  virtual bool begin() = 0;                    // inicia conexão (pode bloquear alguns segundos)
  virtual void update(VehicleData& d) = 0;     // chamado em loop, atualiza d quando houver dado novo
  virtual ObdState state() const = 0;
  virtual const char* name() const = 0;
  virtual const char* lastError() const { return ""; }
  virtual String protocol() const { return ""; }
  virtual void requestDtcs(VehicleData&) {}            // lê modo 03 e preenche dtcs/nDtcs
  virtual bool clearDtcs(VehicleData&) { return false; } // modo 04
  virtual int  signalDbm() const { return 0; }
};

static const char* fuelSystemName(int v) {
  switch (v) { case 1: return "malha aberta"; case 2: return "malha fechada"; case 4: return "aberta (carga)";
               case 8: return "aberta (falha)"; case 16: return "fechada (falha)"; default: return "--"; }
}
static const char* obdStdName(int v) {
  switch (v) { case 1: return "OBD-II (CARB)"; case 2: return "OBD (EPA)"; case 3: return "OBD e OBD-II"; case 4: return "OBD-I";
               case 6: return "EOBD"; case 7: return "EOBD e OBD-II"; case 9: return "EOBD, OBD, OBD-II"; case 13: return "JOBD";
               default: return "outra"; }
}

// Deriva consumo a partir do MAF e integra a viagem. dtMs = tempo desde a última chamada.
static void deriveAndIntegrate(VehicleData& d, TripData& t, uint32_t dtMs, float afr, float density,
                               float displacementL = 1.6f, float ve = 0.85f) {
  float maf = d.mafGs;
  if (isnan(maf) && !isnan(d.mapKpa) && !isnan(d.rpm) && d.rpm > 0) {
    // speed-density: massa de ar por ciclo pela lei dos gases ideais (R = 287 J/kg·K)
    float iatK = (isnan(d.intakeC) ? 30.0f : d.intakeC) + 273.15f;
    float airDensity = d.mapKpa * 1000.0f / (287.0f * iatK);      // kg/m³
    maf = d.rpm / 60.0f / 2.0f * (displacementL / 1000.0f) * airDensity * ve * 1000.0f;  // g/s
  }
  if (!isnan(maf)) {
    d.fuelLph = maf * 3600.0f / (afr * density);               // g/s -> L/h
    d.kmPerL  = (!isnan(d.speedKmh) && d.speedKmh > 2 && d.fuelLph > 0.01f)
                ? d.speedKmh / d.fuelLph : NAN;
  }
  float dtH = dtMs / 3600000.0f;
  if (!isnan(d.speedKmh)) {
    t.distanceKm += d.speedKmh * dtH;
    if (d.speedKmh > t.maxSpeed) t.maxSpeed = d.speedKmh;
    if (d.speedKmh > 2) t.movingMs += dtMs;
  }
  if (!isnan(d.fuelLph)) t.fuelL += d.fuelLph * dtH;
}
