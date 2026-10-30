// Computador de bordo no ESP32-2432S028 (Cheap Yellow Display)
// Lê dados do carro por um adaptador OBD2 ELM327 (Konnwei, BLE) e mostra em três páginas:
// dirigir, motor e diagnóstico. Toque curto troca de página; na página de diagnóstico,
// segurar 2 s e confirmar apaga as falhas. Sem o carro, roda em simulação (OBD_SOURCE 0).

#include "config.h"
#include "secrets.h"
#include "hw.h"
#include "obd_data.h"
#include "obd_mock.h"
#if OBD_SOURCE == 1
#include "obd_bt.h"
#elif OBD_SOURCE == 2
#include "obd_ble.h"
#endif
#include "ui.h"

VehicleData vehicle;
TripData    trip;
ObdSource*  source = nullptr;
MockSource  mockSource;
#if OBD_SOURCE == 1
#ifndef OBD_BT_MAC
#define OBD_BT_MAC nullptr
#endif
ElmBtSource  elmSource(OBD_BT_NAME, OBD_BT_PIN, OBD_BT_MAC);
#elif OBD_SOURCE == 2
ElmBleSource elmSource(OBD_BT_NAME);
#endif

void uiSplashHook(const char* line) { uiSplash(line); }

Page page = PAGE_DRIVE;
bool armClear = false; uint32_t armClearAt = 0;
uint32_t alertUntil = 0;

void updateLed() {
  static uint32_t last = 0; static bool on = false;
  if (millis() - last >= 500) { last = millis(); on = !on; }
  if (vehicle.milOn && source->state() == ObdState::Connected) { ledRGB(on, on ? false : true, false); return; }  // laranja/verde
  switch (source->state()) {
    case ObdState::Connected:  ledRGB(false, true, false); break;
    case ObdState::Mock:       ledRGB(false, false, true); break;
    case ObdState::Error:      ledRGB(on, false, false);   break;
    default:                   ledRGB(on, on, false);      break;
  }
}

void showPage(bool full) {
  static bool blink = false; blink = !blink;
  if (full) tft.fillScreen(UI_BG);
  uiStatusBar(*source, vehicle, trip, page, blink);
  String scan;
#if OBD_SOURCE >= 1
  if (source == &elmSource) scan = elmSource.scanResults();
#endif
  switch (page) {
    case PAGE_DRIVE:  uiPageDrive(vehicle, trip); break;
    case PAGE_ENGINE: uiPageEngine(vehicle); break;
    default:          uiPageDiag(*source, vehicle, armClear, scan); break;
  }
}

void gotoPage(Page p) {
  page = p; armClear = false;
  if (page == PAGE_DIAG) { vehicle.nDtcs = -1; showPage(true); source->requestDtcs(vehicle); }
  showPage(true);
}

// alertas: cada condição dispara uma vez e rearma quando volta ao normal
void checkAlerts() {
  static bool aCool = false, aBatt = false, aMil = false;
  bool engineOn = !isnan(vehicle.rpm) && vehicle.rpm > 400;
  if (!isnan(vehicle.coolantC) && vehicle.coolantC > ALERT_COOLANT_C) {
    if (!aCool) { aCool = true; uiAlert("MOTOR QUENTE", fmt(vehicle.coolantC, 0) + " C", UI_BAD); alertUntil = millis() + ALERT_SHOW_MS; }
  } else aCool = false;
  if (engineOn && !isnan(vehicle.batteryV) && vehicle.batteryV < ALERT_BATTERY_V) {
    if (!aBatt) { aBatt = true; uiAlert("BATERIA BAIXA", fmt(vehicle.batteryV, 1) + " V", UI_WARN); alertUntil = millis() + ALERT_SHOW_MS; }
  } else if (!isnan(vehicle.batteryV) && vehicle.batteryV >= ALERT_BATTERY_V + 0.3f) aBatt = false;
  if (vehicle.milOn) {
    if (!aMil) { aMil = true; uiAlert("LUZ DE INJECAO", String(vehicle.dtcCount) + (vehicle.dtcCount == 1 ? " falha" : " falhas"), UI_WARN); alertUntil = millis() + ALERT_SHOW_MS; }
  } else aMil = false;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== computador de bordo ===");
  hwBegin();
  uiBegin();

#if OBD_SOURCE >= 1
  uiSplash((String("procurando ") + OBD_BT_NAME + (OBD_SOURCE == 2 ? " via BLE..." : " via bluetooth...")).c_str());
  source = &elmSource;
  if (!source->begin()) {
    Serial.printf("[obd] falhou: %s\n", source->lastError());
#if OBD_FALLBACK_TO_MOCK
    uiSplash("sem adaptador, entrando em simulacao"); delay(1500);
    source = &mockSource; source->begin();
#endif
  }
#else
  uiSplash("modo simulacao"); delay(800);
  source = &mockSource; source->begin();
#endif

  trip.startMs = millis();
  showPage(true);
}

void loop() {
  static uint32_t lastUi = 0, lastIntegrate = millis();
  uint32_t now = millis();

  source->update(vehicle);
  deriveAndIntegrate(vehicle, trip, now - lastIntegrate, FUEL_AFR, FUEL_DENSITY, ENGINE_DISPLACEMENT_L, ENGINE_VE);
  lastIntegrate = now;

  // toque: curto troca página; longo na página de diagnóstico arma o apagamento, curto confirma
  TouchEvent ev = touchPoll();
  if (Serial.available() && Serial.peek() == 'P') { Serial.read(); ev = TOUCH_TAP; }     // testes pelo serial
  if (Serial.available() && Serial.peek() == 'L') { Serial.read(); ev = TOUCH_LONG; }
  if (alertUntil && now < alertUntil) { if (ev != TOUCH_NONE) alertUntil = 0; ev = TOUCH_NONE; }  // toque dispensa o alerta
  if (ev == TOUCH_LONG && page == PAGE_DIAG) { armClear = true; armClearAt = now; showPage(false); }
  else if (ev == TOUCH_TAP) {
    if (page == PAGE_DIAG && armClear) {
      bool ok = source->clearDtcs(vehicle);
      Serial.printf("[obd] apagar falhas: %s\n", ok ? "ok" : "falhou");
      armClear = false; vehicle.nDtcs = -1; showPage(true); source->requestDtcs(vehicle); showPage(false);
    } else gotoPage((Page)((page + 1) % PAGE_COUNT));
  }
  if (armClear && now - armClearAt > 5000) { armClear = false; showPage(false); }

  if (alertUntil) {
    if (now >= alertUntil) { alertUntil = 0; showPage(true); }
  } else {
    checkAlerts();
    if (!alertUntil && now - lastUi >= UI_REFRESH_MS) { lastUi = now; showPage(false); }
  }

  updateLed();
  uiScreenshotIfRequested();

  static uint32_t lastLog = 0;
  if (now - lastLog >= 2000) {
    lastLog = now;
    Serial.printf("[%s] %3.0f km/h  %4.0f rpm  %4.1f km/l  motor %3.0fC  %4.1fV  trim %+.1f/%+.1f  mil=%d  trip %.2f km\n",
                  obdStateName(source->state()), vehicle.speedKmh, vehicle.rpm, vehicle.kmPerL,
                  vehicle.coolantC, vehicle.batteryV, vehicle.stftPct, vehicle.ltftPct, vehicle.milOn, trip.distanceKm);
  }
  delay(5);
}
