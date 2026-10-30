#pragma once
// Interface do computador de bordo, 320x240, dark mode. Três páginas + alertas.
#include "hw.h"
#include "obd_data.h"

// paleta (RGB565)
#define UI_BG      0x0000
#define UI_PANEL   0x10A2
#define UI_LINE    0x2124
#define UI_TXT     0xF79E
#define UI_MUTED   0x7BCF
#define UI_ACCENT  0x07FF   // ciano
#define UI_OK      0x07E8   // verde
#define UI_WARN    0xFD20   // laranja
#define UI_BAD     0xF800   // vermelho

enum Page { PAGE_DRIVE = 0, PAGE_ENGINE, PAGE_DIAG, PAGE_COUNT };
static const char* PAGE_NAMES[] = { "DIRIGIR", "MOTOR", "DIAGNOSTICO" };

static TFT_eSprite gauge(&tft);     // velocímetro + arco de rpm
static TFT_eSprite tile(&tft);      // sprite reutilizável para cards e linhas

static String fmt(float v, int dec, const char* nan = "--") {
  if (isnan(v)) return nan;
  char b[16]; dtostrf(v, 0, dec, b); return String(b);
}
static String fmtSigned(float v, int dec) {
  if (isnan(v)) return "--";
  return (v >= 0 ? "+" : "") + fmt(v, dec);
}
static uint16_t lerp565(uint16_t a, uint16_t b, float t) {
  t = constrain(t, 0.0f, 1.0f);
  int r = ((a >> 11) & 31) + (((b >> 11) & 31) - ((a >> 11) & 31)) * t;
  int g = ((a >> 5) & 63)  + (((b >> 5) & 63)  - ((a >> 5) & 63))  * t;
  int bl = (a & 31)        + ((b & 31)         - (a & 31))         * t;
  return (r << 11) | (g << 5) | bl;
}

// ---- barra de status (topo), comum a todas as páginas ----
static void uiStatusBar(const ObdSource& src, const VehicleData& d, const TripData& trip, Page page, bool blink) {
  tft.fillRect(0, 0, 320, 20, UI_PANEL);
  tft.setTextDatum(ML_DATUM);
  uint16_t c = src.state() == ObdState::Connected ? UI_OK : src.state() == ObdState::Mock ? UI_ACCENT
             : src.state() == ObdState::Error ? UI_BAD : UI_WARN;
  if ((src.state() == ObdState::Connecting || src.state() == ObdState::Initializing || src.state() == ObdState::WaitingEcu) && blink) c = UI_PANEL;
  tft.fillCircle(10, 10, 4, c);
  tft.setTextColor(UI_TXT, UI_PANEL);
  tft.drawString(PAGE_NAMES[page], 20, 10, 2);
  int x = 20 + tft.textWidth(PAGE_NAMES[page], 2) + 8;
  tft.setTextColor(UI_MUTED, UI_PANEL);
  tft.drawString(src.state() == ObdState::Connected ? src.name() : obdStateName(src.state()), x, 10, 2);
  // alerta de injeção
  if (d.milOn) {
    uint16_t cm = blink ? UI_WARN : UI_BAD;
    tft.fillRoundRect(188, 3, 62, 14, 3, cm);
    tft.setTextDatum(MC_DATUM); tft.setTextColor(0x0000, cm);
    tft.drawString("INJECAO", 219, 10, 1);
  }
  // tempo de viagem
  uint32_t sec = (millis() - trip.startMs) / 1000;
  char t[12]; snprintf(t, sizeof t, "%02u:%02u:%02u", sec / 3600, (sec / 60) % 60, sec % 60);
  tft.setTextDatum(MR_DATUM); tft.setTextColor(UI_MUTED, UI_PANEL);
  tft.drawString(t, 314, 10, 2);
}

// ---- velocímetro com arco de rpm ----
static void uiGauge(const VehicleData& d) {
  const int cx = 80, cy = 80, R = 77, IR = 65;
  gauge.fillSprite(UI_BG);
  gauge.drawArc(cx, cy, R, IR, 30, 330, UI_LINE, UI_BG, true);
  float rpm = isnan(d.rpm) ? 0 : constrain(d.rpm, 0.0f, 7000.0f);
  int end = 30 + (int)(rpm / 7000.0f * 300);
  if (end > 31) {
    int step = 10;
    for (int a = 30; a < end; a += step) {
      float t = (a - 30) / 300.0f;
      uint16_t col = t < 0.55f ? lerp565(UI_ACCENT, UI_OK, t / 0.55f)
                   : t < 0.8f  ? lerp565(UI_OK, UI_WARN, (t - 0.55f) / 0.25f)
                   :             lerp565(UI_WARN, UI_BAD, (t - 0.8f) / 0.2f);
      gauge.drawArc(cx, cy, R, IR, a, min(a + step, end), col, UI_BG, false);
    }
  }
  for (int k = 0; k <= 7; k++) {
    float ang = (30 + k * 300 / 7.0f) * DEG_TO_RAD;
    gauge.drawLine(cx - sin(ang) * (IR - 3), cy + cos(ang) * (IR - 3), cx - sin(ang) * (IR - 8), cy + cos(ang) * (IR - 8), k >= 6 ? UI_BAD : UI_MUTED);
  }
  gauge.setTextDatum(MC_DATUM);
  gauge.setTextColor(UI_TXT, UI_BG);
  gauge.setFreeFont(&FreeSansBold24pt7b);
  gauge.drawString(fmt(d.speedKmh, 0), cx, cy - 6);
  gauge.setTextFont(2);
  gauge.setTextColor(UI_MUTED, UI_BG);
  gauge.drawString("km/h", cx, cy + 24);
  gauge.setTextColor(rpm > 5500 ? UI_BAD : UI_TXT, UI_BG);
  gauge.drawString(fmt(d.rpm, 0) + " rpm", cx, cy + 62);
  gauge.pushSprite(2, 28);
}

// ---- card de valor ----
static void uiTile(int x, int y, int w, int h, const char* label, const String& value,
                   const char* unit, uint16_t accent, float barPct = -1) {
  tile.createSprite(w, h);
  tile.fillSprite(UI_BG);
  tile.fillRoundRect(0, 0, w, h, 8, UI_PANEL);
  tile.fillRoundRect(0, 0, 4, h, 2, accent);
  tile.setTextDatum(TL_DATUM);
  tile.setTextColor(UI_MUTED, UI_PANEL);
  tile.drawString(label, 11, 2, 2);
  int base = h - (barPct >= 0 ? 13 : 6);
  tile.setTextDatum(BL_DATUM);
  tile.setTextColor(UI_TXT, UI_PANEL);
  tile.setFreeFont(&FreeSansBold12pt7b);
  tile.drawString(value, 10, base);
  int vw = tile.textWidth(value);
  tile.setTextFont(1);
  tile.setTextColor(UI_MUTED, UI_PANEL);
  tile.drawString(unit, 13 + vw, base - 1);
  if (barPct >= 0) {
    tile.fillRoundRect(10, h - 9, w - 20, 4, 2, UI_LINE);
    tile.fillRoundRect(10, h - 9, (w - 20) * constrain(barPct, 0.0f, 100.0f) / 100, 4, 2, accent);
  }
  tile.pushSprite(x, y);
  tile.deleteSprite();
}

// ---- página 1: dirigir ----
static void uiDriveTiles(const VehicleData& d, const TripData& t) {
  const int x0 = 166, w = 73, h = 56, gap = 4;
  bool moving = !isnan(d.speedKmh) && d.speedKmh > 2;
  // consumo: km/l em movimento, l/h parado
  if (moving) {
    float kml = d.kmPerL;
    uint16_t ck = isnan(kml) ? UI_MUTED : kml >= 12 ? UI_OK : kml >= 8 ? UI_WARN : UI_BAD;
    uiTile(x0, 26, w, h, "consumo", fmt(kml, kml >= 10 ? 0 : 1), "km/l", ck);
  } else {
    uiTile(x0, 26, w, h, "consumo", fmt(d.fuelLph, 1), "l/h", isnan(d.fuelLph) ? UI_MUTED : UI_ACCENT);
  }
  float avg = t.avgKmPerL();
  uiTile(x0 + w + gap, 26, w, h, "media", fmt(avg, avg >= 10 ? 0 : 1), "km/l", isnan(avg) ? UI_MUTED : avg >= 10 ? UI_OK : avg >= 7 ? UI_WARN : UI_BAD);
  float tc = d.coolantC;
  uint16_t ct = isnan(tc) ? UI_MUTED : tc > ALERT_COOLANT_C ? UI_BAD : tc < 70 ? UI_ACCENT : UI_OK;
  uiTile(x0, 26 + h + gap, w, h, "motor", fmt(tc, 0), "C", ct, isnan(tc) ? -1 : (tc - 40) / 90 * 100);
  float v = d.batteryV;
  uint16_t cv = isnan(v) ? UI_MUTED : (v < ALERT_BATTERY_V || v > 15.0f) ? UI_BAD : v < 13.2f ? UI_WARN : UI_OK;
  uiTile(x0 + w + gap, 26 + h + gap, w, h, "bateria", fmt(v, 1), "V", cv);
  // card largo: carga e borboleta, cada um com label, valor e barra na largura toda
  const int W = 2 * w + gap;
  tile.createSprite(W, h);
  tile.fillSprite(UI_BG);
  tile.fillRoundRect(0, 0, W, h, 8, UI_PANEL);
  tile.fillRoundRect(0, 0, 4, h, 2, UI_LINE);
  for (int i = 0; i < 2; i++) {
    float p = i == 0 ? d.loadPct : d.throttlePct; int y = i == 0 ? 3 : 29;
    tile.setTextDatum(TL_DATUM); tile.setTextColor(UI_MUTED, UI_PANEL);
    tile.drawString(i == 0 ? "carga" : "borboleta", 11, y, 2);
    tile.setTextDatum(TR_DATUM); tile.setTextColor(UI_TXT, UI_PANEL);
    tile.drawString(fmt(p, 0) + "%", W - 8, y, 2);
    tile.fillRoundRect(11, y + 18, W - 19, 4, 2, UI_LINE);
    if (!isnan(p)) tile.fillRoundRect(11, y + 18, (W - 19) * constrain(p, 0.0f, 100.0f) / 100, 4, 2, i == 0 ? UI_ACCENT : UI_OK);
  }
  tile.pushSprite(x0, 26 + 2 * (h + gap));
  tile.deleteSprite();
}

static void uiFooter(const VehicleData& d, const TripData& t) {
  tft.fillRect(0, 206, 320, 34, UI_BG);
  tft.drawFastHLine(8, 206, 304, UI_LINE);
  struct { const char* l; String v; } items[] = {
    { "dist",  fmt(t.distanceKm, 1) + " km" },
    { "comb.", fmt(t.fuelL, 2) + " L" },
    { "l/h",   fmt(d.fuelLph, 1) },
    { "max",   fmt(t.maxSpeed, 0) + " km/h" },
  };
  int x = 10;
  for (auto& it : items) {
    tft.setTextDatum(TL_DATUM);
    tft.setTextColor(UI_MUTED, UI_BG); tft.drawString(it.l, x, 210, 1);
    tft.setTextColor(UI_TXT, UI_BG);   tft.drawString(it.v, x, 223, 2);
    x += 78;
  }
}

static void uiPageDrive(const VehicleData& d, const TripData& t) {
  uiGauge(d);
  uiDriveTiles(d, t);
  uiFooter(d, t);
}

// ---- página 2: motor ----
static float o2hist[48]; static int o2idx = 0;
static void uiBarRow(TFT_eSprite& sp, int y, const char* label, float pct, uint16_t col, const String& text) {
  sp.setTextDatum(ML_DATUM); sp.setTextColor(UI_MUTED, UI_BG); sp.drawString(label, 0, y, 2);
  sp.fillRoundRect(84, y - 4, 150, 8, 4, UI_LINE);
  if (!isnan(pct)) sp.fillRoundRect(84, y - 4, 150 * constrain(pct, 0.0f, 100.0f) / 100, 8, 4, col);
  sp.setTextDatum(MR_DATUM); sp.setTextColor(UI_TXT, UI_BG); sp.drawString(text, 300, y, 2);
}
static void uiTrimRow(TFT_eSprite& sp, int y, const char* label, float pct) {
  sp.setTextDatum(ML_DATUM); sp.setTextColor(UI_MUTED, UI_BG); sp.drawString(label, 0, y, 2);
  sp.fillRoundRect(84, y - 4, 150, 8, 4, UI_LINE);
  sp.drawFastVLine(159, y - 7, 14, UI_MUTED);
  if (!isnan(pct)) {
    float p = constrain(pct, -25.0f, 25.0f); int wpx = (int)(fabs(p) / 25.0f * 75);
    uint16_t c = fabs(p) < 8 ? UI_OK : fabs(p) < 15 ? UI_WARN : UI_BAD;
    sp.fillRoundRect(p >= 0 ? 159 : 159 - wpx, y - 4, wpx, 8, 3, c);
  }
  sp.setTextDatum(MR_DATUM); sp.setTextColor(UI_TXT, UI_BG); sp.drawString(fmtSigned(pct, 1) + "%", 300, y, 2);
}
static void uiPageEngine(const VehicleData& d) {
  if (!isnan(d.o2s1V)) { o2hist[o2idx] = d.o2s1V; o2idx = (o2idx + 1) % 48; }
  tile.createSprite(304, 214);
  tile.fillSprite(UI_BG);
  uiBarRow(tile, 10, "carga",     d.loadPct,     UI_ACCENT, fmt(d.loadPct, 0) + "%");
  uiBarRow(tile, 34, "borboleta", d.throttlePct, UI_OK,     fmt(d.throttlePct, 0) + "%");
  // linha dupla: MAP / admissão ; avanço / malha
  auto kv = [&](int x, int y, const char* k, const String& v, uint16_t c = UI_TXT) {
    tile.setTextDatum(ML_DATUM); tile.setTextColor(UI_MUTED, UI_BG); tile.drawString(k, x, y, 2);
    tile.setTextColor(c, UI_BG); tile.drawString(v, x + (x ? 66 : 84), y, 2);
  };
  kv(0,   60, "MAP",      fmt(d.mapKpa, 0) + " kPa");
  kv(150, 60, "admissao", fmt(d.intakeC, 0) + " C");
  kv(0,   82, "avanco",   fmt(d.timingDeg, 0) + " graus");
  kv(150, 82, "malha",    fuelSystemName(d.fuelSystem), d.fuelSystem == 2 ? UI_OK : d.fuelSystem >= 8 ? UI_BAD : UI_WARN);
  tile.drawFastHLine(0, 98, 304, UI_LINE);
  uiTrimRow(tile, 114, "trim curto", d.stftPct);
  uiTrimRow(tile, 138, "trim longo", d.ltftPct);
  tile.drawFastHLine(0, 154, 304, UI_LINE);
  // sondas lambda
  kv(0, 172, "sonda 1", fmt(d.o2s1V, 2) + " V");
  kv(150, 172, "sonda 2", fmt(d.o2s2V, 2) + " V", isnan(d.o2s2V) ? UI_MUTED : (d.o2s2V > 0.3f && d.o2s2V < 0.8f) ? UI_OK : UI_WARN);
  // mini gráfico da sonda 1 (0..1 V)
  int gx = 0, gy = 186, gw = 304, gh = 24;
  tile.drawRect(gx, gy, gw, gh, UI_LINE);
  for (int i = 1; i < 48; i++) {
    float a = o2hist[(o2idx + i - 1) % 48], b = o2hist[(o2idx + i) % 48];
    int x1 = gx + (i - 1) * gw / 47, x2 = gx + i * gw / 47;
    tile.drawLine(x1, gy + gh - 1 - a * (gh - 2), x2, gy + gh - 1 - b * (gh - 2), UI_ACCENT);
  }
  tile.pushSprite(8, 24);
  tile.deleteSprite();
}

// ---- página 3: diagnóstico ----
static void uiPageDiag(const ObdSource& src, const VehicleData& d, bool armClear, const String& scanList) {
  tile.createSprite(304, 214);
  tile.fillSprite(UI_BG);
  tile.setTextDatum(TL_DATUM);
  int y = 0;
  auto line = [&](const char* k, const String& v, uint16_t c = UI_TXT) {
    tile.setTextColor(UI_MUTED, UI_BG); tile.drawString(k, 0, y, 2);
    tile.setTextColor(c, UI_BG);        tile.drawString(v, 100, y, 2);
    y += 18;
  };
  // bloco de falhas
  line("luz injecao", d.milOn ? "ACESA" : "apagada", d.milOn ? UI_BAD : UI_OK);
  line("falhas",      String(d.dtcCount) + (isnan(d.distMilKm) || d.distMilKm <= 0 ? "" : "   " + fmt(d.distMilKm, 0) + " km com luz"), d.dtcCount ? UI_WARN : UI_TXT);
  if (d.nDtcs < 0)      line("codigos", "lendo...", UI_MUTED);
  else if (d.nDtcs == 0) line("codigos", "nenhum", UI_OK);
  else {
    String s; for (int i = 0; i < d.nDtcs; i++) s += d.dtcs[i] + "  ";
    line("codigos", s, UI_BAD);
  }
  tile.drawFastHLine(0, y + 2, 304, UI_LINE); y += 8;
  line("veiculo",   d.vin.length() ? d.vin : "--");
  line("norma",     d.obdStd.length() ? d.obdStd : "--");
  line("protocolo", src.protocol().length() ? src.protocol() : "--");
  line("fonte",     String(src.name()) + "  " + obdStateName(src.state()));
  int rssi = src.signalDbm();
  line("sinal",     rssi ? String(rssi) + " dBm" : "--", rssi == 0 ? UI_MUTED : rssi > -75 ? UI_OK : rssi > -85 ? UI_WARN : UI_BAD);
  line("erro",      strlen(src.lastError()) ? src.lastError() : "-", strlen(src.lastError()) ? UI_BAD : UI_TXT);
  line("heap",      String(ESP.getFreeHeap() / 1024) + " KB");
  if (scanList.length()) { tile.setTextColor(UI_MUTED, UI_BG); tile.drawString(scanList.substring(0, 60), 0, y, 1); y += 10; }
  // rodapé: instrução / confirmação de apagar
  tile.fillRoundRect(0, 190, 304, 22, 6, armClear ? UI_BAD : UI_PANEL);
  tile.setTextDatum(MC_DATUM); tile.setTextColor(armClear ? 0x0000 : UI_MUTED, armClear ? UI_BAD : UI_PANEL);
  tile.drawString(armClear ? "APAGAR FALHAS? toque para confirmar" : "segure 2 s para apagar falhas", 152, 201, 2);
  tile.pushSprite(8, 24);
  tile.deleteSprite();
}

// ---- alerta em tela cheia ----
static void uiAlert(const char* title, const String& value, uint16_t color) {
  tft.fillScreen(color);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(0x0000, color);
  tft.setFreeFont(&FreeSansBold18pt7b);
  tft.drawString(title, 160, 90);
  tft.setFreeFont(&FreeSansBold24pt7b);
  tft.drawString(value, 160, 145);
  tft.setTextFont(2);
}

// 'S' no serial: envia a tela (RGB888) para gerar screenshot no computador
static void uiScreenshotIfRequested() {
  if (!(Serial.available() && Serial.peek() == 'S')) return;
  Serial.read();
  Serial.println("IMG 320 240");
  uint8_t row[320 * 3];
  for (int y = 0; y < 240; y++) { tft.readRectRGB(0, y, 320, 1, row); Serial.write(row, sizeof row); }
  Serial.println("\nEND");
}

static void uiSplash(const char* line) {
  tft.fillScreen(UI_BG);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(UI_ACCENT, UI_BG);
  tft.setFreeFont(&FreeSansBold18pt7b);
  tft.drawString("computador", 160, 80);
  tft.drawString("de bordo", 160, 116);
  tft.fillRoundRect(130, 140, 60, 3, 1, UI_LINE);
  tft.setTextFont(2);
  tft.setTextColor(UI_MUTED, UI_BG);
  tft.drawString(line, 160, 162);
  uiScreenshotIfRequested();
}

static void uiBegin() {
  gauge.setColorDepth(8);
  gauge.createSprite(160, 160);
  tile.setColorDepth(8);
  for (auto& v : o2hist) v = 0.45f;
  tft.fillScreen(UI_BG);
}
