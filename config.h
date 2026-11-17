#pragma once
// ======== Configuração do computador de bordo ========

// Placa: 0 = ESP32-2432S028 "Cheap Yellow Display" (2,8" 320x240)
//        1 = Guition JC3248W535 (ESP32-S3, 3,5" 480x320, AXS15231B)
// O Makefile define pela variável BOARD (make flash BOARD=jc3248).
#define BOARD_CYD    0
#define BOARD_JC3248 1
#ifndef BOARD
#define BOARD BOARD_CYD
#endif

// Fonte de dados: 0 = simulação (mock), 1 = ELM327 via Bluetooth clássico (SPP), 2 = ELM327 via BLE
#ifndef OBD_SOURCE
#define OBD_SOURCE 2
#endif

// Se a conexão Bluetooth falhar, cai para o mock em vez de ficar sem dados
#define OBD_FALLBACK_TO_MOCK 1

// Adaptador (Konnwei): nome anunciado (vale para BLE e clássico) e PIN (só clássico).
// Pode trocar por MAC em secrets.h (OBD_BT_MAC, só clássico).
#ifndef OBD_BT_NAME
#define OBD_BT_NAME "KONNWEI"
#endif
#ifndef OBD_BT_PIN
#define OBD_BT_PIN  "1234"
#endif

// Combustível: relação ar/combustível estequiométrica e densidade (g/L).
// Gasolina pura 14.7 / 745 · Gasolina C (BR, ~27% etanol) 13.2 / 750 · Etanol 9.0 / 790
#define FUEL_AFR      13.2f
#define FUEL_DENSITY  750.0f

// Motor, para estimar fluxo de ar quando a ECU não expõe MAF (speed-density):
// MAF ≈ rpm/60 × cilindrada/2 × densidade do ar(MAP, IAT) × eficiência volumétrica
// Carro: Mitsubishi Pajero TR4 2010, 2.0 16V flex (4G94 MIVEC). Ajuste ENGINE_VE comparando
// a média com o consumo real abastecido; FUEL_AFR acima muda se rodar com etanol.
#define ENGINE_DISPLACEMENT_L 2.0f
#define ENGINE_VE             0.85f

// Intervalos (ms)
#define UI_REFRESH_MS    100   // redesenho da tela
#define OBD_FAST_MS      150   // ciclo mínimo da rodada rpm, velocidade, MAF (um PID por volta do loop)
#define OBD_SLOW_MS     1000   // demais PIDs, em rodízio de 13 posições

// Alertas em tela cheia (segundos de exibição e limites)
#define ALERT_SHOW_MS     4000
#define ALERT_COOLANT_C   105.0f
#define ALERT_BATTERY_V   12.0f    // com motor ligado

// Tela
#ifndef TFT_ROTATION
#define TFT_ROTATION 1         // 1 = paisagem com USB à direita, 3 = USB à esquerda
#endif
// Algumas variantes da placa saem com as cores invertidas (fundo branco). 1 corrige.
#define TFT_INVERT   1
