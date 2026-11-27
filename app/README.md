# Painel TR4 (app Android em Flutter)

Computador de bordo da **Mitsubishi Pajero TR4 2010 2.0 flex** no celular. Mostra as mesmas
métricas e as mesmas três páginas do painel ESP32 deste repositório, lendo o carro pelo
adaptador OBD2 **KONNWEI (ELM327 por Bluetooth Low Energy)** diretamente, sem passar pelo ESP32.

O adaptador aceita **um cliente BLE por vez**: enquanto o app estiver conectado, o painel
ESP32 perde a conexão (e vice-versa). Isso é esperado; o app substitui o painel quando
estiver em uso.

Sem o carro, o app roda em **modo simulação** (porte do `obd_mock.h`), com um ciclo
urbano/rodoviário e a luz de injeção acendendo aos 45 s para exercitar o alerta e a página
de diagnóstico.

## Telas

**Conexão** (inicial): `Procurar KONNWEI` varre por BLE e lista o que o firmware listaria no
serial (nome, endereço, sinal, se anuncia o serviço `FFF0`); toque no adaptador para conectar.
`Modo simulação` entra direto no painel com dados simulados.

**Dirigir**: velocímetro com arco de rpm em gradiente (ciano → verde → laranja → vermelho),
consumo instantâneo (km/l em movimento, l/h parado), média da viagem, temperatura do motor,
tensão da bateria, carga e borboleta, rodapé com distância, combustível gasto, l/h e
velocidade máxima.

**Motor**: carga e borboleta, MAP, temperatura de admissão, avanço de ignição, estado da
malha, trims de combustível de curto e longo prazo em barras centradas em zero, sondas
lambda 1 e 2 com mini gráfico da sonda 1.

**Diagnóstico**: luz de injeção, quantidade de falhas, distância com a luz acesa, códigos de
falha (modo 03), `Reler códigos`, `Apagar falhas` com diálogo de confirmação (modo 04), VIN,
norma OBD, protocolo, sinal BLE e último erro.

Barra de status em todas as páginas: ponto de estado (verde conectado, ciano simulação,
amarelo piscando conectando/sem ECU, vermelho erro), nome da página, fonte, selo
**INJEÇÃO** quando a luz está acesa, tempo de viagem e botão para desconectar.

**Alertas em tela cheia** por 4 s, uma vez por ocorrência, um toque dispensa: motor acima de
105 °C, bateria abaixo de 12 V com o motor ligado, luz de injeção acendendo.

Deslize para trocar de página ou toque nas abas embaixo. Dark mode sempre.

## Estrutura

Mesma separação do firmware: transporte, protocolo e interface.

| arquivo | conteúdo | equivale a |
|---|---|---|
| `lib/config.dart` | AFR, densidade, cilindrada, VE, intervalos, limites de alerta | `config.h` |
| `lib/data/vehicle_data.dart` | `VehicleData`, `TripData`, `ObdState`, nomes, `deriveAndIntegrate()` | `obd_data.h` |
| `lib/obd/obd_source.dart` | interface `ObdSource` (begin, update, requestDtcs, clearDtcs) | `ObdSource` |
| `lib/obd/mock_source.dart` | simulação de condução | `obd_mock.h` |
| `lib/obd/elm_link.dart` | interface do link bruto (conectar, escrever, receber bytes, RSSI) | `linkConnect/linkWrite/linkRead` |
| `lib/obd/elm_source.dart` | protocolo ELM327: `cmd()`, `parse()`, init, PIDs, modo 03/04, VIN | `obd_elm.h` |
| `lib/obd/ble_link.dart` | transporte BLE com `flutter_blue_plus` (serviço `FFF0`, `FFF1` notify, `FFF2` write) | `obd_ble.h` |
| `lib/obd/ble_scanner.dart` | permissões em tempo de execução e varredura | varredura em `obd_ble.h` |
| `lib/app/vehicle_controller.dart` | o `loop()`: um passo da fonte por vez, derivação, viagem, páginas, alertas | `eps32.ino` |
| `lib/ui/` | tema, formatação, widgets (gauge, cards, barras, sparkline, barra de status, alerta) e páginas | `ui.h` |
| `test/` | testes de protocolo (com um ELM de mentira), derivação, mock, controlador e widgets | — |

### Protocolo (porte fiel do firmware)

- Sequência de inicialização `ATZ`, `ATE0`, `ATL0`, `ATS0`, `ATH0`, `ATSP0`, `ATAT1`, depois
  `0100` com 10 s de timeout (força a busca de protocolo), `0120`/`0140` para a máscara de PIDs
  suportados e `ATDPN` para o protocolo. Se `0100` não responde, fica em "sem ECU" e tenta de
  novo a cada 5 s (ignição desligada).
- Cada comando termina em `\r`; a resposta termina no prompt `>`. **Um comando por vez**:
  `ElmSource.cmd()` enfileira; nunca há dois comandos em voo.
- Rápidos em rodízio (`0C` rpm, `0D` velocidade, `10` MAF ou `0B` MAP), rodada mínima a cada
  150 ms. Lentos em 13 posições, uma por segundo: `05`, `ATRV`, `01` (luz/falhas), `0F`, `04`,
  `11`, `06`, `07`, `0E`, `14`, `15`, `03`, `2F` ou `21`. Uma vez: `1C` (norma) e `0902` (VIN
  multi-quadro CAN). Só pede os PIDs que a ECU declarou.
- Modo `03` com o byte de contagem em CAN (protocolos 6-9, A, B, C); modo `04` para apagar.
- Consumo: `L/h = MAF × 3600 ÷ (AFR × densidade)`. Sem MAF (caso da TR4), speed-density:
  `MAF ≈ rpm/60 ÷ 2 × cilindrada × ρ(MAP, IAT) × VE`, com AFR 13.2, densidade 750 g/L,
  2.0 L e VE 0.85 em `lib/config.dart`. Com etanol, troque para 9.0 / 790.

## Requisitos

- **Flutter SDK** estável (desenvolvido e compilado com o 3.47; a pasta `android/` foi gerada
  pelo template dele, com Gradle 9.3.1, AGP 9.1.0 e Kotlin 2.4.0). Instalação:
  <https://docs.flutter.dev/get-started/install/macos/mobile-android> ou `brew install --cask flutter`.
  Depois `flutter doctor`.
- **Android SDK** com platform-tools (este Mac já tem em `~/Library/Android/sdk`) e um JDK 17+
  (o do Android Studio serve: `flutter config --jdk-dir "/Applications/Android Studio.app/Contents/jbr/Contents/Home"`).
- Celular com **Android 5.0+** e Bluetooth LE. Para instalar pelo cabo, ative a depuração USB.

## Compilar, instalar e rodar

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

O APK fica em `build/app/outputs/flutter-apk/app-debug.apk`. Instalar no celular conectado:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Ou, com o celular (ou um emulador) ligado, `flutter run` instala e abre com hot reload.
Para um APK menor e mais rápido: `flutter build apk --release` (assinado com a chave de
depuração; basta para uso próprio).

Se a sua versão do Flutter reclamar das versões do Gradle, do AGP ou do Kotlin em
`android/`, apague essa pasta e gere de novo com a versão instalada, preservando o
manifesto de permissões, os estilos (fundo preto na abertura) e os ícones:

```bash
cp -R android /tmp/android-antigo && rm -rf android
flutter create --platforms=android --org br.com.brito --project-name painel_tr4 .
cp /tmp/android-antigo/app/src/main/AndroidManifest.xml android/app/src/main/
cp -R /tmp/android-antigo/app/src/main/res/ android/app/src/main/res/
```

`gradlew`, `gradle-wrapper.jar` e `local.properties` não são versionados: o Flutter os gera
no primeiro build.

## Alternar entre simulação e KONNWEI

É uma escolha na tela inicial, não uma opção de compilação:

- **Modo simulação**: dados gerados no celular. Serve para mexer na interface e para
  conhecer as páginas. A luz de injeção acende aos 45 s; em Diagnóstico aparece `P0171` e
  `Apagar falhas` a apaga.
- **Procurar KONNWEI**: pede as permissões de Bluetooth, liga o adaptador se preciso e varre
  por 6 s. O KONNWEI aparece pelo nome (ou sem nome, anunciando `FFF0`), destacado com um
  ícone de carro. Toque nele. A barra de status passa por conectando → inicializando →
  conectado (ou "sem ECU (ignição?)" até você ligar a ignição).

Para voltar à tela inicial e trocar de fonte, toque no botão de desligar na barra de status
(ou use o botão voltar do Android).

## Permissões

Declaradas em `android/app/src/main/AndroidManifest.xml` e pedidas em tempo de execução na
primeira varredura:

| Android | permissões |
|---|---|
| 12 ou posterior (API 31+) | `BLUETOOTH_SCAN` (com `neverForLocation`) e `BLUETOOTH_CONNECT`, mostradas ao usuário como "Dispositivos por perto" |
| 11 ou anterior | `ACCESS_FINE_LOCATION` (o Android exige localização para varrer BLE), mais `BLUETOOTH`/`BLUETOOTH_ADMIN` |

Se negar, a tela inicial explica o que falta; conceda em Configurações → Apps → Painel TR4.

## No carro

1. Encaixe o adaptador no conector OBD2 (embaixo do painel, lado do motorista) e ligue a
   ignição. O ELM327 só responde com a ECU acordada.
2. Desligue o painel ESP32 (ou aceite que ele vai cair enquanto o app estiver conectado) e não
   deixe outro app de OBD conectado no adaptador.
3. Abra o app, `Procurar KONNWEI`, toque no adaptador.

| sintoma | causa provável |
|---|---|
| varredura não mostra o adaptador | adaptador sem energia (ignição desligada), ou outro cliente (ESP32, outro app) já conectado nele |
| "sem ECU (ignição?)" | adaptador respondeu mas a ECU está dormindo; ligue a ignição, o app tenta a cada 5 s |
| algum valor fica `--` | a ECU não expõe aquele PID (a TR4 não tem MAF nem nível de tanque) |
| "conexão caiu" | BLE perdido; volte à tela inicial e conecte de novo |
| sinal abaixo de -85 dBm | celular longe do conector; aproxime |

## Publicar na Google Play

Chave de upload, bundle e textos da loja: ver [PLAY_STORE.md](PLAY_STORE.md).

## Pendências

- Não testado no carro ainda: o protocolo é o mesmo do firmware validado, mas a camada
  BLE do Android (`flutter_blue_plus`) precisa ser conferida com o KONNWEI real.
- Reconexão automática quando o BLE cai durante a viagem (hoje vai para "erro").
- Persistir os acumulados da viagem entre aberturas do app.
- Manter a tela acesa e o app em primeiro plano durante a viagem (hoje o Android pode
  suspender; ver `wakelock_plus` e serviço em primeiro plano).
- Ajustar `engineVe` comparando a média com o consumo real abastecido.
