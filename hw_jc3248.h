#pragma once
// Hardware da Guition JC3248W535: ESP32-S3 (16 MB flash, 8 MB PSRAM), tela IPS 3,5"
// 320x480 em retrato com controlador AXS15231B por QSPI e touch capacitivo no mesmo chip
// por I2C. Sem LED RGB.
//
// O AXS15231B não é suportado pelo TFT_eSPI e só aceita o quadro inteiro, sem rotação em
// hardware. Então a interface desenha (com a mesma API do TFT_eSPI) num sprite de 480x320
// na PSRAM, e hwFlush() gira esse quadro para retrato e envia pela Arduino_GFX.
#include <TFT_eSPI.h>
#include <Wire.h>
#include <Arduino_GFX_Library.h>
#include "config.h"

#define SCR_W 480
#define SCR_H 320
#define UI_SPRITE_BPP 16  // pushToSprite só copia entre sprites de mesma profundidade

#define LCD_CS   45
#define LCD_SCK  47
#define LCD_D0   21
#define LCD_D1   48
#define LCD_D2   40
#define LCD_D3   39
#define LCD_W    320   // retrato, como o painel é endereçado
#define LCD_H    480
#define BL_PIN   1
#define TP_SDA   4
#define TP_SCL   8
#define TP_ADDR  0x3B

static TFT_eSPI tftDev;            // nunca inicializado: só serve de pai para os sprites
static TFT_eSprite tft(&tftDev);   // quadro 480x320 onde a interface desenha
static Arduino_DataBus* lcdBus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCK, LCD_D0, LCD_D1, LCD_D2, LCD_D3);
static Arduino_GFX* lcd = new Arduino_AXS15231B(
    lcdBus, GFX_NOT_DEFINED, 0, false, LCD_W, LCD_H, 0, 0, 0, 0,
    axs15231b_320480_type1_init_operations, sizeof(axs15231b_320480_type1_init_operations));
static uint16_t* lcdBuf = nullptr; // quadro girado para retrato, no formato do painel

static void ledRGB(bool, bool, bool) {}

static void hwInit() {
  if (!lcd->begin()) Serial.println("[hw] falha ao iniciar o display AXS15231B");
  lcd->fillScreen(0x0000);
  pinMode(BL_PIN, OUTPUT); digitalWrite(BL_PIN, HIGH);
  tft.setColorDepth(16);
  if (!tft.createSprite(SCR_W, SCR_H)) Serial.println("[hw] sem memória para o quadro (PSRAM ativa?)");
  tft.fillSprite(0x0000);
  lcdBuf = (uint16_t*)ps_malloc(LCD_W * LCD_H * sizeof(uint16_t));
  Wire.begin(TP_SDA, TP_SCL, 400000);
}

// Paisagem 480x320 -> retrato 320x480. TFT_ROTATION 1 gira num sentido, 3 no outro (tela
// de cabeça para baixo: troque em config.h). O sprite guarda as cores com os bytes trocados.
static void hwFlush() {
  const uint16_t* src = (const uint16_t*)tft.getPointer();
  if (!src || !lcdBuf) return;
  for (int y = 0; y < SCR_H; y++) {
    const uint16_t* row = src + y * SCR_W;
    for (int x = 0; x < SCR_W; x++) {
      uint16_t v = row[x]; v = (v >> 8) | (v << 8);
#if TFT_ROTATION == 3
      lcdBuf[(SCR_W - 1 - x) * LCD_W + y] = v;
#else
      lcdBuf[x * LCD_W + (SCR_H - 1 - y)] = v;
#endif
    }
  }
  lcd->draw16bitRGBBitmap(0, 0, lcdBuf, LCD_W, LCD_H);
}

// fillScreen do TFT_eSPI usa o tamanho do display pai, não o do sprite: limpa só parte do quadro.
static void hwClear(uint16_t c) { tft.fillSprite(c); }

static void uiPush(TFT_eSprite& s, int x, int y) { s.pushToSprite(&tft, x, y); }

static void hwReadRowRGB(int y, uint8_t* row) {
  for (int x = 0; x < SCR_W; x++) {
    uint16_t c = tft.readPixel(x, y);
    row[x * 3]     = ((c >> 11) & 31) * 255 / 31;
    row[x * 3 + 1] = ((c >> 5) & 63) * 255 / 63;
    row[x * 3 + 2] = (c & 31) * 255 / 31;
  }
}

// Touch do AXS15231B: um comando de leitura, 8 bytes de volta; byte 1 = pontos tocados.
static bool touchPressed() {
  static const uint8_t cmd[11] = { 0xb5, 0xab, 0xa5, 0x5a, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00 };
  Wire.beginTransmission(TP_ADDR);
  Wire.write(cmd, sizeof cmd);
  if (Wire.endTransmission() != 0) return false;
  uint8_t b[8] = { 0 };
  if (Wire.requestFrom((uint8_t)TP_ADDR, (uint8_t)8) != 8) return false;
  for (auto& v : b) v = Wire.read();
  return b[1] > 0 && b[1] < 5;
}
