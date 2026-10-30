#pragma once
#include "obd_data.h"

// Simula um ciclo urbano/rodoviário com física simplificada, para
// desenvolver a interface sem o carro.
class MockSource : public ObdSource {
public:
  bool begin() override { _last = millis(); _state = ObdState::Mock; randomSeed(esp_random()); pickTarget(); return true; }
  ObdState state() const override { return _state; }
  const char* name() const override { return "Mock"; }
  String protocol() const override { return "simulacao"; }

  void update(VehicleData& d) override {
    uint32_t now = millis();
    float dt = (now - _last) / 1000.0f;
    if (dt < 0.05f) return;
    _last = now;

    // alvo de velocidade muda a cada "trecho"
    if (now > _nextChange) pickTarget();

    // aproxima da velocidade alvo com aceleração limitada
    float diff = _target - _speed;
    float accel = constrain(diff * 0.6f, -4.5f, 2.5f);          // m/s²
    _speed += accel * 3.6f * dt;
    if (_speed < 0) _speed = 0;
    _speed += (random(-10, 11) / 10.0f) * dt;                   // tremidinha

    // marcha e rpm
    float ratios[] = { 0, 120, 70, 48, 36, 29, 24 };            // rpm por km/h
    int gear = 1;
    if (_speed > 95) gear = 6; else if (_speed > 70) gear = 5; else if (_speed > 50) gear = 4;
    else if (_speed > 30) gear = 3; else if (_speed > 12) gear = 2;
    float rpm = _speed < 2 ? 850 + random(-30, 30) : _speed * ratios[gear] + random(-40, 40);
    if (accel > 0.5f) rpm += accel * 600;
    rpm = constrain(rpm, 700, 6500);

    // carga e MAF (motor 1.6L, VE variável)
    float load = _speed < 2 ? 0.18f : constrain(0.2f + accel * 0.2f + _speed / 250.0f, 0.15f, 0.95f);
    float maf  = rpm / 60.0f * 0.8f * 1.2f * load * 0.7f;       // g/s (1.6L, 4 tempos, VE ~70%)

    // temperaturas: motor esquenta até ~90 °C
    _coolant += (90.0f - _coolant) * 0.004f * dt * 10;
    _intake   = 28 + (_speed > 40 ? -2 : 3) + random(-10, 10) / 10.0f;

    // combustível cai devagar, tensão oscila
    _fuel -= maf / (FUEL_AFR * FUEL_DENSITY) * dt / 50.0f * 100;
    if (_fuel < 5) _fuel = 62;
    float batt = 14.1f + random(-8, 8) / 100.0f - (accel > 1.5f ? 0.2f : 0);

    d.rpm = rpm; d.speedKmh = _speed; d.coolantC = _coolant; d.intakeC = _intake;
    d.mafGs = maf; d.loadPct = load * 100; d.throttlePct = constrain(load * 100 + 5, 0, 100);
    d.fuelPct = NAN; d.batteryV = batt; d.mapKpa = 30 + load * 70;
    // dados de motor
    d.timingDeg = 8 + load * 20 + (rpm - 800) / 400.0f;
    d.stftPct   = 2.0f * sin(now / 1500.0f) + random(-10, 10) / 10.0f;
    d.ltftPct   = 3.5f + random(-3, 3) / 10.0f;
    d.o2s1V     = 0.45f + 0.4f * sin(now / 350.0f);
    d.o2s2V     = 0.62f + random(-2, 2) / 100.0f;
    d.fuelSystem = _coolant < 60 ? 1 : (accel > 1.8f ? 4 : 2);
    d.obdStd = "OBD-II (CARB)"; d.vin = "9BRTR4MOCK0000001";
    // após 45 s acende a luz de injeção para exercitar alerta e página de diagnóstico
    bool mil = now > 45000 && !_milCleared;
    d.milOn = mil; d.dtcCount = mil ? 1 : 0; d.distMilKm = mil ? (now - 45000) / 1000.0f * 0.02f : 0;
    d.updatedAt = now;
  }
  void requestDtcs(VehicleData& d) override { d.nDtcs = d.milOn ? 1 : 0; d.dtcs[0] = "P0171"; d.dtcsReadAt = millis(); }
  bool clearDtcs(VehicleData& d) override { d.nDtcs = 0; d.milOn = false; d.dtcCount = 0; _milCleared = true; return true; }
  int signalDbm() const override { return -55; }

private:
  void pickTarget() {
    int r = random(100);
    if (r < 15)      _target = 0;                     // semáforo
    else if (r < 55) _target = random(25, 60);        // cidade
    else if (r < 85) _target = random(60, 95);        // avenida
    else             _target = random(95, 125);       // rodovia
    _nextChange = millis() + random(6000, 18000);
  }
  ObdState _state = ObdState::Idle;
  uint32_t _last = 0, _nextChange = 0;
  float _speed = 0, _target = 0, _coolant = 32, _intake = 28, _fuel = 62;
  bool _milCleared = false;
};
