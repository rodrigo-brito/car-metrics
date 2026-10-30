#pragma once
// Transporte Bluetooth clássico (SPP) para o ELM327. Funciona com adaptadores que
// aceitam pareamento por PIN. O KONNWEI testado não aceita pareamento clássico
// (falha "authentication failed, status:9" em qualquer modo); use obd_ble.h com ele.
#include <BluetoothSerial.h>
#include <esp_gap_bt_api.h>
#include <esp_arduino_version.h>
#include "obd_elm.h"

void uiSplashHook(const char* line);   // definido no .ino

class ElmBtSource : public ElmBase {
public:
  ElmBtSource(const char* btName, const char* pin, const char* mac = nullptr)
    : _btName(btName), _pin(pin), _mac(mac) {}
  const char* name() const override { return "ELM327 BT"; }
  const String& scanResults() const { return _scan; }

protected:
  bool linkConnect() override {
    _bt.begin("esp32-painel", true);                       // modo mestre
    setPin(_pin);
    bool ok = false;
    if (_mac) {
      BTAddress addr = parseMac(_mac);
      Serial.printf("[obd] conectando em %s (canal 1, PIN %s)\n", _mac, _pin);
      ok = _bt.connect(addr, 1, (esp_spp_sec_t)(ESP_SPP_SEC_ENCRYPT | ESP_SPP_SEC_AUTHENTICATE), ESP_SPP_ROLE_MASTER);
      if (!ok) {
        _bt.disconnect(); delay(800);
        Serial.printf("[obd] conectando em %s (sem seguranca no SPP)\n", _mac);
        ok = _bt.connect(addr, 1, ESP_SPP_SEC_NONE, ESP_SPP_ROLE_MASTER);
      }
    } else {
      Serial.printf("[obd] conectando em %s (por nome, ~30 s)\n", _btName);
      ok = _bt.connect(String(_btName));
    }
    if (!ok) { _err = "bluetooth classico nao conectou"; scan(); }
    return ok;
  }
  bool linkConnected() override { return _bt.connected(); }
  void linkWrite(const char* s) override { _bt.print(s); }
  int  linkRead() override { return _bt.available() ? _bt.read() : -1; }

private:
  BluetoothSerial _bt;
  const char *_btName, *_pin, *_mac;
  String _scan;

  void setPin(const char* pin) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    _bt.setPin(pin, strlen(pin));
#else
    _bt.setPin(pin);
#endif
  }
  static BTAddress parseMac(const char* s) {
    uint8_t m[6]; sscanf(s, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx", &m[0], &m[1], &m[2], &m[3], &m[4], &m[5]);
    return BTAddress(m);
  }
  void scan() {
    Serial.println("[obd] varrendo dispositivos bluetooth classico...");
    uiSplashHook("adaptador nao encontrado, varrendo...");
    _scan = "";
    BTScanResults* r = _bt.discover(6000);
    if (!r || r->getCount() == 0) { _scan = "nenhum dispositivo visto"; return; }
    for (int i = 0; i < r->getCount(); i++) {
      BTAdvertisedDevice* d = r->getDevice(i);
      String line = String(d->getName().c_str()) + " " + d->getAddress().toString().c_str() + " " + d->getRSSI() + "dBm";
      Serial.println("[obd]   " + line);
      _scan += line + "\n";
    }
    _bt.discoverClear();
  }
};
