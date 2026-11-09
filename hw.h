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

static void touchBegin();
static void hwBegin() {
  pinMode(LED_R, OUTPUT); pinMode(LED_G, OUTPUT); pinMode(LED_B, OUTPUT); ledRGB(false, false, false);
  pinMode(BL_PIN, OUTPUT); digitalWrite(BL_PIN, HIGH);
  tft.init();
  tft.setRotation(TFT_ROTATION);
  tft.invertDisplay(TFT_INVERT);
  touchSpi.begin(T_CLK, T_MISO, T_MOSI, T_CS);
  touch.begin(touchSpi);
  touch.setRotation(TFT_ROTATION);
  touchBegin();
}

// Toque: TOUCH_TAP ao soltar após toque curto, TOUCH_LONG uma vez após segurar 2 s.
// A leitura roda numa tarefa própria a cada 10 ms: no modo real o loop principal fica
// preso centenas de ms (até segundos) esperando o adaptador responder, e o toque se perdia.
enum TouchEvent { TOUCH_NONE, TOUCH_TAP, TOUCH_LONG };
static QueueHandle_t touchQueue = nullptr;

static TouchEvent touchDetect() {
  static bool down = false; static uint32_t t0 = 0; static bool longFired = false;
  bool now = touch.tirqTouched() && touch.touched();
  if (now && !down) { down = true; t0 = millis(); longFired = false; return TOUCH_NONE; }
  if (now && down) {
    if (!longFired && millis() - t0 >= 2000) { longFired = true; return TOUCH_LONG; }
    return TOUCH_NONE;
  }
  if (!now && down) {
    down = false;
    if (!longFired && millis() - t0 >= 40 && millis() - t0 < 700) return TOUCH_TAP;
  }
  return TOUCH_NONE;
}

static void touchTask(void*) {
  for (;;) {
    TouchEvent ev = touchDetect();
    if (ev != TOUCH_NONE) xQueueSend(touchQueue, &ev, 0);   // fila cheia: descarta
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

static void touchBegin() {
  touchQueue = xQueueCreate(2, sizeof(TouchEvent));
  xTaskCreatePinnedToCore(touchTask, "touch", 3072, nullptr, 2, nullptr, 1);  // mesmo core do loop, prioridade acima
}

// Consumido pelo loop: devolve o próximo evento pendente ou TOUCH_NONE.
static TouchEvent touchPoll() {
  TouchEvent ev;
  if (touchQueue && xQueueReceive(touchQueue, &ev, 0) == pdTRUE) return ev;
  return TOUCH_NONE;
}
