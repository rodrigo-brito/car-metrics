#pragma once
// Protocolo ELM327 independente do transporte. As fontes concretas (Bluetooth clássico
// em obd_bt.h, BLE em obd_ble.h) só implementam o link: conectar, escrever, ler bytes.
#include "obd_data.h"
#include "config.h"

class ElmBase : public ObdSource {
public:
  ObdState state() const override { return _state; }
  const char* lastError() const override { return _err.c_str(); }
  String protocol() const override { return _protocol; }

  bool begin() override {
    _state = ObdState::Connecting;
    if (!linkConnect()) { _state = ObdState::Error; return false; }
    _state = ObdState::Initializing;
    if (!initAdapter()) { _state = ObdState::Error; return false; }
    // adaptador ok; a ECU pode estar dormindo (ignição desligada): fica aguardando e tenta de novo no update()
    _state = initEcu() ? ObdState::Connected : ObdState::WaitingEcu;
    return true;
  }

  void update(VehicleData& d) override {
    if (_state != ObdState::Connected && _state != ObdState::WaitingEcu) return;
    if (!linkConnected()) { _err = "conexao caiu"; _state = ObdState::Error; return; }
    uint32_t now = millis();
    if (_state == ObdState::WaitingEcu) {
      if (now - _lastEcuTry >= 5000) { _lastEcuTry = now; if (initEcu()) _state = ObdState::Connected; }
      return;
    }
    if (!_staticDone) { _staticDone = true; readStatic(d); }

    if (now - _lastFast >= OBD_FAST_MS) {
      _lastFast = now;
      if (has(0x0C)) readPid(0x0C, d.rpm,      [](uint8_t* b, int n){ return n >= 2 ? (b[0] * 256 + b[1]) / 4.0f : NAN; });
      if (has(0x0D)) readPid(0x0D, d.speedKmh, [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; });
      if (has(0x10)) readPid(0x10, d.mafGs,    [](uint8_t* b, int n){ return n >= 2 ? (b[0] * 256 + b[1]) / 100.0f : NAN; });
      else if (has(0x0B)) readPid(0x0B, d.mapKpa, [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; });
      d.updatedAt = now;
    }
    if (now - _lastSlow >= OBD_SLOW_MS) {
      _lastSlow = now;
      switch (_slowIdx++ % 13) {
        case 0:  if (has(0x05)) readPid(0x05, d.coolantC,    [](uint8_t* b, int n){ return n >= 1 ? b[0] - 40.0f : NAN; }); break;
        case 1:  readVoltage(d.batteryV); break;
        case 2:  if (has(0x01)) readMil(d); break;
        case 3:  if (has(0x0F)) readPid(0x0F, d.intakeC,     [](uint8_t* b, int n){ return n >= 1 ? b[0] - 40.0f : NAN; }); break;
        case 4:  if (has(0x04)) readPid(0x04, d.loadPct,     [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; }); break;
        case 5:  if (has(0x11)) readPid(0x11, d.throttlePct, [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; }); break;
        case 6:  if (has(0x06)) readPid(0x06, d.stftPct,     [](uint8_t* b, int n){ return n >= 1 ? (b[0] - 128) * 100.0f / 128 : NAN; }); break;
        case 7:  if (has(0x07)) readPid(0x07, d.ltftPct,     [](uint8_t* b, int n){ return n >= 1 ? (b[0] - 128) * 100.0f / 128 : NAN; }); break;
        case 8:  if (has(0x0E)) readPid(0x0E, d.timingDeg,   [](uint8_t* b, int n){ return n >= 1 ? b[0] / 2.0f - 64 : NAN; }); break;
        case 9:  if (has(0x14)) readPid(0x14, d.o2s1V,       [](uint8_t* b, int n){ return n >= 1 ? b[0] / 200.0f : NAN; }); break;
        case 10: if (has(0x15)) readPid(0x15, d.o2s2V,       [](uint8_t* b, int n){ return n >= 1 ? b[0] / 200.0f : NAN; }); break;
        case 11: if (has(0x03)) { float v = NAN; readPid(0x03, v, [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; }); d.fuelSystem = isnan(v) ? -1 : (int)v; } break;
        case 12: if (has(0x2F)) readPid(0x2F, d.fuelPct,     [](uint8_t* b, int n){ return n >= 1 ? b[0] * 100.0f / 255 : NAN; });
                 else if (has(0x21)) readPid(0x21, d.distMilKm, [](uint8_t* b, int n){ return n >= 2 ? (float)(b[0] * 256 + b[1]) : NAN; });
                 break;
      }
    }
  }

  // modo 03: códigos de falha armazenados
  void requestDtcs(VehicleData& d) override {
    if (_state != ObdState::Connected) return;
    String r = cmd("03", 3000);
    Serial.printf("[obd] 03 -> %s\n", r.c_str());
    d.nDtcs = 0; d.dtcsReadAt = millis();
    String h = r; h.replace(" ", ""); h.replace("\r", ""); h.replace("\n", "");
    int i = h.indexOf("43");
    if (i < 0) return;
    i += 2;
    if (_protocol.length() && (_protocol[0] == 'A' || _protocol[_protocol.length() - 1] >= '6')) i += 2;  // CAN: byte de contagem
    while (i + 3 < (int)h.length() && d.nDtcs < 8) {
      String code = decodeDtc(h.substring(i, i + 4));
      i += 4;
      if (code == "P0000") continue;
      d.dtcs[d.nDtcs++] = code;
    }
  }
  bool clearDtcs(VehicleData& d) override {
    if (_state != ObdState::Connected) return false;
    String r = cmd("04", 3000);
    Serial.printf("[obd] 04 -> %s\n", r.c_str());
    bool ok = r.indexOf("44") >= 0 || r.indexOf("OK") >= 0;
    if (ok) { d.nDtcs = 0; d.milOn = false; d.dtcCount = 0; }
    return ok;
  }

  // PIDs que a ECU declarou suportar (0100 / 0120 / 0140)
  bool has(uint8_t pid) const { return pid >= 1 && pid <= 0x60 && (_supported[(pid - 1) / 32] >> (31 - ((pid - 1) % 32))) & 1; }
  String supportedList() const {
    String s; for (int p = 1; p <= 0x60; p++) if (has(p)) { char b[4]; snprintf(b, 4, "%02X ", p); s += b; } return s;
  }

protected:
  // ---- link a implementar pelo transporte ----
  virtual bool linkConnect() = 0;
  virtual bool linkConnected() = 0;
  virtual void linkWrite(const char* s) = 0;
  virtual int  linkRead() = 0;            // -1 se nada disponível
  virtual void linkFlush() { while (linkRead() >= 0) {} }

  ObdState _state = ObdState::Idle;
  String _err, _protocol;
  uint32_t _supported[3] = { 0, 0, 0 };
  uint32_t _lastFast = 0, _lastSlow = 0, _lastEcuTry = 0;
  int _slowIdx = 0;
  bool _staticDone = false;

  // envia comando e lê até o prompt '>'
  String cmd(const String& c, uint32_t timeout = 1500) {
    linkFlush();
    linkWrite((c + "\r").c_str());
    String r; uint32_t t0 = millis();
    while (millis() - t0 < timeout) {
      int ch = linkRead();
      if (ch < 0) { delay(2); continue; }
      if (ch == '>') { r.trim(); return r; }
      if (ch != '\0') r += (char)ch;
    }
    r.trim(); return r;
  }

  bool initAdapter() {
    const char* seq[] = { "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0", "ATAT1" };
    bool alive = false;
    for (auto c : seq) {
      String r = cmd(c, c[2] == 'Z' ? 4000 : 1500);
      Serial.printf("[obd] %s -> %s\n", c, r.c_str());
      if (r.indexOf("ELM") >= 0 || r.indexOf("OK") >= 0) alive = true;
    }
    if (!alive) _err = "adaptador nao respondeu aos comandos AT";
    return alive;
  }

  bool initEcu() {
    String r = cmd("0100", 10000);                         // força busca de protocolo
    Serial.printf("[obd] 0100 -> %s\n", r.c_str());
    if (r.indexOf("41") < 0) { _err = "ECU nao respondeu (ignicao ligada?)"; return false; }
    _err = "";
    parseSupported(r, 0x00, 0);
    if (has(0x20)) { r = cmd("0120", 3000); parseSupported(r, 0x20, 1); }
    if (has(0x40)) { r = cmd("0140", 3000); parseSupported(r, 0x40, 2); }
    _protocol = cmd("ATDPN");
    Serial.printf("[obd] protocolo=%s pids=%s\n", _protocol.c_str(), supportedList().c_str());
    return true;
  }

  void parseSupported(const String& r, uint8_t pid, int idx) {
    uint8_t b[4]; int n = parse(r, pid, b, 4);
    if (n == 4) _supported[idx] = ((uint32_t)b[0] << 24) | ((uint32_t)b[1] << 16) | ((uint32_t)b[2] << 8) | b[3];
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
    String r = cmd(c, 1000);
    uint8_t b[8]; int n = parse(r, pid, b, 8);
    if (n > 0) dst = conv(b, n);
    else if (r.indexOf("NO DATA") >= 0 || r.indexOf("UNABLE") >= 0 || r.indexOf("7F01") >= 0) dst = NAN;
  }

  void readMil(VehicleData& d) {
    String r = cmd("0101", 1000);
    uint8_t b[4]; int n = parse(r, 0x01, b, 4);
    if (n >= 1) { d.milOn = b[0] & 0x80; d.dtcCount = b[0] & 0x7F; }
  }

  static String decodeDtc(const String& hex4) {
    if (hex4.length() < 4) return "";
    const char* pre = "PCBU";
    int a = strtol(hex4.substring(0, 1).c_str(), nullptr, 16);
    String s; s += pre[(a >> 2) & 3]; s += String(a & 3); s += hex4.substring(1);
    return s;
  }

  // informações lidas uma vez: norma OBD e VIN
  void readStatic(VehicleData& d) {
    if (has(0x1C)) { float v = NAN; readPid(0x1C, v, [](uint8_t* b, int n){ return n >= 1 ? (float)b[0] : NAN; }); if (!isnan(v)) d.obdStd = obdStdName((int)v); }
    String r = cmd("0902", 4000);
    Serial.printf("[obd] 0902 -> %s\n", r.c_str());
    String h = r; h.replace(" ", ""); h.replace("\n", "");
    // multi-quadro CAN vem como "014\r0:490201xxxx\r1:xxxx..." : remove "N:" e quebras
    String c; for (int i = 0; i < (int)h.length(); i++) { if (h[i] == ':') { if (c.length()) c.remove(c.length() - 1); continue; } if (h[i] != '\r') c += h[i]; }
    int i = c.indexOf("490201");
    if (i < 0) i = c.indexOf("4902");
    if (i >= 0) {
      i = c.indexOf("4902", i) + 4; if (c.substring(i, i + 2) == "01") i += 2;
      String vin;
      while (i + 1 < (int)c.length() && vin.length() < 17) {
        int ch = strtol(c.substring(i, i + 2).c_str(), nullptr, 16); i += 2;
        if (ch >= 0x30 && ch <= 0x5A) vin += (char)ch;
      }
      if (vin.length() == 17) d.vin = vin;
    }
  }

  void readVoltage(float& dst) {
    String r = cmd("ATRV", 1000);            // ex: "14.2V"
    r.replace("V", ""); r.trim();
    float v = r.toFloat();
    if (v > 5 && v < 40) dst = v;
  }
};
