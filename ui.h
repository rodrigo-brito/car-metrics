#pragma once
// Interface do computador de bordo, 320x240, dark mode.
#include "hw.h"
#include "obd_data.h"

// paleta (RGB565)
#define UI_BG      0x0000   // preto
#define UI_PANEL   0x10A2   // grafite
#define UI_LINE    0x2124
#define UI_TXT     0xF79E   // branco levemente quente
#define UI_MUTED   0x7BCF
#define UI_ACCENT  0x07FF   // ciano
#define UI_OK      0x07E8   // verde
#define UI_WARN    0xFD20   // laranja
#define UI_BAD     0xF800   // vermelho

static TFT_eSprite gauge(&tft);     // velocímetro + arco de rpm
static TFT_eSprite tile(&tft);      // um card reutilizável

static String fmt(float v, int dec, const char* nan = "--") {
  if (isnan(v)) return nan;
  char b[16]; dtostrf(v, 0, dec, b); return String(b);
}

static uint16_t lerp565(uint16_t a, uint16_t b, float t) {
  t = constrain(t, 0.0f, 1.0f);
  int r = ((a >> 11) & 31) + (((b >> 11) & 31) - ((a >> 11) & 31)) * t;
  int g = ((a >> 5) & 63)  + (((b >> 5) & 63)  - ((a >> 5) & 63))  * t;
  int bl = (a & 31)        + ((b & 31)         - (a & 31))         * t;
  return (r << 11) | (g << 5) | bl;
}

// ---- barra de status (topo) ----
static void uiStatusBar(const ObdSource& src, const TripData& trip, bool blink) {
  tft.fillRect(0, 0, 320, 20, UI_PANEL);
  tft.setTextDatum(ML_DATUM);
  uint16_t c = src.state() == ObdState::Connected ? UI_OK : src.state() == ObdState::Mock ? UI_ACCENT
             : src.state() == ObdState::Error ? UI_BAD : UI_WARN;
  if (src.state() == ObdState::Connecting || src.state() == ObdState::Initializing) if (blink) c = UI_PANEL;
  tft.fillCircle(10, 10, 4, c);
  tft.setTextColor(UI_TXT, UI_PANEL);
  String s = String(src.name()) + "  ";
  s.toUpperCase();
  tft.drawString(s, 20, 10, 2);
  tft.setTextColor(UI_MUTED, UI_PANEL);
  tft.drawString(obdStateName(src.state()), 20 + tft.textWidth(s, 2), 10, 2);
  // tempo de viagem
  uint32_t sec = (millis() - trip.startMs) / 1000;
  char t[12]; snprintf(t, sizeof t, "%02u:%02u:%02u", sec / 3600, (sec / 60) % 60, sec % 60);
  tft.setTextDatum(MR_DATUM);
  tft.drawString(t, 314, 10, 2);
}

// ---- velocímetro com arco de rpm ----
// sprite 170x170 centrado em (85,85); arco 0..7000 rpm de 30° a 330° (0° = 6h)
static void uiGauge(const VehicleData& d) {
  const int W = 170, cx = 85, cy = 85, R = 82, IR = 70;
  gauge.fillSprite(UI_BG);
  gauge.drawArc(cx, cy, R, IR, 30, 330, UI_LINE, UI_BG, true);
  float rpm = isnan(d.rpm) ? 0 : constrain(d.rpm, 0.0f, 7000.0f);
  int end = 30 + (int)(rpm / 7000.0f * 300);
  if (end > 31) {
    // gradiente: ciano -> verde -> laranja -> vermelho em fatias
    int step = 10;
    for (int a = 30; a < end; a += step) {
      float t = (a - 30) / 300.0f;
      uint16_t col = t < 0.55f ? lerp565(UI_ACCENT, UI_OK, t / 0.55f)
                   : t < 0.8f  ? lerp565(UI_OK, UI_WARN, (t - 0.55f) / 0.25f)
                   :             lerp565(UI_WARN, UI_BAD, (t - 0.8f) / 0.2f);
      gauge.drawArc(cx, cy, R, IR, a, min(a + step, end), col, UI_BG, false);
    }
  }
  // marcas a cada 1000 rpm
  for (int k = 0; k <= 7; k++) {
    float ang = (30 + k * 300 / 7.0f) * DEG_TO_RAD;
    int x1 = cx - sin(ang) * (IR - 3), y1 = cy + cos(ang) * (IR - 3);
    int x2 = cx - sin(ang) * (IR - 8), y2 = cy + cos(ang) * (IR - 8);
    gauge.drawLine(x1, y1, x2, y2, k >= 6 ? UI_BAD : UI_MUTED);
  }
  // velocidade
  gauge.setTextDatum(MC_DATUM);
  gauge.setTextColor(UI_TXT, UI_BG);
  gauge.setFreeFont(&FreeSansBold24pt7b);
  gauge.drawString(fmt(d.speedKmh, 0), cx, cy - 6);
  gauge.setTextFont(2);
  gauge.setTextColor(UI_MUTED, UI_BG);
  gauge.drawString("km/h", cx, cy + 24);
  // rpm
  gauge.setTextColor(rpm > 5500 ? UI_BAD : UI_TXT, UI_BG);
  gauge.drawString(fmt(d.rpm, 0) + " rpm", cx, cy + 62);
  gauge.pushSprite(4, 26);
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
  tile.drawString(label, 11, 2, 2);                   // label no topo
  int base = h - (barPct >= 0 ? 13 : 6);              // linha de base do valor, com folga do label
  tile.setTextDatum(BL_DATUM);
  tile.setTextColor(UI_TXT, UI_PANEL);
  tile.setFreeFont(&FreeSansBold12pt7b);
  tile.drawString(value, 10, base);
  int vw = tile.textWidth(value);
  tile.setTextFont(2);
  tile.setTextColor(UI_MUTED, UI_PANEL);
  tile.drawString(unit, 14 + vw, base - 1);
  if (barPct >= 0) {
    tile.fillRoundRect(10, h - 9, w - 20, 4, 2, UI_LINE);
    tile.fillRoundRect(10, h - 9, (w - 20) * constrain(barPct, 0.0f, 100.0f) / 100, 4, 2, accent);
  }
  tile.pushSprite(x, y);
  tile.deleteSprite();
}

static void uiTiles(const VehicleData& d, const TripData& t) {
  const int x0 = 180, w = 66, h = 56, gap = 4;
  // consumo instantâneo
  float kml = d.kmPerL;
  uint16_t ck = isnan(kml) ? UI_MUTED : kml >= 12 ? UI_OK : kml >= 8 ? UI_WARN : UI_BAD;
  uiTile(x0, 26, w, h, "consumo", fmt(kml, 1), "km/l", ck);
  // temperatura do motor
  float tc = d.coolantC;
  uint16_t ct = isnan(tc) ? UI_MUTED : tc > 105 ? UI_BAD : tc < 70 ? UI_ACCENT : UI_OK;
  uiTile(x0 + w + gap, 26, w, h, "motor", fmt(tc, 0), "C", ct, isnan(tc) ? -1 : (tc - 40) / 90 * 100);
  // combustível
  float f = d.fuelPct;
  uint16_t cf = isnan(f) ? UI_MUTED : f < 12 ? UI_BAD : f < 25 ? UI_WARN : UI_OK;
  uiTile(x0, 26 + h + gap, w, h, "tanque", fmt(f, 0), "%", cf, f);
  // bateria
  float v = d.batteryV;
  uint16_t cv = isnan(v) ? UI_MUTED : (v < 12.2f || v > 15.0f) ? UI_BAD : v < 13.2f ? UI_WARN : UI_OK;
  uiTile(x0 + w + gap, 26 + h + gap, w, h, "bateria", fmt(v, 1), "V", cv);
  // média da viagem (card largo)
  uiTile(x0, 26 + 2 * (h + gap), 2 * w + gap, h, "media viagem", fmt(t.avgKmPerL(), 1), "km/l",
         UI_ACCENT);
}

// ---- rodapé: viagem ----
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

static void uiDashboard(const ObdSource& src, const VehicleData& d, const TripData& t) {
  static bool blink = false; blink = !blink;
  uiStatusBar(src, t, blink);
  uiGauge(d);
  uiTiles(d, t);
  uiFooter(d, t);
}

// ---- página de diagnóstico (toque alterna) ----
static void uiInfo(const ObdSource& src, const VehicleData& d, const TripData& t) {
  static bool blink = false; blink = !blink;
  uiStatusBar(src, t, blink);
  tft.fillRect(0, 20, 320, 220, UI_BG);
  tft.setTextDatum(TL_DATUM);
  int y = 28;
  auto line = [&](const char* k, const String& v, uint16_t c = UI_TXT) {
    tft.setTextColor(UI_MUTED, UI_BG); tft.drawString(k, 12, y, 2);
    tft.setTextColor(c, UI_BG);        tft.drawString(v, 120, y, 2);
    y += 18;
  };
  line("fonte",      src.name());
  line("estado",     obdStateName(src.state()));
  line("protocolo",  src.protocol());
  line("erro",       strlen(src.lastError()) ? src.lastError() : "-", strlen(src.lastError()) ? UI_BAD : UI_TXT);
  line("ultima leit.", d.updatedAt ? String((millis() - d.updatedAt) / 1000.0f, 1) + " s" : "-");
  y += 6;
  line("maf",        fmt(d.mafGs, 1) + " g/s");
  line("carga",      fmt(d.loadPct, 0) + " %");
  line("borboleta",  fmt(d.throttlePct, 0) + " %");
  line("admissao",   fmt(d.intakeC, 0) + " C");
  line("map",        fmt(d.mapKpa, 0) + " kPa");
  line("heap livre", String(ESP.getFreeHeap() / 1024) + " KB");
}

// lista de dispositivos vistos na varredura (coluna direita da página de diagnóstico)
static void uiScanList(const String& list) {
  if (!list.length()) return;
  tft.setTextDatum(TL_DATUM);
  tft.setTextColor(UI_MUTED, UI_BG);
  tft.drawString("bluetooth por perto", 186, 28, 2);
  int y = 46, start = 0;
  while (start < (int)list.length() && y < 230) {
    int nl = list.indexOf('\n', start); if (nl < 0) nl = list.length();
    String line = list.substring(start, nl); start = nl + 1;
    tft.setTextColor(UI_TXT, UI_BG);
    tft.drawString(line.substring(0, 24), 186, y, 1); y += 10;
  }
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
  gauge.createSprite(170, 170);
  tile.setColorDepth(8);
  tft.fillScreen(UI_BG);
}
