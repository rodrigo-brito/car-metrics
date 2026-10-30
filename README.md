# Computador de bordo ESP32

Computador de bordo rodando num ESP32-2432S028 ("Cheap Yellow Display", tela
ILI9341 320x240 com touch). Lê os dados do carro por um adaptador OBD2 ELM327
(Konnwei KW902) via **Bluetooth Low Energy** e mostra em dark mode, em três páginas
(toque curto na tela alterna):

**Dirigir**, a página principal:
- Velocímetro com arco de rpm em gradiente (ciano → verde → laranja → vermelho).
- Cards: consumo instantâneo (km/l em movimento, l/h parado), média da viagem,
  temperatura do motor e tensão da bateria, com cor conforme a faixa; carga e borboleta
  em barras.
- Rodapé da viagem: distância, combustível gasto, l/h e velocidade máxima.
- Barra de status com fonte, estado, alerta **INJECAO** quando a luz de falha está acesa,
  e tempo de viagem.

**Motor**, para ver o que a ECU está fazendo:
- Carga e borboleta em barras; MAP, temperatura de admissão, avanço de ignição e
  estado da malha (aberta/fechada).
- Correções de combustível de curto e longo prazo em barras centradas em zero. Num flex,
  o trim longo andando para o positivo depois de abastecer indica etanol no tanque.
- Sondas lambda 1 e 2 com mini gráfico da sonda 1 oscilando.

**Diagnóstico**, um scanner básico:
- Luz de injeção, quantidade de falhas, distância rodada com a luz acesa e os códigos
  lidos pelo modo 03 (ex.: `P0171`).
- **Segurar 2 s** arma o apagamento das falhas (modo 04); um toque em até 5 s confirma.
- VIN, norma OBD, protocolo, sinal BLE, erro e heap.

**Alertas em tela cheia** por 4 s, em qualquer página, uma vez por ocorrência: motor acima
de 105 °C, bateria abaixo de 12 V com motor ligado, luz de injeção acendendo. Um toque
dispensa o alerta. Limites em `config.h`.

**LED RGB**: verde = conectado · azul = simulação · amarelo piscando = conectando ou
esperando a ECU · vermelho piscando = erro · laranja/verde alternando = luz de injeção.

Sem o carro, roda em **modo simulação** com um ciclo urbano/rodoviário.

## Arquivos

| arquivo             | conteúdo                                                    |
|---------------------|-------------------------------------------------------------|
| `eps32.ino`         | laço principal: fonte de dados, páginas, LED, log serial     |
| `config.h`          | fonte (mock/BT), nome e PIN do adaptador, combustível, timings |
| `obd_data.h`        | `VehicleData`, `TripData`, interface `ObdSource`, derivação de consumo |
| `obd_mock.h`        | simulação de condução                                       |
| `obd_elm.h`         | protocolo ELM327 (init, PIDs suportados, parse), sem transporte |
| `obd_ble.h`         | transporte BLE com NimBLE (serviço FFF0) — **o que o KONNWEI usa** |
| `obd_bt.h`          | transporte Bluetooth clássico (SPP), para adaptadores com PIN |
| `tools/ble_probe.py`| valida um adaptador BLE a partir do Mac (bleak)             |
| `tools/shot.py`     | captura a tela da placa pelo serial e salva PNG             |

Comandos pelo monitor serial, úteis para testar sem tocar na tela: `P` = toque curto
(próxima página), `L` = toque longo, `S` = despeja a tela para o `tools/shot.py`.
| `ui.h`              | desenho da interface (sprites, gauge, cards, páginas)       |
| `hw.h`              | pinos da placa, touch, LED RGB, backlight                   |
| `secrets.h`         | nome/PIN/MAC do adaptador (não versionado)                  |
| `Makefile`          | build/upload/monitor e flags de pinos do TFT_eSPI           |

## Requisitos

- `arduino-cli` com o core `esp32:esp32` 3.x e as libs `TFT_eSPI`, `XPT2046_Touchscreen`,
  `NimBLE-Arduino` (`arduino-cli lib install TFT_eSPI XPT2046_Touchscreen NimBLE-Arduino`).
- Placa ESP32-2432S028 (CH340, aparece como `/dev/cu.usbserial-XXXX`).

## Comandos

| comando                      | faz                                          |
|------------------------------|----------------------------------------------|
| `make flash`                 | compila com o padrão de `config.h` (hoje: BLE), grava e abre o serial |
| `make flash OBD_SOURCE=0`    | modo simulação, para mexer na interface na bancada |
| `make flash OBD_SOURCE=1`    | adaptador por Bluetooth clássico (SPP)        |
| `make flash OBD_SOURCE=2`    | adaptador por BLE (KONNWEI)                   |
| `make build` / `make upload` | só compila / compila e grava                 |
| `make monitor`               | monitor serial 115200 (Ctrl+C sai)           |

## Conectando no adaptador (Konnwei)

### Como o KONNWEI se conecta (descoberto na prática)

O KW902 testado é **dual-mode**: anuncia um nome `KONNWEI` por Bluetooth clássico e
outro por BLE, com o mesmo MAC. A parte clássica **não aceita pareamento de ninguém**
(ESP32 e Mac falham com "authentication failed" em qualquer combinação de PIN, SSP,
papel mestre/escravo e versão do core). A parte BLE funciona direto, sem pareamento:
serviço `FFF0`, notificações em `FFF1`, escrita em `FFF2`. O firmware usa BLE por padrão.

Para validar um adaptador novo antes de mexer no firmware, rode do Mac:

```
pip install bleak
python3 tools/ble_probe.py KONNWEI
```

Ele lista as características e executa `ATZ … 0100` e os PIDs básicos.

### No carro

1. Encaixe o adaptador no conector OBD2 (embaixo do painel, lado do motorista).
2. Ligue a ignição no contato ou dê partida. O ELM327 só responde com a ECU acordada.
3. Desligue o Bluetooth do celular se ele já pareou com o adaptador antes. O adaptador
   aceita uma conexão por vez.
4. Alimente o ESP32 pelo notebook (primeiro teste) ou por um carregador USB veicular 5 V.
5. Observe o serial (`make monitor`). O fluxo esperado:

   ```
   [obd] conectando em OBDII (tentativa 1)
   [obd] ATZ -> ELM327 v1.5
   [obd] ATE0 -> OK
   ...
   [obd] 0100 -> 41 00 BE 3E B8 11
   [obd] protocolo=A6 maf=1
   [conectado]  42 km/h  1850 rpm  12.3 km/l  motor  88C  tanque 54%  14.1V  trip 0.12 km
   ```

   LED verde e a tela saindo da simulação confirmam que os dados são do carro.

### Se não conectar

O ESP32 faz até três varreduras BLE de 6 s e lista nome, MAC, sinal e se o dispositivo
anuncia `FFF0`, no serial e na página de diagnóstico (toque na tela). Se o adaptador
não aparecer, ele está sem energia ou é só clássico; neste caso use `OBD_SOURCE=1`.

| sintoma                                     | causa provável                                       |
|---------------------------------------------|------------------------------------------------------|
| varredura não mostra o adaptador            | adaptador sem energia (ignição desligada) ou só clássico |
| conecta, `ATZ` responde, `0100` dá `UNABLE TO CONNECT` | ECU dormindo: o firmware fica em "sem ECU" e tenta a cada 5 s; ligue a ignição |
| `7F 01 12` em algum PID                     | o carro não expõe aquele PID; o valor fica `--`      |
| consumo `--` com motor ligado               | sem MAF e sem MAP; conferir a lista de PIDs no serial |
| sinal abaixo de -85 dBm                     | ESP32 longe do conector OBD2; aproxime ou mude a posição |

### Depois de validar

`OBD_SOURCE` já está em `2` (BLE) em `config.h`. Com `OBD_FALLBACK_TO_MOCK 1` a placa
cai na simulação se o adaptador não for encontrado, útil na bancada. No carro, zere
para não mostrar dados falsos. Se o adaptador estiver presente mas a ignição desligada,
o painel fica em "sem ECU" com LED amarelo e começa a ler sozinho quando a ECU acordar.

## PIDs usados

| PID  | dado                                | ritmo  | onde aparece            |
|------|-------------------------------------|--------|-------------------------|
| 010C | rpm                                 | rápido | dirigir                 |
| 010D | velocidade                          | rápido | dirigir                 |
| 0110 | MAF (fluxo de ar), se existir       | rápido | consumo                 |
| 010B | pressão do coletor (MAP)            | rápido | consumo, motor          |
| 0105 | temp. arrefecimento                 | lento  | dirigir, alerta         |
| ATRV | tensão da bateria (adaptador)       | lento  | dirigir, alerta         |
| 0101 | luz de injeção e nº de falhas       | lento  | status, diagnóstico     |
| 010F | temp. admissão                      | lento  | motor, consumo          |
| 0104 | carga do motor                      | lento  | dirigir, motor          |
| 0111 | borboleta                           | lento  | dirigir, motor          |
| 0106 | trim de combustível curto prazo     | lento  | motor                   |
| 0107 | trim de combustível longo prazo     | lento  | motor                   |
| 010E | avanço de ignição                   | lento  | motor                   |
| 0114 | sonda lambda 1                      | lento  | motor                   |
| 0115 | sonda lambda 2                      | lento  | motor                   |
| 0103 | estado do sistema de combustível    | lento  | motor                   |
| 012F | nível do tanque, se existir         | lento  | (TR4 não tem)           |
| 0121 | distância com a luz acesa           | lento  | diagnóstico             |
| 011C | norma OBD                           | 1 vez  | diagnóstico             |
| 0902 | VIN                                 | 1 vez  | diagnóstico             |
| 03   | códigos de falha                    | ao abrir diagnóstico | diagnóstico |
| 04   | apagar falhas                       | sob confirmação | diagnóstico  |

O firmware lê `0100`/`0120`/`0140` na inicialização e só consulta os PIDs que a ECU
declarou. O carro testado expõe `01 03 04 05 06 07 0B 0C 0D 0E 0F 11 13 14 15 1C 20 21`:
tem MAP (`0B`) mas **não tem MAF (`10`) nem nível de tanque (`2F`)**.

O consumo vem do fluxo de ar: `L/h = MAF(g/s) × 3600 ÷ (AFR × densidade)`. Sem MAF o
fluxo é estimado por **speed-density** com MAP, rpm e temperatura de admissão:
`MAF ≈ rpm/60 ÷ 2 × cilindrada × ρ(MAP, IAT) × VE`. AFR, densidade do combustível,
cilindrada (`ENGINE_DISPLACEMENT_L`) e eficiência volumétrica (`ENGINE_VE`) ficam em
`config.h`. Configurado para a **Pajero TR4 2010 2.0 16V flex** (2.0 L). Rodando com etanol,
troque `FUEL_AFR`/`FUEL_DENSITY` para 9.0 / 790.

## Notas

- Partição `huge_app` (3 MB) porque a pilha Bluetooth clássica é grande.
- Pinos do display passados ao TFT_eSPI por flags no Makefile; não é preciso editar
  o `User_Setup.h` da biblioteca.
- Upload a 115200 baud: o CH340 atrás de hub USB falha a 921600.
- Esta unidade sai com as cores invertidas (fundo branco); `TFT_INVERT 1` em `config.h`
  corrige. Se os tons ainda ficarem errados, veja o comentário sobre ST7789 no Makefile.

## Pendências

Estado em 2026-10-29, fim do dia. Conexão real com o carro validada.

**Validado**
- Tela, touch, LED RGB, inversão de cores da placa, modo simulação, captura de tela por serial.
- Conexão BLE com o KONNWEI, inicialização do ELM327, detecção de protocolo (CAN, `A5`),
  leitura de PIDs com ignição ligada: temperatura do motor, MAP, IAT, borboleta, tensão.
- Fallback para simulação quando o adaptador não aparece; espera pela ECU quando a ignição está desligada.
- Diagnóstico completo do Bluetooth clássico do KONNWEI (não pareia com ninguém); código mantido em `obd_bt.h` para outros adaptadores.

**Pendente, depende de rodar com o carro**
- [ ] Ver o painel com motor ligado e em movimento: rpm, velocidade, consumo, trims e sondas.
- [ ] Validar com o carro a leitura do VIN (resposta multi-quadro) e dos códigos de falha (modo 03).
- [ ] Comparar a média calculada com o consumo real abastecido e ajustar `ENGINE_VE` (cilindrada já em 2.0 L).
- [ ] Conferir a leitura de tensão (`ATRV`): o adaptador deu 28,3 V num teste e 11,8 V em outro; pode precisar de `ATCV`.
- [ ] Posicionar o ESP32 no carro: sinal BLE ficou entre -61 e -86 dBm na bancada.
- [ ] Avaliar desligar `OBD_FALLBACK_TO_MOCK` para uso no carro.

**Pendente, melhorias**
- [ ] Reconexão automática quando o BLE cair durante a viagem (hoje vai para `erro`).
- [ ] Persistir os acumulados da viagem (distância, combustível) entre desligamentos.
- [ ] Calibração do touch; hoje só detecta toque curto/longo, sem usar a posição.
- [ ] Sensor de temperatura externa (BME280) nos pinos livres; a ECU não expõe o PID 46.
- [ ] Alimentação no carro: carregador USB e caixa para a placa.
