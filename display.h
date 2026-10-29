#pragma once
// Painel na tela do ESP32-2432S028 (Cheap Yellow Display): ILI9341 320x240 + touch XPT2046.
// A configuração de pinos do TFT_eSPI vem por flags de compilação (ver Makefile).
#include <TFT_eSPI.h>
#include <SPI.h>
#include <XPT2046_Touchscreen.h>

// touch (barramento SPI separado)
#define T_CLK  25
#define T_MOSI 32
#define T_MISO 39
#define T_CS   33
#define T_IRQ  36

// LED RGB onboard (ativo em LOW)
#define LED_R 4
#define LED_G 16
#define LED_B 17

#define TFT_BL_PIN 21

static TFT_eSPI tft;
static SPIClass touchSpi(VSPI);
static XPT2046_Touchscreen touch(T_CS, T_IRQ);

// cores
#define C_BG    0x0841          // quase preto
#define C_CARD  0x18E3          // cinza escuro
#define C_LINE  0x2965
#define C_FG    0xEF5D
#define C_MUT   0x8C71
#define C_OK    0x2E8B          // verde
#define C_WARN  0xFE60          // amarelo
#define C_BAD   0xE946          // vermelho

static uint16_t statusColor(const String& s) {
  if (s == "ok") return C_OK;
  if (s == "degraded" || s == "warn") return C_WARN;
  if (s == "unknown" || s == "?") return C_MUT;
  return C_BAD;
}

static void ledRGB(bool r, bool g, bool b) {   // true = aceso
  digitalWrite(LED_R, r ? LOW : HIGH);
  digitalWrite(LED_G, g ? LOW : HIGH);
  digitalWrite(LED_B, b ? LOW : HIGH);
}

static void displayBegin() {
  pinMode(LED_R, OUTPUT); pinMode(LED_G, OUTPUT); pinMode(LED_B, OUTPUT);
  ledRGB(false, false, false);
  pinMode(TFT_BL_PIN, OUTPUT); digitalWrite(TFT_BL_PIN, HIGH);   // backlight
  tft.init();
  tft.setRotation(1);           // paisagem, USB à direita
  tft.fillScreen(C_BG);
  touchSpi.begin(T_CLK, T_MISO, T_MOSI, T_CS);
  touch.begin(touchSpi);
  touch.setRotation(1);
}

// tela de boot / mensagens
static void displayMessage(const char* title, const char* line) {
  tft.fillScreen(C_BG);
  tft.setTextDatum(MC_DATUM);
  tft.setTextColor(C_FG, C_BG);
  tft.drawString(title, 160, 100, 4);
  tft.setTextColor(C_MUT, C_BG);
  tft.drawString(line, 160, 135, 2);
}

// ---- layout 320x240 ----
//  y 0..34   cabeçalho: bolinha + "usestl.com/health" + status
//  y 38..110 checks (3 cards lado a lado)
//  y 114..218 operations (grade 4x2)
//  y 222..240 rodapé: ip, rssi, idade
static void drawHeader(const State& s) {
  tft.fillRect(0, 0, 320, 36, C_CARD);
  uint16_t c = statusColor(s.overall);
  tft.fillCircle(16, 18, 8, c);
  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_FG, C_CARD);
  tft.drawString("usestl.com/health", 32, 18, 4);
  tft.setTextDatum(MR_DATUM);
  tft.setTextColor(c, C_CARD);
  String ov = s.overall; ov.toUpperCase();
  tft.drawString(ov, 312, 18, 4);
}

static void drawChecks(const State& s) {
  const int y = 40, h = 68, n = s.nChecks ? s.nChecks : 1;
  const int gap = 4, w = (320 - gap * (n + 1)) / n;
  tft.fillRect(0, y, 320, h, C_BG);
  for (int i = 0; i < s.nChecks; i++) {
    int x = gap + i * (w + gap);
    tft.fillRoundRect(x, y, w, h, 6, C_CARD);
    tft.fillRect(x, y, 4, h, statusColor(s.checks[i].status));
    tft.setTextDatum(TL_DATUM);
    tft.setTextColor(C_FG, C_CARD);
    tft.drawString(s.checks[i].name, x + 10, y + 8, 2);
    tft.setTextColor(statusColor(s.checks[i].status), C_CARD);
    tft.drawString(s.checks[i].status, x + 10, y + 26, 2);
    tft.setTextColor(C_MUT, C_CARD);
    tft.drawString(String(s.checks[i].latencyMs) + " ms", x + 10, y + 46, 2);
  }
}

static void drawOps(const State& s) {
  const int y0 = 114, cols = 4, rows = 2, gap = 4;
  const int w = (320 - gap * (cols + 1)) / cols, h = 48;
  tft.fillRect(0, y0, 320, rows * (h + gap) + gap, C_BG);
  for (int i = 0; i < s.nOps && i < cols * rows; i++) {
    int x = gap + (i % cols) * (w + gap);
    int y = y0 + (i / cols) * (h + gap);
    const Operation& o = s.ops[i];
    tft.fillRoundRect(x, y, w, h, 5, C_CARD);
    tft.setTextDatum(TL_DATUM);
    tft.setTextColor(statusColor(o.status), C_CARD);
    tft.drawString(o.name, x + 6, y + 5, 2);
    int pct = (int)(o.rate * 100 + 0.5f);
    tft.setTextDatum(TR_DATUM);
    tft.setTextColor(C_FG, C_CARD);
    tft.drawString(String(pct) + "%", x + w - 6, y + 5, 2);
    tft.setTextDatum(TL_DATUM);
    tft.setTextColor(C_MUT, C_CARD);
    tft.drawString(String(o.ok) + "/" + String(o.fail), x + 6, y + 23, 1);
    // barra
    int bx = x + 6, by = y + h - 10, bw = w - 12;
    tft.fillRect(bx, by, bw, 5, C_LINE);
    uint16_t bc = pct >= 99 ? C_OK : pct >= 90 ? C_WARN : C_BAD;
    tft.fillRect(bx, by, bw * pct / 100, 5, bc);
  }
}

static void drawFooter(const State& s, bool wifiOk) {
  tft.fillRect(0, 222, 320, 18, C_BG);
  tft.setTextDatum(ML_DATUM);
  tft.setTextColor(C_MUT, C_BG);
  String l = wifiOk ? WiFi.localIP().toString() + "  " + String(WiFi.RSSI()) + "dBm" : "sem wifi";
  tft.drawString(l, 6, 231, 2);
  tft.setTextDatum(MR_DATUM);
  String r;
  if (s.error.length()) { tft.setTextColor(C_BAD, C_BG); r = s.error; }
  else if (s.lastPoll)  { r = "ha " + String((millis() - s.lastPoll) / 1000) + "s  " + String(s.pollMs) + "ms   "; }
  if (r.length() > 34) r = r.substring(0, 34);
  tft.fillRect(170, 222, 150, 18, C_BG);
  tft.drawString(r, 314, 231, 2);
}

static void displayFull(const State& s) {
  drawHeader(s); drawChecks(s); drawOps(s); drawFooter(s, WiFi.status() == WL_CONNECTED);
}

static bool touchTapped() {
  static uint32_t last = 0;
  if (!touch.tirqTouched() || !touch.touched()) return false;
  if (millis() - last < 800) return false;      // debounce
  last = millis();
  return true;
}
