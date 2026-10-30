#pragma once
// Transporte Bluetooth Low Energy para o ELM327 (serviço FFF0: FFF1 notify, FFF2 write).
// É o que o KONNWEI usa. Validado com o adaptador real a partir do Mac (tools/ble_probe.py).
#include <NimBLEDevice.h>
#include "obd_elm.h"

void uiSplashHook(const char* line);   // definido no .ino

class ElmBleSource : public ElmBase {
public:
  ElmBleSource(const char* devName) : _devName(devName) {}
  const char* name() const override { return "ELM327 BLE"; }
  const String& scanResults() const { return _scan; }
  int signalDbm() const override { return _client && _client->isConnected() ? _client->getRssi() : 0; }

protected:
  bool linkConnect() override {
    NimBLEDevice::init("esp32-painel");
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);
    NimBLEScan* scan = NimBLEDevice::getScan();
    scan->setActiveScan(true);
    scan->setInterval(45); scan->setWindow(30);

    const NimBLEAdvertisedDevice* target = nullptr;
    NimBLEScanResults results;
    for (int tent = 0; tent < 3 && !target; tent++) {
      Serial.printf("[obd] procurando \"%s\" por BLE (tentativa %d)\n", _devName, tent + 1);
      results = scan->getResults(6000, false);
      _scan = "";
      for (int i = 0; i < results.getCount(); i++) {
        const NimBLEAdvertisedDevice* d = results.getDevice(i);
        String nm = d->getName().c_str();
        bool ffF0 = d->isAdvertisingService(NimBLEUUID("fff0"));
        if (nm.length() || ffF0) {
          String line = (nm.length() ? nm : String("?")) + " " + d->getAddress().toString().c_str() + " " + d->getRSSI() + "dBm" + (ffF0 ? " [fff0]" : "");
          Serial.println("[obd]   " + line); _scan += line + "\n";
        }
        if (!target && (nm.equalsIgnoreCase(_devName) || (nm.length() == 0 && ffF0))) target = d;
      }
      if (!target) scan->clearResults();
    }
    if (!target) { _err = "adaptador BLE nao encontrado"; return false; }

    _client = NimBLEDevice::createClient();
    _client->setConnectTimeout(10000);
    Serial.printf("[obd] conectando em %s %s\n", target->getName().c_str(), target->getAddress().toString().c_str());
    if (!_client->connect(target)) { _err = "conexao BLE falhou"; return false; }
    scan->clearResults();

    NimBLERemoteService* svc = _client->getService("fff0");
    if (!svc) { _err = "servico fff0 ausente"; _client->disconnect(); return false; }
    _rx = svc->getCharacteristic("fff1");
    _tx = svc->getCharacteristic("fff2");
    if (!_tx && _rx && _rx->canWrite()) _tx = _rx;              // alguns clones usam só fff1
    if (!_rx || !_tx) { _err = "caracteristicas fff1/fff2 ausentes"; _client->disconnect(); return false; }
    _self = this;
    if (!_rx->subscribe(true, [](NimBLERemoteCharacteristic*, uint8_t* data, size_t len, bool) {
          for (size_t i = 0; i < len; i++) _self->push(data[i]);
        })) { _err = "subscribe fff1 falhou"; _client->disconnect(); return false; }
    Serial.printf("[obd] BLE conectado, mtu=%d\n", _client->getMTU());
    return true;
  }
  bool linkConnected() override { return _client && _client->isConnected(); }
  void linkWrite(const char* s) override {
    size_t len = strlen(s), mtu = _client->getMTU() - 3; if (mtu < 20) mtu = 20;
    for (size_t off = 0; off < len; off += mtu) {                 // fragmenta se exceder o MTU
      size_t n = min(mtu, len - off);
      _tx->writeValue((const uint8_t*)s + off, n, false);
    }
  }
  int linkRead() override {
    if (_head == _tail) return -1;
    uint8_t c = _buf[_tail]; _tail = (_tail + 1) % sizeof _buf; return c;
  }

private:
  const char* _devName;
  NimBLEClient* _client = nullptr;
  NimBLERemoteCharacteristic *_rx = nullptr, *_tx = nullptr;
  String _scan;
  volatile uint16_t _head = 0, _tail = 0;
  uint8_t _buf[1024];
  static ElmBleSource* _self;
  void push(uint8_t c) { uint16_t nx = (_head + 1) % sizeof _buf; if (nx != _tail) { _buf[_head] = c; _head = nx; } }
};
ElmBleSource* ElmBleSource::_self = nullptr;
