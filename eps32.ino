// Computador de bordo no ESP32-2432S028 (Cheap Yellow Display)
// Lê dados do carro por um adaptador OBD2 ELM327 (Konnwei) via Bluetooth
// e mostra velocidade, rpm, consumo, temperatura, tanque, bateria e viagem.
// Sem o carro, roda em modo simulação (OBD_SOURCE 0 em config.h).

#include "config.h"
#include "secrets.h"
#include "hw.h"
#include "obd_data.h"
#include "obd_mock.h"
#if OBD_SOURCE == 1
#include "obd_elm.h"
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
ElmSource   elmSource(OBD_BT_NAME, OBD_BT_PIN, OBD_BT_MAC);
#endif

void uiSplashHook(const char* line) { uiSplash(line); }

enum Page { PAGE_DASH, PAGE_INFO };
Page page = PAGE_DASH;

void updateLed() {
  static uint32_t last = 0; static bool on = false;
  if (millis() - last >= 500) { last = millis(); on = !on; }
  switch (source->state()) {
    case ObdState::Connected: ledRGB(false, true, false); break;
    case ObdState::Mock:      ledRGB(false, false, true); break;
    case ObdState::Error:     ledRGB(on, false, false);   break;
    default:                  ledRGB(on, on, false);      break;
  }
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== computador de bordo ===");
  hwBegin();
  uiBegin();

#if OBD_SOURCE == 1
  uiSplash((String("procurando ") + OBD_BT_NAME + " via bluetooth...").c_str());
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
  tft.fillScreen(UI_BG);
}

void loop() {
  static uint32_t lastUi = 0, lastIntegrate = millis();
  uint32_t now = millis();

  source->update(vehicle);
  deriveAndIntegrate(vehicle, trip, now - lastIntegrate, FUEL_AFR, FUEL_DENSITY);
  lastIntegrate = now;

  if (touchTapped()) {
    page = page == PAGE_DASH ? PAGE_INFO : PAGE_DASH;
    tft.fillScreen(UI_BG);
    lastUi = 0;
  }

  if (now - lastUi >= UI_REFRESH_MS) {
    lastUi = now;
    if (page == PAGE_DASH) uiDashboard(*source, vehicle, trip);
    else {
      uiInfo(*source, vehicle, trip);
#if OBD_SOURCE == 1
      uiScanList(elmSource.scanResults());
#endif
    }
  }

  updateLed();

  uiScreenshotIfRequested();

  static uint32_t lastLog = 0;
  if (now - lastLog >= 2000) {
    lastLog = now;
    Serial.printf("[%s] %3.0f km/h  %4.0f rpm  %4.1f km/l  motor %3.0fC  tanque %2.0f%%  %4.1fV  trip %.2f km\n",
                  obdStateName(source->state()), vehicle.speedKmh, vehicle.rpm, vehicle.kmPerL,
                  vehicle.coolantC, vehicle.fuelPct, vehicle.batteryV, trip.distanceKm);
  }
  delay(5);
}
