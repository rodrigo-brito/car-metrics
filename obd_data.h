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

enum class ObdState { Idle, Connecting, Initializing, Connected, Mock, Error };

static const char* obdStateName(ObdState s) {
  switch (s) {
    case ObdState::Idle:         return "parado";
    case ObdState::Connecting:   return "conectando";
    case ObdState::Initializing: return "inicializando";
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
};

// Deriva consumo a partir do MAF e integra a viagem. dtMs = tempo desde a última chamada.
static void deriveAndIntegrate(VehicleData& d, TripData& t, uint32_t dtMs, float afr, float density) {
  if (!isnan(d.mafGs)) {
    d.fuelLph = d.mafGs * 3600.0f / (afr * density);           // g/s -> L/h
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
