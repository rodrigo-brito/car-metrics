#pragma once
// ======== Configuração do computador de bordo ========

// Fonte de dados: 0 = simulação (mock), 1 = adaptador ELM327 via Bluetooth clássico (SPP)
#ifndef OBD_SOURCE
#define OBD_SOURCE 0
#endif

// Se a conexão Bluetooth falhar, cai para o mock em vez de ficar sem dados
#define OBD_FALLBACK_TO_MOCK 1

// Adaptador (Konnwei): nome anunciado e PIN. Pode trocar por MAC em secrets.h (OBD_BT_MAC).
#ifndef OBD_BT_NAME
#define OBD_BT_NAME "OBDII"
#endif
#ifndef OBD_BT_PIN
#define OBD_BT_PIN  "1234"
#endif

// Combustível: relação ar/combustível estequiométrica e densidade (g/L).
// Gasolina pura 14.7 / 745 · Gasolina C (BR, ~27% etanol) 13.2 / 750 · Etanol 9.0 / 790
#define FUEL_AFR      13.2f
#define FUEL_DENSITY  750.0f

// Intervalos (ms)
#define UI_REFRESH_MS    100   // redesenho da tela
#define OBD_FAST_MS      150   // rpm, velocidade, MAF
#define OBD_SLOW_MS     2000   // temperatura, combustível, tensão, admissão

// Tela
#define TFT_ROTATION 1         // 1 = paisagem com USB à direita, 3 = USB à esquerda
// Algumas variantes da placa saem com as cores invertidas (fundo branco). 1 corrige.
#define TFT_INVERT   1
