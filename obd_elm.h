#pragma once
// Fonte ELM327 via Bluetooth clássico (SPP). Konnwei KW902 e similares.
// Para adaptadores BLE (KW903 / "iOS"), implementar uma fonte com NimBLE
// seguindo esta mesma interface.
#include <BluetoothSerial.h>
#include "obd_data.h"
#include "config.h"

void uiSplashHook(const char* line);   // definido no .ino

class ElmSource : public ObdSource {
public:
  ElmSource(const char* btName, const char* pin, const char* mac = nullptr)
    : _btName(btName), _pin(pin), _mac(mac) {}

  ObdState state() const override { return _state; }
  const char* name() const override { return "ELM327 BT"; }
  const char* lastError() const override { return _err.c_str(); }
  String protocol() const override { return _protocol; }
  const String& scanResults() const { return _scan; }   // "nome mac rssi" por linha

  // varre dispositivos Bluetooth clássico por ~6 s e registra nome, MAC e sinal
  void scan() {
    Serial.println("[obd] varrendo dispositivos bluetooth...");
    uiSplashHook("adaptador nao encontrado, varrendo...");
    _scan = "";
    BTScanResults* r = _bt.discover(6000);
    if (!r || r->getCount() == 0) { _scan = "nenhum dispositivo visto"; Serial.println("[obd] nada encontrado"); return; }
    for (int i = 0; i < r->getCount(); i++) {
      BTAdvertisedDevice* d = r->getDevice(i);
      String line = String(d->getName().c_str()) + " " + d->getAddress().toString().c_str() + " " + d->getRSSI() + "dBm";
      Serial.println("[obd]   " + line);
      _scan += line + "\n";
    }
    _bt.discoverClear();
  }

  bool begin() override {
    _state = ObdState::Connecting;
    _bt.begin("esp32-painel", true);                       // modo mestre
    _bt.setPin(_pin, strlen(_pin));
    bool ok = false;
    int tentativas = _mac ? 3 : 1;                         // por nome já inclui uma busca de ~30 s
    for (int tent = 0; tent < tentativas && !ok; tent++) {
      Serial.printf("[obd] conectando em %s (tentativa %d)\n", _mac ? _mac : _btName, tent + 1);
      ok = _mac ? _bt.connect(parseMac(_mac)) : _bt.connect(String(_btName));
      if (!ok) delay(1500);
    }
    if (!ok) {
      _err = "bluetooth nao conectou";
      scan();                                              // lista o que há por perto para ajudar a configurar
      _state = ObdState::Error;
      return false;
    }

    _state = ObdState::Initializing;
    if (!init()) { _state = ObdState::Error; return false; }
    _state = ObdState::Connected;
    return true;
  }

  void update(VehicleData& d) override {
    if (_state != ObdState::Connected) return;
    if (!_bt.connected()) { _err = "bluetooth caiu"; _state = ObdState::Error; return; }
    uint32_t now = millis();

    if (now - _lastFast >= OBD_FAST_MS) {
      _lastFast = now;
      readPid(0x0C, d.rpm,      [](uint8_t* b, int n){ return n >= 2 ? (b[0] * 256 + b[1]) / 4.0f : NAN; });
      readPid(0x0D, d.speedKmh, [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; });
      if (_hasMaf) readPid(0x10, d.mafGs, [](uint8_t* b, int n){ return n >= 2 ? (b[0] * 256 + b[1]) / 100.0f : NAN; });
      d.updatedAt = now;
    }
    if (now - _lastSlow >= OBD_SLOW_MS) {
      _lastSlow = now;
      switch (_slowIdx++ % 7) {
        case 0: readPid(0x05, d.coolantC,    [](uint8_t* b, int n){ return n >= 1 ? b[0] - 40.0f : NAN; }); break;
        case 1: readPid(0x2F, d.fuelPct,     [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; }); break;
        case 2: readVoltage(d.batteryV); break;
        case 3: readPid(0x0F, d.intakeC,     [](uint8_t* b, int n){ return n >= 1 ? b[0] - 40.0f : NAN; }); break;
        case 4: readPid(0x04, d.loadPct,     [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; }); break;
        case 5: readPid(0x11, d.throttlePct, [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; }); break;
        case 6: readPid(0x0B, d.mapKpa,      [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; }); break;
      }
    }
  }

private:
  BluetoothSerial _bt;
  const char *_btName, *_pin, *_mac;
  ObdState _state = ObdState::Idle;
  String _err, _protocol, _scan;
  bool _hasMaf = true;
  uint32_t _lastFast = 0, _lastSlow = 0;
  int _slowIdx = 0;

  static BTAddress parseMac(const char* s) {
    uint8_t m[6]; sscanf(s, "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx", &m[0], &m[1], &m[2], &m[3], &m[4], &m[5]);
    return BTAddress(m);
  }

  // envia comando e lê até o prompt '>'
  String cmd(const String& c, uint32_t timeout = 1500) {
    while (_bt.available()) _bt.read();
    _bt.print(c); _bt.print('\r');
    String r; uint32_t t0 = millis();
    while (millis() - t0 < timeout) {
      while (_bt.available()) {
        char ch = _bt.read();
        if (ch == '>') { r.trim(); return r; }
        if (ch != '\0') r += ch;
      }
      delay(2);
    }
    r.trim(); return r;
  }

  bool init() {
    const char* seq[] = { "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0", "ATAT1" };
    for (auto c : seq) { String r = cmd(c, c[2] == 'Z' ? 3000 : 1500); Serial.printf("[obd] %s -> %s\n", c, r.c_str()); }
    String r = cmd("0100", 8000);                          // força busca de protocolo
    Serial.printf("[obd] 0100 -> %s\n", r.c_str());
    if (r.indexOf("41") < 0) { _err = "ECU nao respondeu (ignicao ligada?)"; return false; }
    _protocol = cmd("ATDPN");
    // bit do MAF (PID 0x10) na resposta de 0100: byte B bit 0
    uint8_t b[4]; int n = parse(r, 0x00, b, 4);
    if (n >= 2) _hasMaf = (b[1] & 0x01);
    Serial.printf("[obd] protocolo=%s maf=%d\n", _protocol.c_str(), _hasMaf);
    return true;
  }

  // procura "41 <pid>" na resposta e devolve os bytes de dados
  static int parse(String r, uint8_t pid, uint8_t* out, int max) {
    r.replace(" ", ""); r.replace("\r", ""); r.replace("\n", "");
    char tag[5]; snprintf(tag, sizeof tag, "41%02X", pid);
    int i = r.indexOf(tag);
    if (i < 0) return -1;
    i += 4; int n = 0;
    while (n < max && i + 1 < (int)r.length() && isxdigit(r[i]) && isxdigit(r[i + 1])) {
      out[n++] = strtol(r.substring(i, i + 2).c_str(), nullptr, 16); i += 2;
    }
    return n;
  }

  template <typename F>
  void readPid(uint8_t pid, float& dst, F conv) {
    char c[5]; snprintf(c, sizeof c, "01%02X", pid);
    String r = cmd(c, 800);
    uint8_t b[8]; int n = parse(r, pid, b, 8);
    if (n > 0) dst = conv(b, n);
    else if (r.indexOf("NO DATA") >= 0 || r.indexOf("UNABLE") >= 0) dst = NAN;
  }

  void readVoltage(float& dst) {
    String r = cmd("ATRV", 800);            // ex: "14.2V"
    r.replace("V", ""); r.trim();
    float v = r.toFloat();
    if (v > 5 && v < 20) dst = v;
  }
};
