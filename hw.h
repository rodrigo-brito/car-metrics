#pragma once
// Camada de hardware: escolhe a placa por BOARD (config.h / Makefile) e implementa o toque
// em cima de touchPressed(), que cada placa fornece. Cada placa também define:
//   tft            onde a interface desenha (o display, ou um quadro em memória)
//   SCR_W, SCR_H   tamanho da tela em paisagem
//   hwInit()       liga display, backlight, touch e LED
//   hwClear()      pinta a tela inteira
//   hwFlush()      envia o quadro desenhado para o display (vazio quando desenha direto)
//   uiPush()       coloca um sprite em tft
//   ledRGB()       LED de estado (vazio se a placa não tem)
//   hwReadRowRGB() lê uma linha da tela, para o screenshot
#include "config.h"
#if BOARD == BOARD_JC3248
#include "hw_jc3248.h"
#else
#include "hw_cyd.h"
#endif

static void touchBegin();
static void hwBegin() {
  hwInit();
  touchBegin();
}

// Toque: TOUCH_TAP ao soltar após toque curto, TOUCH_LONG uma vez após segurar 2 s.
// A leitura roda numa tarefa própria a cada 10 ms: no modo real o loop principal fica
// preso centenas de ms (até segundos) esperando o adaptador responder, e o toque se perdia.
enum TouchEvent { TOUCH_NONE, TOUCH_TAP, TOUCH_LONG };
static QueueHandle_t touchQueue = nullptr;

static TouchEvent touchDetect() {
  static bool down = false; static uint32_t t0 = 0; static bool longFired = false;
  bool now = touchPressed();
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
