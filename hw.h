#pragma once
// Hardware do ESP32-2432S028 (Cheap Yellow Display): ILI9341 320x240 por HSPI,
// touch XPT2046 em SPI separado, LED RGB (ativo em LOW), backlight no GPIO 21.
// Os pinos do TFT_eSPI vêm por flags de compilação (Makefile).
#include <TFT_eSPI.h>
#include <SPI.h>
#include <XPT2046_Touchscreen.h>
#include "config.h"

#define T_CLK 25
#define T_MOSI 32
#define T_MISO 39
#define T_CS 33
#define T_IRQ 36
#define LED_R 4
#define LED_G 16
#define LED_B 17
#define BL_PIN 21

static TFT_eSPI tft;
static SPIClass touchSpi(VSPI);
static XPT2046_Touchscreen touch(T_CS, T_IRQ);

static void ledRGB(bool r, bool g, bool b) {
  digitalWrite(LED_R, r ? LOW : HIGH); digitalWrite(LED_G, g ? LOW : HIGH); digitalWrite(LED_B, b ? LOW : HIGH);
}

static void hwBegin() {
  pinMode(LED_R, OUTPUT); pinMode(LED_G, OUTPUT); pinMode(LED_B, OUTPUT); ledRGB(false, false, false);
  pinMode(BL_PIN, OUTPUT); digitalWrite(BL_PIN, HIGH);
  tft.init();
  tft.setRotation(TFT_ROTATION);
  tft.invertDisplay(TFT_INVERT);
  touchSpi.begin(T_CLK, T_MISO, T_MOSI, T_CS);
  touch.begin(touchSpi);
  touch.setRotation(TFT_ROTATION);
}

// toque com debounce; devolve true uma vez por toque
static bool touchTapped() {
  static uint32_t last = 0;
  if (!touch.tirqTouched() || !touch.touched()) return false;
  if (millis() - last < 600) return false;
  last = millis();
  return true;
}
