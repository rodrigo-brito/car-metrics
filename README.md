# esp32-painel

Mini painel de status rodando num ESP32-2432S028 ("Cheap Yellow Display"):
conecta no Wi-Fi, consulta `https://usestl.com/health` a cada 30 s e mostra o
resultado em quatro lugares:

- **Tela ILI9341 320x240**: cabeçalho com status geral, cards dos checks com
  latência, grade das operations com barra de taxa de sucesso e rodapé com IP,
  sinal e idade da última consulta. Tocar na tela força uma consulta imediata.
- **Página web** servida pelo próprio ESP32: `http://esp32-painel.local/` (ou pelo IP que aparece no serial).
- **Monitor serial** (115200 baud): tabela com checks e operations a cada consulta.
- **LED RGB onboard**: verde fixo = tudo ok · vermelho piscando = algum problema · azul piscando = sem Wi-Fi.

## Requisitos

- `arduino-cli` com o core `esp32:esp32` e as libs `ArduinoJson`, `TFT_eSPI` e
  `XPT2046_Touchscreen` (`arduino-cli lib install ArduinoJson TFT_eSPI XPT2046_Touchscreen`).
- Placa ESP32-2432S028 com conversor CH340 (aparece como `/dev/cu.usbserial-XXXX`).

## Configuração

1. Copie `secrets.h.example` para `secrets.h` e preencha SSID e senha.
   **O ESP32 só fala em 2.4 GHz.** Se o roteador anuncia 2.4 e 5 GHz com o mesmo
   nome ele negocia sozinho; se forem nomes diferentes use o de 2.4 GHz.
2. `make flash` compila, grava e abre o monitor serial.

## Comandos

| comando        | faz                                   |
|----------------|---------------------------------------|
| `make build`   | compila                               |
| `make upload`  | compila e grava na placa              |
| `make monitor` | abre o monitor serial (Ctrl+C sai)    |
| `make flash`   | upload + monitor                      |

## Endpoints no ESP32

- `GET /` painel HTML (auto-atualiza a cada 10 s)
- `GET /api` último estado em JSON
- `POST /refresh` força consulta imediata

## Arquivos

| arquivo           | conteúdo                                              |
|-------------------|-------------------------------------------------------|
| `eps32.ino`       | Wi-Fi, consulta à API, parse do JSON, servidor web    |
| `display.h`       | desenho do painel na tela, touch e LED RGB            |
| `dashboard.h`     | página HTML servida em `/`                            |
| `secrets.h`       | SSID e senha (não versionado)                         |
| `Makefile`        | build/upload/monitor e flags de pinos do TFT_eSPI     |

## Notas

- Os pinos do display são passados ao TFT_eSPI por flags no Makefile (`TFT_FLAGS`),
  então não é preciso editar o `User_Setup.h` da biblioteca. Se a placa for a
  variante com duas portas USB (tela ST7789, cores invertidas), siga o comentário
  no Makefile.
- O upload é feito a 115200 baud porque o CH340 atrás de hub USB falha a 921600.

- O TLS usa `setInsecure()` (não valida o certificado do servidor). Para validar,
  troque por `client.setCACert(...)` com a raiz da Cloudflare/Let's Encrypt.
- Para mudar a URL ou o intervalo edite `HEALTH_URL` e `POLL_MS` em `eps32.ino`.
