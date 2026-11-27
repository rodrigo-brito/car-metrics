#pragma once
// Interface do computador de bordo, dark mode. Três páginas + alertas.
// Layout em 320x240 (CYD) ou 480x320 (JC3248W535): PICK(cyd, grande) escolhe cada medida.
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

#define PICK(a, b) (SCR_W >= 480 ? (b) : (a))
#define F_VAL  PICK(2, 4)   // fonte dos valores em texto (2 = 16 px, 4 = 26 px)
#define STATUS_H PICK(20, 30)

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
  const int cy = STATUS_H / 2;
  tft.fillRect(0, 0, SCR_W, STATUS_H, UI_PANEL);
  tft.setTextDatum(ML_DATUM);
  uint16_t c = src.state() == ObdState::Connected ? UI_OK : src.state() == ObdState::Mock ? UI_ACCENT
             : src.state() == ObdState::Error ? UI_BAD : UI_WARN;
  if ((src.state() == ObdState::Connecting || src.state() == ObdState::Initializing || src.state() == ObdState::WaitingEcu) && blink) c = UI_PANEL;
  tft.fillCircle(PICK(10, 14), cy, PICK(4, 6), c);
  tft.setTextColor(UI_TXT, UI_PANEL);
  tft.drawString(PAGE_NAMES[page], PICK(20, 28), cy, F_VAL);
  int x = PICK(20, 28) + tft.textWidth(PAGE_NAMES[page], F_VAL) + 8;
  tft.setTextColor(UI_MUTED, UI_PANEL);
  tft.drawString(src.state() == ObdState::Connected ? src.name() : obdStateName(src.state()), x, cy, 2);
  // alerta de injeção
  if (d.milOn) {
    uint16_t cm = blink ? UI_WARN : UI_BAD;
    tft.fillRoundRect(PICK(188, 312), PICK(3, 4), PICK(62, 86), PICK(14, 22), 3, cm);
    tft.setTextDatum(MC_DATUM); tft.setTextColor(0x0000, cm);
    tft.drawString("INJECAO", PICK(219, 355), cy, PICK(1, 2));
  }
  // tempo de viagem
  uint32_t sec = (millis() - trip.startMs) / 1000;
  char t[12]; snprintf(t, sizeof t, "%02u:%02u:%02u", sec / 3600, (sec / 60) % 60, sec % 60);
  tft.setTextDatum(MR_DATUM); tft.setTextColor(UI_MUTED, UI_PANEL);
  tft.drawString(t, SCR_W - 6, cy, 2);
}

// ---- velocímetro com arco de rpm ----
static void uiGauge(const VehicleData& d) {
  const int cx = PICK(80, 118), cy = cx, R = PICK(77, 114), IR = PICK(65, 96);
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
    gauge.drawLine(cx - sin(ang) * (IR - 3), cy + cos(ang) * (IR - 3), cx - sin(ang) * (IR - PICK(8, 12)), cy + cos(ang) * (IR - PICK(8, 12)), k >= 6 ? UI_BAD : UI_MUTED);
  }
  gauge.setTextDatum(MC_DATUM);
  gauge.setTextColor(UI_TXT, UI_BG);
#if SCR_W >= 480
  gauge.drawString(fmt(d.speedKmh, 0), cx, cy - 14, 8);   // fonte 8: dígitos de 75 px
#else
  gauge.setFreeFont(&FreeSansBold24pt7b);
  gauge.drawString(fmt(d.speedKmh, 0), cx, cy - 6);
#endif
  gauge.setTextFont(2);
  gauge.setTextColor(UI_MUTED, UI_BG);
  gauge.drawString("km/h", cx, cy + PICK(24, 38), F_VAL);
  gauge.setTextColor(rpm > 5500 ? UI_BAD : UI_TXT, UI_BG);
  gauge.drawString(fmt(d.rpm, 0) + " rpm", cx, cy + PICK(62, 88), F_VAL);
  uiPush(gauge, PICK(2, 6), PICK(28, 36));
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
  tile.drawString(label, PICK(11, 14), PICK(2, 5), 2);
  int base = h - (barPct >= 0 ? PICK(13, 17) : PICK(6, 9));
  tile.setTextDatum(BL_DATUM);
  tile.setTextColor(UI_TXT, UI_PANEL);
  tile.setFreeFont(PICK(&FreeSansBold12pt7b, &FreeSansBold18pt7b));
  tile.drawString(value, PICK(10, 13), base);
  int vw = tile.textWidth(value);
  tile.setTextFont(PICK(1, 2));
  tile.setTextColor(UI_MUTED, UI_PANEL);
  tile.drawString(unit, PICK(13, 18) + vw, base - PICK(1, 3));
  if (barPct >= 0) {
    const int bh = PICK(4, 6), by = h - PICK(9, 12);
    tile.fillRoundRect(PICK(10, 13), by, w - PICK(20, 26), bh, 2, UI_LINE);
    tile.fillRoundRect(PICK(10, 13), by, (w - PICK(20, 26)) * constrain(barPct, 0.0f, 100.0f) / 100, bh, 2, accent);
  }
  uiPush(tile, x, y);
  tile.deleteSprite();
}

// ---- página 1: dirigir ----
static void uiDriveTiles(const VehicleData& d, const TripData& t) {
  const int x0 = PICK(166, 248), w = PICK(73, 111), h = PICK(56, 76), gap = PICK(4, 5), y0 = PICK(26, 34);
  bool moving = !isnan(d.speedKmh) && d.speedKmh > 2;
  // consumo: km/l em movimento, l/h parado
  if (moving) {
    float kml = d.kmPerL;
    uint16_t ck = isnan(kml) ? UI_MUTED : kml >= 12 ? UI_OK : kml >= 8 ? UI_WARN : UI_BAD;
    uiTile(x0, y0, w, h, "consumo", fmt(kml, kml >= 10 ? 0 : 1), "km/l", ck);
  } else {
    uiTile(x0, y0, w, h, "consumo", fmt(d.fuelLph, 1), "l/h", isnan(d.fuelLph) ? UI_MUTED : UI_ACCENT);
  }
  float avg = t.avgKmPerL();
  uiTile(x0 + w + gap, y0, w, h, "media", fmt(avg, avg >= 10 ? 0 : 1), "km/l", isnan(avg) ? UI_MUTED : avg >= 10 ? UI_OK : avg >= 7 ? UI_WARN : UI_BAD);
  float tc = d.coolantC;
  uint16_t ct = isnan(tc) ? UI_MUTED : tc > ALERT_COOLANT_C ? UI_BAD : tc < 70 ? UI_ACCENT : UI_OK;
  uiTile(x0, y0 + h + gap, w, h, "motor", fmt(tc, 0), "C", ct, isnan(tc) ? -1 : (tc - 40) / 90 * 100);
  float v = d.batteryV;
  uint16_t cv = isnan(v) ? UI_MUTED : (v < ALERT_BATTERY_V || v > 15.0f) ? UI_BAD : v < 13.2f ? UI_WARN : UI_OK;
  uiTile(x0 + w + gap, y0 + h + gap, w, h, "bateria", fmt(v, 1), "V", cv);
  // card largo: carga e borboleta, cada um com label, valor e barra na largura toda
  const int W = 2 * w + gap;
  tile.createSprite(W, h);
  tile.fillSprite(UI_BG);
  tile.fillRoundRect(0, 0, W, h, 8, UI_PANEL);
  tile.fillRoundRect(0, 0, 4, h, 2, UI_LINE);
  for (int i = 0; i < 2; i++) {
    float p = i == 0 ? d.loadPct : d.throttlePct; int y = i == 0 ? PICK(3, 6) : PICK(29, 42);
    const int by = y + PICK(18, 22), bh = PICK(4, 6);
    tile.setTextDatum(TL_DATUM); tile.setTextColor(UI_MUTED, UI_PANEL);
    tile.drawString(i == 0 ? "carga" : "borboleta", PICK(11, 14), y, 2);
    tile.setTextDatum(TR_DATUM); tile.setTextColor(UI_TXT, UI_PANEL);
    tile.drawString(fmt(p, 0) + "%", W - PICK(8, 12), y, 2);
    tile.fillRoundRect(PICK(11, 14), by, W - PICK(19, 26), bh, 2, UI_LINE);
    if (!isnan(p)) tile.fillRoundRect(PICK(11, 14), by, (W - PICK(19, 26)) * constrain(p, 0.0f, 100.0f) / 100, bh, 2, i == 0 ? UI_ACCENT : UI_OK);
  }
  uiPush(tile, x0, y0 + 2 * (h + gap));
  tile.deleteSprite();
}

static void uiFooter(const VehicleData& d, const TripData& t) {
  const int fy = PICK(206, 276);
  tft.fillRect(0, fy, SCR_W, SCR_H - fy, UI_BG);
  tft.drawFastHLine(8, fy, SCR_W - 16, UI_LINE);
  struct { const char* l; String v; } items[] = {
    { "dist",  fmt(t.distanceKm, 1) + " km" },
    { "comb.", fmt(t.fuelL, 2) + " L" },
    { "l/h",   fmt(d.fuelLph, 1) },
    { "max",   fmt(t.maxSpeed, 0) + " km/h" },
  };
  int x = 10;
  for (auto& it : items) {
    tft.setTextDatum(TL_DATUM);
    tft.setTextColor(UI_MUTED, UI_BG); tft.drawString(it.l, x, fy + PICK(4, 3), PICK(1, 2));
    tft.setTextColor(UI_TXT, UI_BG);   tft.drawString(it.v, x, fy + PICK(17, 18), F_VAL);
    x += PICK(78, 117);
  }
}

static void uiPageDrive(const VehicleData& d, const TripData& t) {
  uiGauge(d);
  uiDriveTiles(d, t);
  uiFooter(d, t);
}

// ---- página 2: motor ----
static float o2hist[48]; static int o2idx = 0;
// área das páginas motor e diagnóstico, abaixo da barra de status
#define CONTENT_X PICK(8, 8)
#define CONTENT_Y PICK(24, 36)
#define CONTENT_W PICK(304, 464)
#define CONTENT_H PICK(214, 280)
#define BAR_X  PICK(84, 130)      // início das barras
#define BAR_W  PICK(150, 230)
#define VAL_R  PICK(300, 460)     // valores alinhados à direita
static int sy(int y) { return y * CONTENT_H / 214; }   // y do layout 320x240 para a tela atual

static void uiBarRow(TFT_eSprite& sp, int y, const char* label, float pct, uint16_t col, const String& text) {
  sp.setTextDatum(ML_DATUM); sp.setTextColor(UI_MUTED, UI_BG); sp.drawString(label, 0, y, 2);
  sp.fillRoundRect(BAR_X, y - 4, BAR_W, 8, 4, UI_LINE);
  if (!isnan(pct)) sp.fillRoundRect(BAR_X, y - 4, BAR_W * constrain(pct, 0.0f, 100.0f) / 100, 8, 4, col);
  sp.setTextDatum(MR_DATUM); sp.setTextColor(UI_TXT, UI_BG); sp.drawString(text, VAL_R, y, F_VAL);
}
static void uiTrimRow(TFT_eSprite& sp, int y, const char* label, float pct) {
  sp.setTextDatum(ML_DATUM); sp.setTextColor(UI_MUTED, UI_BG); sp.drawString(label, 0, y, 2);
  const int mid = BAR_X + BAR_W / 2;
  sp.fillRoundRect(BAR_X, y - 4, BAR_W, 8, 4, UI_LINE);
  sp.drawFastVLine(mid, y - 7, 14, UI_MUTED);
  if (!isnan(pct)) {
    float p = constrain(pct, -25.0f, 25.0f); int wpx = (int)(fabs(p) / 25.0f * (BAR_W / 2));
    uint16_t c = fabs(p) < 8 ? UI_OK : fabs(p) < 15 ? UI_WARN : UI_BAD;
    sp.fillRoundRect(p >= 0 ? mid : mid - wpx, y - 4, wpx, 8, 3, c);
  }
  sp.setTextDatum(MR_DATUM); sp.setTextColor(UI_TXT, UI_BG); sp.drawString(fmtSigned(pct, 1) + "%", VAL_R, y, F_VAL);
}
static void uiPageEngine(const VehicleData& d) {
  if (!isnan(d.o2s1V)) { o2hist[o2idx] = d.o2s1V; o2idx = (o2idx + 1) % 48; }
  tile.createSprite(CONTENT_W, CONTENT_H);
  tile.fillSprite(UI_BG);
  uiBarRow(tile, sy(10), "carga",     d.loadPct,     UI_ACCENT, fmt(d.loadPct, 0) + "%");
  uiBarRow(tile, sy(34), "borboleta", d.throttlePct, UI_OK,     fmt(d.throttlePct, 0) + "%");
  // linha dupla: MAP / admissão ; avanço / malha
  auto kv = [&](int x, int y, const char* k, const String& v, uint16_t c = UI_TXT) {
    tile.setTextDatum(ML_DATUM); tile.setTextColor(UI_MUTED, UI_BG); tile.drawString(k, x, y, 2);
    tile.setTextColor(c, UI_BG); tile.drawString(v, x + (x ? PICK(66, 82) : PICK(84, 96)), y, F_VAL);
  };
  const int col2 = PICK(150, 218);
  kv(0,    sy(60), "MAP",      fmt(d.mapKpa, 0) + " kPa");
  kv(col2, sy(60), "admissao", fmt(d.intakeC, 0) + " C");
  kv(0,    sy(82), "avanco",   fmt(d.timingDeg, 0) + " graus");
  kv(col2, sy(82), "malha",    fuelSystemName(d.fuelSystem), d.fuelSystem == 2 ? UI_OK : d.fuelSystem >= 8 ? UI_BAD : UI_WARN);
  tile.drawFastHLine(0, sy(98), CONTENT_W, UI_LINE);
  uiTrimRow(tile, sy(114), "trim curto", d.stftPct);
  uiTrimRow(tile, sy(138), "trim longo", d.ltftPct);
  tile.drawFastHLine(0, sy(154), CONTENT_W, UI_LINE);
  // sondas lambda
  kv(0,    sy(172), "sonda 1", fmt(d.o2s1V, 2) + " V");
  kv(col2, sy(172), "sonda 2", fmt(d.o2s2V, 2) + " V", isnan(d.o2s2V) ? UI_MUTED : (d.o2s2V > 0.3f && d.o2s2V < 0.8f) ? UI_OK : UI_WARN);
  // mini gráfico da sonda 1 (0..1 V)
  int gx = 0, gy = sy(186), gw = CONTENT_W, gh = CONTENT_H - 4 - sy(186);
  tile.drawRect(gx, gy, gw, gh, UI_LINE);
  for (int i = 1; i < 48; i++) {
    float a = o2hist[(o2idx + i - 1) % 48], b = o2hist[(o2idx + i) % 48];
    int x1 = gx + (i - 1) * gw / 47, x2 = gx + i * gw / 47;
    tile.drawLine(x1, gy + gh - 1 - a * (gh - 2), x2, gy + gh - 1 - b * (gh - 2), UI_ACCENT);
  }
  uiPush(tile, CONTENT_X, CONTENT_Y);
  tile.deleteSprite();
}

// ---- página 3: diagnóstico ----
static void uiPageDiag(const ObdSource& src, const VehicleData& d, bool armClear, const String& scanList) {
  tile.createSprite(CONTENT_W, CONTENT_H);
  tile.fillSprite(UI_BG);
  tile.setTextDatum(TL_DATUM);
  int y = 0;
  auto line = [&](const char* k, const String& v, uint16_t c = UI_TXT) {
    tile.setTextColor(UI_MUTED, UI_BG); tile.drawString(k, 0, y, 2);
    tile.setTextColor(c, UI_BG);        tile.drawString(v, PICK(100, 140), y, 2);
    y += PICK(18, 22);
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
  tile.drawFastHLine(0, y + 2, CONTENT_W, UI_LINE); y += 8;
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
  const int by = CONTENT_H - PICK(24, 34), bh = PICK(22, 32);
  tile.fillRoundRect(0, by, CONTENT_W, bh, 6, armClear ? UI_BAD : UI_PANEL);
  tile.setTextDatum(MC_DATUM); tile.setTextColor(armClear ? 0x0000 : UI_MUTED, armClear ? UI_BAD : UI_PANEL);
  tile.drawString(armClear ? "APAGAR FALHAS? toque para confirmar" : "segure 2 s para apagar falhas", CONTENT_W / 2, by + bh / 2, 2);
  uiPush(tile, CONTENT_X, CONTENT_Y);
  tile.deleteSprite();
}

// ---- alerta em tela cheia ----
static void uiAlert(const char* title, const String& value, uint16_t color) {
  hwClear(color);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(0x0000, color);
  tft.setFreeFont(PICK(&FreeSansBold18pt7b, &FreeSansBold24pt7b));
  tft.drawString(title, SCR_W / 2, SCR_H * 90 / 240);
  tft.setFreeFont(&FreeSansBold24pt7b);
  tft.drawString(value, SCR_W / 2, SCR_H * 145 / 240);
  tft.setTextFont(2);
  hwFlush();
}

// 'S' no serial: envia a tela (RGB888) para gerar screenshot no computador
static void uiScreenshotIfRequested() {
  if (!(Serial.available() && Serial.peek() == 'S')) return;
  Serial.read();
  Serial.printf("IMG %d %d\n", SCR_W, SCR_H);
  static uint8_t row[SCR_W * 3];
  for (int y = 0; y < SCR_H; y++) { hwReadRowRGB(y, row); Serial.write(row, sizeof row); }
  Serial.println("\nEND");
}

static void uiSplash(const char* line) {
  hwClear(UI_BG);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(UI_ACCENT, UI_BG);
  tft.setFreeFont(PICK(&FreeSansBold18pt7b, &FreeSansBold24pt7b));
  const int cx = SCR_W / 2, k = SCR_H;   // posições proporcionais à altura de 240
  tft.drawString("computador", cx, k * 80 / 240);
  tft.drawString("de bordo", cx, k * 116 / 240);
  tft.fillRoundRect(cx - 30, k * 140 / 240, 60, 3, 1, UI_LINE);
  tft.setTextFont(2);
  tft.setTextColor(UI_MUTED, UI_BG);
  tft.drawString(line, cx, k * 162 / 240, F_VAL);
  hwFlush();
  uiScreenshotIfRequested();
}

static void uiBegin() {
  gauge.setColorDepth(UI_SPRITE_BPP);
  gauge.createSprite(PICK(160, 236), PICK(160, 236));
  tile.setColorDepth(UI_SPRITE_BPP);
  for (auto& v : o2hist) v = 0.45f;
  hwClear(UI_BG);
}
