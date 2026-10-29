# Computador de bordo ESP32

Computador de bordo rodando num ESP32-2432S028 ("Cheap Yellow Display", tela
ILI9341 320x240 com touch). Lê os dados do carro por um adaptador OBD2 ELM327
(Konnwei) via Bluetooth e mostra em dark mode:

- **Velocímetro** com arco de rpm em gradiente (ciano → verde → laranja → vermelho).
- **Cards**: consumo instantâneo (km/l), temperatura do motor, nível do tanque,
  tensão da bateria e média da viagem. A cor do card muda conforme a faixa.
- **Rodapé da viagem**: distância, combustível gasto, L/h e velocidade máxima.
- **Barra de status**: fonte de dados, estado da conexão e tempo de viagem.
- **Toque na tela** alterna para a página de diagnóstico (protocolo, erro,
  MAF, carga, borboleta, admissão, MAP, heap).
- **LED RGB**: verde = conectado ao carro · azul = simulação · amarelo piscando =
  conectando · vermelho piscando = erro.

Sem o carro, roda em **modo simulação** com um ciclo urbano/rodoviário.

## Arquivos

| arquivo             | conteúdo                                                    |
|---------------------|-------------------------------------------------------------|
| `eps32.ino`         | laço principal: fonte de dados, páginas, LED, log serial     |
| `config.h`          | fonte (mock/BT), nome e PIN do adaptador, combustível, timings |
| `obd_data.h`        | `VehicleData`, `TripData`, interface `ObdSource`, derivação de consumo |
| `obd_mock.h`        | simulação de condução                                       |
| `obd_elm.h`         | ELM327 via Bluetooth clássico (SPP): init, PIDs, parse       |
| `ui.h`              | desenho da interface (sprites, gauge, cards, páginas)       |
| `hw.h`              | pinos da placa, touch, LED RGB, backlight                   |
| `secrets.h`         | nome/PIN/MAC do adaptador (não versionado)                  |
| `Makefile`          | build/upload/monitor e flags de pinos do TFT_eSPI           |

## Requisitos

- `arduino-cli` com o core `esp32:esp32` 3.x e as libs `TFT_eSPI`, `XPT2046_Touchscreen`
  (`arduino-cli lib install TFT_eSPI XPT2046_Touchscreen`).
- Placa ESP32-2432S028 (CH340, aparece como `/dev/cu.usbserial-XXXX`).

## Comandos

| comando                      | faz                                          |
|------------------------------|----------------------------------------------|
| `make flash`                 | compila em modo simulação, grava e abre o serial |
| `make flash OBD_SOURCE=1`    | idem, conectando no adaptador Bluetooth       |
| `make build` / `make upload` | só compila / compila e grava                 |
| `make monitor`               | monitor serial 115200 (Ctrl+C sai)           |

## Conectando no adaptador (Konnwei)

### Antes de ir ao carro

- **Modelo do adaptador.** KW902 e similares usam Bluetooth clássico (SPP) e funcionam
  com este firmware. KW903 e modelos anunciados "para iPhone" usam BLE, que precisa
  de outra fonte de dados (ver nota abaixo).
- **Firmware em modo carro.** Grave com `make flash OBD_SOURCE=1`. A placa já sobe
  procurando o adaptador; se não achar, varre o Bluetooth e cai na simulação.
- **Notebook no primeiro teste.** O monitor serial mostra a conversa com o adaptador
  e é a única forma de ver por que algo não funcionou.

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

Depois de uma tentativa por nome (~30 s), o ESP32 varre os dispositivos Bluetooth ao
redor e lista nome, MAC e sinal no serial e na página de diagnóstico (toque na tela):

```
[obd] varrendo dispositivos bluetooth...
[obd]   OBDII 00:1D:A5:68:98:8B -62dBm
```

Use isso para preencher `secrets.h` e regrave:

```c
#define OBD_BT_NAME "OBDII"               // nome que apareceu na varredura
#define OBD_BT_PIN  "1234"                // ou "0000"
#define OBD_BT_MAC  "00:1D:A5:68:98:8B"   // conexão direta: leva segundos em vez de 30 s
```

| sintoma                                   | causa provável                                       |
|-------------------------------------------|------------------------------------------------------|
| varredura não mostra o adaptador          | adaptador sem energia (ignição desligada) ou é BLE   |
| aparece na varredura mas não conecta      | PIN errado ou celular ainda conectado nele           |
| conecta, `ATZ` responde, `0100` sem `41`  | ECU dormindo: ligue a ignição e reinicie o ESP32     |
| `0100` ok mas `NO DATA` em algum PID      | o carro não expõe aquele PID; o valor fica `--`      |
| consumo sempre `--`                       | carro sem MAF; cálculo por MAP/rpm ainda não existe  |

### Depois de validar

Troque o padrão em `config.h` para que a placa ligue direto em modo carro, sem o
notebook:

```c
#define OBD_SOURCE 1
```

Com `OBD_FALLBACK_TO_MOCK 1` ela continua caindo na simulação se o adaptador não
estiver presente, o que é útil na bancada. No carro, zere para não mostrar dados
falsos quando a conexão cair.

> **BLE**: modelos "iOS"/BLE (ex.: KW903) não usam SPP. A interface `ObdSource` permite
> adicionar uma fonte com NimBLE sem mexer na interface gráfica.

## PIDs usados

| PID  | dado                 | ritmo  |
|------|----------------------|--------|
| 010C | rpm                  | rápido |
| 010D | velocidade           | rápido |
| 0110 | MAF (fluxo de ar)    | rápido |
| 0105 | temp. arrefecimento  | lento  |
| 012F | nível do tanque      | lento  |
| ATRV | tensão da bateria    | lento  |
| 010F | temp. admissão       | lento  |
| 0104 | carga do motor       | lento  |
| 0111 | borboleta            | lento  |
| 010B | pressão do coletor   | lento  |

O consumo vem do MAF: `L/h = MAF(g/s) × 3600 ÷ (AFR × densidade)`. AFR e densidade
ficam em `config.h` (padrão: gasolina C brasileira). Carros sem MAF ficam com consumo
`--` nesta versão; o cálculo por MAP/rpm (speed-density) é o próximo passo.

## Notas

- Partição `huge_app` (3 MB) porque a pilha Bluetooth clássica é grande.
- Pinos do display passados ao TFT_eSPI por flags no Makefile; não é preciso editar
  o `User_Setup.h` da biblioteca.
- Upload a 115200 baud: o CH340 atrás de hub USB falha a 921600.
- Esta unidade sai com as cores invertidas (fundo branco); `TFT_INVERT 1` em `config.h`
  corrige. Se os tons ainda ficarem errados, veja o comentário sobre ST7789 no Makefile.

## Pendências

Estado em 2026-10-29. O que já foi validado na bancada e o que ainda depende do carro.

**Validado**
- Tela, touch, LED RGB, inversão de cores da placa e modo simulação.
- Compilação das duas variantes (`OBD_SOURCE=0` e `1`).
- Caminho de falha do Bluetooth: tentativa por nome, varredura dos dispositivos ao redor
  e fallback para simulação (~43 s até o fallback).
- Captura de tela pelo serial (comando `S`) para inspecionar a interface sem a placa à vista.

**Pendente, depende do carro**
- [ ] Primeira conexão real com o KW902 (nome `KONNWEI`, PIN `1234`). Levar o notebook e
      acompanhar o serial; respostas do ELM327 fora do formato previsto exigem ajuste no parser.
- [ ] Completar o sexto par do MAC em `secrets.h` (`5C:F0:39:14:5B:??`) para conexão direta,
      que leva segundos em vez de ~30 s. O MAC completo aparece na varredura do serial.
- [ ] Conferir quais PIDs o carro responde; os que vierem `NO DATA` ficam como `--`.
- [ ] Validar o cálculo de consumo pelo MAF contra o computador de bordo original do carro
      e ajustar `FUEL_AFR`/`FUEL_DENSITY` em `config.h` conforme o combustível usado.
- [ ] Depois de validar, trocar `OBD_SOURCE` para `1` em `config.h` e avaliar desligar
      `OBD_FALLBACK_TO_MOCK` para não mostrar dados simulados no carro.

**Pendente, melhorias**
- [ ] Consumo por MAP/rpm/temperatura de admissão (speed-density) para carros sem MAF.
- [ ] Reconexão automática quando o Bluetooth cair durante a viagem (hoje vai para `erro`).
- [ ] Fonte BLE com NimBLE para adaptadores como o KW903, usando a mesma interface `ObdSource`.
- [ ] Persistir os acumulados da viagem (distância, combustível) entre desligamentos.
- [ ] Calibração do touch; hoje só detecta toque, sem usar a posição.
- [ ] Alimentação no carro: definir carregador USB e caixa para a placa.
